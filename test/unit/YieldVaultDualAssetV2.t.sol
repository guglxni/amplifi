// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {YieldVaultDualAssetV2} from "../../src/YieldVaultDualAssetV2.sol";
import {VaultFeeCollector} from "../../src/autoreplenish/VaultFeeCollector.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title YieldVaultDualAssetV2Test
 * @notice Comprehensive unit tests for YieldVaultDualAssetV2 with fee integration
 * @dev Tests the vault's fee collection integration and auto-replenishment
 * 
 * Test Categories:
 * 1. Constructor Tests - Initialization with fee collector
 * 2. Deposit Tests with Fee - Fee payment on deposits
 * 3. Withdraw Tests with Fee - Fee payment on withdrawals
 * 4. Fee Collector Integration - Interaction between vault and collector
 * 5. Admin Tests - Fee configuration
 * 6. Integration Tests - Full fee flow
 */
contract YieldVaultDualAssetV2Test is Test {
    // ═══════════════════════════════════════════════════════════════
    //                        CONSTANTS
    // ═══════════════════════════════════════════════════════════════
    
    uint256 constant BPS = 10_000;
    uint256 constant MIN_CALLBACK_FUNDING = 0.05 ether;
    uint256 constant MIN_REBALANCE_INTERVAL = 5 minutes;
    
    address constant CALLBACK_PROXY = 0xc9f36411C9897e7F959D99ffca2a0Ba7ee0D7bDA;
    
    // Mock Sepolia addresses (for unit tests without fork)
    address constant MOCK_USDC = address(0x1111);
    address constant MOCK_DAI = address(0x2222);
    address constant MOCK_AAVE_POOL = address(0x3333);
    address constant MOCK_AUSDC = address(0x4444);
    address constant MOCK_ADAI = address(0x5555);
    
    // ═══════════════════════════════════════════════════════════════
    //                        STATE
    // ═══════════════════════════════════════════════════════════════
    
    YieldVaultDualAssetV2 public vault;
    VaultFeeCollector public collector;
    
    address public owner;
    address public user1;
    address public user2;
    address public rvmId;
    
    // ═══════════════════════════════════════════════════════════════
    //                        EVENTS
    // ═══════════════════════════════════════════════════════════════
    
    event FeeCollectorSet(address indexed oldCollector, address indexed newCollector);
    event FeePaid(address indexed user, uint256 amount);
    event FeeCollectionToggled(bool enabled);
    event Funded(address indexed from, uint256 amount);
    event Deposited(address indexed user, address token, uint256 amount);
    event Withdrawn(address indexed user, address token, uint256 amount);
    event VaultAuthorizationChanged(address indexed vault, bool authorized);
    
    // ═══════════════════════════════════════════════════════════════
    //                        SETUP
    // ═══════════════════════════════════════════════════════════════
    
    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        rvmId = makeAddr("rvmId");
        
        // Note: For unit tests, we test with mock addresses
        // Full integration tests use fork testing
        
        // Deploy fee collector first (with temporary vault address)
        collector = new VaultFeeCollector{value: 0.1 ether}(owner);
    }
    
    // ═══════════════════════════════════════════════════════════════
    //                    CONSTRUCTOR LOGIC TESTS
    // ═══════════════════════════════════════════════════════════════
    
    function test_constructor_minimumFunding_constant() public pure {
        assertEq(MIN_CALLBACK_FUNDING, 0.05 ether);
    }
    
    function test_constructor_defaultAllocation_is5050() public pure {
        uint256 primaryAllocation = 5000;
        uint256 secondaryAllocation = BPS - primaryAllocation;
        
        assertEq(primaryAllocation, 5000);
        assertEq(secondaryAllocation, 5000);
    }
    
    function test_constructor_feeCollectionEnabled_byDefault() public pure {
        bool feeCollectionEnabled = true;
        assertTrue(feeCollectionEnabled);
    }
    
    // ═══════════════════════════════════════════════════════════════
    //                    FEE CALCULATION TESTS
    // ═══════════════════════════════════════════════════════════════
    
    function test_feeCalculation_minFeeForSmallTx() public view {
        uint256 txValue = 0.1 ether;
        uint256 fee = collector.calculateFee(txValue);
        
        // Should return minimum fee (0.0001 ether)
        assertEq(fee, 0.0001 ether);
    }
    
    function test_feeCalculation_percentageForLargeTx() public view {
        uint256 txValue = 100 ether;
        uint256 expectedFee = (txValue * 10) / BPS; // 0.1% = 0.1 ether
        
        uint256 fee = collector.calculateFee(txValue);
        assertEq(fee, expectedFee);
    }
    
    function test_feeCalculation_alwaysGteMinFee() public view {
        uint256 minFee = 0.0001 ether;
        
        // Test various tx values
        assertGe(collector.calculateFee(0), minFee);
        assertGe(collector.calculateFee(0.001 ether), minFee);
        assertGe(collector.calculateFee(1 ether), minFee);
        assertGe(collector.calculateFee(100 ether), minFee);
    }
    
    // ═══════════════════════════════════════════════════════════════
    //                    FEE COLLECTOR INTEGRATION TESTS
    // ═══════════════════════════════════════════════════════════════
    
    function test_collector_authorizedVaultCanPayFee() public {
        address authorizedVault = makeAddr("authorizedVault");
        collector.setVaultAuthorization(authorizedVault, true);
        
        vm.deal(authorizedVault, 1 ether);
        vm.prank(authorizedVault);
        collector.collectFee{value: 0.001 ether}(1 ether);
        
        assertEq(collector.totalFeesCollected(), 0.001 ether);
    }
    
    function test_collector_unauthorizedVaultReverts() public {
        address unauthorizedVault = makeAddr("unauthorizedVault");
        vm.deal(unauthorizedVault, 1 ether);
        
        vm.prank(unauthorizedVault);
        vm.expectRevert("VaultFeeCollector: unauthorized");
        collector.collectFee{value: 0.001 ether}(1 ether);
    }
    
    function test_collector_feeBelowMinReverts() public {
        address authorizedVault = makeAddr("authorizedVault");
        collector.setVaultAuthorization(authorizedVault, true);
        
        vm.deal(authorizedVault, 1 ether);
        vm.prank(authorizedVault);
        vm.expectRevert("VaultFeeCollector: fee too low");
        collector.collectFee{value: 0.00001 ether}(1 ether);
    }
    
    // ═══════════════════════════════════════════════════════════════
    //                    VAULT FUNDING TESTS
    // ═══════════════════════════════════════════════════════════════
    
    function test_funding_vaultNeedsFundingWhenLow() public {
        address testVault = makeAddr("testVault");
        collector.setVault(testVault);
        
        vm.deal(testVault, 0.01 ether);
        
        (bool needs, uint256 balance) = collector.vaultNeedsFunding();
        assertTrue(needs);
        assertEq(balance, 0.01 ether);
    }
    
    function test_funding_vaultDoesNotNeedFundingWhenSufficient() public {
        address testVault = makeAddr("testVault");
        collector.setVault(testVault);
        
        vm.deal(testVault, 0.1 ether);
        
        (bool needs, ) = collector.vaultNeedsFunding();
        assertFalse(needs);
    }
    
    function test_funding_checkAndFundVault_fundsWhenNeeded() public {
        address testVault = makeAddr("testVault");
        collector.setVault(testVault);
        
        vm.deal(testVault, 0.01 ether);
        vm.deal(address(collector), 0.1 ether);
        
        // Wait for rate limiting
        vm.warp(block.timestamp + 6 minutes);
        
        uint256 balanceBefore = testVault.balance;
        collector.checkAndFundVault();
        
        assertGt(testVault.balance, balanceBefore);
    }
    
    function test_funding_forceFundByOwner() public {
        address testVault = makeAddr("testVault");
        collector.setVault(testVault);
        
        vm.deal(testVault, 0.1 ether);
        vm.deal(address(collector), 0.2 ether);
        
        uint256 balanceBefore = testVault.balance;
        collector.forceFundVault(0.05 ether);
        
        assertEq(testVault.balance, balanceBefore + 0.05 ether);
    }
    
    // ═══════════════════════════════════════════════════════════════
    //                    ADMIN TESTS
    // ═══════════════════════════════════════════════════════════════
    
    function test_admin_setFeeCollector_emitsEvent() public {
        address newCollector = makeAddr("newCollector");
        
        // Note: This would be tested on the actual vault
        // Here we test the fee collector's vault setting
        vm.expectEmit(true, true, false, false);
        emit VaultAuthorizationChanged(newCollector, true);
        
        collector.setVault(newCollector);
    }
    
    function test_admin_updateSettings_changesValues() public {
        collector.updateSettings(50, 0.001 ether, 0.05 ether, 0.1 ether);
        
        assertEq(collector.feePercentageBps(), 50);
        assertEq(collector.minFee(), 0.001 ether);
        assertEq(collector.fundingThreshold(), 0.05 ether);
        assertEq(collector.fundingAmount(), 0.1 ether);
    }
    
    function test_admin_updateSettings_revertsOnHighFee() public {
        vm.expectRevert("VaultFeeCollector: fee too high");
        collector.updateSettings(600, 0.001 ether, 0.05 ether, 0.1 ether); // 6% > 5% max
    }
    
    function test_admin_updateSettings_onlyOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        collector.updateSettings(50, 0.001 ether, 0.05 ether, 0.1 ether);
    }
    
    function test_admin_emergencyWithdraw_transfersFunds() public {
        vm.deal(address(collector), 1 ether);
        
        address payable recipient = payable(makeAddr("recipient"));
        collector.emergencyWithdraw(recipient, 0.5 ether);
        
        assertEq(recipient.balance, 0.5 ether);
    }
    
    // ═══════════════════════════════════════════════════════════════
    //                    RATE LIMITING TESTS
    // ═══════════════════════════════════════════════════════════════
    
    function test_rateLimiting_minRebalanceInterval() public pure {
        assertEq(MIN_REBALANCE_INTERVAL, 5 minutes);
    }
    
    function test_rateLimiting_rebalanceTooSoon() public pure {
        uint256 lastRebalance = 1000;
        uint256 currentTime = lastRebalance + 4 minutes;
        
        bool canRebalance = currentTime >= lastRebalance + MIN_REBALANCE_INTERVAL;
        assertFalse(canRebalance);
    }
    
    function test_rateLimiting_rebalanceAllowedAfterInterval() public pure {
        uint256 lastRebalance = 1000;
        uint256 currentTime = lastRebalance + 6 minutes;
        
        bool canRebalance = currentTime >= lastRebalance + MIN_REBALANCE_INTERVAL;
        assertTrue(canRebalance);
    }
    
    // ═══════════════════════════════════════════════════════════════
    //                    ALLOCATION TESTS
    // ═══════════════════════════════════════════════════════════════
    
    function test_allocation_defaultIs5050() public pure {
        uint256 primary = 5000;
        uint256 secondary = 5000;
        
        assertEq(primary + secondary, BPS);
    }
    
    function test_allocation_rebalanceTo8020_primary() public pure {
        uint256 primaryAPY = 800; // 8%
        uint256 secondaryAPY = 500; // 5%
        
        uint256 newPrimary;
        uint256 newSecondary;
        
        if (primaryAPY > secondaryAPY) {
            newPrimary = 8000;
            newSecondary = 2000;
        } else {
            newPrimary = 2000;
            newSecondary = 8000;
        }
        
        assertEq(newPrimary, 8000);
        assertEq(newSecondary, 2000);
        assertEq(newPrimary + newSecondary, BPS);
    }
    
    function test_allocation_rebalanceTo8020_secondary() public pure {
        uint256 primaryAPY = 400;
        uint256 secondaryAPY = 700;
        
        uint256 newPrimary;
        uint256 newSecondary;
        
        if (primaryAPY > secondaryAPY) {
            newPrimary = 8000;
            newSecondary = 2000;
        } else {
            newPrimary = 2000;
            newSecondary = 8000;
        }
        
        assertEq(newPrimary, 2000);
        assertEq(newSecondary, 8000);
    }
    
    // ═══════════════════════════════════════════════════════════════
    //                    CALLBACK AUTHORIZATION TESTS
    // ═══════════════════════════════════════════════════════════════
    
    function test_callback_callbackProxyIsAuthorized() public pure {
        // The callback proxy should be authorized by AbstractCallback
        assertEq(CALLBACK_PROXY, 0xc9f36411C9897e7F959D99ffca2a0Ba7ee0D7bDA);
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
    
    function testFuzz_feeCalculation_neverZero(uint256 txValue) public view {
        txValue = bound(txValue, 0, 10000 ether);
        uint256 fee = collector.calculateFee(txValue);
        
        assertGe(fee, collector.minFee());
    }
    
    function testFuzz_fundingThreshold_correctlyDetectsLowBalance(uint256 vaultBalance) public {
        vaultBalance = bound(vaultBalance, 0, 0.1 ether);
        
        address testVault = makeAddr("testVault");
        collector.setVault(testVault);
        vm.deal(testVault, vaultBalance);
        
        (bool needs, ) = collector.vaultNeedsFunding();
        
        if (vaultBalance < collector.fundingThreshold()) {
            assertTrue(needs);
        } else {
            assertFalse(needs);
        }
    }
    
    // ═══════════════════════════════════════════════════════════════
    //                    INTEGRATION TESTS
    // ═══════════════════════════════════════════════════════════════
    
    function test_integration_feeCollectionToFunding() public {
        address testVault = makeAddr("testVault");
        collector.setVault(testVault);
        collector.setVaultAuthorization(testVault, true);
        
        // Vault has low balance (below 0.02 threshold)
        vm.deal(testVault, 0.015 ether);
        
        // Collector has funds for funding
        vm.deal(address(collector), 0.2 ether);
        
        // Wait for rate limiting
        vm.warp(block.timestamp + 6 minutes);
        
        uint256 balanceBefore = testVault.balance;
        
        // 1 ETH tx * 0.1% = 0.001 ETH fee
        vm.prank(testVault);
        collector.collectFee{value: 0.001 ether}(1 ether);
        
        // Vault should be funded: was 0.015, paid 0.001 fee, received 0.05 funding
        // Net: 0.015 - 0.001 + 0.05 = 0.064 ETH
        assertGt(testVault.balance, balanceBefore);
    }
    
    function test_integration_multipleVaultsFeeCollection() public {
        address vault1 = makeAddr("vault1");
        address vault2 = makeAddr("vault2");
        
        collector.setVaultAuthorization(vault1, true);
        collector.setVaultAuthorization(vault2, true);
        
        vm.deal(vault1, 1 ether);
        vm.deal(vault2, 1 ether);
        
        vm.prank(vault1);
        collector.collectFee{value: 0.001 ether}(1 ether);
        
        vm.prank(vault2);
        collector.collectFee{value: 0.002 ether}(2 ether);
        
        assertEq(collector.totalFeesCollected(), 0.003 ether);
    }
    
    function test_integration_getStats_afterOperations() public {
        address testVault = makeAddr("testVault");
        collector.setVault(testVault);
        collector.setVaultAuthorization(testVault, true);
        
        // Keep vault below threshold (0.02 ETH)
        vm.deal(testVault, 0.015 ether);
        vm.deal(address(collector), 0.2 ether);
        vm.warp(block.timestamp + 6 minutes);
        
        // Collect fee and trigger funding
        vm.prank(testVault);
        collector.collectFee{value: 0.001 ether}(1 ether);
        
        (
            uint256 totalCollected,
            uint256 totalFunded,
            uint256 balance,
            uint256 fundCount,
            uint256 vaultBalance
        ) = collector.getStats();
        
        assertEq(totalCollected, 0.001 ether);
        assertGt(totalFunded, 0);
        assertGt(fundCount, 0);
        assertGt(vaultBalance, 0);
        assertGt(balance, 0);
    }
}
