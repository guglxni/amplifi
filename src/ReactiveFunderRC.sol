// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AbstractReactive} from "@reactive/abstract-base/AbstractReactive.sol";
import {IReactive} from "@reactive/interfaces/IReactive.sol";
import {AbstractPayer} from "@reactive/abstract-base/AbstractPayer.sol";
import {IPayer} from "@reactive/interfaces/IPayer.sol";

/**
 * @title ReactiveFunderRC
 * @notice Reactive contract that monitors Funder and bridges funds to AutoLooperReactive
 * @dev Enables self-sustaining gas for the Auto-Looper system (Reactivate pattern)
 * 
 * Flow:
 * 1. Funder.sol on Sepolia receives fees and emits FundsReceived
 * 2. This contract detects the event and triggers a callback
 * 3. Callback causes funds to be bridged to the reactive contract
 * 4. AutoLooperReactive stays funded for continuous operation
 */
contract ReactiveFunderRC is AbstractReactive {
    // ═══════════════════════════════════════════════════════════════
    //                         CONSTANTS
    // ═══════════════════════════════════════════════════════════════

    /// @notice FundsReceived(address indexed sender, uint256 amount) event topic
    /// @dev keccak256("FundsReceived(address,uint256)")
    uint256 private constant FUNDS_RECEIVED_TOPIC_0 = 
        0x8e47b87b0ef542cdfa1659c551d88bad38aa7f452d2bbb349ab7530dfec8be8f;

    /// @notice Callback gas limit
    uint64 private constant CALLBACK_GAS_LIMIT = 500_000;

    /// @notice Sepolia chain ID
    uint256 private constant SEPOLIA_CHAIN_ID = 11155111;

    /// @notice Reactive Network Lasna chain ID
    uint256 private constant REACTIVE_CHAIN_ID = 5318007;

    /// @notice Minimum amount to trigger bridge (wei)
    uint256 private constant MIN_BRIDGE_AMOUNT = 0.001 ether;

    // ═══════════════════════════════════════════════════════════════
    //                         IMMUTABLES
    // ═══════════════════════════════════════════════════════════════

    /// @notice Funder.sol address on Sepolia
    address private immutable funderContract;

    /// @notice AutoLooperReactive address (recipient of bridged funds)
    address private immutable autoLooperReactive;

    // ═══════════════════════════════════════════════════════════════
    //                           STATE
    // ═══════════════════════════════════════════════════════════════

    /// @notice Total amount bridged (tracked for statistics)
    uint256 public totalBridged;

    /// @notice Number of bridge operations
    uint256 public bridgeCount;

    /// @notice Owner address for admin functions
    address public owner;
    
    /// @notice Threshold below which auto-refill triggers (in REACT wei)
    /// @dev Default 1 REACT - when RSC balance drops below this, auto-refill kicks in
    uint256 public refillThreshold = 1 ether;
    
    /// @notice Amount of SepETH to convert to REACT per auto-refill (max 5 ETH)
    uint256 public faucetBridgeAmount = 0.1 ether;
    
    /// @notice Enable/disable auto-refill feature
    bool public autoRefillEnabled = true;

    // ═══════════════════════════════════════════════════════════════
    //                           EVENTS
    // ═══════════════════════════════════════════════════════════════

    /// @notice Emitted when bridge callback is triggered
    event BridgeTriggered(
        address indexed originalSender,
        uint256 amount,
        uint256 bridgeAmount,
        uint256 timestamp
    );

    /// @notice Emitted when owner is updated
    event OwnerUpdated(address indexed oldOwner, address indexed newOwner);
    
    /// @notice Emitted when auto-refill is triggered due to low balance
    event AutoRefillTriggered(
        address indexed recipient,
        uint256 currentBalance,
        uint256 threshold,
        uint256 faucetAmount
    );

    // ═══════════════════════════════════════════════════════════════
    //                        CONSTRUCTOR
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Initialize the reactive funder
     * @param _funderContract Funder.sol address on Sepolia
     * @param _autoLooperReactive AutoLooperReactive address on Reactive Network
     */
    constructor(
        address _funderContract,
        address _autoLooperReactive
    ) payable {
        require(_funderContract != address(0), "Invalid funder");
        require(_autoLooperReactive != address(0), "Invalid recipient");

        funderContract = _funderContract;
        autoLooperReactive = _autoLooperReactive;
        owner = msg.sender;
        
        // Note: Subscription done separately via subscribe() to avoid constructor issues
    }
    
    /**
     * @notice Subscribe to FundsReceived events (call after deployment)
     * @dev Must be called on Reactive Network, not in ReactVM
     */
    function subscribe() external rnOnly {
        service.subscribe(
            SEPOLIA_CHAIN_ID,            // Origin chain
            funderContract,              // Origin contract
            FUNDS_RECEIVED_TOPIC_0,      // Event signature
            REACTIVE_IGNORE,             // Don't filter by sender
            REACTIVE_IGNORE,             // Don't filter by amount
            REACTIVE_IGNORE              // Don't filter by topic_3
        );
    }

    // ═══════════════════════════════════════════════════════════════
    //                        MODIFIERS
    // ═══════════════════════════════════════════════════════════════

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    // ═══════════════════════════════════════════════════════════════
    //                      REACT FUNCTION
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice React to FundsReceived events by bridging funds
     * @dev Called by ReactVM when subscribed events are detected
     *      Implements hybrid auto-refill: checks RSC balance and triggers
     *      faucet bridge if below threshold
     * @param log The log record from the event
     */
    function react(IReactive.LogRecord calldata log) external override vmOnly {
        // Validate origin
        if (log.chain_id != SEPOLIA_CHAIN_ID) {
            return;
        }
        if (log._contract != funderContract) {
            return;
        }
        if (log.topic_0 != FUNDS_RECEIVED_TOPIC_0) {
            return;
        }

        // Extract sender from topic1 (indexed parameter)
        address originalSender = address(uint160(log.topic_1));

        // Decode amount from event data
        uint256 amount = abi.decode(log.data, (uint256));

        // Skip if amount too small (not worth bridging)
        if (amount < MIN_BRIDGE_AMOUNT) {
            return;
        }

        // Calculate bridge amount (95% bridged, 5% kept for gas buffer)
        uint256 bridgeAmount = (amount * 95) / 100;

        // Emit callback to trigger fund transfer via Callback Proxy
        _emitBridgeCallback(originalSender, bridgeAmount);

        // HYBRID AUTO-REFILL: Check if RSC needs REACT tokens
        // Since we're in ReactVM, we can check autoLooperReactive's balance
        if (autoRefillEnabled) {
            uint256 rscBalance = autoLooperReactive.balance;
            
            if (rscBalance < refillThreshold) {
                // RSC balance is low - trigger faucet bridge
                _emitFaucetBridgeCallback(autoLooperReactive, faucetBridgeAmount);
                
                emit AutoRefillTriggered(
                    autoLooperReactive,
                    rscBalance,
                    refillThreshold,
                    faucetBridgeAmount
                );
            }
        }

        // Track statistics (RN state, not ReactVM state)
        if (!vm) {
            totalBridged += bridgeAmount;
            bridgeCount++;
        }

        emit BridgeTriggered(originalSender, amount, bridgeAmount, block.timestamp);
    }

    /**
     * @notice Emit callback to initiate bridge transfer
     * @dev Calls Funder.coverDebt() which bridges funds via Callback Proxy
     * @param originalSender The original fee payer
     * @param amount Amount to bridge
     */
    function _emitBridgeCallback(address originalSender, uint256 amount) internal {
        // Call coverDebt(address) on Funder - this triggers the actual bridge
        // The Funder.coverDebt() function will:
        // 1. Calculate bridgeable amount (balance - gasReserve)
        // 2. Call CallbackProxy.depositTo(targetRsc) to fund the RSC
        // 3. Track bridged amounts
        bytes memory payload = abi.encodeWithSignature(
            "coverDebt(address)",
            autoLooperReactive  // Target RSC to fund
        );

        emit Callback(
            SEPOLIA_CHAIN_ID,
            funderContract,
            CALLBACK_GAS_LIMIT,
            payload
        );
    }
    
    /**
     * @notice Emit callback to bridge via faucet for REACT tokens
     * @dev Calls Funder.bridgeToFaucet() which gets REACT at 100:1 ratio
     * @param recipient Address to receive REACT on Lasna
     * @param amount Amount of SepETH to convert (max 5 ETH)
     */
    function _emitFaucetBridgeCallback(address recipient, uint256 amount) internal {
        // Cap at 5 ETH (faucet limit)
        uint256 bridgeAmount = amount > 5 ether ? 5 ether : amount;
        
        bytes memory payload = abi.encodeWithSignature(
            "bridgeToFaucet(address,uint256)",
            recipient,
            bridgeAmount
        );

        emit Callback(
            SEPOLIA_CHAIN_ID,
            funderContract,
            CALLBACK_GAS_LIMIT,
            payload
        );
    }
    
    /**
     * @notice Request auto-refill of REACT tokens via faucet
     * @dev Can be called by owner to trigger manual faucet bridge
     * @param amount Amount of SepETH to convert (max 5 ETH)
     */
    function requestReactRefill(uint256 amount) external onlyOwner {
        _emitFaucetBridgeCallback(autoLooperReactive, amount);
    }

    // ═══════════════════════════════════════════════════════════════
    //                     ADMIN FUNCTIONS
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Transfer ownership
     * @param newOwner New owner address
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid owner");
        address oldOwner = owner;
        owner = newOwner;
        emit OwnerUpdated(oldOwner, newOwner);
    }
    
    /**
     * @notice Set the refill threshold
     * @param _threshold New threshold in REACT wei
     */
    function setRefillThreshold(uint256 _threshold) external onlyOwner {
        refillThreshold = _threshold;
    }
    
    /**
     * @notice Set the faucet bridge amount
     * @param _amount Amount of SepETH to convert per refill (max 5 ETH)
     */
    function setFaucetBridgeAmount(uint256 _amount) external onlyOwner {
        require(_amount <= 5 ether, "Max 5 ETH per request");
        faucetBridgeAmount = _amount;
    }
    
    /**
     * @notice Enable or disable auto-refill
     * @param _enabled True to enable, false to disable
     */
    function setAutoRefillEnabled(bool _enabled) external onlyOwner {
        autoRefillEnabled = _enabled;
    }

    /**
     * @notice Pause the reactive contract
     */
    function pause() external rnOnly {
        bytes memory payload = abi.encodeWithSignature(
            "unsubscribe(uint256,address,uint256,uint256,uint256)",
            SEPOLIA_CHAIN_ID,
            funderContract,
            FUNDS_RECEIVED_TOPIC_0,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE
        );
        (bool success,) = address(service).call(payload);
        require(success, "Unsubscribe failed");
    }

    /**
     * @notice Resume the reactive contract
     */
    function resume() external rnOnly {
        bytes memory payload = abi.encodeWithSignature(
            "subscribe(uint256,address,uint256,uint256,uint256)",
            SEPOLIA_CHAIN_ID,
            funderContract,
            FUNDS_RECEIVED_TOPIC_0,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE
        );
        (bool success,) = address(service).call(payload);
        require(success, "Subscribe failed");
    }

    // ═══════════════════════════════════════════════════════════════
    //                      VIEW FUNCTIONS
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Get funder contract address
     */
    function getFunderContract() external view returns (address) {
        return funderContract;
    }

    /**
     * @notice Get recipient (AutoLooperReactive) address
     */
    function getRecipient() external view returns (address) {
        return autoLooperReactive;
    }

    /**
     * @notice Get bridge statistics
     */
    function getStats() external view returns (
        uint256 _totalBridged,
        uint256 _bridgeCount,
        address _funder,
        address _recipient
    ) {
        return (totalBridged, bridgeCount, funderContract, autoLooperReactive);
    }

    /**
     * @notice Receive ETH for gas payments
     */
    receive() external payable override(AbstractPayer, IPayer) {}
}
