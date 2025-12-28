// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import '../lib/reactive-lib/src/interfaces/IReactive.sol';
import '../lib/reactive-lib/src/interfaces/IPayer.sol';
import '../lib/reactive-lib/src/abstract-base/AbstractReactive.sol';
import '../lib/reactive-lib/src/abstract-base/AbstractPayer.sol';

/**
 * @title WildcardTestRSC
 * @notice RSC that subscribes to ALL events from our vault to test if react() is called
 */
contract WildcardTestRSC is IReactive, AbstractReactive {
    
    event ReactCalled(uint256 chainId, address sourceContract, uint256 topic0);
    event Subscribed();
    
    uint256 private constant SEPOLIA_CHAIN_ID = 11155111;
    address private constant VAULT = 0xe6e06F94d1aaa2496b9e33afeE29f01436E9fA4A;
    
    uint256 public reactCallCount;
    uint256 public lastReactBlock;
    
    constructor() payable {
        if (!vm) {
            // Subscribe to ALL events from VAULT, not just YieldSnapshot
            service.subscribe(
                SEPOLIA_CHAIN_ID,
                VAULT,
                REACTIVE_IGNORE,  // Match ANY topic_0
                REACTIVE_IGNORE,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE
            );
            emit Subscribed();
        }
    }
    
    function react(LogRecord calldata log) external vmOnly {
        reactCallCount++;
        lastReactBlock = block.number;
        emit ReactCalled(log.chain_id, log._contract, log.topic_0);
    }
    
    receive() external payable override(AbstractPayer, IPayer) {}
}
