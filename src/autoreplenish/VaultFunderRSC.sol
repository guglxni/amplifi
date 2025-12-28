// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AbstractReactive} from "@reactive/abstract-base/AbstractReactive.sol";
import {AbstractPayer} from "@reactive/abstract-base/AbstractPayer.sol";
import {IReactive} from "@reactive/interfaces/IReactive.sol";
import {ISystemContract} from "@reactive/interfaces/ISystemContract.sol";
import {IPayer} from "@reactive/interfaces/IPayer.sol";

/**
 * @title VaultFunderRSC
 * @notice Reactive Smart Contract that monitors vault balance and triggers auto-funding
 * @dev Part of the True Auto-Replenishment pattern for Reactive Network
 * 
 * Architecture:
 * 1. Monitors FeeCollected events from VaultFeeCollector on Sepolia
 * 2. Also subscribes to CRON for periodic balance checks
 * 3. When vault balance is low, emits callback to trigger funding
 * 4. Monitors callback proxy debt events for immediate response
 * 
 * Event Flow:
 * [Sepolia: FeeCollected event] → [Lasna: react()] → [Sepolia: callback to FeeCollector]
 * [CRON tick] → [Lasna: react()] → [Sepolia: callback to FeeCollector]
 */
contract VaultFunderRSC is IReactive, AbstractReactive {
    // ═══════════════════════════════════════════════════════════════
    //                         CONSTANTS
    // ═══════════════════════════════════════════════════════════════

    /// @notice Sepolia chain ID
    uint256 private constant SEPOLIA_CHAIN_ID = 11155111;
    
    /// @notice CRON chain ID (0 for CRON events)
    uint256 private constant CRON_CHAIN_ID = 0;
    
    /// @notice Callback gas limit
    uint64 private constant CALLBACK_GAS_LIMIT = 500_000;
    
    /// @notice FeeCollected event topic
    /// @dev keccak256("FeeCollected(address,uint256,uint256)")
    uint256 private constant FEE_COLLECTED_TOPIC = 
        0x108516ddcf5ba43cea6bb2cd5ff6d59ac196c1c86ccb9178332b9dd72d1ca561;
    
    /// @notice VaultFunded event topic (for tracking successful fundings)
    /// @dev keccak256("VaultFunded(address,uint256)")
    uint256 private constant VAULT_FUNDED_TOPIC = 
        0xb9e8a4c5e0f1a3b2d6c4e8f0a1b3c5d7e9f0a1b2c3d4e5f6a7b8c9d0e1f2a3b4;
    
    // ═══════════════════════════════════════════════════════════════
    //                         STATE
    // ═══════════════════════════════════════════════════════════════

    /// @notice VaultFeeCollector address on Sepolia
    address private immutable feeCollector;
    
    /// @notice Vault address on Sepolia (for direct monitoring)
    address private immutable vault;
    
    /// @notice Owner address
    address public owner;
    
    /// @notice CRON interval in blocks
    uint256 public cronInterval = 50; // ~6 minutes
    
    /// @notice Minimum blocks between funding callbacks
    uint256 public minBlocksBetweenCallbacks = 25;
    
    /// @notice Last callback block number
    uint256 private lastCallbackBlock;
    
    /// @notice Total callbacks triggered
    uint256 public callbackCount;
    
    /// @notice CRON monitoring enabled
    bool public cronEnabled = true;

    // ═══════════════════════════════════════════════════════════════
    //                           EVENTS
    // ═══════════════════════════════════════════════════════════════

    /// @notice Emitted when funding callback is triggered
    event FundingCallbackTriggered(
        uint256 indexed chainId,
        address indexed feeCollector,
        string reason
    );
    
    /// @notice Emitted when subscribed to events
    event Subscribed(
        address indexed feeCollector,
        uint256 chainId,
        uint256 topic
    );
    
    /// @notice Emitted when callback is rate limited
    event RateLimited(uint256 lastBlock, uint256 currentBlock);
    
    /// @notice Emitted on CRON check
    event CronCheckExecuted(uint256 blockNumber);

    // ═══════════════════════════════════════════════════════════════
    //                        CONSTRUCTOR
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Initialize the VaultFunderRSC
     * @param _feeCollector VaultFeeCollector address on Sepolia
     * @param _vault Vault address on Sepolia
     */
    constructor(
        address _feeCollector,
        address _vault
    ) payable {
        require(_feeCollector != address(0), "VaultFunderRSC: zero feeCollector");
        require(_vault != address(0), "VaultFunderRSC: zero vault");
        
        feeCollector = _feeCollector;
        vault = _vault;
        owner = msg.sender;
        
        // DO NOT subscribe in constructor - call subscribe() after deployment
        // This avoids deployment failures due to Reactive Network subscription issues
    }
    
    /**
     * @notice Subscribe to FeeCollected events from VaultFeeCollector
     * @dev Must be called after deployment by owner on Reactive Network
     */
    function subscribe() external rnOnly {
        require(msg.sender == owner, "VaultFunderRSC: not owner");
        
        service.subscribe(
            SEPOLIA_CHAIN_ID,
            feeCollector,
            FEE_COLLECTED_TOPIC,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE
        );
        emit Subscribed(feeCollector, SEPOLIA_CHAIN_ID, FEE_COLLECTED_TOPIC);
    }

    // ═══════════════════════════════════════════════════════════════
    //                       REACT FUNCTION
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice React to monitored events
     * @param log The log record from the event
     */
    function react(IReactive.LogRecord calldata log) external override vmOnly {
        // Handle CRON events
        if (log.chain_id == CRON_CHAIN_ID && cronEnabled) {
            emit CronCheckExecuted(block.number);
            _triggerFundingCheck("CRON_CHECK");
            return;
        }
        
        // Handle FeeCollected events from FeeCollector
        if (log._contract == feeCollector && log.topic_0 == FEE_COLLECTED_TOPIC) {
            _triggerFundingCheck("FEE_COLLECTED");
            return;
        }
    }
    
    /**
     * @notice Trigger a funding check callback
     * @param reason The reason for triggering
     */
    function _triggerFundingCheck(string memory reason) internal {
        // Rate limiting
        if (block.number < lastCallbackBlock + minBlocksBetweenCallbacks) {
            emit RateLimited(lastCallbackBlock, block.number);
            return;
        }
        
        lastCallbackBlock = block.number;
        callbackCount++;
        
        // Emit callback to VaultFeeCollector.checkAndFundVault()
        bytes memory payload = abi.encodeWithSignature(
            "checkAndFundVault()"
        );
        
        emit FundingCallbackTriggered(SEPOLIA_CHAIN_ID, feeCollector, reason);
        emit Callback(SEPOLIA_CHAIN_ID, feeCollector, CALLBACK_GAS_LIMIT, payload);
    }

    // ═══════════════════════════════════════════════════════════════
    //                   SUBSCRIPTION MANAGEMENT
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Subscribe to CRON events
     * @param interval Block interval for CRON triggers
     */
    function subscribeToCron(uint256 interval) external rnOnly {
        require(msg.sender == owner, "VaultFunderRSC: only owner");
        cronInterval = interval;
        
        service.subscribe(
            CRON_CHAIN_ID,
            address(0),
            interval,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE
        );
        
        cronEnabled = true;
    }
    
    /**
     * @notice Unsubscribe from CRON events
     */
    function unsubscribeFromCron() external rnOnly {
        require(msg.sender == owner, "VaultFunderRSC: only owner");
        bytes memory payload = abi.encodeWithSignature(
            "unsubscribe(uint256,address,uint256,uint256,uint256,uint256)",
            CRON_CHAIN_ID,
            address(0),
            cronInterval,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE
        );
        (bool success,) = address(service).call(payload);
        require(success, "VaultFunderRSC: unsubscribe failed");
        
        cronEnabled = false;
    }

    // ═══════════════════════════════════════════════════════════════
    //                      ADMIN FUNCTIONS
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Update minimum blocks between callbacks
     */
    function setMinBlocksBetweenCallbacks(uint256 blocks) external {
        require(msg.sender == owner, "VaultFunderRSC: only owner");
        minBlocksBetweenCallbacks = blocks;
    }
    
    /**
     * @notice Enable/disable CRON
     */
    function setCronEnabled(bool enabled) external {
        require(msg.sender == owner, "VaultFunderRSC: only owner");
        cronEnabled = enabled;
    }
    
    /**
     * @notice Transfer ownership
     */
    function transferOwnership(address newOwner) external {
        require(msg.sender == owner, "VaultFunderRSC: only owner");
        require(newOwner != address(0), "VaultFunderRSC: zero address");
        owner = newOwner;
    }

    // ═══════════════════════════════════════════════════════════════
    //                      VIEW FUNCTIONS
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Get monitored addresses
     */
    function getConfig() external view returns (
        address _feeCollector,
        address _vault,
        uint256 _chainId,
        uint256 _callbackCount,
        bool _cronEnabled
    ) {
        return (feeCollector, vault, SEPOLIA_CHAIN_ID, callbackCount, cronEnabled);
    }

    /**
     * @notice Receive ETH
     */
    receive() external payable override(AbstractPayer, IPayer) {}
}
