// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import '../lib/reactive-lib/src/interfaces/IReactive.sol';
import '../lib/reactive-lib/src/interfaces/IPayer.sol';
import '../lib/reactive-lib/src/abstract-base/AbstractReactive.sol';
import '../lib/reactive-lib/src/abstract-base/AbstractPayer.sol';

/**
 * @title YieldOptimizerReactiveV3
 * @notice Minimal RSC following exact pattern from Uniswap Stop Order demo
 * @dev Key differences from V2:
 *      - Subscribe in constructor with if (!vm) check
 *      - Use regular storage variable, not immutable
 *      - Exact same pattern as working demo
 */
contract YieldOptimizerReactiveV3 is IReactive, AbstractReactive {
    
    // Events
    event Subscribed(address indexed vault, uint256 indexed chainId);
    event ReactCalled(uint256 chainId, address sourceContract, uint256 topic0);
    event CallbackSent(uint256 primaryAPY, uint256 secondaryAPY);
    event RebalanceSkipped(string reason);
    
    // Constants
    uint256 private constant SEPOLIA_CHAIN_ID = 11155111;
    uint256 private constant YIELD_SNAPSHOT_TOPIC_0 = 
        0xcfc791d57cbe67b39a1e34c851c3eebf9a7edb42f31260acf4f18a7d5959ff62;
    uint64 private constant CALLBACK_GAS_LIMIT = 800000;
    
    // State - using regular storage, not immutable (matches demo pattern)
    address private vault;
    address public owner;
    bool private triggered;
    uint256 public lastRebalanceBlock;
    
    constructor(
        address _vault
    ) payable {
        vault = _vault;
        owner = msg.sender;
        triggered = false;
        
        // Subscribe in constructor, just like the demo
        if (!vm) {
            service.subscribe(
                SEPOLIA_CHAIN_ID,
                _vault,
                YIELD_SNAPSHOT_TOPIC_0,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE
            );
            emit Subscribed(_vault, SEPOLIA_CHAIN_ID);
        }
    }
    
    // React function - vmOnly
    function react(LogRecord calldata log) external vmOnly {
        // Log that react was called
        emit ReactCalled(log.chain_id, log._contract, log.topic_0);
        
        // Verify source
        if (log._contract != vault) {
            emit RebalanceSkipped("Wrong contract");
            return;
        }
        
        if (log.topic_0 != YIELD_SNAPSHOT_TOPIC_0) {
            emit RebalanceSkipped("Wrong topic");
            return;
        }
        
        // Rate limiting
        if (block.number < lastRebalanceBlock + 50) {
            emit RebalanceSkipped("Rate limited");
            return;
        }
        
        // Decode event data: primaryAPY, secondaryAPY, primaryAlloc, secondaryAlloc, tvl, timestamp
        (
            uint256 primaryAPY,
            uint256 secondaryAPY,
            /* uint256 primaryAlloc */,
            /* uint256 secondaryAlloc */,
            /* uint256 tvl */,
            /* uint256 timestamp */
        ) = abi.decode(log.data, (uint256, uint256, uint256, uint256, uint256, uint256));
        
        // Calculate new allocation (80% to higher yield)
        uint256 newPrimaryPct;
        uint256 newSecondaryPct;
        
        if (primaryAPY >= secondaryAPY) {
            newPrimaryPct = 8000;
            newSecondaryPct = 2000;
        } else {
            newPrimaryPct = 2000;
            newSecondaryPct = 8000;
        }
        
        // Create callback payload
        bytes memory payload = abi.encodeWithSignature(
            "executeRebalance(address,uint256,uint256)",
            address(0), // RVM ID placeholder - network injects actual value
            newPrimaryPct,
            newSecondaryPct
        );
        
        // Update state
        triggered = true;
        lastRebalanceBlock = block.number;
        
        // Emit events
        emit CallbackSent(primaryAPY, secondaryAPY);
        emit Callback(log.chain_id, vault, CALLBACK_GAS_LIMIT, payload);
    }
    
    function getVault() external view returns (address) {
        return vault;
    }
    
    receive() external payable override(AbstractPayer, IPayer) {}
}
