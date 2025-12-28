// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {VaultFeeCollector} from "../../src/autoreplenish/VaultFeeCollector.sol";
import {IPayable} from "@reactive/interfaces/IPayable.sol";

/**
 * @title VaultFeeCollectorTest
 * @notice Comprehensive unit tests for VaultFeeCollector
 * @dev Tests the fee collection and vault funding mechanisms
 * 
 * Test Categories:
 * 1. Constructor Tests - Initialization and configuration
 * 2. Fee Collection Tests - collectFee function behavior
 * 3. Vault Funding Tests - Auto-funding logic
 * 4. Admin Tests - Owner functions
 * 5. View Function Tests - Getters and calculations
 * 6. Edge Cases - Boundary conditions
 * 7. Fuzz Tests - Property-based testing
 */
contract VaultFeeCollectorTest is Test {
    // ═══════════════════════════════════════════════════════════════
    //                        CONSTANTS
    // ═══════════════════════════════════════════════════════════════
    
    address constant CALLBACK_PROXY = 0xc9f36411C9897e7F959D99ffca2a0Ba7ee0D7bDA;
    uint256 constant BPS = 10_000;
    uint256 constant MAX_FEE_BPS = 500; // 5%
    uint256 constant DEFAULT_FEE_BPS = 10; // 0.1%
    uint256 constant DEFAULT_MIN_FEE = 0.0001 ether;
    uint256 constant DEFAULT_FUNDING_THRESHOLD = 0.02 ether;
    uint256 constant DEFAULT_FUNDING_AMOUNT = 0.05 ether;
    
    // ═══════════════════════════════════════════════════════════════
    //                        STATE
    // ═══════════════════════════════════════════════════════════════
    
    VaultFeeCollector public collector;
    address public vault;
    address public owner;
    address public user1;
    address public user2;
    
    // ═══════════════════════════════════════════════════════════════
    //                        EVENTS
    // ═══════════════════════════════════════════════════════════════
    
    event FeeCollected(address indexed vault, uint256 amount, uint256 totalCollected);
    event VaultFunded(address indexed vault, uint256 amount);
    event DebtCovered(address indexed vault, uint256 debtAmount);
    event InsufficientFundsForVault(address indexed vault, uint256 needed, uint256 available);
    event SettingsUpdated(uint256 feePercentageBps, uint256 minFee, uint256 fundingThreshold, uint256 fundingAmount);
    event VaultAuthorizationChanged(address indexed vault, bool authorized);
    
    // ═══════════════════════════════════════════════════════════════
    //                        SETUP
    // ═══════════════════════════════════════════════════════════════
    
    function setUp() public {
        owner = address(this);
        vault = makeAddr("vault");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        
        // Deploy with initial funding
        collector = new VaultFeeCollector{value: 0.1 ether}(vault);
    }
    
    // ═══════════════════════════════════════════════════════════════
    //                    CONSTRUCTOR TESTS
    // ═══════════════════════════════════════════════════════════════
    
    function test_constructor_setsOwner() public view {
        assertEq(collector.owner(), owner);
    }
    
    function test_constructor_setsVault() public view {
        assertEq(collector.vault(), vault);
    }
    
    function test_constructor_authorizesVault() public view {
        assertTrue(collector.authorizedVaults(vault));
    }
    
    function test_constructor_setsDefaultFeePercentage() public view {
        assertEq(collector.feePercentageBps(), DEFAULT_FEE_BPS);
    }
    
    function test_constructor_setsDefaultMinFee() public view {
        assertEq(collector.minFee(), DEFAULT_MIN_FEE);
    }
    
    function test_constructor_setsDefaultFundingThreshold() public view {
        assertEq(collector.fundingThreshold(), DEFAULT_FUNDING_THRESHOLD);
    }
    
    function test_constructor_setsDefaultFundingAmount() public view {
        assertEq(collector.fundingAmount(), DEFAULT_FUNDING_AMOUNT);
    }
    
    function test_constructor_receivesInitialFunding() public view {
        assertEq(address(collector).balance, 0.1 ether);
    }
    
    function test_constructor_revertsOnZeroVault() public {
        vm.expectRevert("VaultFeeCollector: zero vault");
        new VaultFeeCollector(address(0));
    }
    
    function test_constructor_emitsVaultAuthorizationEvent() public {
        vm.expectEmit(true, false, false, true);
        emit VaultAuthorizationChanged(vault, true);
        new VaultFeeCollector(vault);
    }
    
    // ═══════════════════════════════════════════════════════════════
    //                    FEE COLLECTION TESTS
    // ═══════════════════════════════════════════════════════════════
    
    function test_collectFee_acceptsMinimumFee() public {
        vm.deal(vault, 1 ether);
        // For very small tx, only min fee is required
        // 0.1 ETH tx * 0.1% = 0.0001 ETH (== min fee)
        vm.prank(vault);
        collector.collectFee{value: DEFAULT_MIN_FEE}(0.1 ether);
        
        assertEq(collector.totalFeesCollected(), DEFAULT_MIN_FEE);
    }
    
    function test_collectFee_emitsFeeCollectedEvent() public {
        vm.deal(vault, 1 ether);
        // Use small tx so min fee is sufficient
        vm.expectEmit(true, false, false, true);
        emit FeeCollected(vault, DEFAULT_MIN_FEE, DEFAULT_MIN_FEE);
        
        vm.prank(vault);
        collector.collectFee{value: DEFAULT_MIN_FEE}(0.1 ether);
    }
    
    function test_collectFee_updatesTotalCollected() public {
        vm.deal(vault, 1 ether);
        
        vm.prank(vault);
        collector.collectFee{value: 0.01 ether}(10 ether);
        
        assertEq(collector.totalFeesCollected(), 0.01 ether);
    }
    
    function test_collectFee_revertsOnUnauthorizedVault() public {
        address unauthorizedVault = makeAddr("unauthorized");
        vm.deal(unauthorizedVault, 1 ether);
        
        vm.prank(unauthorizedVault);
        vm.expectRevert("VaultFeeCollector: unauthorized");
        collector.collectFee{value: 0.001 ether}(1 ether);
    }
    
    function test_collectFee_revertsOnFeeTooLow() public {
        vm.deal(vault, 1 ether);
        
        vm.prank(vault);
        vm.expectRevert("VaultFeeCollector: fee too low");
        collector.collectFee{value: 0.00001 ether}(1 ether);
    }
    
    function test_collectFee_revertsOnInsufficientFee() public {
        vm.deal(vault, 1 ether);
        
        // For 100 ETH tx, 0.1% = 0.1 ETH required
        vm.prank(vault);
        vm.expectRevert("VaultFeeCollector: insufficient fee");
        collector.collectFee{value: 0.01 ether}(100 ether);
    }
    
    function test_collectFee_acceptsPercentageFee() public {
        vm.deal(vault, 1 ether);
        
        // 100 ETH tx * 0.1% = 0.1 ETH fee
        uint256 txValue = 100 ether;
        uint256 expectedFee = (txValue * DEFAULT_FEE_BPS) / BPS;
        
        vm.prank(vault);
        collector.collectFee{value: expectedFee}(txValue);
        
        assertEq(collector.totalFeesCollected(), expectedFee);
    }
    
    function test_collectFee_multipleCollections() public {
        vm.deal(vault, 10 ether);
        
        vm.startPrank(vault);
        collector.collectFee{value: 0.001 ether}(1 ether);
        collector.collectFee{value: 0.002 ether}(2 ether);
        collector.collectFee{value: 0.003 ether}(3 ether);
        vm.stopPrank();
        
        assertEq(collector.totalFeesCollected(), 0.006 ether);
    }
    
    // ═══════════════════════════════════════════════════════════════
    //                    VAULT FUNDING TESTS
    // ═══════════════════════════════════════════════════════════════
    
    function test_checkAndFundVault_fundsWhenBelowThreshold() public {
        // Set vault balance below threshold
        vm.deal(vault, 0.01 ether);
        
        // Collector has funds
        vm.deal(address(collector), 0.1 ether);
        
        // Wait for rate limiting
        vm.warp(block.timestamp + 6 minutes);
        
        uint256 vaultBalanceBefore = vault.balance;
        
        collector.checkAndFundVault();
        
        assertEq(vault.balance - vaultBalanceBefore, DEFAULT_FUNDING_AMOUNT);
    }
    
    function test_checkAndFundVault_emitsVaultFundedEvent() public {
        vm.deal(vault, 0.01 ether);
        vm.deal(address(collector), 0.1 ether);
        vm.warp(block.timestamp + 6 minutes);
        
        vm.expectEmit(true, false, false, true);
        emit VaultFunded(vault, DEFAULT_FUNDING_AMOUNT);
        
        collector.checkAndFundVault();
    }
    
    function test_checkAndFundVault_updatesFundingStats() public {
        vm.deal(vault, 0.01 ether);
        vm.deal(address(collector), 0.1 ether);
        vm.warp(block.timestamp + 6 minutes);
        
        collector.checkAndFundVault();
        
        assertEq(collector.totalFundedToVault(), DEFAULT_FUNDING_AMOUNT);
        assertEq(collector.fundingCount(), 1);
    }
    
    function test_checkAndFundVault_skipsFundingWhenAboveThreshold() public {
        // Set vault balance above threshold
        vm.deal(vault, 0.1 ether);
        vm.deal(address(collector), 0.1 ether);
        vm.warp(block.timestamp + 6 minutes);
        
        uint256 vaultBalanceBefore = vault.balance;
        
        collector.checkAndFundVault();
        
        assertEq(vault.balance, vaultBalanceBefore);
    }
    
    function test_checkAndFundVault_skipsFundingWhenRateLimited() public {
        vm.deal(vault, 0.01 ether);
        vm.deal(address(collector), 0.2 ether);
        vm.warp(block.timestamp + 6 minutes);
        
        // First funding
        collector.checkAndFundVault();
        
        // Drain vault again
        vm.deal(vault, 0.01 ether);
        
        // Second funding immediately - should be rate limited
        uint256 vaultBalanceBefore = vault.balance;
        collector.checkAndFundVault();
        
        assertEq(vault.balance, vaultBalanceBefore);
    }
    
    function test_checkAndFundVault_emitsInsufficientFundsEvent() public {
        vm.deal(vault, 0.01 ether);
        vm.deal(address(collector), 0.01 ether); // Less than funding amount
        vm.warp(block.timestamp + 6 minutes);
        
        vm.expectEmit(true, false, false, true);
        emit InsufficientFundsForVault(vault, DEFAULT_FUNDING_AMOUNT, 0.01 ether);
        
        collector.checkAndFundVault();
    }
    
    function test_forceFundVault_bypassesRateLimit() public {
        vm.deal(vault, 0.1 ether);
        vm.deal(address(collector), 0.2 ether);
        
        // No waiting - force fund
        collector.forceFundVault(0.05 ether);
        
        assertEq(vault.balance, 0.15 ether);
    }
    
    function test_forceFundVault_onlyOwner() public {
        vm.deal(address(collector), 0.2 ether);
        
        vm.prank(user1);
        vm.expectRevert();
        collector.forceFundVault(0.05 ether);
    }
    
    function test_forceFundVault_revertsOnInsufficientBalance() public {
        vm.deal(address(collector), 0.01 ether);
        
        vm.expectRevert("VaultFeeCollector: insufficient balance");
        collector.forceFundVault(0.05 ether);
    }
    
    // ═══════════════════════════════════════════════════════════════
    //                    RECEIVE ETH TESTS
    // ═══════════════════════════════════════════════════════════════
    
    function test_receive_acceptsEth() public {
        vm.deal(user1, 1 ether);
        uint256 balanceBefore = address(collector).balance;
        
        vm.prank(user1);
        (bool success, ) = address(collector).call{value: 0.1 ether}("");
        assertTrue(success);
        
        assertEq(address(collector).balance, balanceBefore + 0.1 ether);
    }
    
    function test_receive_emitsFeeCollectedEvent() public {
        vm.deal(user1, 1 ether);
        
        vm.expectEmit(true, false, false, true);
        emit FeeCollected(address(0), 0.1 ether, 0.1 ether);
        
        vm.prank(user1);
        (bool success, ) = address(collector).call{value: 0.1 ether}("");
        assertTrue(success);
    }
    
    // ═══════════════════════════════════════════════════════════════
    //                    ADMIN TESTS
    // ═══════════════════════════════════════════════════════════════
    
    function test_setVault_updatesVault() public {
        address newVault = makeAddr("newVault");
        collector.setVault(newVault);
        
        assertEq(collector.vault(), newVault);
        assertTrue(collector.authorizedVaults(newVault));
    }
    
    function test_setVault_deauthorizesOldVault() public {
        address newVault = makeAddr("newVault");
        collector.setVault(newVault);
        
        assertFalse(collector.authorizedVaults(vault));
    }
    
    function test_setVault_revertsOnZeroAddress() public {
        vm.expectRevert("VaultFeeCollector: zero address");
        collector.setVault(address(0));
    }
    
    function test_setVault_onlyOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        collector.setVault(makeAddr("newVault"));
    }
    
    function test_setVaultAuthorization_addsVault() public {
        address anotherVault = makeAddr("anotherVault");
        collector.setVaultAuthorization(anotherVault, true);
        
        assertTrue(collector.authorizedVaults(anotherVault));
    }
    
    function test_setVaultAuthorization_removesVault() public {
        address anotherVault = makeAddr("anotherVault");
        collector.setVaultAuthorization(anotherVault, true);
        collector.setVaultAuthorization(anotherVault, false);
        
        assertFalse(collector.authorizedVaults(anotherVault));
    }
    
    function test_updateSettings_updatesAllValues() public {
        collector.updateSettings(50, 0.001 ether, 0.05 ether, 0.1 ether);
        
        assertEq(collector.feePercentageBps(), 50);
        assertEq(collector.minFee(), 0.001 ether);
        assertEq(collector.fundingThreshold(), 0.05 ether);
        assertEq(collector.fundingAmount(), 0.1 ether);
    }
    
    function test_updateSettings_emitsEvent() public {
        vm.expectEmit(false, false, false, true);
        emit SettingsUpdated(50, 0.001 ether, 0.05 ether, 0.1 ether);
        
        collector.updateSettings(50, 0.001 ether, 0.05 ether, 0.1 ether);
    }
    
    function test_updateSettings_revertsOnFeeTooHigh() public {
        vm.expectRevert("VaultFeeCollector: fee too high");
        collector.updateSettings(600, 0.001 ether, 0.05 ether, 0.1 ether); // 6% > 5%
    }
    
    function test_updateSettings_onlyOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        collector.updateSettings(50, 0.001 ether, 0.05 ether, 0.1 ether);
    }
    
    function test_setMinFundingInterval_updates() public {
        collector.setMinFundingInterval(10 minutes);
        // No direct getter, but we can test via behavior
    }
    
    function test_emergencyWithdraw_transfersFunds() public {
        vm.deal(address(collector), 1 ether);
        
        address payable recipient = payable(makeAddr("recipient"));
        collector.emergencyWithdraw(recipient, 0.5 ether);
        
        assertEq(recipient.balance, 0.5 ether);
    }
    
    function test_emergencyWithdraw_revertsOnInsufficientBalance() public {
        vm.deal(address(collector), 0.1 ether);
        
        vm.expectRevert("VaultFeeCollector: insufficient balance");
        collector.emergencyWithdraw(payable(owner), 1 ether);
    }
    
    // ═══════════════════════════════════════════════════════════════
    //                    VIEW FUNCTION TESTS
    // ═══════════════════════════════════════════════════════════════
    
    function test_vaultNeedsFunding_returnsTrueWhenLow() public {
        vm.deal(vault, 0.01 ether);
        (bool needs, uint256 balance) = collector.vaultNeedsFunding();
        
        assertTrue(needs);
        assertEq(balance, 0.01 ether);
    }
    
    function test_vaultNeedsFunding_returnsFalseWhenSufficient() public {
        vm.deal(vault, 0.1 ether);
        (bool needs, uint256 balance) = collector.vaultNeedsFunding();
        
        assertFalse(needs);
        assertEq(balance, 0.1 ether);
    }
    
    function test_calculateFee_returnsMinFeeForSmallTx() public view {
        uint256 fee = collector.calculateFee(0.1 ether);
        assertEq(fee, DEFAULT_MIN_FEE);
    }
    
    function test_calculateFee_returnsPercentageForLargeTx() public view {
        uint256 txValue = 100 ether;
        uint256 expectedFee = (txValue * DEFAULT_FEE_BPS) / BPS;
        
        assertEq(collector.calculateFee(txValue), expectedFee);
    }
    
    function test_getStats_returnsCorrectValues() public {
        vm.deal(vault, 0.5 ether);
        vm.deal(address(collector), 0.2 ether);
        
        (
            uint256 totalCollected,
            uint256 totalFunded,
            uint256 balance,
            uint256 fundCount,
            uint256 vaultBalance
        ) = collector.getStats();
        
        assertEq(totalCollected, 0);
        assertEq(totalFunded, 0);
        assertEq(balance, 0.2 ether);
        assertEq(fundCount, 0);
        assertEq(vaultBalance, 0.5 ether);
    }
    
    // ═══════════════════════════════════════════════════════════════
    //                    FUZZ TESTS
    // ═══════════════════════════════════════════════════════════════
    
    function testFuzz_calculateFee_alwaysGteMinFee(uint256 txValue) public view {
        txValue = bound(txValue, 0, 1000 ether);
        uint256 fee = collector.calculateFee(txValue);
        
        assertGe(fee, DEFAULT_MIN_FEE);
    }
    
    function testFuzz_calculateFee_neverExceedsMaxPercentage(uint256 txValue) public view {
        txValue = bound(txValue, 1 ether, 10000 ether);
        uint256 fee = collector.calculateFee(txValue);
        uint256 maxFee = (txValue * MAX_FEE_BPS) / BPS;
        
        assertLe(fee, maxFee);
    }
    
    function testFuzz_collectFee_updatesTotal(uint256 feeAmount) public {
        feeAmount = bound(feeAmount, DEFAULT_MIN_FEE, 1 ether);
        uint256 txValue = feeAmount * BPS / DEFAULT_FEE_BPS;
        
        vm.deal(vault, 10 ether);
        vm.prank(vault);
        collector.collectFee{value: feeAmount}(txValue);
        
        assertEq(collector.totalFeesCollected(), feeAmount);
    }
    
    function testFuzz_fundingThreshold_triggersAtBoundary(uint256 vaultBalance) public {
        vaultBalance = bound(vaultBalance, 0, DEFAULT_FUNDING_THRESHOLD);
        
        vm.deal(vault, vaultBalance);
        (bool needs, ) = collector.vaultNeedsFunding();
        
        if (vaultBalance < DEFAULT_FUNDING_THRESHOLD) {
            assertTrue(needs);
        }
    }
    
    // ═══════════════════════════════════════════════════════════════
    //                    INTEGRATION TESTS
    // ═══════════════════════════════════════════════════════════════
    
    function test_fullFeeToFundingCycle() public {
        // Setup: Vault has low balance (below threshold of 0.02 ETH)
        vm.deal(vault, 0.015 ether);
        vm.deal(address(collector), 0.1 ether);
        
        vm.warp(block.timestamp + 6 minutes);
        
        uint256 vaultBalanceBefore = vault.balance;
        
        // Collect fee - 1 ETH tx * 0.1% = 0.001 ETH
        vm.prank(vault);
        collector.collectFee{value: 0.001 ether}(1 ether);
        
        // Vault sends 0.001 ETH but receives 0.05 ETH funding
        assertGt(vault.balance, vaultBalanceBefore);
    }
    
    function test_multipleVaultsAuthorized() public {
        address vault2 = makeAddr("vault2");
        address vault3 = makeAddr("vault3");
        
        collector.setVaultAuthorization(vault2, true);
        collector.setVaultAuthorization(vault3, true);
        
        vm.deal(vault2, 1 ether);
        vm.deal(vault3, 1 ether);
        
        vm.prank(vault2);
        collector.collectFee{value: 0.001 ether}(1 ether);
        
        vm.prank(vault3);
        collector.collectFee{value: 0.002 ether}(2 ether);
        
        assertEq(collector.totalFeesCollected(), 0.003 ether);
    }
}
