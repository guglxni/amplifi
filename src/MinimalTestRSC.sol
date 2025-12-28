// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import '../lib/reactive-lib/src/interfaces/IReactive.sol';
import '../lib/reactive-lib/src/interfaces/IPayer.sol';
import '../lib/reactive-lib/src/abstract-base/AbstractReactive.sol';
import '../lib/reactive-lib/src/abstract-base/AbstractPayer.sol';

/**
 * @title MinimalTestRSC
 * @notice Ultra-minimal RSC to test if react() is being called at all
 */
contract MinimalTestRSC is IReactive, AbstractReactive {
    
    // Events for debugging
    event ReactCalled(uint256 chainId, address sourceContract, uint256 topic0, uint256 blockNumber);
    event Subscribed();
    
    // Constants - Sepolia
    uint256 private constant SEPOLIA_CHAIN_ID = 11155111;
    
    // YieldSnapshot event signature
    uint256 private constant YIELD_SNAPSHOT_TOPIC = 
        0xcfc791d57cbe67b39a1e34c851c3eebf9a7edb42f31260acf4f18a7d5959ff62;
    
    // Target vault
    address private constant VAULT = 0xe6e06F94d1aaa2496b9e33afeE29f01436E9fA4A;
    
    // Track react calls
    uint256 public reactCallCount;
    uint256 public lastReactBlock;
    uint256 public lastSeenChainId;
    address public lastSeenContract;
    
    constructor() payable {
        // Subscribe in constructor
        if (!vm) {
            service.subscribe(
                SEPOLIA_CHAIN_ID,
                VAULT,
                YIELD_SNAPSHOT_TOPIC,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE
            );
            emit Subscribed();
        }
    }
    
    function react(LogRecord calldata log) external vmOnly {
        // Simplest possible react - just record that it was called
        reactCallCount++;
        lastReactBlock = block.number;
        lastSeenChainId = log.chain_id;
        lastSeenContract = log._contract;
        
        emit ReactCalled(log.chain_id, log._contract, log.topic_0, block.number);
    }
    
    receive() external payable override(AbstractPayer, IPayer) {}
}
