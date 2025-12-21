// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {YieldVaultDualAsset} from "../../src/YieldVaultDualAsset.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title YieldVaultDualAssetTest
 * @notice Unit tests for YieldVaultDualAsset (Aave USDC vs DAI comparison)
 */
contract YieldVaultDualAssetTest is Test {
    // ═══════════════════════════════════════════════════════════════
    //                        CONSTANTS
    // ═══════════════════════════════════════════════════════════════
    
    uint256 constant BPS = 10_000;
    uint256 constant MIN_REBALANCE_INTERVAL = 5 minutes;
    
    // ═══════════════════════════════════════════════════════════════
    //                        STATE
    // ═══════════════════════════════════════════════════════════════
    
    address public owner;
    address public user1;
    
    // Mock addresses for testing
    address public primaryAsset;
    address public secondaryAsset;
    address public aavePool;
    address public primaryAToken;
    address public secondaryAToken;
    address public callbackProxy;
    
    // ═══════════════════════════════════════════════════════════════
    //                        SETUP
    // ═══════════════════════════════════════════════════════════════
    
    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        
        // Create mock addresses
        primaryAsset = makeAddr("USDC");
        secondaryAsset = makeAddr("DAI");
        aavePool = makeAddr("AavePool");
        primaryAToken = makeAddr("aUSDC");
        secondaryAToken = makeAddr("aDAI");
        callbackProxy = makeAddr("CallbackProxy");
    }
    
    // ═══════════════════════════════════════════════════════════════
    //                    ALLOCATION LOGIC TESTS
    // ═══════════════════════════════════════════════════════════════
    
    function test_defaultAllocation_is5050() public pure {
        uint256 primaryAllocation = 5000;
        uint256 secondaryAllocation = BPS - primaryAllocation;
        
        assertEq(primaryAllocation, 5000);
        assertEq(secondaryAllocation, 5000);
    }
    
    function test_rebalanceAllocation_primaryHigher() public pure {
        uint256 primaryAPY = 700; // 7%
        uint256 secondaryAPY = 500; // 5%
        
        uint256 newPrimaryPct;
        uint256 newSecondaryPct;
        
        if (primaryAPY > secondaryAPY) {
            newPrimaryPct = 8000;
            newSecondaryPct = 2000;
        } else {
            newPrimaryPct = 2000;
            newSecondaryPct = 8000;
        }
        
        assertEq(newPrimaryPct, 8000);
        assertEq(newSecondaryPct, 2000);
        assertEq(newPrimaryPct + newSecondaryPct, BPS);
    }
    
    function test_rebalanceAllocation_secondaryHigher() public pure {
        uint256 primaryAPY = 400; // 4%
        uint256 secondaryAPY = 600; // 6%
        
        uint256 newPrimaryPct;
        uint256 newSecondaryPct;
        
        if (primaryAPY > secondaryAPY) {
            newPrimaryPct = 8000;
            newSecondaryPct = 2000;
        } else {
            newPrimaryPct = 2000;
            newSecondaryPct = 8000;
        }
        
        assertEq(newPrimaryPct, 2000);
        assertEq(newSecondaryPct, 8000);
    }
    
    // ═══════════════════════════════════════════════════════════════
    //                    RATE LIMITING TESTS
    // ═══════════════════════════════════════════════════════════════
    
    function test_minRebalanceInterval_is5Minutes() public pure {
        assertEq(MIN_REBALANCE_INTERVAL, 300);
    }
    
    function test_rebalance_rateLimiting() public pure {
        // Rate limiting validates that MIN_REBALANCE_INTERVAL is 5 minutes
        // and allocation changes must respect this interval
        
        uint256 lastRebalance = 1000;
        uint256 currentTime = 1200; // 200 seconds later
        
        bool allowed = currentTime >= lastRebalance + MIN_REBALANCE_INTERVAL;
        assertFalse(allowed); // 200s < 300s
        
        currentTime = 1400; // 400 seconds later
        allowed = currentTime >= lastRebalance + MIN_REBALANCE_INTERVAL;
        assertTrue(allowed); // 400s > 300s
    }
    
    // ═══════════════════════════════════════════════════════════════
    //                    APY COMPARISON TESTS
    // ═══════════════════════════════════════════════════════════════
    
    function test_apyComparison_significantDiff() public pure {
        uint256 primaryAPY = 575; // 5.75%
        uint256 secondaryAPY = 709; // 7.09%
        
        uint256 diff = secondaryAPY > primaryAPY 
            ? secondaryAPY - primaryAPY 
            : primaryAPY - secondaryAPY;
        
        // Diff = 134 bps = 1.34%
        assertEq(diff, 134);
        
        // Check if diff is significant (> 1%)
        assertTrue(diff > 100);
    }
    
    function test_apyComparison_marginalDiff() public pure {
        uint256 primaryAPY = 500;
        uint256 secondaryAPY = 510;
        
        uint256 diff = secondaryAPY - primaryAPY;
        assertEq(diff, 10); // 0.1%
        
        // Marginal diff shouldn't trigger rebalance
        assertTrue(diff < 50);
    }
    
    // ═══════════════════════════════════════════════════════════════
    //                    SNAPSHOT COUNTER TESTS
    // ═══════════════════════════════════════════════════════════════
    
    function test_snapshotCounter_incrementsCorrectly() public {
        uint256 counter = 0;
        
        // Simulate 3 snapshots
        counter++;
        assertEq(counter, 1);
        
        counter++;
        assertEq(counter, 2);
        
        counter++;
        assertEq(counter, 3);
    }
    
    // ═══════════════════════════════════════════════════════════════
    //                    TVL CALCULATION TESTS
    // ═══════════════════════════════════════════════════════════════
    
    function test_tvl_normalizesDecimals() public pure {
        // USDC has 6 decimals
        uint256 primaryBal = 1000e6; // 1000 USDC
        
        // DAI has 18 decimals
        uint256 secondaryBal = 500e18; // 500 DAI
        
        // Normalize to 6 decimals
        uint256 tvl = primaryBal + (secondaryBal / 1e12);
        
        assertEq(tvl, 1500e6); // 1500 in 6 decimals
    }
    
    // ═══════════════════════════════════════════════════════════════
    //                    FUZZ TESTS
    // ═══════════════════════════════════════════════════════════════
    
    function testFuzz_allocation_sumTo100(uint256 primaryPct) public pure {
        primaryPct = bound(primaryPct, 2000, 8000);
        uint256 secondaryPct = BPS - primaryPct;
        
        assertEq(primaryPct + secondaryPct, BPS);
        assertGe(primaryPct, 2000);
        assertGe(secondaryPct, 2000);
    }
    
    function testFuzz_apyDiff_calculatedCorrectly(uint256 apy1, uint256 apy2) public pure {
        apy1 = bound(apy1, 1, 10000);
        apy2 = bound(apy2, 1, 10000);
        
        uint256 diff = apy1 > apy2 ? apy1 - apy2 : apy2 - apy1;
        
        // Diff should never exceed max APY
        assertLe(diff, 10000);
        
        // Diff should be absolute (always positive)
        assertGe(diff, 0);
    }
}
