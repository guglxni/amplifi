// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {LiquidationProtectorRsc} from "../../src/LiquidationProtectorRsc.sol";

/**
 * @title LiquidationProtectorRscTest
 * @notice Unit tests for the LiquidationProtectorRsc contract
 */
contract LiquidationProtectorRscTest is Test {
    LiquidationProtectorRsc public protector;
    
    address public owner = address(this);
    address public user1 = address(0x1);
    address public user2 = address(0x2);
    address public aavePool = address(0xA1);
    address public protectionVault = address(0xB1);
    
    function setUp() public {
        // Deploy the protector contract
        protector = new LiquidationProtectorRsc{value: 1 ether}(
            aavePool,
            protectionVault
        );
    }
    
    // ═══════════════════════════════════════════════════════════════
    //                    DEPLOYMENT TESTS
    // ═══════════════════════════════════════════════════════════════
    
    function test_Deployment() public view {
        assertEq(protector.owner(), owner);
        assertEq(protector.aavePool(), aavePool);
        assertEq(protector.defaultProtectionVault(), protectionVault);
        assertEq(protector.totalProtectionTriggers(), 0);
        assertEq(protector.paused(), false);
    }
    
    function test_DeploymentRevertsWithZeroAavePool() public {
        vm.expectRevert(LiquidationProtectorRsc.ZeroAddress.selector);
        new LiquidationProtectorRsc{value: 1 ether}(
            address(0),
            protectionVault
        );
    }
    
    function test_DeploymentRevertsWithZeroVault() public {
        vm.expectRevert(LiquidationProtectorRsc.ZeroAddress.selector);
        new LiquidationProtectorRsc{value: 1 ether}(
            aavePool,
            address(0)
        );
    }
    
    // ═══════════════════════════════════════════════════════════════
    //                    PROTECTION REGISTRATION TESTS
    // ═══════════════════════════════════════════════════════════════
    
    function test_RegisterProtection() public {
        // Register a user for protection
        uint256 threshold = 1.15e18;
        uint256 reserveAmount = 1 ether;
        
        protector.registerProtection(
            user1,
            LiquidationProtectorRsc.ProtectionStrategy.HYBRID,
            threshold,
            reserveAmount
        );
        
        (
            bool active,
            LiquidationProtectorRsc.ProtectionStrategy strategy,
            uint256 storedThreshold,
            uint256 storedReserve
        ) = protector.getProtectionStatus(user1);
        
        assertTrue(active);
        assertEq(uint8(strategy), uint8(LiquidationProtectorRsc.ProtectionStrategy.HYBRID));
        assertEq(storedThreshold, threshold);
        assertEq(storedReserve, reserveAmount);
        assertEq(protector.getProtectedUserCount(), 1);
    }
    
    function test_RegisterProtectionRevertsForNonOwner() public {
        vm.prank(user1);
        vm.expectRevert(LiquidationProtectorRsc.OnlyOwner.selector);
        protector.registerProtection(
            user1,
            LiquidationProtectorRsc.ProtectionStrategy.HYBRID,
            1.15e18,
            1 ether
        );
    }
    
    function test_RegisterProtectionRevertsForLowThreshold() public {
        // Threshold below MIN_HEALTH_FACTOR (1.05e18)
        vm.expectRevert(LiquidationProtectorRsc.InvalidThreshold.selector);
        protector.registerProtection(
            user1,
            LiquidationProtectorRsc.ProtectionStrategy.HYBRID,
            1.04e18, // Too low
            1 ether
        );
    }
    
    function test_RegisterProtectionRevertsIfAlreadyProtected() public {
        protector.registerProtection(
            user1,
            LiquidationProtectorRsc.ProtectionStrategy.HYBRID,
            1.15e18,
            1 ether
        );
        
        vm.expectRevert(LiquidationProtectorRsc.AlreadyProtected.selector);
        protector.registerProtection(
            user1,
            LiquidationProtectorRsc.ProtectionStrategy.ADD_COLLATERAL,
            1.2e18,
            2 ether
        );
    }
    
    // ═══════════════════════════════════════════════════════════════
    //                    UPDATE PROTECTION TESTS
    // ═══════════════════════════════════════════════════════════════
    
    function test_UpdateProtection() public {
        // Register first
        protector.registerProtection(
            user1,
            LiquidationProtectorRsc.ProtectionStrategy.HYBRID,
            1.15e18,
            1 ether
        );
        
        // Update
        protector.updateProtection(
            user1,
            LiquidationProtectorRsc.ProtectionStrategy.REPAY_DEBT,
            1.25e18
        );
        
        (
            bool active,
            LiquidationProtectorRsc.ProtectionStrategy strategy,
            uint256 threshold,
        ) = protector.getProtectionStatus(user1);
        
        assertTrue(active);
        assertEq(uint8(strategy), uint8(LiquidationProtectorRsc.ProtectionStrategy.REPAY_DEBT));
        assertEq(threshold, 1.25e18);
    }
    
    function test_UpdateProtectionRevertsIfNotProtected() public {
        vm.expectRevert(LiquidationProtectorRsc.NotProtected.selector);
        protector.updateProtection(
            user1,
            LiquidationProtectorRsc.ProtectionStrategy.REPAY_DEBT,
            1.25e18
        );
    }
    
    // ═══════════════════════════════════════════════════════════════
    //                    DEACTIVATE PROTECTION TESTS
    // ═══════════════════════════════════════════════════════════════
    
    function test_DeactivateProtection() public {
        protector.registerProtection(
            user1,
            LiquidationProtectorRsc.ProtectionStrategy.HYBRID,
            1.15e18,
            1 ether
        );
        
        protector.deactivateProtection(user1);
        
        (bool active,,,) = protector.getProtectionStatus(user1);
        assertFalse(active);
    }
    
    function test_DeactivateProtectionRevertsIfNotProtected() public {
        vm.expectRevert(LiquidationProtectorRsc.NotProtected.selector);
        protector.deactivateProtection(user1);
    }
    
    // ═══════════════════════════════════════════════════════════════
    //                    ADMIN FUNCTION TESTS
    // ═══════════════════════════════════════════════════════════════
    
    function test_TransferOwnership() public {
        protector.transferOwnership(user1);
        assertEq(protector.owner(), user1);
    }
    
    function test_TransferOwnershipRevertsForNonOwner() public {
        vm.prank(user1);
        vm.expectRevert(LiquidationProtectorRsc.OnlyOwner.selector);
        protector.transferOwnership(user2);
    }
    
    function test_SetProtectionVault() public {
        address newVault = address(0x111);
        protector.setProtectionVault(newVault);
        assertEq(protector.defaultProtectionVault(), newVault);
    }
    
    function test_SetAavePool() public {
        address newPool = address(0x222);
        protector.setAavePool(newPool);
        assertEq(protector.aavePool(), newPool);
    }
    
    function test_Pause() public {
        protector.pause();
        assertTrue(protector.paused());
    }
    
    function test_Unpause() public {
        protector.pause();
        protector.unpause();
        assertFalse(protector.paused());
    }
    
    // ═══════════════════════════════════════════════════════════════
    //                    VIEW FUNCTION TESTS
    // ═══════════════════════════════════════════════════════════════
    
    function test_GetAllProtectedUsers() public {
        protector.registerProtection(
            user1,
            LiquidationProtectorRsc.ProtectionStrategy.HYBRID,
            1.15e18,
            1 ether
        );
        
        protector.registerProtection(
            user2,
            LiquidationProtectorRsc.ProtectionStrategy.ADD_COLLATERAL,
            1.2e18,
            0.5 ether
        );
        
        address[] memory users = protector.getAllProtectedUsers();
        assertEq(users.length, 2);
        assertEq(users[0], user1);
        assertEq(users[1], user2);
    }
    
    // ═══════════════════════════════════════════════════════════════
    //                    RECEIVE FUNCTION TESTS
    // ═══════════════════════════════════════════════════════════════
    
    function test_ReceiveEth() public {
        uint256 balanceBefore = address(protector).balance;
        payable(address(protector)).transfer(1 ether);
        assertEq(address(protector).balance, balanceBefore + 1 ether);
    }
}
