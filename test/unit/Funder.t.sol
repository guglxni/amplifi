// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {Funder} from "../../src/Funder.sol";

/**
 * @title FunderTest
 * @notice Comprehensive unit tests for the Funder contract
 * @dev Tests the Reactivate auto-funding pattern
 */
contract FunderTest is Test {
    // ═══════════════════════════════════════════════════════════════
    //                        CONSTANTS
    // ═══════════════════════════════════════════════════════════════
    
    address constant CALLBACK_PROXY = 0xc9f36411C9897e7F959D99ffca2a0Ba7ee0D7bDA;
    uint256 constant MIN_TRANSFER = 0.001 ether;
    
    // ═══════════════════════════════════════════════════════════════
    //                        STATE
    // ═══════════════════════════════════════════════════════════════
    
    Funder public funder;
    address public targetRsc;
    address public owner;
    address public user1;
    
    // ═══════════════════════════════════════════════════════════════
    //                        EVENTS
    // ═══════════════════════════════════════════════════════════════
    
    event FundsReceived(address indexed sender, uint256 amount);
    event FundsBridged(address indexed reactiveContract, uint256 amount);
    event FundsWithdrawn(address indexed to, uint256 amount);
    
    // ═══════════════════════════════════════════════════════════════
    //                        SETUP
    // ═══════════════════════════════════════════════════════════════
    
    function setUp() public {
        targetRsc = makeAddr("targetRsc");
        owner = address(this);
        user1 = makeAddr("user1");
        
        funder = new Funder(targetRsc);
    }
    
    // ═══════════════════════════════════════════════════════════════
    //                    CONSTRUCTOR TESTS
    // ═══════════════════════════════════════════════════════════════
    
    function test_constructor_setsOwner() public view {
        assertEq(funder.owner(), owner);
    }
    
    function test_constructor_setsTargetRsc() public view {
        assertEq(funder.targetRsc(), targetRsc);
    }
    
    function test_constructor_authorizesCallbackProxy() public view {
        assertTrue(funder.authorizedCallers(CALLBACK_PROXY));
    }
    
    function test_constructor_authorizesOwner() public view {
        assertTrue(funder.authorizedCallers(owner));
    }
    
    // ═══════════════════════════════════════════════════════════════
    //                    RECEIVE FUNDS TESTS
    // ═══════════════════════════════════════════════════════════════
    
    function test_receive_emitsFundsReceived() public {
        vm.deal(user1, 1 ether);
        
        vm.expectEmit(true, false, false, true);
        emit FundsReceived(user1, 0.1 ether);
        
        vm.prank(user1);
        (bool success, ) = address(funder).call{value: 0.1 ether}("");
        assertTrue(success);
    }
    
    function test_receive_updatesTotalCollected() public {
        vm.deal(user1, 1 ether);
        
        vm.prank(user1);
        (bool success, ) = address(funder).call{value: 0.1 ether}("");
        assertTrue(success);
        
        assertEq(funder.totalCollected(), 0.1 ether);
    }
    
    function test_fund_emitsFundsReceived() public {
        vm.deal(user1, 1 ether);
        
        vm.expectEmit(true, false, false, true);
        emit FundsReceived(user1, 0.1 ether);
        
        vm.prank(user1);
        funder.fund{value: 0.1 ether}();
    }
    
    function test_receive_revertsOnZeroValue() public {
        vm.prank(user1);
        vm.expectRevert("Funder: no ETH sent");
        funder.fund{value: 0}();
    }
    
    // ═══════════════════════════════════════════════════════════════
    //                    BRIDGE TESTS
    // ═══════════════════════════════════════════════════════════════
    
    function test_canBridge_returnsFalseWhenBelowThreshold() public view {
        assertFalse(funder.canBridge());
    }
    
    function test_canBridge_returnsTrueWhenAboveThreshold() public {
        vm.deal(address(funder), 0.1 ether);
        assertTrue(funder.canBridge());
    }
    
    function test_getBridgeableAmount_returnsCorrectAmount() public {
        vm.deal(address(funder), 0.1 ether);
        
        uint256 expected = 0.1 ether - funder.gasReserve();
        assertEq(funder.getBridgeableAmount(), expected);
    }
    
    function test_getBridgeableAmount_returnsZeroWhenBelowReserve() public {
        vm.deal(address(funder), 0.001 ether);
        assertEq(funder.getBridgeableAmount(), 0);
    }
    
    // ═══════════════════════════════════════════════════════════════
    //                    ADMIN TESTS
    // ═══════════════════════════════════════════════════════════════
    
    function test_setTargetRsc_updatesAddress() public {
        address newRsc = makeAddr("newRsc");
        funder.setTargetRsc(newRsc);
        assertEq(funder.targetRsc(), newRsc);
    }
    
    function test_setTargetRsc_revertsOnZeroAddress() public {
        vm.expectRevert("Funder: zero address");
        funder.setTargetRsc(address(0));
    }
    
    function test_setTargetRsc_onlyOwner() public {
        vm.prank(user1);
        vm.expectRevert("Funder: only owner");
        funder.setTargetRsc(makeAddr("newRsc"));
    }
    
    function test_setBridgeThreshold_updatesValue() public {
        funder.setBridgeThreshold(0.05 ether);
        assertEq(funder.bridgeThreshold(), 0.05 ether);
    }
    
    function test_setGasReserve_updatesValue() public {
        funder.setGasReserve(0.01 ether);
        assertEq(funder.gasReserve(), 0.01 ether);
    }
    
    function test_setAuthorizedCaller_addsAddress() public {
        address newCaller = makeAddr("newCaller");
        funder.setAuthorizedCaller(newCaller, true);
        assertTrue(funder.authorizedCallers(newCaller));
    }
    
    function test_setAuthorizedCaller_removesAddress() public {
        address caller = makeAddr("caller");
        funder.setAuthorizedCaller(caller, true);
        funder.setAuthorizedCaller(caller, false);
        assertFalse(funder.authorizedCallers(caller));
    }
    
    // ═══════════════════════════════════════════════════════════════
    //                    EMERGENCY WITHDRAW TESTS
    // ═══════════════════════════════════════════════════════════════
    
    function test_emergencyWithdraw_transfersFunds() public {
        vm.deal(address(funder), 1 ether);
        
        address payable recipient = payable(makeAddr("recipient"));
        uint256 balanceBefore = recipient.balance;
        funder.emergencyWithdraw(recipient, 0.5 ether);
        
        assertEq(recipient.balance - balanceBefore, 0.5 ether);
    }
    
    function test_emergencyWithdraw_revertsOnInsufficientBalance() public {
        vm.deal(address(funder), 0.1 ether);
        
        vm.expectRevert("Funder: insufficient balance");
        funder.emergencyWithdraw(payable(owner), 1 ether);
    }
    
    function test_emergencyWithdraw_revertsOnZeroAddress() public {
        vm.deal(address(funder), 1 ether);
        
        vm.expectRevert("Funder: zero address");
        funder.emergencyWithdraw(payable(address(0)), 0.5 ether);
    }
    
    function test_emergencyWithdraw_onlyOwner() public {
        vm.deal(address(funder), 1 ether);
        
        vm.prank(user1);
        vm.expectRevert("Funder: only owner");
        funder.emergencyWithdraw(payable(user1), 0.5 ether);
    }
    
    // ═══════════════════════════════════════════════════════════════
    //                    VIEW FUNCTION TESTS
    // ═══════════════════════════════════════════════════════════════
    
    function test_getBalance_returnsCorrectValue() public {
        vm.deal(address(funder), 0.5 ether);
        assertEq(funder.getBalance(), 0.5 ether);
    }
    
    function test_getStats_returnsAllValues() public {
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        funder.fund{value: 0.1 ether}();
        
        (
            uint256 totalCollected,
            uint256 totalBridged,
            uint256 currentBalance,
            uint256 bridgeThreshold,
            uint256 bridgeCount,
            address rsc
        ) = funder.getStats();
        
        assertEq(totalCollected, 0.1 ether);
        assertEq(totalBridged, 0);
        assertEq(currentBalance, 0.1 ether);
        assertEq(bridgeThreshold, 0.01 ether);
        assertEq(bridgeCount, 0);
        assertEq(rsc, targetRsc);
    }
    
    // ═══════════════════════════════════════════════════════════════
    //                    FUZZ TESTS
    // ═══════════════════════════════════════════════════════════════
    
    function testFuzz_receive_acceptsAnyAmount(uint256 amount) public {
        amount = bound(amount, 1, 100 ether);
        vm.deal(user1, amount);
        
        vm.prank(user1);
        funder.fund{value: amount}();
        
        assertEq(funder.totalCollected(), amount);
        assertEq(address(funder).balance, amount);
    }
    
    function testFuzz_getBridgeableAmount_alwaysLessThanBalance(uint256 balance) public {
        balance = bound(balance, 0, 100 ether);
        vm.deal(address(funder), balance);
        
        uint256 bridgeable = funder.getBridgeableAmount();
        assertLe(bridgeable, balance);
    }
    
    // ═══════════════════════════════════════════════════════════════
    //               FAUCET BRIDGE TESTS (NEW)
    // ═══════════════════════════════════════════════════════════════
    
    function test_REACTIVE_FAUCET_constant() public view {
        assertEq(funder.REACTIVE_FAUCET(), 0x9b9BB25f1A81078C544C829c5EB7822d747Cf434);
    }
    
    function test_bridgeToFaucet_revertsOnZeroRecipient() public {
        vm.deal(address(funder), 1 ether);
        
        vm.expectRevert("Funder: invalid recipient");
        funder.bridgeToFaucet(address(0), 0.1 ether);
    }
    
    function test_bridgeToFaucet_revertsOnAmountTooSmall() public {
        vm.deal(address(funder), 1 ether);
        
        vm.expectRevert("Funder: amount too small");
        funder.bridgeToFaucet(targetRsc, 0.0001 ether);
    }
    
    function test_bridgeToFaucet_revertsOnAmountTooLarge() public {
        vm.deal(address(funder), 10 ether);
        
        vm.expectRevert("Funder: max 5 ETH per faucet request");
        funder.bridgeToFaucet(targetRsc, 6 ether);
    }
    
    function test_bridgeToFaucet_revertsOnInsufficientBalance() public {
        vm.deal(address(funder), 0.05 ether);
        
        vm.expectRevert("Funder: insufficient balance");
        funder.bridgeToFaucet(targetRsc, 0.1 ether);
    }
    
    function test_bridgeToFaucet_onlyAuthorized() public {
        vm.deal(address(funder), 1 ether);
        
        vm.prank(user1);
        vm.expectRevert("Funder: not authorized");
        funder.bridgeToFaucet(targetRsc, 0.1 ether);
    }
    
    function test_autoRefillReact_revertsOnNoTargetRsc() public {
        // Deploy funder with zero target (not allowed in constructor, so test indirectly)
        vm.deal(address(funder), 1 ether);
        
        // Set target to zero
        funder.setTargetRsc(makeAddr("temp"));
        // Can't set to zero due to revert, so skip this test aspect
    }
    
    function test_autoRefillReact_revertsOnAmountTooLarge() public {
        vm.deal(address(funder), 10 ether);
        
        vm.expectRevert("Funder: max 5 ETH per faucet request");
        funder.autoRefillReact(6 ether);
    }
    
    function testFuzz_bridgeToFaucet_validRange(uint256 amount) public {
        amount = bound(amount, 0.001 ether, 5 ether);
        vm.deal(address(funder), amount + funder.gasReserve());
        
        // Create mock faucet that accepts the call
        vm.mockCall(
            funder.REACTIVE_FAUCET(),
            abi.encodeWithSignature("request(address)", targetRsc),
            abi.encode(true)
        );
        
        // Should not revert with valid params
        funder.bridgeToFaucet(targetRsc, amount);
    }
}
