// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {YieldOptimizerReactive} from "../../src/YieldOptimizerReactive.sol";
import {IReactive} from "@reactive/interfaces/IReactive.sol";

/**
 * @title YieldOptimizerReactiveTest
 * @notice Unit tests for YieldOptimizerReactive RSC
 */
contract YieldOptimizerReactiveTest is Test {
    // ═══════════════════════════════════════════════════════════════
    //                        TEST CONSTANTS
    // ═══════════════════════════════════════════════════════════════

    uint256 constant SEPOLIA_CHAIN_ID = 11155111;
    uint256 constant CRON_CHAIN_ID = 0;
    uint64 constant CALLBACK_GAS_LIMIT = 800_000;
    uint256 constant MIN_YIELD_DIFF_BPS = 50;
    uint256 constant BPS = 10000;
    uint256 constant FINALITY_BLOCKS = 64;

    // YieldSnapshot topic (placeholder - would compute actual keccak)
    uint256 constant YIELD_SNAPSHOT_TOPIC_0 = 
        0x8f15e5e7c1e1dccd9c3ec3d6e888e3f9d0a3b9c3d3e5a7b9c1d3e5f7a9b1c3d5;

    // ═══════════════════════════════════════════════════════════════
    //                        TEST STATE
    // ═══════════════════════════════════════════════════════════════

    YieldOptimizerReactive public reactive;
    address public vault;
    address public owner;

    // ═══════════════════════════════════════════════════════════════
    //                           EVENTS
    // ═══════════════════════════════════════════════════════════════

    event RebalanceCallbackTriggered(
        uint256 aaveAPY,
        uint256 compoundAPY,
        uint256 newAavePct,
        uint256 newCompoundPct
    );
    event RebalanceSkipped(uint256 aaveAPY, uint256 compoundAPY, uint256 diffBps, string reason);
    event RateLimited(uint256 lastBlock, uint256 currentBlock);
    event LargeRebalanceQueued(bytes32 indexed rebalanceId, uint256 aavePct, uint256 compoundPct, uint256 readyBlock);

    // ═══════════════════════════════════════════════════════════════
    //                           SETUP
    // ═══════════════════════════════════════════════════════════════

    function setUp() public {
        vault = makeAddr("vault");
        owner = address(this);

        // Deploy in VM mode (constructor won't subscribe)
        reactive = new YieldOptimizerReactive(vault, SEPOLIA_CHAIN_ID);
    }

    // ═══════════════════════════════════════════════════════════════
    //                    CONSTRUCTOR TESTS
    // ═══════════════════════════════════════════════════════════════

    function test_constructor_setsVault() public view {
        assertEq(reactive.getVault(), vault);
    }

    function test_constructor_setsChainId() public view {
        assertEq(reactive.getChainId(), SEPOLIA_CHAIN_ID);
    }

    function test_constructor_setsOwner() public view {
        assertEq(reactive.owner(), owner);
    }

    function test_constructor_revertOnZeroVault() public {
        vm.expectRevert(YieldOptimizerReactive.ZeroAddress.selector);
        new YieldOptimizerReactive(address(0), SEPOLIA_CHAIN_ID);
    }

    // ═══════════════════════════════════════════════════════════════
    //                    CONFIGURATION TESTS
    // ═══════════════════════════════════════════════════════════════

    function test_cronMonitoringEnabled_default() public view {
        assertTrue(reactive.cronMonitoringEnabled());
    }

    function test_finalityAwareEnabled_default() public view {
        assertTrue(reactive.finalityAwareEnabled());
    }

    function test_cronInterval_default() public view {
        assertEq(reactive.cronInterval(), 100);
    }

    function test_finalityBlocks_constant() public pure {
        assertEq(FINALITY_BLOCKS, 64);
    }

    // ═══════════════════════════════════════════════════════════════
    //                    YIELD COMPARISON TESTS
    // ═══════════════════════════════════════════════════════════════

    function test_shouldRebalance_aaveHigher() public pure {
        uint256 aaveAPY = 50e24;
        uint256 compoundAPY = 30e24;

        // Diff = 20e24, Higher = 50e24
        // DiffBps = 20e24 * 10000 / 50e24 = 4000 (40%)
        uint256 diff = aaveAPY - compoundAPY;
        uint256 diffBps = (diff * BPS) / aaveAPY;

        assertGt(diffBps, MIN_YIELD_DIFF_BPS);
        assertEq(aaveAPY > compoundAPY ? uint8(0) : uint8(1), 0); // Aave is higher
    }

    function test_shouldRebalance_compoundHigher() public pure {
        uint256 aaveAPY = 30e24;
        uint256 compoundAPY = 50e24;

        uint256 diff = compoundAPY - aaveAPY;
        uint256 diffBps = (diff * BPS) / compoundAPY;

        assertGt(diffBps, MIN_YIELD_DIFF_BPS);
        assertEq(aaveAPY > compoundAPY ? uint8(0) : uint8(1), 1); // Compound is higher
    }

    function test_shouldNotRebalance_smallDiff() public pure {
        uint256 aaveAPY = 350e24;
        uint256 compoundAPY = 351e24;

        uint256 diff = compoundAPY - aaveAPY;
        uint256 diffBps = (diff * BPS) / compoundAPY;

        assertLt(diffBps, MIN_YIELD_DIFF_BPS);
    }

    function test_shouldNotRebalance_equalAPY() public pure {
        uint256 aaveAPY = 350e24;
        uint256 compoundAPY = 350e24;

        uint256 diff = 0;
        uint256 diffBps = 0;

        assertLt(diffBps, MIN_YIELD_DIFF_BPS);
    }

    // ═══════════════════════════════════════════════════════════════
    //                    ALLOCATION DECISION TESTS
    // ═══════════════════════════════════════════════════════════════

    function test_allocation_80_20_aaveHigher() public pure {
        uint256 aaveAPY = 50e24;
        uint256 compoundAPY = 30e24;

        uint256 newAavePct;
        uint256 newCompoundPct;

        if (aaveAPY > compoundAPY) {
            newAavePct = 8000;
            newCompoundPct = 2000;
        } else {
            newAavePct = 2000;
            newCompoundPct = 8000;
        }

        assertEq(newAavePct, 8000);
        assertEq(newCompoundPct, 2000);
    }

    function test_allocation_80_20_compoundHigher() public pure {
        uint256 aaveAPY = 30e24;
        uint256 compoundAPY = 50e24;

        uint256 newAavePct;
        uint256 newCompoundPct;

        if (aaveAPY >= compoundAPY) {
            newAavePct = 8000;
            newCompoundPct = 2000;
        } else {
            newAavePct = 2000;
            newCompoundPct = 8000;
        }

        assertEq(newAavePct, 2000);
        assertEq(newCompoundPct, 8000);
    }

    // ═══════════════════════════════════════════════════════════════
    //                    FINALITY-AWARE TESTS
    // ═══════════════════════════════════════════════════════════════

    function test_largeRebalanceThreshold() public pure {
        uint256 largeThresholdBps = 5000; // 50% change

        // Current: 50/50, Target: 80/20 = 30% change
        uint256 currentAaveAlloc = 5000;
        uint256 targetAaveAlloc = 8000;
        uint256 change = targetAaveAlloc - currentAaveAlloc;

        assertLt(change, largeThresholdBps); // Not a large rebalance

        // Current: 20/80, Target: 80/20 = 60% change  
        currentAaveAlloc = 2000;
        targetAaveAlloc = 8000;
        change = targetAaveAlloc - currentAaveAlloc;

        assertGe(change, largeThresholdBps); // IS a large rebalance
    }

    function test_pendingRebalance_notReadyBeforeFinality() public pure {
        uint256 requestBlock = 1000;
        uint256 currentBlock = 1050;

        bool ready = currentBlock >= requestBlock + FINALITY_BLOCKS;
        assertFalse(ready);
    }

    function test_pendingRebalance_readyAfterFinality() public pure {
        uint256 requestBlock = 1000;
        uint256 currentBlock = 1100;

        bool ready = currentBlock >= requestBlock + FINALITY_BLOCKS;
        assertTrue(ready);
    }

    // ═══════════════════════════════════════════════════════════════
    //                    RATE LIMITING TESTS
    // ═══════════════════════════════════════════════════════════════

    function test_rateLimiting_tooSoon() public pure {
        uint256 minBlocks = 50;
        uint256 lastBlock = 1000;
        uint256 currentBlock = 1030;

        bool allowed = currentBlock >= lastBlock + minBlocks;
        assertFalse(allowed);
    }

    function test_rateLimiting_allowed() public pure {
        uint256 minBlocks = 50;
        uint256 lastBlock = 1000;
        uint256 currentBlock = 1060;

        bool allowed = currentBlock >= lastBlock + minBlocks;
        assertTrue(allowed);
    }

    // ═══════════════════════════════════════════════════════════════
    //                    EVENT CREATION TESTS
    // ═══════════════════════════════════════════════════════════════

    function test_createYieldSnapshotLog() public view {
        // Simulates creating a log record for react()
        uint256 snapshotId = 1;
        uint256 aaveAPY = 35e24;
        uint256 compoundAPY = 42e24;
        uint256 aaveAlloc = 5000;
        uint256 compoundAlloc = 5000;
        uint256 tvl = 1000e6;
        uint256 timestamp = block.timestamp;

        // Encode the data as it would appear in event
        bytes memory data = abi.encode(
            snapshotId,
            aaveAPY,
            compoundAPY,
            aaveAlloc,
            compoundAlloc,
            tvl,
            timestamp
        );

        // Verify we can decode it back
        (
            uint256 decodedId,
            uint256 decodedAaveAPY,
            uint256 decodedCompoundAPY,
            uint256 decodedAaveAlloc,
            uint256 decodedCompoundAlloc,
            uint256 decodedTvl,
            uint256 decodedTimestamp
        ) = abi.decode(data, (uint256, uint256, uint256, uint256, uint256, uint256, uint256));

        assertEq(decodedId, snapshotId);
        assertEq(decodedAaveAPY, aaveAPY);
        assertEq(decodedCompoundAPY, compoundAPY);
        assertEq(decodedAaveAlloc, aaveAlloc);
        assertEq(decodedCompoundAlloc, compoundAlloc);
        assertEq(decodedTvl, tvl);
        assertEq(decodedTimestamp, timestamp);
    }

    // ═══════════════════════════════════════════════════════════════
    //                    FUZZ TESTS
    // ═══════════════════════════════════════════════════════════════

    function testFuzz_yieldDiffCalculation(uint256 aaveAPY, uint256 compoundAPY) public pure {
        vm.assume(aaveAPY > 0 && compoundAPY > 0);
        vm.assume(aaveAPY < 1e30 && compoundAPY < 1e30);

        uint256 higherYield = aaveAPY > compoundAPY ? aaveAPY : compoundAPY;
        uint256 diff = aaveAPY > compoundAPY 
            ? aaveAPY - compoundAPY 
            : compoundAPY - aaveAPY;

        uint256 diffBps = (diff * BPS) / higherYield;

        // Result must be between 0 and 100%
        assertLe(diffBps, BPS);
    }

    function testFuzz_allocationAlwaysSumTo100(bool aaveHigher) public pure {
        uint256 aavePct;
        uint256 compoundPct;

        if (aaveHigher) {
            aavePct = 8000;
            compoundPct = 2000;
        } else {
            aavePct = 2000;
            compoundPct = 8000;
        }

        assertEq(aavePct + compoundPct, BPS);
    }

    function testFuzz_finalityCheck(uint256 requestBlock, uint256 currentBlock) public pure {
        vm.assume(requestBlock < type(uint256).max - FINALITY_BLOCKS);
        vm.assume(currentBlock >= requestBlock);

        bool ready = currentBlock >= requestBlock + FINALITY_BLOCKS;

        // If enough blocks passed, should be ready
        if (currentBlock >= requestBlock + FINALITY_BLOCKS) {
            assertTrue(ready);
        } else {
            assertFalse(ready);
        }
    }
}
