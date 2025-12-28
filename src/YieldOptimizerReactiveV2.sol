// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AbstractReactive} from "@reactive/abstract-base/AbstractReactive.sol";
import {IReactive} from "@reactive/interfaces/IReactive.sol";
import {AbstractPayer} from "@reactive/abstract-base/AbstractPayer.sol";
import {IPayer} from "@reactive/interfaces/IPayer.sol";

/**
 * @title YieldOptimizerReactiveV2
 * @notice Simplified Reactive Smart Contract for Yield Optimization
 * @dev Subscribe after deployment, not in constructor
 */
contract YieldOptimizerReactiveV2 is IReactive, AbstractReactive {
    
    /// @notice YieldSnapshot event topic for DualAsset vault
    /// keccak256("YieldSnapshot(uint256,uint256,uint256,uint256,uint256,uint256,uint256)")
    uint256 private constant YIELD_SNAPSHOT_TOPIC_0 = 
        0xcfc791d57cbe67b39a1e34c851c3eebf9a7edb42f31260acf4f18a7d5959ff62;
    
    /// @notice Callback gas limit
    uint64 private constant CALLBACK_GAS_LIMIT = 800_000;
    
    /// @notice Minimum yield difference to trigger (50 bps)
    uint256 private constant MIN_YIELD_DIFF_BPS = 50;
    
    /// @notice Basis points constant
    uint256 private constant BPS = 10000;
    
    /// @notice Sepolia chain ID
    uint256 private constant SEPOLIA_CHAIN_ID = 11155111;
    
    /// @notice Vault address on Sepolia
    address public immutable vault;
    
    /// @notice Owner
    address public owner;
    
    /// @notice Subscription active flag
    bool public subscribed;
    
    /// @notice Last callback block (rate limiting)
    uint256 public lastCallbackBlock;
    
    // Events
    event RebalanceCallback(uint256 primaryAPY, uint256 secondaryAPY, uint256 primaryPct, uint256 secondaryPct);
    event SubscriptionCreated(address vault, uint256 chainId);
    event RebalanceSkipped(string reason);
    
    error OnlyOwner();
    
    modifier onlyOwner() {
        if (msg.sender != owner) revert OnlyOwner();
        _;
    }
    
    constructor(address _vault) payable {
        vault = _vault;
        owner = msg.sender;
        // Do NOT subscribe in constructor - call subscribeToVault() after deployment
    }
    
    /**
     * @notice Subscribe to vault events after deployment
     * @dev Must be called from Reactive Network (rnOnly)
     */
    function subscribeToVault() external rnOnly {
        service.subscribe(
            SEPOLIA_CHAIN_ID,
            vault,
            YIELD_SNAPSHOT_TOPIC_0,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE
        );
        subscribed = true;
        emit SubscriptionCreated(vault, SEPOLIA_CHAIN_ID);
    }
    
    /**
     * @notice React to YieldSnapshot events
     */
    function react(IReactive.LogRecord calldata log) external override vmOnly {
        // Only process YieldSnapshot from our vault
        if (log._contract != vault || log.topic_0 != YIELD_SNAPSHOT_TOPIC_0) {
            return;
        }
        
        // Rate limiting - 50 blocks between callbacks
        if (block.number < lastCallbackBlock + 50) {
            emit RebalanceSkipped("Rate limited");
            return;
        }
        
        // Decode: primaryAPY, secondaryAPY, primaryAlloc, secondaryAlloc, tvl, timestamp
        (
            uint256 primaryAPY,
            uint256 secondaryAPY,
            /* uint256 currentPrimaryAlloc */,
            /* uint256 currentSecondaryAlloc */,
            /* uint256 tvl */,
            /* uint256 timestamp */
        ) = abi.decode(log.data, (uint256, uint256, uint256, uint256, uint256, uint256));
        
        // Calculate yield difference
        uint256 higherYield = primaryAPY > secondaryAPY ? primaryAPY : secondaryAPY;
        if (higherYield == 0) {
            emit RebalanceSkipped("Zero yield");
            return;
        }
        
        uint256 diff = primaryAPY > secondaryAPY 
            ? primaryAPY - secondaryAPY 
            : secondaryAPY - primaryAPY;
        
        uint256 diffBps = (diff * BPS) / higherYield;
        
        if (diffBps < MIN_YIELD_DIFF_BPS) {
            emit RebalanceSkipped("Below threshold");
            return;
        }
        
        // Determine new allocation (80% to higher yield, 20% to lower)
        uint256 newPrimaryPct;
        uint256 newSecondaryPct;
        
        if (primaryAPY > secondaryAPY) {
            newPrimaryPct = 8000;  // 80%
            newSecondaryPct = 2000; // 20%
        } else {
            newPrimaryPct = 2000;  // 20%
            newSecondaryPct = 8000; // 80%
        }
        
        // Emit callback to vault
        bytes memory payload = abi.encodeWithSignature(
            "executeRebalance(address,uint256,uint256)",
            address(0),  // RVM ID - auto-injected by network
            newPrimaryPct,
            newSecondaryPct
        );
        
        lastCallbackBlock = block.number;
        emit RebalanceCallback(primaryAPY, secondaryAPY, newPrimaryPct, newSecondaryPct);
        emit Callback(SEPOLIA_CHAIN_ID, vault, CALLBACK_GAS_LIMIT, payload);
    }
    
    /// @notice Get vault address
    function getVault() external view returns (address) {
        return vault;
    }
    
    /// @notice Transfer ownership
    function transferOwnership(address newOwner) external onlyOwner {
        owner = newOwner;
    }
    
    /// @notice Receive ETH
    receive() external payable override(AbstractPayer, IPayer) {}
}
