// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../src/YieldVault.sol";
import "../../src/interfaces/IAavePool.sol";
import "../../src/interfaces/IComet.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title YieldVaultForkTest
 * @notice Fork tests against real Aave V3 and Compound V3 on Sepolia
 * @dev Run with: forge test --match-contract YieldVaultForkTest --fork-url $SEPOLIA_RPC_URL -vvv
 */
contract YieldVaultForkTest is Test {
    // ═══════════════════════════════════════════════════════════════
    //                    SEPOLIA ADDRESSES
    // ═══════════════════════════════════════════════════════════════
    
    // Aave V3 Sepolia
    address constant AAVE_POOL = 0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951;
    address constant AAVE_USDC_ATOKEN = 0x16dA4541aD1807f4443d92D26044C1147406EB80;
    
    // Compound V3 Sepolia
    address constant COMPOUND_COMET_USDC = 0x285617313887d43256F852cAE0Ee4de4b68D45B0;
    
    // Reactive Network Callback Proxy (Sepolia)
    address constant CALLBACK_PROXY = 0xc9f36411C9897e7F959D99ffca2a0Ba7ee0D7bDA;
    
    // USDC on Sepolia
    address constant USDC = 0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8;
    
    // ═══════════════════════════════════════════════════════════════
    //                    TEST STATE
    // ═══════════════════════════════════════════════════════════════
    
    YieldVault public vault;
    
    address public user1;
    address public user2;
    address public deployer;
    address public rvmId;
    
    uint256 constant DEPOSIT_AMOUNT = 1000e6; // 1000 USDC
    
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
        
        // Deploy vault
        vm.startPrank(deployer);
        vault = new YieldVault(
            USDC,
            AAVE_POOL,
            AAVE_USDC_ATOKEN,
            COMPOUND_COMET_USDC,
            CALLBACK_PROXY
        );
        
        // Set RVM ID for callbacks
        vault.setRvmId(rvmId);
        
        // Fund vault for operations
        (bool success,) = address(vault).call{value: 0.5 ether}("");
        require(success, "Fund vault failed");
        vm.stopPrank();
        
        // Give users USDC
        deal(USDC, user1, 10_000e6);
        deal(USDC, user2, 10_000e6);
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
    
    function test_deployment_setsCorrectAddresses() public onlyFork {
        assertEq(address(vault.asset()), USDC);
        assertEq(address(vault.aavePool()), AAVE_POOL);
        assertEq(address(vault.aToken()), AAVE_USDC_ATOKEN);
        assertEq(address(vault.compoundComet()), COMPOUND_COMET_USDC);
    }
    
    function test_deployment_defaultAllocation() public onlyFork {
        assertEq(vault.aaveAllocation(), 5000);
        assertEq(vault.compoundAllocation(), 5000);
    }
    
    function test_deployment_ownerIsDeployer() public onlyFork {
        assertEq(vault.owner(), deployer);
    }
    
    // ═══════════════════════════════════════════════════════════════
    //                    DEPOSIT TESTS
    // ═══════════════════════════════════════════════════════════════
    
    function test_deposit_updatesBalance() public onlyFork {
        vm.startPrank(user1);
        IERC20(USDC).approve(address(vault), DEPOSIT_AMOUNT);
        vault.deposit(DEPOSIT_AMOUNT);
        vm.stopPrank();
        
        assertEq(vault.getUserBalance(user1), DEPOSIT_AMOUNT);
        assertEq(vault.totalDeposits(), DEPOSIT_AMOUNT);
    }
    
    function test_deposit_allocatesToBothPools() public onlyFork {
        vm.startPrank(user1);
        IERC20(USDC).approve(address(vault), DEPOSIT_AMOUNT);
        vault.deposit(DEPOSIT_AMOUNT);
        vm.stopPrank();
        
        // Check both pools have funds
        (uint256 aaveBalance, uint256 compoundBalance) = vault.getPoolBalances();
        
        // With 50/50 allocation, each should have ~500 USDC
        assertGt(aaveBalance, 0, "Aave should have balance");
        assertGt(compoundBalance, 0, "Compound should have balance");
        assertApproxEqRel(aaveBalance, DEPOSIT_AMOUNT / 2, 0.01e18); // 1% tolerance
    }
    
    function test_deposit_emitsYieldSnapshot() public onlyFork {
        vm.startPrank(user1);
        IERC20(USDC).approve(address(vault), DEPOSIT_AMOUNT);
        
        // Just verify deposit succeeds (event is emitted internally)
        vault.deposit(DEPOSIT_AMOUNT);
        vm.stopPrank();
        
        // Verify snapshot counter incremented (indicates event was emitted)
        assertGt(vault.snapshotCounter(), 0);
    }
    
    function test_deposit_revertsOnSmallAmount() public onlyFork {
        vm.startPrank(user1);
        IERC20(USDC).approve(address(vault), 100); // < MIN_DEPOSIT
        
        vm.expectRevert(YieldVault.AmountTooSmall.selector);
        vault.deposit(100);
        vm.stopPrank();
    }
    
    // ═══════════════════════════════════════════════════════════════
    //                    WITHDRAW TESTS
    // ═══════════════════════════════════════════════════════════════
    
    function test_withdraw_returnsCorrectAmount() public onlyFork {
        // Deposit first
        vm.startPrank(user1);
        IERC20(USDC).approve(address(vault), DEPOSIT_AMOUNT);
        vault.deposit(DEPOSIT_AMOUNT);
        
        // Record balance before withdraw
        uint256 balanceBefore = IERC20(USDC).balanceOf(user1);
        
        // Withdraw half
        vault.withdraw(DEPOSIT_AMOUNT / 2);
        vm.stopPrank();
        
        // Verify user received funds
        uint256 balanceAfter = IERC20(USDC).balanceOf(user1);
        assertApproxEqRel(balanceAfter - balanceBefore, DEPOSIT_AMOUNT / 2, 0.01e18);
    }
    
    function test_withdraw_updatesVaultBalance() public onlyFork {
        vm.startPrank(user1);
        IERC20(USDC).approve(address(vault), DEPOSIT_AMOUNT);
        vault.deposit(DEPOSIT_AMOUNT);
        
        vault.withdraw(DEPOSIT_AMOUNT / 2);
        vm.stopPrank();
        
        assertApproxEqRel(vault.getUserBalance(user1), DEPOSIT_AMOUNT / 2, 0.01e18);
    }
    
    function test_withdraw_revertsOnInsufficientBalance() public onlyFork {
        vm.startPrank(user1);
        IERC20(USDC).approve(address(vault), DEPOSIT_AMOUNT);
        vault.deposit(DEPOSIT_AMOUNT);
        
        vm.expectRevert(YieldVault.InsufficientBalance.selector);
        vault.withdraw(DEPOSIT_AMOUNT * 2);
        vm.stopPrank();
    }
    
    // ═══════════════════════════════════════════════════════════════
    //                    APY TESTS
    // ═══════════════════════════════════════════════════════════════
    
    function test_getAaveAPY_returnsPositiveValue() public onlyFork {
        uint256 apy = vault.getAaveAPY();
        
        // Aave APY should be positive (in RAY format)
        console.log("Aave APY (RAY):", apy);
        assertGt(apy, 0, "Aave APY should be positive");
    }
    
    function test_getCompoundAPY_returnsPositiveValue() public onlyFork {
        uint256 apy = vault.getCompoundAPY();
        
        // Compound APY should be positive
        console.log("Compound APY:", apy);
        assertGt(apy, 0, "Compound APY should be positive");
    }
    
    // ═══════════════════════════════════════════════════════════════
    //                    REBALANCE TESTS
    // ═══════════════════════════════════════════════════════════════
    
    function test_executeRebalance_changesAllocation() public onlyFork {
        // Deposit first
        vm.startPrank(user1);
        IERC20(USDC).approve(address(vault), DEPOSIT_AMOUNT);
        vault.deposit(DEPOSIT_AMOUNT);
        vm.stopPrank();
        
        // Wait for rate limiting
        vm.roll(block.number + 200);
        
        // Execute rebalance from callback proxy as RVM
        vm.prank(CALLBACK_PROXY);
        vault.executeRebalance(rvmId, 8000, 2000);
        
        // Check allocation changed
        assertEq(vault.aaveAllocation(), 8000);
        assertEq(vault.compoundAllocation(), 2000);
    }
    
    function test_executeRebalance_movesFunds() public onlyFork {
        // Deposit first
        vm.startPrank(user1);
        IERC20(USDC).approve(address(vault), DEPOSIT_AMOUNT);
        vault.deposit(DEPOSIT_AMOUNT);
        vm.stopPrank();
        
        // Record initial balances
        (uint256 aaveBefore, uint256 compoundBefore) = vault.getPoolBalances();
        
        // Wait for rate limiting
        vm.roll(block.number + 200);
        
        // Rebalance to 80/20
        vm.prank(CALLBACK_PROXY);
        vault.executeRebalance(rvmId, 8000, 2000);
        
        // Check funds moved
        (uint256 aaveAfter, uint256 compoundAfter) = vault.getPoolBalances();
        
        // Aave should have more now (80% vs 50%)
        assertGt(aaveAfter, aaveBefore, "Aave balance should increase");
        assertLt(compoundAfter, compoundBefore, "Compound balance should decrease");
    }
    
    function test_executeRebalance_onlyCallbackProxy() public onlyFork {
        vm.prank(user1);
        vm.expectRevert("Authorized sender only");
        vault.executeRebalance(rvmId, 8000, 2000);
    }
    
    function test_executeRebalance_onlyCorrectRvmId() public onlyFork {
        vm.prank(CALLBACK_PROXY);
        vm.expectRevert("Authorized RVM ID only");
        vault.executeRebalance(address(0x9999), 8000, 2000);
    }
    
    function test_executeRebalance_rateLimited() public onlyFork {
        // Deposit first
        vm.startPrank(user1);
        IERC20(USDC).approve(address(vault), DEPOSIT_AMOUNT);
        vault.deposit(DEPOSIT_AMOUNT);
        vm.stopPrank();
        
        // Wait for rate limiting
        vm.roll(block.number + 200);
        
        // First rebalance succeeds
        vm.prank(CALLBACK_PROXY);
        vault.executeRebalance(rvmId, 8000, 2000);
        
        // Second rebalance too soon should fail
        vm.prank(CALLBACK_PROXY);
        vm.expectRevert(YieldVault.RebalanceTooSoon.selector);
        vault.executeRebalance(rvmId, 2000, 8000);
    }
    
    function test_executeRebalance_mustSumTo100() public onlyFork {
        // Deposit first
        vm.startPrank(user1);
        IERC20(USDC).approve(address(vault), DEPOSIT_AMOUNT);
        vault.deposit(DEPOSIT_AMOUNT);
        vm.stopPrank();
        
        // Wait for rate limiting
        vm.roll(block.number + 200);
        
        vm.prank(CALLBACK_PROXY);
        vm.expectRevert(YieldVault.AllocationMismatch.selector);
        vault.executeRebalance(rvmId, 6000, 3000); // Only 90%
    }
    
    // ═══════════════════════════════════════════════════════════════
    //                    YIELD SNAPSHOT TESTS
    // ═══════════════════════════════════════════════════════════════
    
    function test_triggerYieldSnapshot_incrementsCounter() public onlyFork {
        uint256 countBefore = vault.snapshotCounter();
        vault.triggerYieldSnapshot();
        uint256 countAfter = vault.snapshotCounter();
        
        assertEq(countAfter, countBefore + 1);
    }
    
    function test_triggerYieldSnapshot_emitsEvent() public onlyFork {
        // Deposit first to have TVL
        vm.startPrank(user1);
        IERC20(USDC).approve(address(vault), DEPOSIT_AMOUNT);
        vault.deposit(DEPOSIT_AMOUNT);
        vm.stopPrank();
        
        // Trigger snapshot - just verify no revert
        vault.triggerYieldSnapshot();
    }
    
    // ═══════════════════════════════════════════════════════════════
    //                    ADMIN TESTS
    // ═══════════════════════════════════════════════════════════════
    
    function test_pause_blocksDeposit() public onlyFork {
        vm.prank(deployer);
        vault.pause();
        
        vm.startPrank(user1);
        IERC20(USDC).approve(address(vault), DEPOSIT_AMOUNT);
        
        vm.expectRevert();
        vault.deposit(DEPOSIT_AMOUNT);
        vm.stopPrank();
    }
    
    function test_emergencyWithdraw_returnsAllFunds() public onlyFork {
        // Deposit
        vm.startPrank(user1);
        IERC20(USDC).approve(address(vault), DEPOSIT_AMOUNT);
        vault.deposit(DEPOSIT_AMOUNT);
        vm.stopPrank();
        
        uint256 ownerBalanceBefore = IERC20(USDC).balanceOf(deployer);
        
        // Emergency withdraw
        vm.prank(deployer);
        vault.emergencyWithdraw();
        
        // Owner should receive all funds
        uint256 ownerBalanceAfter = IERC20(USDC).balanceOf(deployer);
        assertGt(ownerBalanceAfter, ownerBalanceBefore);
    }
    
    // ═══════════════════════════════════════════════════════════════
    //                    MULTI-USER TESTS
    // ═══════════════════════════════════════════════════════════════
    
    function test_multipleUsers_trackSeparately() public onlyFork {
        // User 1 deposits
        vm.startPrank(user1);
        IERC20(USDC).approve(address(vault), DEPOSIT_AMOUNT);
        vault.deposit(DEPOSIT_AMOUNT);
        vm.stopPrank();
        
        // User 2 deposits
        vm.startPrank(user2);
        IERC20(USDC).approve(address(vault), DEPOSIT_AMOUNT * 2);
        vault.deposit(DEPOSIT_AMOUNT * 2);
        vm.stopPrank();
        
        assertEq(vault.getUserBalance(user1), DEPOSIT_AMOUNT);
        assertEq(vault.getUserBalance(user2), DEPOSIT_AMOUNT * 2);
        assertEq(vault.totalDeposits(), DEPOSIT_AMOUNT * 3);
    }
}
