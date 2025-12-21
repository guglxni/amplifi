// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {AbstractCallback} from "@reactive/abstract-base/AbstractCallback.sol";
import {IAavePool} from "./interfaces/IAavePool.sol";

/**
 * @title YieldVaultStablePlus
 * @notice Yield optimization between EURS (stablecoin) and AAVE token on Aave V3
 * @dev Uses assets with NO SUPPLY CAP on Sepolia testnet to avoid error 51
 * 
 * Why EURS/AAVE instead of USDC/DAI?
 * - USDC and DAI have supply caps that are exceeded on Sepolia testnet
 * - EURS (Euro stablecoin) and AAVE token have supplyCap = 0 (unlimited)
 * - This demonstrates the same yield optimization logic with functional assets
 * 
 * Asset Details:
 * - EURS: 2 decimals, Euro-pegged stablecoin
 * - AAVE: 18 decimals, Aave governance token
 */
contract YieldVaultStablePlus is Ownable, ReentrancyGuard, AbstractCallback {
    using SafeERC20 for IERC20;

    // ═══════════════════════════════════════════════════════════════
    //                         STATE VARIABLES
    // ═══════════════════════════════════════════════════════════════

    /// @notice Primary asset (EURS - stablecoin)
    IERC20 public immutable primaryAsset;
    /// @notice Secondary asset (AAVE token)  
    IERC20 public immutable secondaryAsset;
    
    /// @notice Aave V3 Pool
    IAavePool public immutable aavePool;
    
    /// @notice aToken for primary asset (aEURS)
    IERC20 public immutable primaryAToken;
    /// @notice aToken for secondary asset (aAAVE)
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
        address _primaryAsset,    // EURS: 0x6d906e526a4e2Ca02097BA9d0caA3c382F52278E
        address _secondaryAsset,  // AAVE: 0x88541670E55cC00bEEFD87eB59EDd1b7C511AC9a
        address _aavePool,        // Pool: 0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951
        address _primaryAToken,   // aEURS: 0xB20691021F9AcED8631eDaa3c0Cd2949EB45662D
        address _secondaryAToken, // aAAVE: 0x6b8558764d3b7572136F17174Cb9aB1DDc7E1259
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

    /// @notice Deposit EURS (primary stablecoin)
    function depositPrimary(uint256 amount) external nonReentrant {
        primaryAsset.safeTransferFrom(msg.sender, address(this), amount);
        aavePool.supply(address(primaryAsset), amount, address(this), 0);
        emit Deposited(msg.sender, address(primaryAsset), amount);
        _emitSnapshot();
    }

    /// @notice Deposit AAVE (secondary asset - governance token)
    function depositSecondary(uint256 amount) external nonReentrant {
        secondaryAsset.safeTransferFrom(msg.sender, address(this), amount);
        aavePool.supply(address(secondaryAsset), amount, address(this), 0);
        emit Deposited(msg.sender, address(secondaryAsset), amount);
        _emitSnapshot();
    }

    /// @notice Withdraw EURS
    function withdrawPrimary(uint256 amount) external nonReentrant onlyOwner {
        aavePool.withdraw(address(primaryAsset), amount, msg.sender);
        emit Withdrawn(msg.sender, address(primaryAsset), amount);
    }

    /// @notice Withdraw AAVE
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

    /// @notice Get total value locked in USD terms (normalized)
    /// @dev EURS (2 decimals) normalized to 6 decimals, AAVE (18 decimals) at ~$100
    function getTotalValueLocked() public view returns (uint256) {
        uint256 eursBal = primaryAToken.balanceOf(address(this));
        uint256 aaveBal = secondaryAToken.balanceOf(address(this));
        
        // EURS is 2 decimals, convert to 6 decimals for USD display
        // Assume 1 EUR ≈ 1.05 USD
        uint256 eursValueUSD = eursBal * 10500; // 2 decimals * 10500 / 10000 = ~1.05 USD per EUR
        
        // AAVE is 18 decimals, assume ~$100 per AAVE for testnet display
        uint256 aaveValueUSD = (aaveBal * 100) / 1e12; // 18 decimals -> 6 decimals * $100
        
        return eursValueUSD + aaveValueUSD;
    }

    /// @notice Get raw TVL (sum of aToken balances, not USD normalized)
    function getTotalValueLockedRaw() public view returns (uint256 eursBal, uint256 aaveBal) {
        eursBal = primaryAToken.balanceOf(address(this));
        aaveBal = secondaryAToken.balanceOf(address(this));
    }

    // ═══════════════════════════════════════════════════════════════
    //                      ADMIN FUNCTIONS
    // ═══════════════════════════════════════════════════════════════

    function setRvmId(address _rvmId) external onlyOwner {
        rvm_id = _rvmId;
    }

    receive() external payable override {}
}
