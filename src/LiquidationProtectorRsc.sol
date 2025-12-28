// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AbstractReactive} from "@reactive/abstract-base/AbstractReactive.sol";
import {AbstractPayer} from "@reactive/abstract-base/AbstractPayer.sol";
import {IReactive} from "@reactive/interfaces/IReactive.sol";
import {IPayer} from "@reactive/interfaces/IPayer.sol";

/**
 * @title LiquidationProtectorRsc
 * @notice Reactive Smart Contract for automated liquidation protection
 * @dev Monitors Aave health factors and triggers protective actions
 * 
 * Architecture:
 * - Subscribes to HealthFactorUpdated events from Aave
 * - Triggers protective callbacks when health factor drops below threshold
 * - Supports multiple protection strategies: add collateral, repay debt, or hybrid
 * 
 * Protection Flow:
 * 1. User registers for protection with strategy and reserve funds
 * 2. RSC monitors health factor events
 * 3. When HF < threshold, RSC emits callback to execute protection
 * 4. ProtectionVault on Sepolia executes the chosen strategy
 */
contract LiquidationProtectorRsc is IReactive, AbstractReactive {
    // ═══════════════════════════════════════════════════════════════
    //                         CONSTANTS
    // ═══════════════════════════════════════════════════════════════

    /// @notice Sepolia chain ID
    uint256 private constant SEPOLIA_CHAIN_ID = 11155111;
    
    /// @notice Default callback gas limit
    uint64 private constant CALLBACK_GAS_LIMIT = 300000;
    
    /// @notice Health factor threshold (1.1 = 10% buffer above liquidation)
    /// @dev Stored as 1e18 scaled value (1.1e18 = 1.1)
    uint256 public constant DEFAULT_PROTECTION_THRESHOLD = 1.1e18;
    
    /// @notice Minimum health factor to trigger protection (safety floor)
    uint256 public constant MIN_HEALTH_FACTOR = 1.05e18;
    
    /// @notice Event signature for HealthFactorUpdated (computed from ABI)
    /// @dev keccak256("HealthFactorUpdated(address,uint256)")
    uint256 private constant HEALTH_FACTOR_TOPIC_0 = 0x0;  // To be computed

    // ═══════════════════════════════════════════════════════════════
    //                         ENUMS
    // ═══════════════════════════════════════════════════════════════

    /// @notice Available protection strategies
    enum ProtectionStrategy {
        ADD_COLLATERAL,    // Deposit more collateral from reserve
        REPAY_DEBT,        // Use reserve to repay borrowed amount
        HYBRID             // Combination of both strategies
    }

    // ═══════════════════════════════════════════════════════════════
    //                         STRUCTS
    // ═══════════════════════════════════════════════════════════════

    /// @notice User protection configuration
    struct UserProtection {
        address user;               // User's address
        address protectionVault;    // Vault holding reserve funds
        ProtectionStrategy strategy; // Chosen strategy
        uint256 triggerThreshold;   // Health factor threshold to trigger
        uint256 reserveAmount;      // Funds set aside for protection
        bool active;                // Whether protection is enabled
    }

    // ═══════════════════════════════════════════════════════════════
    //                         STATE
    // ═══════════════════════════════════════════════════════════════

    /// @notice Owner address
    address public owner;
    
    /// @notice Aave Pool address on Sepolia
    address public aavePool;
    
    /// @notice Default protection vault on Sepolia
    address public defaultProtectionVault;
    
    /// @notice User protection configurations
    mapping(address => UserProtection) public userProtections;
    
    /// @notice List of protected users for iteration
    address[] public protectedUsers;
    
    /// @notice Count of protection triggers
    uint256 public totalProtectionTriggers;
    
    /// @notice Paused state
    bool public paused;

    // ═══════════════════════════════════════════════════════════════
    //                         EVENTS
    // ═══════════════════════════════════════════════════════════════

    event ProtectionRegistered(
        address indexed user,
        ProtectionStrategy strategy,
        uint256 threshold,
        uint256 reserveAmount
    );
    
    event ProtectionTriggered(
        address indexed user,
        uint256 healthFactor,
        ProtectionStrategy strategy,
        uint256 amountUsed
    );
    
    event ProtectionDeactivated(address indexed user);
    
    event OwnerUpdated(address indexed oldOwner, address indexed newOwner);
    
    event VaultUpdated(address indexed oldVault, address indexed newVault);

    // ═══════════════════════════════════════════════════════════════
    //                         ERRORS
    // ═══════════════════════════════════════════════════════════════

    error OnlyOwner();
    error ZeroAddress();
    error InvalidThreshold();
    error AlreadyProtected();
    error NotProtected();
    error Paused();

    // ═══════════════════════════════════════════════════════════════
    //                         MODIFIERS
    // ═══════════════════════════════════════════════════════════════

    modifier onlyOwner() {
        if (msg.sender != owner) revert OnlyOwner();
        _;
    }
    
    modifier whenNotPaused() {
        if (paused) revert Paused();
        _;
    }

    // ═══════════════════════════════════════════════════════════════
    //                         CONSTRUCTOR
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Initialize the liquidation protector RSC
     * @param _aavePool Aave Pool address on Sepolia
     * @param _protectionVault Default protection vault address
     */
    constructor(
        address _aavePool,
        address _protectionVault
    ) payable {
        if (_aavePool == address(0)) revert ZeroAddress();
        if (_protectionVault == address(0)) revert ZeroAddress();
        
        owner = msg.sender;
        aavePool = _aavePool;
        defaultProtectionVault = _protectionVault;
    }

    // ═══════════════════════════════════════════════════════════════
    //                    SUBSCRIPTION MANAGEMENT
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Subscribe to health factor events from Aave
     * @dev Must be called on Reactive Network (rnOnly modifier)
     */
    function subscribeToHealthFactor() external rnOnly {
        service.subscribe(
            SEPOLIA_CHAIN_ID,
            aavePool,
            HEALTH_FACTOR_TOPIC_0,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE
        );
    }
    
    /**
     * @notice Unsubscribe from health factor events
     */
    function unsubscribe() external rnOnly onlyOwner {
        bytes memory payload = abi.encodeWithSignature(
            "unsubscribe(uint256,address,uint256,uint256,uint256,uint256)",
            SEPOLIA_CHAIN_ID,
            aavePool,
            HEALTH_FACTOR_TOPIC_0,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE
        );
        (bool success,) = address(service).call(payload);
        require(success, "Unsubscribe failed");
    }

    // ═══════════════════════════════════════════════════════════════
    //                    USER PROTECTION MANAGEMENT
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Register a user for liquidation protection
     * @param user User address to protect
     * @param strategy Protection strategy to use
     * @param threshold Health factor threshold to trigger protection
     * @param reserveAmount Amount of funds reserved for protection
     */
    function registerProtection(
        address user,
        ProtectionStrategy strategy,
        uint256 threshold,
        uint256 reserveAmount
    ) external onlyOwner {
        if (user == address(0)) revert ZeroAddress();
        if (threshold < MIN_HEALTH_FACTOR) revert InvalidThreshold();
        if (userProtections[user].active) revert AlreadyProtected();
        
        userProtections[user] = UserProtection({
            user: user,
            protectionVault: defaultProtectionVault,
            strategy: strategy,
            triggerThreshold: threshold,
            reserveAmount: reserveAmount,
            active: true
        });
        
        protectedUsers.push(user);
        
        emit ProtectionRegistered(user, strategy, threshold, reserveAmount);
    }
    
    /**
     * @notice Update protection configuration for a user
     * @param user User address
     * @param strategy New strategy
     * @param threshold New threshold
     */
    function updateProtection(
        address user,
        ProtectionStrategy strategy,
        uint256 threshold
    ) external onlyOwner {
        if (!userProtections[user].active) revert NotProtected();
        if (threshold < MIN_HEALTH_FACTOR) revert InvalidThreshold();
        
        userProtections[user].strategy = strategy;
        userProtections[user].triggerThreshold = threshold;
    }
    
    /**
     * @notice Deactivate protection for a user
     * @param user User address
     */
    function deactivateProtection(address user) external onlyOwner {
        if (!userProtections[user].active) revert NotProtected();
        
        userProtections[user].active = false;
        
        emit ProtectionDeactivated(user);
    }

    // ═══════════════════════════════════════════════════════════════
    //                    REACTIVE FUNCTION
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice React to HealthFactorUpdated events
     * @dev Called by ReactVM when subscribed events are detected
     * @param log The log record from the event
     */
    function react(IReactive.LogRecord calldata log) external override vmOnly whenNotPaused {
        // Validate origin
        if (log.chain_id != SEPOLIA_CHAIN_ID) {
            return;
        }
        if (log._contract != aavePool) {
            return;
        }
        
        // Decode health factor update
        // Expected event: HealthFactorUpdated(address indexed user, uint256 healthFactor)
        address user = address(uint160(uint256(log.topic_1)));
        uint256 healthFactor = abi.decode(log.data, (uint256));
        
        // Check if user has active protection
        UserProtection storage protection = userProtections[user];
        if (!protection.active) {
            return;
        }
        
        // Check if health factor is below threshold
        if (healthFactor >= protection.triggerThreshold) {
            return; // Health factor is safe, no action needed
        }
        
        // Trigger protection
        _executeProtection(user, healthFactor, protection);
    }

    // ═══════════════════════════════════════════════════════════════
    //                    PROTECTION EXECUTION
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Execute the protection strategy
     * @param user User being protected
     * @param currentHF Current health factor
     * @param protection User's protection configuration
     */
    function _executeProtection(
        address user,
        uint256 currentHF,
        UserProtection storage protection
    ) internal {
        totalProtectionTriggers++;
        
        // Calculate required amount based on how far below threshold
        uint256 deficit = protection.triggerThreshold - currentHF;
        uint256 requiredAmount = (protection.reserveAmount * deficit) / 1e18;
        
        // Cap at reserve amount
        if (requiredAmount > protection.reserveAmount) {
            requiredAmount = protection.reserveAmount;
        }
        
        // Emit callback based on strategy
        if (protection.strategy == ProtectionStrategy.ADD_COLLATERAL) {
            _emitAddCollateralCallback(user, requiredAmount, protection.protectionVault);
        } else if (protection.strategy == ProtectionStrategy.REPAY_DEBT) {
            _emitRepayDebtCallback(user, requiredAmount, protection.protectionVault);
        } else {
            // HYBRID: 50% collateral, 50% repay
            uint256 halfAmount = requiredAmount / 2;
            _emitAddCollateralCallback(user, halfAmount, protection.protectionVault);
            _emitRepayDebtCallback(user, halfAmount, protection.protectionVault);
        }
        
        // Update reserve (in RN state, not ReactVM)
        if (!vm) {
            protection.reserveAmount -= requiredAmount;
        }
        
        emit ProtectionTriggered(user, currentHF, protection.strategy, requiredAmount);
    }
    
    /**
     * @notice Emit callback to add collateral
     */
    function _emitAddCollateralCallback(
        address user,
        uint256 amount,
        address vault
    ) internal {
        bytes memory payload = abi.encodeWithSignature(
            "addEmergencyCollateral(address,uint256)",
            user,
            amount
        );
        
        emit Callback(
            SEPOLIA_CHAIN_ID,
            vault,
            CALLBACK_GAS_LIMIT,
            payload
        );
    }
    
    /**
     * @notice Emit callback to repay debt
     */
    function _emitRepayDebtCallback(
        address user,
        uint256 amount,
        address vault
    ) internal {
        bytes memory payload = abi.encodeWithSignature(
            "repayEmergencyDebt(address,uint256)",
            user,
            amount
        );
        
        emit Callback(
            SEPOLIA_CHAIN_ID,
            vault,
            CALLBACK_GAS_LIMIT,
            payload
        );
    }

    // ═══════════════════════════════════════════════════════════════
    //                    ADMIN FUNCTIONS
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Transfer ownership
     * @param newOwner New owner address
     */
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address oldOwner = owner;
        owner = newOwner;
        emit OwnerUpdated(oldOwner, newOwner);
    }
    
    /**
     * @notice Update default protection vault
     * @param newVault New vault address
     */
    function setProtectionVault(address newVault) external onlyOwner {
        if (newVault == address(0)) revert ZeroAddress();
        address oldVault = defaultProtectionVault;
        defaultProtectionVault = newVault;
        emit VaultUpdated(oldVault, newVault);
    }
    
    /**
     * @notice Update Aave pool address
     * @param newPool New pool address
     */
    function setAavePool(address newPool) external onlyOwner {
        if (newPool == address(0)) revert ZeroAddress();
        aavePool = newPool;
    }
    
    /**
     * @notice Pause protection triggers
     */
    function pause() external onlyOwner {
        paused = true;
    }
    
    /**
     * @notice Unpause protection triggers
     */
    function unpause() external onlyOwner {
        paused = false;
    }

    // ═══════════════════════════════════════════════════════════════
    //                    VIEW FUNCTIONS
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Get protection status for a user
     */
    function getProtectionStatus(address user) external view returns (
        bool active,
        ProtectionStrategy strategy,
        uint256 threshold,
        uint256 reserveAmount
    ) {
        UserProtection storage p = userProtections[user];
        return (p.active, p.strategy, p.triggerThreshold, p.reserveAmount);
    }
    
    /**
     * @notice Get total number of protected users
     */
    function getProtectedUserCount() external view returns (uint256) {
        return protectedUsers.length;
    }
    
    /**
     * @notice Get all protected users
     */
    function getAllProtectedUsers() external view returns (address[] memory) {
        return protectedUsers;
    }
    
    /**
     * @notice Receive function for REACT tokens
     */
    receive() external payable override(AbstractPayer, IPayer) {}
}
