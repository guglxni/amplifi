// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {AbstractCallback} from "@reactive/abstract-base/AbstractCallback.sol";
import {IAavePool} from "./interfaces/IAavePool.sol";

/**
 * @title IVaultFeeCollector
 * @notice Interface for the fee collector
 */
interface IVaultFeeCollector {
    function collectFee(uint256 txValue) external payable;
    function calculateFee(uint256 txValue) external view returns (uint256);
}

/**
 * @title YieldVaultDualAssetV2
 * @notice Compares yields between two Aave markets (USDC vs DAI) with auto-replenishment
 * @dev Includes True Auto-Replenishment pattern:
 *      - Charges small fees on deposits/withdrawals
 *      - Sends fees to VaultFeeCollector
 *      - VaultFeeCollector funds this vault when low on ETH
 *      - Prevents blocklisting due to callback payment failures
 */
contract YieldVaultDualAssetV2 is Ownable, ReentrancyGuard, AbstractCallback {
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
    
    /// @notice Minimum ETH required for callback payments
    uint256 public constant MIN_CALLBACK_FUNDING = 0.05 ether;

    // ═══════════════════════════════════════════════════════════════
    //                     AUTO-REPLENISHMENT STATE
    // ═══════════════════════════════════════════════════════════════

    /// @notice Fee collector contract address
    IVaultFeeCollector public feeCollector;
    
    /// @notice Whether fee collection is enabled
    bool public feeCollectionEnabled = true;
    
    /// @notice Minimum required ETH balance before accepting fee-paying operations
    uint256 public minOperationalBalance = 0.01 ether;

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
    
    /// @notice Auto-replenishment events
    event FeeCollectorSet(address indexed oldCollector, address indexed newCollector);
    event FeePaid(address indexed user, uint256 amount);
    event FeeCollectionToggled(bool enabled);
    event Funded(address indexed from, uint256 amount);

    // ═══════════════════════════════════════════════════════════════
    //                        CONSTRUCTOR
    // ═══════════════════════════════════════════════════════════════

    /**
     * @param _primaryAsset USDC token address
     * @param _secondaryAsset DAI token address
     * @param _aavePool Aave V3 Pool address
     * @param _primaryAToken aUSDC token address
     * @param _secondaryAToken aDAI token address
     * @param _callbackProxy Reactive Network callback proxy on this chain
     * @param _feeCollector VaultFeeCollector address (can be zero initially)
     * @dev Must be deployed with at least 0.05 ETH for callback payment
     */
    constructor(
        address _primaryAsset,    // USDC
        address _secondaryAsset,  // DAI
        address _aavePool,
        address _primaryAToken,   // aUSDC
        address _secondaryAToken, // aDAI
        address _callbackProxy,
        address _feeCollector
    ) payable Ownable(msg.sender) AbstractCallback(_callbackProxy) {
        // Require minimum ETH for callback fees to prevent blocklisting
        require(msg.value >= MIN_CALLBACK_FUNDING, "Insufficient callback funding: need >= 0.05 ETH");
        
        primaryAsset = IERC20(_primaryAsset);
        secondaryAsset = IERC20(_secondaryAsset);
        aavePool = IAavePool(_aavePool);
        primaryAToken = IERC20(_primaryAToken);
        secondaryAToken = IERC20(_secondaryAToken);
        
        if (_feeCollector != address(0)) {
            feeCollector = IVaultFeeCollector(_feeCollector);
            emit FeeCollectorSet(address(0), _feeCollector);
        }
        
        // Approve Aave for max
        IERC20(_primaryAsset).approve(_aavePool, type(uint256).max);
        IERC20(_secondaryAsset).approve(_aavePool, type(uint256).max);
    }

    // ═══════════════════════════════════════════════════════════════
    //                      DEPOSIT/WITHDRAW
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Deposit primary asset (USDC)
     * @param amount Amount to deposit
     * @dev Requires msg.value to cover fee for auto-replenishment
     */
    function depositPrimary(uint256 amount) external payable nonReentrant {
        _collectFee(amount);
        
        primaryAsset.safeTransferFrom(msg.sender, address(this), amount);
        aavePool.supply(address(primaryAsset), amount, address(this), 0);
        emit Deposited(msg.sender, address(primaryAsset), amount);
        _emitSnapshot();
    }

    /**
     * @notice Deposit secondary asset (DAI)
     * @param amount Amount to deposit
     * @dev Requires msg.value to cover fee for auto-replenishment
     */
    function depositSecondary(uint256 amount) external payable nonReentrant {
        _collectFee(amount);
        
        secondaryAsset.safeTransferFrom(msg.sender, address(this), amount);
        aavePool.supply(address(secondaryAsset), amount, address(this), 0);
        emit Deposited(msg.sender, address(secondaryAsset), amount);
        _emitSnapshot();
    }

    /**
     * @notice Withdraw primary asset
     * @param amount Amount to withdraw
     */
    function withdrawPrimary(uint256 amount) external payable nonReentrant onlyOwner {
        _collectFee(amount);
        aavePool.withdraw(address(primaryAsset), amount, msg.sender);
        emit Withdrawn(msg.sender, address(primaryAsset), amount);
    }

    /**
     * @notice Withdraw secondary asset
     * @param amount Amount to withdraw
     */
    function withdrawSecondary(uint256 amount) external payable nonReentrant onlyOwner {
        _collectFee(amount);
        aavePool.withdraw(address(secondaryAsset), amount, msg.sender);
        emit Withdrawn(msg.sender, address(secondaryAsset), amount);
    }

    // ═══════════════════════════════════════════════════════════════
    //                      FEE COLLECTION
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Collect fee and forward to fee collector
     * @param txValue Transaction value for percentage calculation
     */
    function _collectFee(uint256 txValue) internal {
        if (!feeCollectionEnabled || address(feeCollector) == address(0)) {
            return;
        }
        
        // Calculate required fee
        uint256 requiredFee = feeCollector.calculateFee(txValue);
        
        if (msg.value > 0) {
            if (msg.value >= requiredFee) {
                // Forward fee to collector
                feeCollector.collectFee{value: msg.value}(txValue);
                emit FeePaid(msg.sender, msg.value);
            } else {
                // Partial fee - keep it in vault for self-funding
                emit FeePaid(msg.sender, msg.value);
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    //                    SNAPSHOT FUNCTIONS
    // ═══════════════════════════════════════════════════════════════

    function triggerYieldSnapshot() external {
        _emitSnapshot();
    }

    function _emitSnapshot() internal {
        uint256 primaryAPY = getPrimaryAPY();
        uint256 secondaryAPY = getSecondaryAPY();
        uint256 tvl = getTotalValueLocked();
        uint256 secondary = 10000 - primaryAllocation;
        
        snapshotCounter++;
        
        emit YieldSnapshot(
            snapshotCounter,
            primaryAPY,
            secondaryAPY,
            primaryAllocation,
            secondary,
            tvl,
            block.timestamp
        );
    }

    // ═══════════════════════════════════════════════════════════════
    //                    REBALANCE CALLBACK
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
        return data.currentLiquidityRate / 1e23;
    }

    function getSecondaryAPY() public view returns (uint256) {
        IAavePool.ReserveData memory data = aavePool.getReserveData(address(secondaryAsset));
        return data.currentLiquidityRate / 1e23;
    }

    function getTotalValueLocked() public view returns (uint256) {
        return primaryAToken.balanceOf(address(this)) + secondaryAToken.balanceOf(address(this));
    }

    // ═══════════════════════════════════════════════════════════════
    //                AUTO-REPLENISHMENT ADMIN
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Set fee collector address
     */
    function setFeeCollector(address _feeCollector) external onlyOwner {
        address old = address(feeCollector);
        feeCollector = IVaultFeeCollector(_feeCollector);
        emit FeeCollectorSet(old, _feeCollector);
    }
    
    /**
     * @notice Toggle fee collection
     */
    function setFeeCollectionEnabled(bool enabled) external onlyOwner {
        feeCollectionEnabled = enabled;
        emit FeeCollectionToggled(enabled);
    }
    
    /**
     * @notice Set minimum operational balance
     */
    function setMinOperationalBalance(uint256 balance) external onlyOwner {
        minOperationalBalance = balance;
    }

    // ═══════════════════════════════════════════════════════════════
    //                      VIEW FUNCTIONS
    // ═══════════════════════════════════════════════════════════════

    function setRvmId(address _rvm_id) external onlyOwner {
        rvm_id = _rvm_id;
    }

    function getRvmId() external view returns (address) {
        return rvm_id;
    }
    
    /**
     * @notice Check if vault has sufficient callback funding
     */
    function hasSufficientFunding() external view returns (bool) {
        return address(this).balance >= minOperationalBalance;
    }
    
    /**
     * @notice Get fee required for a transaction
     */
    function getRequiredFee(uint256 txValue) external view returns (uint256) {
        if (address(feeCollector) == address(0)) return 0;
        return feeCollector.calculateFee(txValue);
    }

    /**
     * @notice Receive ETH for callback funding
     */
    receive() external payable override {
        emit Funded(msg.sender, msg.value);
    }
}
