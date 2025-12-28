// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import '../lib/reactive-lib/src/interfaces/IReactive.sol';
import '../lib/reactive-lib/src/interfaces/IPayer.sol';
import '../lib/reactive-lib/src/abstract-base/AbstractReactive.sol';
import '../lib/reactive-lib/src/abstract-base/AbstractPayer.sol';

/**
 * @title CallbackTestRSCV2
 * @notice RSC that emits a Callback event on every react() call
 * @dev Explicitly calls AbstractReactive constructor
 */
contract CallbackTestRSCV2 is IReactive, AbstractReactive {
    
    event ReactCalled(uint256 chainId, address sourceContract, uint256 topic0);
    event Subscribed(address indexed vault, uint256 chainId, uint256 topic);
    
    uint256 private constant SEPOLIA_CHAIN_ID = 11155111;
    address private constant VAULT = 0xe6e06F94d1aaa2496b9e33afeE29f01436E9fA4A;
    uint256 private constant YIELD_SNAPSHOT_TOPIC = 0xcfc791d57cbe67b39a1e34c851c3eebf9a7edb42f31260acf4f18a7d5959ff62;
    uint64 private constant CALLBACK_GAS_LIMIT = 1000000;
    
    uint256 public reactCallCount;
    
    // Explicitly call parent constructor
    constructor() payable AbstractReactive() {
        if (!vm) {
            // Subscribe to YieldSnapshot events
            service.subscribe(
                SEPOLIA_CHAIN_ID,
                VAULT,
                YIELD_SNAPSHOT_TOPIC,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE
            );
            emit Subscribed(VAULT, SEPOLIA_CHAIN_ID, YIELD_SNAPSHOT_TOPIC);
        }
    }
    
    function react(LogRecord calldata log) external vmOnly {
        reactCallCount++;
        emit ReactCalled(log.chain_id, log._contract, log.topic_0);
        
        // ALWAYS emit a Callback to verify the flow works
        bytes memory payload = abi.encodeWithSignature(
            "executeRebalance(address,uint256,uint256)",
            address(0), // RVM ID placeholder - network will replace this
            8000,       // 80% to primary
            2000        // 20% to secondary
        );
        
        emit Callback(SEPOLIA_CHAIN_ID, VAULT, CALLBACK_GAS_LIMIT, payload);
    }
    
    receive() external payable override(AbstractPayer, IPayer) {}
}
