// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {AbstractCallback} from "@reactive/abstract-base/AbstractCallback.sol";
import {IAavePool} from "./interfaces/IAavePool.sol";

/**
 * @title YieldVaultDualAsset
 * @notice Compares yields between two Aave markets (USDC vs DAI)
 * @dev Live system approach when protocols use different tokens on testnet
 */
contract YieldVaultDualAsset is Ownable, ReentrancyGuard, AbstractCallback {
    using SafeERC20 for IERC20;

    // ═══════════════════════════════════════════════════════════════
    //                         STATE VARIABLES
    // ═══════════════════════════════════════════════════════════════

    /// @notice Primary asset (USDC)
    IERC20 public immutable primaryAsset;
    /// @notice Secondary asset (DAI)  
    IERC20 public immutable secondaryAsset;
    
    /// @notice Aave V3 Pool
    IAavePool public immutable aavePool;
    
    /// @notice aToken for primary asset
    IERC20 public immutable primaryAToken;
    /// @notice aToken for secondary asset
    IERC20 public immutable secondaryAToken;
    
    /// @notice Current allocation to primary (basis points)
    uint256 public primaryAllocation = 5000; // 50%
    /// @notice Allocation to secondary (10000 - primary)
    
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

    /// @notice Minimum ETH required for callback payments
    uint256 public constant MIN_CALLBACK_FUNDING = 0.05 ether;
    
    /**
     * @param _primaryAsset USDC token address
     * @param _secondaryAsset DAI token address
     * @param _aavePool Aave V3 Pool address
     * @param _primaryAToken aUSDC token address
     * @param _secondaryAToken aDAI token address
     * @param _callbackProxy Reactive Network callback proxy on this chain
     * @dev Must be deployed with at least 0.05 ETH for callback payment
     */
    constructor(
        address _primaryAsset,    // USDC
        address _secondaryAsset,  // DAI
        address _aavePool,
        address _primaryAToken,   // aUSDC
        address _secondaryAToken, // aDAI
        address _callbackProxy
    ) payable Ownable(msg.sender) AbstractCallback(_callbackProxy) {
        // Require minimum ETH for callback fees to prevent blocklisting
        require(msg.value >= MIN_CALLBACK_FUNDING, "Insufficient callback funding: need >= 0.05 ETH");
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

    function depositPrimary(uint256 amount) external nonReentrant {
        primaryAsset.safeTransferFrom(msg.sender, address(this), amount);
        aavePool.supply(address(primaryAsset), amount, address(this), 0);
        emit Deposited(msg.sender, address(primaryAsset), amount);
        _emitSnapshot();
    }

    function depositSecondary(uint256 amount) external nonReentrant {
        secondaryAsset.safeTransferFrom(msg.sender, address(this), amount);
        aavePool.supply(address(secondaryAsset), amount, address(this), 0);
        emit Deposited(msg.sender, address(secondaryAsset), amount);
        _emitSnapshot();
    }

    function withdrawPrimary(uint256 amount) external nonReentrant onlyOwner {
        aavePool.withdraw(address(primaryAsset), amount, msg.sender);
        emit Withdrawn(msg.sender, address(primaryAsset), amount);
    }

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

    function getTotalValueLocked() public view returns (uint256) {
        // Returns combined value (simplified - assumes 1:1 for stablecoins)
        uint256 primaryBal = primaryAToken.balanceOf(address(this));
        uint256 secondaryBal = secondaryAToken.balanceOf(address(this));
        // Normalize to 6 decimals (USDC) - DAI is 18 decimals
        return primaryBal + (secondaryBal / 1e12);
    }

    // ═══════════════════════════════════════════════════════════════
    //                      ADMIN FUNCTIONS
    // ═══════════════════════════════════════════════════════════════

    function setRvmId(address _rvmId) external onlyOwner {
        rvm_id = _rvmId;
    }

    receive() external payable override {}
}
