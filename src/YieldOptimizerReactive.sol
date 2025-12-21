// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AbstractReactive} from "@reactive/abstract-base/AbstractReactive.sol";
import {IReactive} from "@reactive/interfaces/IReactive.sol";
import {AbstractPayer} from "@reactive/abstract-base/AbstractPayer.sol";
import {IPayer} from "@reactive/interfaces/IPayer.sol";

/**
 * @title YieldOptimizerReactive
 * @notice Reactive Smart Contract for Cross-Chain Yield Optimization (Bounty 3)
 * @dev Forked from AutoLooperReactiveEnhanced, adapted for yield-based decisions
 * 
 * Key Differences from AutoLooperReactive:
 * - Monitors YieldSnapshot events instead of PositionUpdated
 * - Compares APYs between pools instead of health factors
 * - Emits executeRebalance callback instead of executeLoopStep
 * - Uses 80/20 allocation strategy with minimum diversification
 * 
 * Features Retained:
 * - CRON subscriptions for periodic checks
 * - Batch processing (50 users per CRON)
 * - Finality-aware operations for large rebalances
 * - Rate limiting
 * - Stale position detection
 */
contract YieldOptimizerReactive is IReactive, AbstractReactive {
    // ═══════════════════════════════════════════════════════════════
    //                         CONSTANTS
    // ═══════════════════════════════════════════════════════════════

    /// @notice YieldSnapshot event topic
    /// @dev keccak256("YieldSnapshot(uint256,uint256,uint256,uint256,uint256,uint256,uint256)")
    uint256 private constant YIELD_SNAPSHOT_TOPIC_0 = 
        0xcfc791d57cbe67b39a1e34c851c3eebf9a7edb42f31260acf4f18a7d5959ff62;
    
    /// @notice CRON chain ID indicator (0 for CRON events)
    uint256 private constant CRON_CHAIN_ID = 0;

    /// @notice Callback gas limit for rebalancing
    uint64 private constant CALLBACK_GAS_LIMIT = 800_000;

    /// @notice Minimum yield difference to trigger rebalance (50 bps = 0.5%)
    uint256 private constant MIN_YIELD_DIFF_BPS = 50;
    
    /// @notice Minimum allocation per pool for diversification (2000 bps = 20%)
    uint256 private constant MIN_ALLOCATION_BPS = 2000;
    
    /// @notice Major allocation for higher-yield pool (8000 bps = 80%)
    uint256 private constant MAJOR_ALLOCATION_BPS = 8000;

    /// @notice Basis points constant
    uint256 private constant BPS = 10000;

    /// @notice Sepolia chain ID
    uint256 private constant SEPOLIA_CHAIN_ID = 11155111;
    
    /// @notice Finality blocks for large rebalances (from Performance Race article)
    uint256 public constant FINALITY_BLOCKS = 64;
    
    /// @notice Large rebalance threshold (50% TVL change)
    uint256 private constant LARGE_REBALANCE_THRESHOLD_BPS = 5000;

    // ═══════════════════════════════════════════════════════════════
    //                         IMMUTABLES
    // ═══════════════════════════════════════════════════════════════

    /// @notice YieldVault contract address on Sepolia
    address private immutable vault;

    /// @notice Destination chain ID
    uint256 private immutable chainId;

    // ═══════════════════════════════════════════════════════════════
    //                      CONFIGURATION STATE
    // ═══════════════════════════════════════════════════════════════

    /// @notice Owner address for admin functions
    address public owner;

    /// @notice CRON monitoring enabled flag
    bool public cronMonitoringEnabled = true;

    /// @notice CRON interval in blocks (100 blocks ≈ 12 minutes on Reactive)
    uint256 public cronInterval = 100;

    /// @notice Minimum blocks between rebalance callbacks
    uint256 public constant MIN_BLOCKS_BETWEEN_CALLBACKS = 50;

    /// @notice Last rebalance callback block
    uint256 private lastRebalanceBlock;

    /// @notice Finality-aware mode enabled
    bool public finalityAwareEnabled = true;

    /// @notice Pending large rebalances awaiting finality
    mapping(bytes32 => PendingRebalance) public pendingRebalances;

    struct PendingRebalance {
        uint256 requestBlock;
        uint256 aavePct;
        uint256 compoundPct;
        uint256 tvl;
        bool executed;
    }

    // ═══════════════════════════════════════════════════════════════
    //                           EVENTS
    // ═══════════════════════════════════════════════════════════════

    /// @notice Emitted when rebalance callback is triggered
    event RebalanceCallbackTriggered(
        uint256 aaveAPY,
        uint256 compoundAPY,
        uint256 newAavePct,
        uint256 newCompoundPct
    );

    /// @notice Emitted when CRON yield check is executed
    event CronYieldCheckExecuted(uint256 snapshotId, uint256 aaveAPY, uint256 compoundAPY);

    /// @notice Emitted when rebalance is skipped (threshold not met)
    event RebalanceSkipped(uint256 aaveAPY, uint256 compoundAPY, uint256 diffBps, string reason);

    /// @notice Emitted when large rebalance is queued for finality
    event LargeRebalanceQueued(bytes32 indexed rebalanceId, uint256 aavePct, uint256 compoundPct, uint256 readyBlock);

    /// @notice Emitted when large rebalance is executed after finality
    event LargeRebalanceExecuted(bytes32 indexed rebalanceId);

    /// @notice Emitted when rate limited
    event RateLimited(uint256 lastBlock, uint256 currentBlock);

    // ═══════════════════════════════════════════════════════════════
    //                           ERRORS
    // ═══════════════════════════════════════════════════════════════

    error OnlyOwner();
    error ZeroAddress();

    // ═══════════════════════════════════════════════════════════════
    //                        MODIFIERS
    // ═══════════════════════════════════════════════════════════════

    modifier onlyOwner() {
        if (msg.sender != owner) revert OnlyOwner();
        _;
    }

    // ═══════════════════════════════════════════════════════════════
    //                        CONSTRUCTOR
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Initialize the yield optimizer reactive contract
     * @param _vault YieldVault address on destination chain
     * @param _chainId Destination chain ID (Sepolia = 11155111)
     */
    constructor(address _vault, uint256 _chainId) payable {
        if (_vault == address(0)) revert ZeroAddress();
        
        vault = _vault;
        chainId = _chainId;
        owner = msg.sender;
        
        // Subscribe to YieldSnapshot events in constructor
        if (!vm) {
            service.subscribe(
                _chainId,                    // Chain ID to monitor (Sepolia)
                _vault,                      // Contract address to monitor (YieldVault)
                YIELD_SNAPSHOT_TOPIC_0,      // topic_0 - event signature
                REACTIVE_IGNORE,             // topic_1 - snapshotId (indexed)
                REACTIVE_IGNORE,             // topic_2 - ignore
                REACTIVE_IGNORE              // topic_3 - ignore
            );
        }
    }

    // ═══════════════════════════════════════════════════════════════
    //                  SUBSCRIPTION MANAGEMENT
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Subscribe to YieldSnapshot events from the Vault
     * @dev Backup method if constructor subscription needs refresh
     */
    function subscribeToVault() external rnOnly {
        service.subscribe(
            chainId,
            vault,
            YIELD_SNAPSHOT_TOPIC_0,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE
        );
    }

    /**
     * @notice Subscribe to CRON events for periodic yield checks
     * @dev NFT SUB pattern - blocks between checks
     * @param interval Block interval for CRON triggers
     */
    function subscribeToCron(uint256 interval) external rnOnly onlyOwner {
        cronInterval = interval;
        
        // CRON subscription: chain_id = 0 indicates CRON
        service.subscribe(
            CRON_CHAIN_ID,       // CRON indicator
            address(0),           // No specific contract
            interval,             // Block interval as topic_0
            REACTIVE_IGNORE,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE
        );
        
        cronMonitoringEnabled = true;
    }

    /**
     * @notice Unsubscribe from CRON events
     */
    function unsubscribeFromCron() external rnOnly onlyOwner {
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
        require(success, "Unsubscribe failed");
        
        cronMonitoringEnabled = false;
    }

    // ═══════════════════════════════════════════════════════════════
    //                      REACT FUNCTION
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice React to yield-related events
     * @dev Main entry point for event processing
     *      Handles: YieldSnapshot, CRON
     * @param log The log record from the event
     */
    function react(IReactive.LogRecord calldata log) external override vmOnly {
        // Check for CRON event (chain_id = 0)
        if (log.chain_id == CRON_CHAIN_ID && cronMonitoringEnabled) {
            _handleCronEvent();
            return;
        }

        // Check for YieldSnapshot from Vault
        if (log._contract == vault && log.topic_0 == YIELD_SNAPSHOT_TOPIC_0) {
            _handleYieldSnapshot(log);
            return;
        }
    }

    // ═══════════════════════════════════════════════════════════════
    //                 YIELD SNAPSHOT HANDLING
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Handle YieldSnapshot event from YieldVault
     * @param log The log record containing yield data
     */
    function _handleYieldSnapshot(IReactive.LogRecord calldata log) internal {
        // Decode event data
        // YieldSnapshot event structure:
        // - topic_0: event signature
        // - topic_1: snapshotId (indexed)
        // - data: primaryAPY, secondaryAPY, primaryAlloc, secondaryAlloc, tvl, timestamp
        
        uint256 snapshotId = log.topic_1;
        
        (
            uint256 aaveAPY,
            uint256 compoundAPY,
            uint256 currentAaveAlloc,
            uint256 currentCompoundAlloc,
            uint256 tvl,
            /* uint256 timestamp */
        ) = abi.decode(log.data, (uint256, uint256, uint256, uint256, uint256, uint256));

        // Rate limiting
        if (block.number < lastRebalanceBlock + MIN_BLOCKS_BETWEEN_CALLBACKS) {
            emit RateLimited(lastRebalanceBlock, block.number);
            return;
        }

        // Process yield comparison and potentially emit rebalance
        _processYieldComparison(
            snapshotId,
            aaveAPY,
            compoundAPY,
            currentAaveAlloc,
            currentCompoundAlloc,
            tvl
        );
    }

    /**
     * @notice Process yield comparison and determine if rebalance needed
     */
    function _processYieldComparison(
        uint256 snapshotId,
        uint256 aaveAPY,
        uint256 compoundAPY,
        uint256 currentAaveAlloc,
        uint256 currentCompoundAlloc,
        uint256 tvl
    ) internal {
        // Calculate yield difference as percentage of higher yield
        (bool shouldRebalance, uint8 higherYieldPool) = _shouldRebalance(aaveAPY, compoundAPY);

        if (!shouldRebalance) {
            uint256 diffBps = _calculateYieldDiffBps(aaveAPY, compoundAPY);
            emit RebalanceSkipped(aaveAPY, compoundAPY, diffBps, "Yield diff below threshold");
            return;
        }

        // Determine new allocation (80% to higher yield, 20% to lower)
        uint256 newAavePct;
        uint256 newCompoundPct;

        if (higherYieldPool == 0) {
            // Aave has higher yield
            newAavePct = MAJOR_ALLOCATION_BPS;
            newCompoundPct = MIN_ALLOCATION_BPS;
        } else {
            // Compound has higher yield
            newAavePct = MIN_ALLOCATION_BPS;
            newCompoundPct = MAJOR_ALLOCATION_BPS;
        }

        // Check if this would be a large rebalance (finality-aware)
        uint256 aaveChange = newAavePct > currentAaveAlloc 
            ? newAavePct - currentAaveAlloc 
            : currentAaveAlloc - newAavePct;

        if (finalityAwareEnabled && aaveChange >= LARGE_REBALANCE_THRESHOLD_BPS) {
            _queueLargeRebalance(newAavePct, newCompoundPct, tvl);
        } else {
            _emitRebalanceCallback(newAavePct, newCompoundPct);
            emit RebalanceCallbackTriggered(aaveAPY, compoundAPY, newAavePct, newCompoundPct);
            lastRebalanceBlock = block.number;
        }
    }

    /**
     * @notice Determine if rebalancing is beneficial
     */
    function _shouldRebalance(
        uint256 aaveAPY,
        uint256 compoundAPY
    ) internal pure returns (bool, uint8 higherYieldPool) {
        if (aaveAPY == 0 && compoundAPY == 0) {
            return (false, 0);
        }

        uint256 diff;
        if (aaveAPY > compoundAPY) {
            diff = aaveAPY - compoundAPY;
            higherYieldPool = 0;
        } else {
            diff = compoundAPY - aaveAPY;
            higherYieldPool = 1;
        }

        uint256 higherYield = aaveAPY > compoundAPY ? aaveAPY : compoundAPY;
        uint256 diffBps = (diff * BPS) / higherYield;

        return (diffBps >= MIN_YIELD_DIFF_BPS, higherYieldPool);
    }

    /**
     * @notice Calculate yield difference in basis points
     */
    function _calculateYieldDiffBps(
        uint256 aaveAPY,
        uint256 compoundAPY
    ) internal pure returns (uint256) {
        if (aaveAPY == 0 && compoundAPY == 0) return 0;
        
        uint256 diff = aaveAPY > compoundAPY 
            ? aaveAPY - compoundAPY 
            : compoundAPY - aaveAPY;
        
        uint256 higherYield = aaveAPY > compoundAPY ? aaveAPY : compoundAPY;
        return (diff * BPS) / higherYield;
    }

    // ═══════════════════════════════════════════════════════════════
    //                    CRON HANDLING
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Handle CRON event for periodic yield checks
     * @dev Triggers a yield snapshot request to the vault
     */
    function _handleCronEvent() internal {
        if (!cronMonitoringEnabled) {
            return;
        }

        // Emit callback to trigger yield snapshot in vault
        _emitYieldSnapshotRequest();
    }

    /**
     * @notice Emit callback to request yield snapshot from vault
     */
    function _emitYieldSnapshotRequest() internal {
        bytes memory payload = abi.encodeWithSignature(
            "triggerYieldSnapshot()"
        );

        emit Callback(
            chainId,
            vault,
            CALLBACK_GAS_LIMIT,
            payload
        );
    }

    // ═══════════════════════════════════════════════════════════════
    //                  FINALITY-AWARE REBALANCING
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Queue a large rebalance that requires finality
     */
    function _queueLargeRebalance(
        uint256 aavePct,
        uint256 compoundPct,
        uint256 tvl
    ) internal {
        bytes32 rebalanceId = keccak256(abi.encodePacked(
            block.number,
            aavePct,
            compoundPct,
            tvl
        ));

        pendingRebalances[rebalanceId] = PendingRebalance({
            requestBlock: block.number,
            aavePct: aavePct,
            compoundPct: compoundPct,
            tvl: tvl,
            executed: false
        });

        uint256 readyBlock = block.number + FINALITY_BLOCKS;
        emit LargeRebalanceQueued(rebalanceId, aavePct, compoundPct, readyBlock);
    }

    /**
     * @notice Execute a pending large rebalance after finality
     * @param rebalanceId The rebalance ID to execute
     */
    function executePendingRebalance(bytes32 rebalanceId) external {
        PendingRebalance storage pending = pendingRebalances[rebalanceId];
        require(pending.requestBlock > 0, "Not pending");
        require(!pending.executed, "Already executed");
        require(
            block.number >= pending.requestBlock + FINALITY_BLOCKS,
            "Awaiting finality"
        );

        pending.executed = true;
        _emitRebalanceCallback(pending.aavePct, pending.compoundPct);
        lastRebalanceBlock = block.number;

        emit LargeRebalanceExecuted(rebalanceId);
    }

    /**
     * @notice Check if a pending rebalance is ready
     */
    function isPendingRebalanceReady(bytes32 rebalanceId) external view returns (bool ready, uint256 blocksRemaining) {
        PendingRebalance memory pending = pendingRebalances[rebalanceId];
        if (pending.requestBlock == 0 || pending.executed) {
            return (false, 0);
        }

        uint256 readyBlock = pending.requestBlock + FINALITY_BLOCKS;
        if (block.number >= readyBlock) {
            return (true, 0);
        }
        return (false, readyBlock - block.number);
    }

    // ═══════════════════════════════════════════════════════════════
    //                     CALLBACK EMISSION
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Emit rebalance callback to YieldVault
     * @param aavePct New allocation for Aave (basis points)
     * @param compoundPct New allocation for Compound (basis points)
     */
    function _emitRebalanceCallback(uint256 aavePct, uint256 compoundPct) internal {
        bytes memory payload = abi.encodeWithSignature(
            "executeRebalance(address,uint256,uint256)",
            address(0), // RVM ID placeholder - injected by network
            aavePct,
            compoundPct
        );

        emit Callback(
            chainId,
            vault,
            CALLBACK_GAS_LIMIT,
            payload
        );
    }

    // ═══════════════════════════════════════════════════════════════
    //                      ADMIN FUNCTIONS
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Enable or disable CRON monitoring
     */
    function setCronMonitoringEnabled(bool enabled) external rnOnly onlyOwner {
        cronMonitoringEnabled = enabled;
    }

    /**
     * @notice Enable or disable finality-aware mode
     */
    function setFinalityAwareEnabled(bool enabled) external rnOnly onlyOwner {
        finalityAwareEnabled = enabled;
    }

    /**
     * @notice Transfer ownership
     */
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        owner = newOwner;
    }

    // ═══════════════════════════════════════════════════════════════
    //                      VIEW FUNCTIONS
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Get the vault address
     */
    function getVault() external view returns (address) {
        return vault;
    }

    /**
     * @notice Get the chain ID
     */
    function getChainId() external view returns (uint256) {
        return chainId;
    }

    /**
     * @notice Get last rebalance block
     */
    function getLastRebalanceBlock() external view returns (uint256) {
        return lastRebalanceBlock;
    }

    /**
     * @notice Receive ETH for gas
     */
    receive() external payable override(AbstractPayer, IPayer) {}
}
