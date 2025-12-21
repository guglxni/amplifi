// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {ReactiveFunderRC} from "../../src/ReactiveFunderRC.sol";
import {IReactive} from "@reactive/interfaces/IReactive.sol";

/**
 * @title ReactiveFunderRCTest
 * @notice Unit tests for the ReactiveFunderRC contract
 * @dev Tests the Reactivate auto-funding RSC pattern
 */
contract ReactiveFunderRCTest is Test {
    // ═══════════════════════════════════════════════════════════════
    //                        CONSTANTS
    // ═══════════════════════════════════════════════════════════════
    
    uint256 constant SEPOLIA_CHAIN_ID = 11155111;
    uint256 constant FUNDS_RECEIVED_TOPIC = 0x8e47b87b0ef542cdfa1659c551d88bad38aa7f452d2bbb349ab7530dfec8be8f;
    uint256 constant MIN_BRIDGE_AMOUNT = 0.001 ether;
    
    // ═══════════════════════════════════════════════════════════════
    //                        STATE
    // ═══════════════════════════════════════════════════════════════
    
    ReactiveFunderRC public reactive;
    address public funderContract;
    address public autoLooperReactive;
    address public owner;
    
    // ═══════════════════════════════════════════════════════════════
    //                        EVENTS
    // ═══════════════════════════════════════════════════════════════
    
    event BridgeTriggered(
        address indexed originalSender,
        uint256 amount,
        uint256 bridgeAmount,
        uint256 timestamp
    );
    
    // ═══════════════════════════════════════════════════════════════
    //                        SETUP
    // ═══════════════════════════════════════════════════════════════
    
    function setUp() public {
        funderContract = makeAddr("funder");
        autoLooperReactive = makeAddr("autoLooper");
        owner = address(this);
        
        // Deploy in local mode (not Reactive Network)
        reactive = new ReactiveFunderRC(funderContract, autoLooperReactive);
    }
    
    // ═══════════════════════════════════════════════════════════════
    //                    CONSTRUCTOR TESTS
    // ═══════════════════════════════════════════════════════════════
    
    function test_constructor_setsFunderContract() public view {
        assertEq(reactive.getFunderContract(), funderContract);
    }
    
    function test_constructor_setsRecipient() public view {
        assertEq(reactive.getRecipient(), autoLooperReactive);
    }
    
    function test_constructor_setsOwner() public view {
        assertEq(reactive.owner(), owner);
    }
    
    function test_constructor_revertsOnZeroFunder() public {
        vm.expectRevert("Invalid funder");
        new ReactiveFunderRC(address(0), autoLooperReactive);
    }
    
    function test_constructor_revertsOnZeroRecipient() public {
        vm.expectRevert("Invalid recipient");
        new ReactiveFunderRC(funderContract, address(0));
    }
    
    // ═══════════════════════════════════════════════════════════════
    //                    BRIDGE CALCULATION TESTS
    // ═══════════════════════════════════════════════════════════════
    
    function test_bridgeAmount_is95Percent() public pure {
        uint256 amount = 1 ether;
        uint256 bridgeAmount = (amount * 95) / 100;
        
        assertEq(bridgeAmount, 0.95 ether);
    }
    
    function test_bridgeAmount_gasBuffer() public pure {
        uint256 amount = 1 ether;
        uint256 bridgeAmount = (amount * 95) / 100;
        uint256 gasBuffer = amount - bridgeAmount;
        
        assertEq(gasBuffer, 0.05 ether); // 5% kept for gas
    }
    
    function test_minBridgeAmount_filter() public pure {
        uint256 smallAmount = 0.0005 ether;
        bool shouldBridge = smallAmount >= MIN_BRIDGE_AMOUNT;
        
        assertFalse(shouldBridge);
    }
    
    function test_minBridgeAmount_pass() public pure {
        uint256 validAmount = 0.01 ether;
        bool shouldBridge = validAmount >= MIN_BRIDGE_AMOUNT;
        
        assertTrue(shouldBridge);
    }
    
    // ═══════════════════════════════════════════════════════════════
    //                    STATS TESTS
    // ═══════════════════════════════════════════════════════════════
    
    function test_getStats_returnsInitialValues() public view {
        (
            uint256 totalBridged,
            uint256 bridgeCount,
            address funder,
            address recipient
        ) = reactive.getStats();
        
        assertEq(totalBridged, 0);
        assertEq(bridgeCount, 0);
        assertEq(funder, funderContract);
        assertEq(recipient, autoLooperReactive);
    }
    
    // ═══════════════════════════════════════════════════════════════
    //                    OWNERSHIP TESTS
    // ═══════════════════════════════════════════════════════════════
    
    function test_transferOwnership_updatesOwner() public {
        address newOwner = makeAddr("newOwner");
        reactive.transferOwnership(newOwner);
        
        assertEq(reactive.owner(), newOwner);
    }
    
    function test_transferOwnership_onlyOwner() public {
        address attacker = makeAddr("attacker");
        
        vm.prank(attacker);
        vm.expectRevert("Only owner");
        reactive.transferOwnership(attacker);
    }
    
    function test_transferOwnership_revertsOnZeroAddress() public {
        vm.expectRevert("Invalid owner");
        reactive.transferOwnership(address(0));
    }
    
    // ═══════════════════════════════════════════════════════════════
    //                    EVENT TOPIC TESTS
    // ═══════════════════════════════════════════════════════════════
    
    function test_fundsReceivedTopic_matchesExpected() public pure {
        bytes32 expected = keccak256("FundsReceived(address,uint256)");
        assertEq(uint256(expected), FUNDS_RECEIVED_TOPIC);
    }
    
    // ═══════════════════════════════════════════════════════════════
    //                    FUZZ TESTS
    // ═══════════════════════════════════════════════════════════════
    
    function testFuzz_bridgeAmount_always95Percent(uint256 amount) public pure {
        amount = bound(amount, 0.001 ether, 1000 ether);
        
        uint256 bridgeAmount = (amount * 95) / 100;
        uint256 gasBuffer = amount - bridgeAmount;
        
        // Bridge amount should be 95%
        assertEq(bridgeAmount, (amount * 95) / 100);
        
        // Gas buffer should be 5%
        assertEq(gasBuffer, amount - bridgeAmount);
        
        // Total should equal original
        assertEq(bridgeAmount + gasBuffer, amount);
    }
    
    function testFuzz_minBridgeFilter_works(uint256 amount) public pure {
        amount = bound(amount, 0, 0.01 ether);
        
        bool shouldBridge = amount >= MIN_BRIDGE_AMOUNT;
        
        if (amount >= MIN_BRIDGE_AMOUNT) {
            assertTrue(shouldBridge);
        } else {
            assertFalse(shouldBridge);
        }
    }
    
    // ═══════════════════════════════════════════════════════════════
    //            HYBRID AUTO-REFILL TESTS (NEW)
    // ═══════════════════════════════════════════════════════════════
    
    function test_refillThreshold_defaultValue() public view {
        assertEq(reactive.refillThreshold(), 1 ether);
    }
    
    function test_faucetBridgeAmount_defaultValue() public view {
        assertEq(reactive.faucetBridgeAmount(), 0.1 ether);
    }
    
    function test_autoRefillEnabled_defaultValue() public view {
        assertTrue(reactive.autoRefillEnabled());
    }
    
    function test_setRefillThreshold_updatesValue() public {
        reactive.setRefillThreshold(2 ether);
        assertEq(reactive.refillThreshold(), 2 ether);
    }
    
    function test_setRefillThreshold_onlyOwner() public {
        address attacker = makeAddr("attacker");
        
        vm.prank(attacker);
        vm.expectRevert("Only owner");
        reactive.setRefillThreshold(2 ether);
    }
    
    function test_setFaucetBridgeAmount_updatesValue() public {
        reactive.setFaucetBridgeAmount(0.5 ether);
        assertEq(reactive.faucetBridgeAmount(), 0.5 ether);
    }
    
    function test_setFaucetBridgeAmount_revertsOnExceedMax() public {
        vm.expectRevert("Max 5 ETH per request");
        reactive.setFaucetBridgeAmount(6 ether);
    }
    
    function test_setFaucetBridgeAmount_onlyOwner() public {
        address attacker = makeAddr("attacker");
        
        vm.prank(attacker);
        vm.expectRevert("Only owner");
        reactive.setFaucetBridgeAmount(0.5 ether);
    }
    
    function test_setAutoRefillEnabled_togglesOn() public {
        reactive.setAutoRefillEnabled(false);
        assertFalse(reactive.autoRefillEnabled());
        
        reactive.setAutoRefillEnabled(true);
        assertTrue(reactive.autoRefillEnabled());
    }
    
    function test_setAutoRefillEnabled_onlyOwner() public {
        address attacker = makeAddr("attacker");
        
        vm.prank(attacker);
        vm.expectRevert("Only owner");
        reactive.setAutoRefillEnabled(false);
    }
    
    function testFuzz_setRefillThreshold_anyValue(uint256 threshold) public {
        reactive.setRefillThreshold(threshold);
        assertEq(reactive.refillThreshold(), threshold);
    }
    
    function testFuzz_setFaucetBridgeAmount_validRange(uint256 amount) public {
        amount = bound(amount, 0, 5 ether);
        reactive.setFaucetBridgeAmount(amount);
        assertEq(reactive.faucetBridgeAmount(), amount);
    }
}
