// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {AbstractCallback} from "@reactive/abstract-base/AbstractCallback.sol";
import {IAavePool} from "./interfaces/IAavePool.sol";

/**
 * @title YieldVaultWethLink
 * @notice Compares yields between WETH and LINK on Aave V3
 * @dev Uses assets with no supply cap on Sepolia testnet to avoid error 51
 * 
 * Why WETH/LINK instead of USDC/DAI?
 * - USDC and DAI have supply caps that are already exceeded on Sepolia testnet
 * - WETH and LINK have supply cap = 0 (unlimited) and work properly
 * - This demonstrates the same yield optimization logic with functional assets
 */
contract YieldVaultWethLink is Ownable, ReentrancyGuard, AbstractCallback {
    using SafeERC20 for IERC20;

    // ═══════════════════════════════════════════════════════════════
    //                         STATE VARIABLES
    // ═══════════════════════════════════════════════════════════════

    /// @notice Primary asset (WETH)
    IERC20 public immutable primaryAsset;
    /// @notice Secondary asset (LINK)  
    IERC20 public immutable secondaryAsset;
    
    /// @notice Aave V3 Pool
    IAavePool public immutable aavePool;
    
    /// @notice aToken for primary asset (aWETH)
    IERC20 public immutable primaryAToken;
    /// @notice aToken for secondary asset (aLINK)
    IERC20 public immutable secondaryAToken;
    
    /// @notice Current allocation to primary (basis points)
    uint256 public primaryAllocation = 5000; // 50%
    
    /// @notice Snapshot counter for events
    uint256 public snapshotCounter;
    
    /// @notice Last rebalance timestamp
    uint256 public lastRebalanceTime;
    
    /// @notice Minimum time between rebalances
    uint256 public constant MIN_REBALANCE_INTERVAL = 5 minutes;

    // ═══════════════════════════════════════════════════════════════
    //                           EVENTS
    // ═══════════════════════════════════════════════════════════════

    event YieldSnapshot(
        uint256 indexed snapshotId,
        uint256 primaryAPY,
        uint256 secondaryAPY,
        uint256 primaryAlloc,
        uint256 secondaryAlloc,
        uint256 tvl,
        uint256 timestamp
    );

    event Deposited(address indexed user, address token, uint256 amount);
    event Withdrawn(address indexed user, address token, uint256 amount);
    event Rebalanced(uint256 newPrimaryAlloc, uint256 newSecondaryAlloc);

    // ═══════════════════════════════════════════════════════════════
    //                        CONSTRUCTOR
    // ═══════════════════════════════════════════════════════════════

    constructor(
        address _primaryAsset,    // WETH: 0xC558DBdd856501FCd9aaF1E62eae57A9F0629a3c
        address _secondaryAsset,  // LINK: 0xf8Fb3713D459D7C1018BD0A49D19b4C44290EBE5
        address _aavePool,        // Pool: 0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951
        address _primaryAToken,   // aWETH: 0x5b071b590a59395fE4025A0Ccc1FcC931AAc1830
        address _secondaryAToken, // aLINK: 0x3FfAf50D4F4E96eB78f2407c090b72e86eCaed24
        address _callbackProxy
    ) Ownable(msg.sender) AbstractCallback(_callbackProxy) {
        primaryAsset = IERC20(_primaryAsset);
        secondaryAsset = IERC20(_secondaryAsset);
        aavePool = IAavePool(_aavePool);
        primaryAToken = IERC20(_primaryAToken);
        secondaryAToken = IERC20(_secondaryAToken);
        
        // Approve Aave for max
        IERC20(_primaryAsset).approve(_aavePool, type(uint256).max);
        IERC20(_secondaryAsset).approve(_aavePool, type(uint256).max);
    }

    // ═══════════════════════════════════════════════════════════════
    //                      DEPOSIT/WITHDRAW
    // ═══════════════════════════════════════════════════════════════

    /// @notice Deposit WETH (primary asset)
    function depositPrimary(uint256 amount) external nonReentrant {
        primaryAsset.safeTransferFrom(msg.sender, address(this), amount);
        aavePool.supply(address(primaryAsset), amount, address(this), 0);
        emit Deposited(msg.sender, address(primaryAsset), amount);
        _emitSnapshot();
    }

    /// @notice Deposit LINK (secondary asset)
    function depositSecondary(uint256 amount) external nonReentrant {
        secondaryAsset.safeTransferFrom(msg.sender, address(this), amount);
        aavePool.supply(address(secondaryAsset), amount, address(this), 0);
        emit Deposited(msg.sender, address(secondaryAsset), amount);
        _emitSnapshot();
    }

    /// @notice Withdraw WETH
    function withdrawPrimary(uint256 amount) external nonReentrant onlyOwner {
        aavePool.withdraw(address(primaryAsset), amount, msg.sender);
        emit Withdrawn(msg.sender, address(primaryAsset), amount);
    }

    /// @notice Withdraw LINK
    function withdrawSecondary(uint256 amount) external nonReentrant onlyOwner {
        aavePool.withdraw(address(secondaryAsset), amount, msg.sender);
        emit Withdrawn(msg.sender, address(secondaryAsset), amount);
    }

    // ═══════════════════════════════════════════════════════════════
    //                      YIELD SNAPSHOT
    // ═══════════════════════════════════════════════════════════════

    function triggerYieldSnapshot() external {
        _emitSnapshot();
    }

    function _emitSnapshot() internal {
        uint256 primaryAPY = getPrimaryAPY();
        uint256 secondaryAPY = getSecondaryAPY();
        uint256 tvl = getTotalValueLocked();
        
        snapshotCounter++;
        
        emit YieldSnapshot(
            snapshotCounter,
            primaryAPY,
            secondaryAPY,
            primaryAllocation,
            10000 - primaryAllocation,
            tvl,
            block.timestamp
        );
    }

    // ═══════════════════════════════════════════════════════════════
    //                   REBALANCE (RSC Callback)
    // ═══════════════════════════════════════════════════════════════

    function executeRebalance(
        address /* _rvm */,
        uint256 newPrimaryPct,
        uint256 newSecondaryPct
    ) external authorizedSenderOnly {
        require(
            block.timestamp >= lastRebalanceTime + MIN_REBALANCE_INTERVAL,
            "Rebalance too soon"
        );
        require(newPrimaryPct + newSecondaryPct == 10000, "Invalid allocation");
        
        primaryAllocation = newPrimaryPct;
        lastRebalanceTime = block.timestamp;
        
        emit Rebalanced(newPrimaryPct, newSecondaryPct);
        _emitSnapshot();
    }

    // ═══════════════════════════════════════════════════════════════
    //                      APY FUNCTIONS
    // ═══════════════════════════════════════════════════════════════

    function getPrimaryAPY() public view returns (uint256) {
        IAavePool.ReserveData memory data = aavePool.getReserveData(address(primaryAsset));
        // liquidityRate is in RAY (1e27), convert to basis points
        return data.currentLiquidityRate / 1e23;
    }

    function getSecondaryAPY() public view returns (uint256) {
        IAavePool.ReserveData memory data = aavePool.getReserveData(address(secondaryAsset));
        return data.currentLiquidityRate / 1e23;
    }

    /// @notice Get total value locked in ETH terms
    /// @dev Both WETH and LINK are 18 decimals, but we normalize to ETH value
    function getTotalValueLocked() public view returns (uint256) {
        // Both assets are 18 decimals
        uint256 primaryBal = primaryAToken.balanceOf(address(this));
        uint256 secondaryBal = secondaryAToken.balanceOf(address(this));
        // For simplicity, return raw balance sum (for real-world, use oracle for USD conversion)
        return primaryBal + secondaryBal;
    }

    /// @notice Get TVL in USD using simple price assumption
    /// @dev For demo purposes - assumes WETH=$2000, LINK=$15
    function getTotalValueLockedUSD() public view returns (uint256) {
        uint256 primaryBal = primaryAToken.balanceOf(address(this));
        uint256 secondaryBal = secondaryAToken.balanceOf(address(this));
        // WETH at ~$2000, LINK at ~$15 (rough testnet estimates)
        // Returns value with 6 decimal precision
        uint256 wethValueUSD = (primaryBal * 2000) / 1e12; // 18 decimals -> 6 decimals * $2000
        uint256 linkValueUSD = (secondaryBal * 15) / 1e12;  // 18 decimals -> 6 decimals * $15
        return wethValueUSD + linkValueUSD;
    }

    // ═══════════════════════════════════════════════════════════════
    //                      ADMIN FUNCTIONS
    // ═══════════════════════════════════════════════════════════════

    function setRvmId(address _rvmId) external onlyOwner {
        rvm_id = _rvmId;
    }

    receive() external payable override {}
}
