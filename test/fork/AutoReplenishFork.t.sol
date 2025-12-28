// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {YieldVaultDualAssetV2} from "../../src/YieldVaultDualAssetV2.sol";
import {VaultFeeCollector} from "../../src/autoreplenish/VaultFeeCollector.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IAavePool} from "../../src/interfaces/IAavePool.sol";

/**
 * @title AutoReplenishForkTest
 * @notice Fork tests for the True Auto-Replenishment system on Sepolia
 * @dev Run with: forge test --match-contract AutoReplenishForkTest --fork-url $SEPOLIA_RPC_URL -vvv
 * 
 * This test suite validates:
 * 1. Full deployment of the auto-replenishment system
 * 2. Fee collection on real vault operations
 * 3. Automatic vault funding when balance is low
 * 4. Integration with Aave V3 on Sepolia
 * 5. Callback proxy interaction
 */
contract AutoReplenishForkTest is Test {
    // ═══════════════════════════════════════════════════════════════
    //                    SEPOLIA ADDRESSES
    // ═══════════════════════════════════════════════════════════════
    
    // Aave V3 Sepolia
    address constant AAVE_POOL = 0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951;
    address constant AUSDC = 0x16dA4541aD1807f4443d92D26044C1147406EB80;
    address constant ADAI = 0x29598b72eb5CeBd806C5dCD549490FdA35B13cD8;
    
    // Tokens
    address constant USDC = 0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8;
    address constant DAI = 0xFF34B3d4Aee8ddCd6F9AFFFB6Fe49bD371b8a357;
    
    // Reactive Network Callback Proxy
    address constant CALLBACK_PROXY = 0xc9f36411C9897e7F959D99ffca2a0Ba7ee0D7bDA;
    
    // ═══════════════════════════════════════════════════════════════
    //                    TEST STATE
    // ═══════════════════════════════════════════════════════════════
    
    YieldVaultDualAssetV2 public vault;
    VaultFeeCollector public collector;
    
    address public deployer;
    address public user1;
    address public user2;
    address public rvmId;
    
    uint256 constant DEPOSIT_AMOUNT = 1000e6; // 1000 USDC
    uint256 constant MIN_FEE = 0.0001 ether;
    
    // ═══════════════════════════════════════════════════════════════
    //                    EVENTS
    // ═══════════════════════════════════════════════════════════════
    
    event FeeCollected(address indexed vault, uint256 amount, uint256 totalCollected);
    event VaultFunded(address indexed vault, uint256 amount);
    event FeePaid(address indexed user, uint256 amount);
    event Deposited(address indexed user, address token, uint256 amount);
    
    // ═══════════════════════════════════════════════════════════════
    //                    SETUP
    // ═══════════════════════════════════════════════════════════════
    
    function setUp() public {
        // Skip if not on fork
        if (block.chainid != 11155111) {
            return;
        }
        
        // Create test accounts
        deployer = makeAddr("deployer");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        rvmId = makeAddr("rvmId");
        
        // Fund accounts with ETH
        vm.deal(deployer, 10 ether);
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
        
        // Deploy the auto-replenishment system
        vm.startPrank(deployer);
        
        // 1. Deploy fee collector with temporary vault address (deployer)
        collector = new VaultFeeCollector{value: 0.5 ether}(deployer);
        
        // 2. Deploy vault with fee collector integration
        vault = new YieldVaultDualAssetV2{value: 0.1 ether}(
            USDC,
            DAI,
            AAVE_POOL,
            AUSDC,
            ADAI,
            CALLBACK_PROXY,
            address(collector)
        );
        
        // 3. Configure fee collector with actual vault
        collector.setVault(address(vault));
        
        // 4. Set RVM ID for callbacks
        vault.setRvmId(rvmId);
        
        vm.stopPrank();
        
        // Give users USDC and DAI
        deal(USDC, user1, 100_000e6);
        deal(DAI, user1, 100_000e18);
        deal(USDC, user2, 100_000e6);
        deal(DAI, user2, 100_000e18);
    }
    
    // ═══════════════════════════════════════════════════════════════
    //                    MODIFIER
    // ═══════════════════════════════════════════════════════════════
    
    modifier onlyFork() {
        if (block.chainid != 11155111) {
            console.log("Skipping - not Sepolia fork");
            return;
        }
        _;
    }
    
    // ═══════════════════════════════════════════════════════════════
    //                    DEPLOYMENT TESTS
    // ═══════════════════════════════════════════════════════════════
    
    function test_deployment_collectorInitialized() public onlyFork {
        assertEq(collector.vault(), address(vault));
        assertTrue(collector.authorizedVaults(address(vault)));
        assertEq(collector.feePercentageBps(), 10); // 0.1%
    }
    
    function test_deployment_vaultInitialized() public onlyFork {
        assertEq(address(vault.primaryAsset()), USDC);
        assertEq(address(vault.secondaryAsset()), DAI);
        assertEq(vault.primaryAllocation(), 5000);
        assertTrue(vault.feeCollectionEnabled());
    }
    
    function test_deployment_vaultHasInitialFunding() public onlyFork {
        assertGe(address(vault).balance, 0.05 ether);
    }
    
    function test_deployment_collectorHasFunding() public onlyFork {
        assertGe(address(collector).balance, 0.1 ether);
    }
    
    // ═══════════════════════════════════════════════════════════════
    //                    FEE COLLECTION TESTS
    // ═══════════════════════════════════════════════════════════════
    
    function test_deposit_withFee_collectsFee() public onlyFork {
        uint256 collectorBalanceBefore = address(collector).balance;
        
        vm.startPrank(user1);
        IERC20(USDC).approve(address(vault), DEPOSIT_AMOUNT);
        
        // Deposit with fee
        vault.depositPrimary{value: MIN_FEE}(DEPOSIT_AMOUNT);
        vm.stopPrank();
        
        // Fee should be collected
        assertGe(address(collector).balance, collectorBalanceBefore);
        assertGe(collector.totalFeesCollected(), MIN_FEE);
    }
    
    function test_deposit_withFee_emitsFeePaidEvent() public onlyFork {
        vm.startPrank(user1);
        IERC20(USDC).approve(address(vault), DEPOSIT_AMOUNT);
        
        vm.expectEmit(true, false, false, true);
        emit FeePaid(user1, MIN_FEE);
        
        vault.depositPrimary{value: MIN_FEE}(DEPOSIT_AMOUNT);
        vm.stopPrank();
    }
    
    function test_deposit_withoutFee_stillSucceeds() public onlyFork {
        vm.startPrank(user1);
        IERC20(USDC).approve(address(vault), DEPOSIT_AMOUNT);
        
        // Deposit without fee (no msg.value)
        vault.depositPrimary(DEPOSIT_AMOUNT);
        vm.stopPrank();
        
        // Deposit should succeed even without fee
        assertGt(vault.snapshotCounter(), 0);
    }
    
    function test_deposit_secondary_withFee() public onlyFork {
        vm.startPrank(user1);
        IERC20(DAI).approve(address(vault), 1000e18);
        
        vault.depositSecondary{value: MIN_FEE}(1000e18);
        vm.stopPrank();
        
        assertGe(collector.totalFeesCollected(), MIN_FEE);
    }
    
    // ═══════════════════════════════════════════════════════════════
    //                    AUTO-FUNDING TESTS
    // ═══════════════════════════════════════════════════════════════
    
    function test_autoFunding_triggersWhenVaultLow() public onlyFork {
        // Drain vault balance below threshold using vm.deal
        vm.deal(address(vault), 0.01 ether);
        
        // Vault should now be below threshold
        assertLt(address(vault).balance, 0.02 ether);
        
        // Wait for rate limiting
        vm.warp(block.timestamp + 6 minutes);
        
        uint256 vaultBalanceBefore = address(vault).balance;
        
        // Collect fee (should trigger funding check)
        vm.startPrank(user1);
        IERC20(USDC).approve(address(vault), DEPOSIT_AMOUNT);
        vault.depositPrimary{value: MIN_FEE}(DEPOSIT_AMOUNT);
        vm.stopPrank();
        
        // Vault should be funded
        assertGt(address(vault).balance, vaultBalanceBefore);
    }
    
    function test_autoFunding_manualCheck() public onlyFork {
        // Drain vault using vm.deal
        vm.deal(address(vault), 0.01 ether);
        
        vm.warp(block.timestamp + 6 minutes);
        
        uint256 vaultBalanceBefore = address(vault).balance;
        
        // Manual funding check
        collector.checkAndFundVault();
        
        assertGt(address(vault).balance, vaultBalanceBefore);
    }
    
    function test_autoFunding_updatesFundingStats() public onlyFork {
        // Drain vault using vm.deal
        vm.deal(address(vault), 0.01 ether);
        
        vm.warp(block.timestamp + 6 minutes);
        
        collector.checkAndFundVault();
        
        assertGt(collector.totalFundedToVault(), 0);
        assertGe(collector.fundingCount(), 1);
    }
    
    // ═══════════════════════════════════════════════════════════════
    //                    APY TESTS
    // ═══════════════════════════════════════════════════════════════
    
    function test_getAPY_primaryReturnsValue() public onlyFork {
        uint256 apy = vault.getPrimaryAPY();
        console.log("Primary APY (bps):", apy);
        // APY should be a reasonable value
        assertGt(apy, 0);
        assertLt(apy, 10000); // Less than 100%
    }
    
    function test_getAPY_secondaryReturnsValue() public onlyFork {
        uint256 apy = vault.getSecondaryAPY();
        console.log("Secondary APY (bps):", apy);
        assertGt(apy, 0);
        assertLt(apy, 10000);
    }
    
    // ═══════════════════════════════════════════════════════════════
    //                    REBALANCE TESTS
    // ═══════════════════════════════════════════════════════════════
    
    function test_rebalance_fromCallbackProxy() public onlyFork {
        // Deposit first
        vm.startPrank(user1);
        IERC20(USDC).approve(address(vault), DEPOSIT_AMOUNT);
        vault.depositPrimary{value: MIN_FEE}(DEPOSIT_AMOUNT);
        vm.stopPrank();
        
        // Wait for rate limiting
        vm.warp(block.timestamp + 6 minutes);
        
        uint256 allocationBefore = vault.primaryAllocation();
        
        // Execute rebalance from callback proxy
        vm.prank(CALLBACK_PROXY);
        vault.executeRebalance(rvmId, 8000, 2000);
        
        assertEq(vault.primaryAllocation(), 8000);
        assertTrue(vault.primaryAllocation() != allocationBefore);
    }
    
    function test_rebalance_onlyCallbackProxy() public onlyFork {
        vm.prank(user1);
        vm.expectRevert("Authorized sender only");
        vault.executeRebalance(rvmId, 8000, 2000);
    }
    
    function test_rebalance_allocationMustSum100() public onlyFork {
        vm.warp(block.timestamp + 6 minutes);
        
        vm.prank(CALLBACK_PROXY);
        vm.expectRevert("Invalid allocation");
        vault.executeRebalance(rvmId, 6000, 3000); // Only 90%
    }
    
    // ═══════════════════════════════════════════════════════════════
    //                    SNAPSHOT TESTS
    // ═══════════════════════════════════════════════════════════════
    
    function test_triggerYieldSnapshot_incrementsCounter() public onlyFork {
        uint256 countBefore = vault.snapshotCounter();
        vault.triggerYieldSnapshot();
        assertEq(vault.snapshotCounter(), countBefore + 1);
    }
    
    function test_deposit_triggersSnapshot() public onlyFork {
        uint256 countBefore = vault.snapshotCounter();
        
        vm.startPrank(user1);
        IERC20(USDC).approve(address(vault), DEPOSIT_AMOUNT);
        vault.depositPrimary{value: MIN_FEE}(DEPOSIT_AMOUNT);
        vm.stopPrank();
        
        assertEq(vault.snapshotCounter(), countBefore + 1);
    }
    
    // ═══════════════════════════════════════════════════════════════
    //                    ADMIN TESTS
    // ═══════════════════════════════════════════════════════════════
    
    function test_admin_setFeeCollector() public onlyFork {
        address newCollector = makeAddr("newCollector");
        
        vm.prank(deployer);
        vault.setFeeCollector(newCollector);
        
        assertEq(address(vault.feeCollector()), newCollector);
    }
    
    function test_admin_setFeeCollectionEnabled() public onlyFork {
        vm.prank(deployer);
        vault.setFeeCollectionEnabled(false);
        
        assertFalse(vault.feeCollectionEnabled());
    }
    
    function test_admin_setRvmId() public onlyFork {
        address newRvmId = makeAddr("newRvmId");
        
        vm.prank(deployer);
        vault.setRvmId(newRvmId);
        
        assertEq(vault.getRvmId(), newRvmId);
    }
    
    // ═══════════════════════════════════════════════════════════════
    //                    VIEW FUNCTION TESTS
    // ═══════════════════════════════════════════════════════════════
    
    function test_hasSufficientFunding_returnsTrue() public onlyFork {
        assertTrue(vault.hasSufficientFunding());
    }
    
    function test_hasSufficientFunding_returnsFalseWhenLow() public onlyFork {
        // Drain vault using vm.deal
        vm.deal(address(vault), 0);
        
        assertFalse(vault.hasSufficientFunding());
    }
    
    function test_getRequiredFee_returnsValue() public onlyFork {
        uint256 fee = vault.getRequiredFee(1 ether);
        assertGe(fee, MIN_FEE);
    }
    
    function test_getTotalValueLocked_afterDeposit() public onlyFork {
        uint256 tvlBefore = vault.getTotalValueLocked();
        
        vm.startPrank(user1);
        IERC20(USDC).approve(address(vault), DEPOSIT_AMOUNT);
        vault.depositPrimary{value: MIN_FEE}(DEPOSIT_AMOUNT);
        vm.stopPrank();
        
        uint256 tvlAfter = vault.getTotalValueLocked();
        assertGt(tvlAfter, tvlBefore);
    }
    
    // ═══════════════════════════════════════════════════════════════
    //                    MULTI-USER TESTS
    // ═══════════════════════════════════════════════════════════════
    
    function test_multiUser_bothPayFees() public onlyFork {
        uint256 collectorBalanceBefore = address(collector).balance;
        
        // User 1 deposits USDC
        vm.startPrank(user1);
        IERC20(USDC).approve(address(vault), DEPOSIT_AMOUNT);
        vault.depositPrimary{value: MIN_FEE}(DEPOSIT_AMOUNT);
        vm.stopPrank();
        
        // User 2 deposits DAI
        vm.startPrank(user2);
        IERC20(DAI).approve(address(vault), 1000e18);
        vault.depositSecondary{value: MIN_FEE * 2}(1000e18);
        vm.stopPrank();
        
        // Both fees collected
        assertGe(collector.totalFeesCollected(), MIN_FEE * 2);
        assertGt(address(collector).balance, collectorBalanceBefore);
    }
    
    // ═══════════════════════════════════════════════════════════════
    //                    FULL INTEGRATION TEST
    // ═══════════════════════════════════════════════════════════════
    
    function test_fullIntegration_feeToFundingCycle() public onlyFork {
        console.log("=== Full Integration Test ===");
        console.log("Initial vault balance:", address(vault).balance);
        console.log("Initial collector balance:", address(collector).balance);
        
        // 1. User deposits with fee
        vm.startPrank(user1);
        IERC20(USDC).approve(address(vault), DEPOSIT_AMOUNT);
        vault.depositPrimary{value: 0.001 ether}(DEPOSIT_AMOUNT);
        vm.stopPrank();
        
        console.log("After deposit - collector fees:", collector.totalFeesCollected());
        
        // 2. Simulate vault running low on funds using vm.deal
        vm.deal(address(vault), 0.01 ether);
        
        console.log("After drain - vault balance:", address(vault).balance);
        
        // 3. Wait for rate limiting
        vm.warp(block.timestamp + 6 minutes);
        
        // 4. Another deposit triggers funding check
        vm.startPrank(user2);
        IERC20(USDC).approve(address(vault), DEPOSIT_AMOUNT);
        vault.depositPrimary{value: 0.001 ether}(DEPOSIT_AMOUNT);
        vm.stopPrank();
        
        console.log("After second deposit - vault balance:", address(vault).balance);
        console.log("Total funded to vault:", collector.totalFundedToVault());
        console.log("Funding count:", collector.fundingCount());
        
        // 5. Verify vault was funded
        assertGt(address(vault).balance, 0.01 ether);
        assertGt(collector.totalFundedToVault(), 0);
        assertGe(collector.fundingCount(), 1);
        
        console.log("=== Test Passed ===");
    }
}
