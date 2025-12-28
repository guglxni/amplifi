// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title AuditLogger
 * @notice Library for consistent audit logging across YieldOpt contracts
 * @dev Provides standardized events and logging utilities for security and compliance
 */
library AuditLogger {
    // ═══════════════════════════════════════════════════════════════
    //                     AUDIT EVENTS
    // ═══════════════════════════════════════════════════════════════

    /// @notice Emitted when an admin action is performed
    event AdminAction(
        address indexed actor,
        bytes4 indexed selector,
        bytes32 indexed actionType,
        bytes data,
        uint256 timestamp
    );

    /// @notice Emitted when a critical configuration change occurs
    event ConfigurationChanged(
        address indexed contract_,
        bytes32 indexed parameter,
        bytes32 oldValue,
        bytes32 newValue,
        uint256 timestamp
    );

    /// @notice Emitted when a security-sensitive operation happens
    event SecurityEvent(
        address indexed contract_,
        bytes32 indexed eventType,
        address indexed actor,
        bytes details,
        uint256 timestamp
    );

    /// @notice Emitted when funds are moved
    event FundsMovement(
        address indexed contract_,
        bytes32 indexed operation,
        address indexed token,
        address from,
        address to,
        uint256 amount,
        uint256 timestamp
    );

    /// @notice Emitted for cross-chain operations
    event CrossChainActivity(
        uint256 indexed sourceChain,
        uint256 indexed destinationChain,
        bytes32 indexed operationType,
        address sourceContract,
        address destContract,
        bytes payload,
        uint256 timestamp
    );

    /// @notice Emitted when RSC callback is received
    event RSCCallback(
        address indexed rvm,
        bytes4 indexed functionSelector,
        bytes data,
        uint256 gasUsed,
        uint256 timestamp
    );

    // ═══════════════════════════════════════════════════════════════
    //                     ACTION TYPES
    // ═══════════════════════════════════════════════════════════════

    bytes32 public constant ACTION_ASSET_ADDED = keccak256("ASSET_ADDED");
    bytes32 public constant ACTION_ASSET_REMOVED = keccak256("ASSET_REMOVED");
    bytes32 public constant ACTION_ALLOCATION_CHANGED = keccak256("ALLOCATION_CHANGED");
    bytes32 public constant ACTION_PRICE_UPDATED = keccak256("PRICE_UPDATED");
    bytes32 public constant ACTION_REBALANCE = keccak256("REBALANCE");
    bytes32 public constant ACTION_DEPOSIT = keccak256("DEPOSIT");
    bytes32 public constant ACTION_WITHDRAW = keccak256("WITHDRAW");
    bytes32 public constant ACTION_EMERGENCY = keccak256("EMERGENCY");
    bytes32 public constant ACTION_OWNERSHIP = keccak256("OWNERSHIP");
    
    bytes32 public constant SECURITY_ACCESS_GRANTED = keccak256("ACCESS_GRANTED");
    bytes32 public constant SECURITY_ACCESS_REVOKED = keccak256("ACCESS_REVOKED");
    bytes32 public constant SECURITY_CALLBACK_RECEIVED = keccak256("CALLBACK_RECEIVED");
    bytes32 public constant SECURITY_UNAUTHORIZED = keccak256("UNAUTHORIZED_ATTEMPT");

    // ═══════════════════════════════════════════════════════════════
    //                     LOGGING FUNCTIONS
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Log an admin action
     * @param actor Address performing the action
     * @param selector Function selector being called
     * @param actionType Type of action
     * @param data Additional data
     */
    function logAdminAction(
        address actor,
        bytes4 selector,
        bytes32 actionType,
        bytes memory data
    ) internal {
        emit AdminAction(actor, selector, actionType, data, block.timestamp);
    }

    /**
     * @notice Log a configuration change
     * @param parameter Parameter being changed
     * @param oldValue Previous value
     * @param newValue New value
     */
    function logConfigChange(
        bytes32 parameter,
        bytes32 oldValue,
        bytes32 newValue
    ) internal {
        emit ConfigurationChanged(
            address(this),
            parameter,
            oldValue,
            newValue,
            block.timestamp
        );
    }

    /**
     * @notice Log a security event
     * @param eventType Type of security event
     * @param actor Address involved
     * @param details Additional details
     */
    function logSecurityEvent(
        bytes32 eventType,
        address actor,
        bytes memory details
    ) internal {
        emit SecurityEvent(
            address(this),
            eventType,
            actor,
            details,
            block.timestamp
        );
    }

    /**
     * @notice Log a funds movement
     * @param operation Type of operation
     * @param token Token being moved
     * @param from Source address
     * @param to Destination address
     * @param amount Amount moved
     */
    function logFundsMovement(
        bytes32 operation,
        address token,
        address from,
        address to,
        uint256 amount
    ) internal {
        emit FundsMovement(
            address(this),
            operation,
            token,
            from,
            to,
            amount,
            block.timestamp
        );
    }

    /**
     * @notice Log cross-chain activity
     * @param sourceChain Source chain ID
     * @param destChain Destination chain ID
     * @param opType Operation type
     * @param sourceContract Source contract
     * @param destContract Destination contract
     * @param payload Transaction payload
     */
    function logCrossChain(
        uint256 sourceChain,
        uint256 destChain,
        bytes32 opType,
        address sourceContract,
        address destContract,
        bytes memory payload
    ) internal {
        emit CrossChainActivity(
            sourceChain,
            destChain,
            opType,
            sourceContract,
            destContract,
            payload,
            block.timestamp
        );
    }

    /**
     * @notice Log RSC callback
     * @param rvm RVM address
     * @param selector Function selector
     * @param data Callback data
     * @param gasUsed Gas used
     */
    function logRSCCallback(
        address rvm,
        bytes4 selector,
        bytes memory data,
        uint256 gasUsed
    ) internal {
        emit RSCCallback(rvm, selector, data, gasUsed, block.timestamp);
    }
}
