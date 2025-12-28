// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {AbstractCallback} from "@reactive/abstract-base/AbstractCallback.sol";

/**
 * @title ILendingPool
 * @notice Minimal interface for Aave-like lending pool
 */
interface ILendingPool {
    function supply(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode
    ) external;
    
    function repay(
        address asset,
        uint256 amount,
        uint256 rateMode,
        address onBehalfOf
    ) external returns (uint256);
    
    function getUserAccountData(address user) external view returns (
        uint256 totalCollateralBase,
        uint256 totalDebtBase,
        uint256 availableBorrowsBase,
        uint256 currentLiquidationThreshold,
        uint256 ltv,
        uint256 healthFactor
    );
}

/**
 * @title ProtectionVault
 * @notice Vault for holding and deploying liquidation protection reserves
 * @dev Receives callbacks from LiquidationProtectorRsc via Callback Proxy
 * 
 * Features:
 * - Users can deposit reserve funds for protection
 * - Supports both collateral addition and debt repayment
 * - Only Callback Proxy can trigger protection actions
 * - Tracks protection metrics per user
 */
contract ProtectionVault is Ownable, ReentrancyGuard, AbstractCallback {
    using SafeERC20 for IERC20;

    // ═══════════════════════════════════════════════════════════════
    //                         CONSTANTS
    // ═══════════════════════════════════════════════════════════════

    /// @notice Variable rate mode for Aave repayments
    uint256 private constant VARIABLE_RATE_MODE = 2;
    
    /// @notice Minimum reserve to maintain (0.01 ETH worth)
    uint256 public constant MIN_RESERVE = 0.01 ether;

    // ═══════════════════════════════════════════════════════════════
    //                         STATE
    // ═══════════════════════════════════════════════════════════════

    /// @notice Aave Pool address
    ILendingPool public immutable lendingPool;
    
    /// @notice Default collateral token (WETH)
    IERC20 public collateralToken;
    
    /// @notice Default debt token (USDC or DAI)
    IERC20 public debtToken;
    
    /// @notice User reserve balances (in collateral token)
    mapping(address => uint256) public userReserves;
    
    /// @notice Total reserves held
    uint256 public totalReserves;
    
    /// @notice Protection triggers count per user
    mapping(address => uint256) public protectionTriggers;
    
    /// @notice Total ETH used for protection
    mapping(address => uint256) public totalProtectionUsed;

    // ═══════════════════════════════════════════════════════════════
    //                         EVENTS
    // ═══════════════════════════════════════════════════════════════

    event ReserveDeposited(address indexed user, uint256 amount);
    event ReserveWithdrawn(address indexed user, uint256 amount);
    event CollateralAdded(address indexed user, uint256 amount);
    event DebtRepaid(address indexed user, uint256 amount);
    event TokensUpdated(address collateral, address debt);

    // ═══════════════════════════════════════════════════════════════
    //                         ERRORS
    // ═══════════════════════════════════════════════════════════════

    error InsufficientReserve();
    error ZeroAmount();
    error TransferFailed();

    // ═══════════════════════════════════════════════════════════════
    //                         CONSTRUCTOR
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Initialize the protection vault
     * @param _lendingPool Aave Pool address
     * @param _callbackProxy Reactive Callback Proxy address
     * @param _collateralToken Default collateral token (WETH)
     * @param _debtToken Default debt token (USDC)
     */
    constructor(
        address _lendingPool,
        address _callbackProxy,
        address _collateralToken,
        address _debtToken
    ) payable Ownable(msg.sender) AbstractCallback(_callbackProxy) {
        lendingPool = ILendingPool(_lendingPool);
        collateralToken = IERC20(_collateralToken);
        debtToken = IERC20(_debtToken);
        
        // Approve lending pool for token transfers
        IERC20(_collateralToken).approve(_lendingPool, type(uint256).max);
        IERC20(_debtToken).approve(_lendingPool, type(uint256).max);
    }

    // ═══════════════════════════════════════════════════════════════
    //                    USER RESERVE MANAGEMENT
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Deposit reserve funds for protection
     * @param amount Amount of collateral token to deposit
     */
    function depositReserve(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        
        collateralToken.safeTransferFrom(msg.sender, address(this), amount);
        
        userReserves[msg.sender] += amount;
        totalReserves += amount;
        
        emit ReserveDeposited(msg.sender, amount);
    }
    
    /**
     * @notice Withdraw reserve funds
     * @param amount Amount to withdraw
     */
    function withdrawReserve(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (userReserves[msg.sender] < amount) revert InsufficientReserve();
        
        userReserves[msg.sender] -= amount;
        totalReserves -= amount;
        
        collateralToken.safeTransfer(msg.sender, amount);
        
        emit ReserveWithdrawn(msg.sender, amount);
    }

    // ═══════════════════════════════════════════════════════════════
    //                    PROTECTION CALLBACKS
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Add emergency collateral to user's Aave position
     * @dev Only callable by Callback Proxy (from RSC)
     * @param user User to protect
     * @param amount Amount of collateral to add
     */
    function addEmergencyCollateral(
        address user,
        uint256 amount
    ) external authorizedSenderOnly nonReentrant {
        if (userReserves[user] < amount) {
            // Use whatever is available
            amount = userReserves[user];
        }
        
        if (amount == 0) return;
        
        // Deduct from reserves
        userReserves[user] -= amount;
        totalReserves -= amount;
        
        // Supply collateral to Aave on behalf of user
        lendingPool.supply(
            address(collateralToken),
            amount,
            user,
            0 // referral code
        );
        
        // Track metrics
        protectionTriggers[user]++;
        totalProtectionUsed[user] += amount;
        
        emit CollateralAdded(user, amount);
    }
    
    /**
     * @notice Repay emergency debt from user's Aave position
     * @dev Only callable by Callback Proxy (from RSC)
     * @param user User to protect
     * @param amount Amount of debt to repay
     */
    function repayEmergencyDebt(
        address user,
        uint256 amount
    ) external authorizedSenderOnly nonReentrant {
        if (userReserves[user] < amount) {
            amount = userReserves[user];
        }
        
        if (amount == 0) return;
        
        // Deduct from reserves
        userReserves[user] -= amount;
        totalReserves -= amount;
        
        // For debt repayment, we need to swap collateral to debt token
        // In production, this would use a DEX - for now, assume 1:1 for simplicity
        // TODO: Integrate with Uniswap or similar
        
        // Repay debt on behalf of user
        lendingPool.repay(
            address(debtToken),
            amount,
            VARIABLE_RATE_MODE,
            user
        );
        
        // Track metrics
        protectionTriggers[user]++;
        totalProtectionUsed[user] += amount;
        
        emit DebtRepaid(user, amount);
    }

    // ═══════════════════════════════════════════════════════════════
    //                    ADMIN FUNCTIONS
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Update token addresses
     * @param _collateral New collateral token
     * @param _debt New debt token
     */
    function setTokens(address _collateral, address _debt) external onlyOwner {
        collateralToken = IERC20(_collateral);
        debtToken = IERC20(_debt);
        
        // Approve new tokens
        IERC20(_collateral).approve(address(lendingPool), type(uint256).max);
        IERC20(_debt).approve(address(lendingPool), type(uint256).max);
        
        emit TokensUpdated(_collateral, _debt);
    }
    
    /**
     * @notice Emergency withdraw all tokens (owner only)
     * @param token Token to withdraw
     * @param to Recipient address
     */
    function emergencyWithdraw(address token, address to) external onlyOwner {
        uint256 balance = IERC20(token).balanceOf(address(this));
        IERC20(token).safeTransfer(to, balance);
    }

    // ═══════════════════════════════════════════════════════════════
    //                    VIEW FUNCTIONS
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Get user's current health factor from Aave
     * @param user User address
     */
    function getUserHealthFactor(address user) external view returns (uint256) {
        (,,,,, uint256 healthFactor) = lendingPool.getUserAccountData(user);
        return healthFactor;
    }
    
    /**
     * @notice Get user's protection stats
     * @param user User address
     */
    function getUserStats(address user) external view returns (
        uint256 reserve,
        uint256 triggers,
        uint256 totalUsed
    ) {
        return (
            userReserves[user],
            protectionTriggers[user],
            totalProtectionUsed[user]
        );
    }
    
    /**
     * @notice Get vault stats
     */
    function getVaultStats() external view returns (
        uint256 totalReservesHeld,
        address collateral,
        address debt
    ) {
        return (
            totalReserves,
            address(collateralToken),
            address(debtToken)
        );
    }
    
    /**
     * @notice Receive function for ETH
     */
    receive() external payable override {}
}
