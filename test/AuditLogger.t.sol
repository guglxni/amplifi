// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {AuditLogger} from "../src/AuditLogger.sol";

/**
 * @title TestAuditLoggerUser
 * @notice Test contract that uses AuditLogger for testing events
 */
contract TestAuditLoggerUser {
    using AuditLogger for *;

    address public owner;

    constructor() {
        owner = msg.sender;
    }

    function simulateAdminAction(bytes32 actionType, bytes memory data) external {
        AuditLogger.logAdminAction(
            msg.sender,
            msg.sig,
            actionType,
            data
        );
    }

    function simulateConfigChange(bytes32 param, bytes32 oldVal, bytes32 newVal) external {
        AuditLogger.logConfigChange(param, oldVal, newVal);
    }

    function simulateSecurityEvent(bytes32 eventType, address actor, bytes memory details) external {
        AuditLogger.logSecurityEvent(eventType, actor, details);
    }

    function simulateFundsMovement(
        bytes32 operation,
        address token,
        address from,
        address to,
        uint256 amount
    ) external {
        AuditLogger.logFundsMovement(operation, token, from, to, amount);
    }

    function simulateCrossChain(
        uint256 sourceChain,
        uint256 destChain,
        bytes32 opType,
        address sourceContract,
        address destContract,
        bytes memory payload
    ) external {
        AuditLogger.logCrossChain(sourceChain, destChain, opType, sourceContract, destContract, payload);
    }

    function simulateRSCCallback(
        address rvm,
        bytes4 selector,
        bytes memory data,
        uint256 gasUsed
    ) external {
        AuditLogger.logRSCCallback(rvm, selector, data, gasUsed);
    }
}

/**
 * @title AuditLoggerTest
 * @notice Tests for AuditLogger library
 */
contract AuditLoggerTest is Test {
    TestAuditLoggerUser public user;
    address public testActor = address(0x1234);
    address public testToken = address(0x5678);

    function setUp() public {
        user = new TestAuditLoggerUser();
    }

    // ═══════════════════════════════════════════════════════════════
    //                     ADMIN ACTION TESTS
    // ═══════════════════════════════════════════════════════════════

    function test_AdminAction_EmitsEvent() public {
        bytes memory testData = abi.encode("test data");
        
        vm.expectEmit(true, true, true, true);
        emit AuditLogger.AdminAction(
            address(this),
            user.simulateAdminAction.selector,
            AuditLogger.ACTION_ASSET_ADDED,
            testData,
            block.timestamp
        );
        
        user.simulateAdminAction(AuditLogger.ACTION_ASSET_ADDED, testData);
    }

    function test_AdminAction_DifferentActionTypes() public {
        bytes32[] memory actionTypes = new bytes32[](4);
        actionTypes[0] = AuditLogger.ACTION_ASSET_ADDED;
        actionTypes[1] = AuditLogger.ACTION_ASSET_REMOVED;
        actionTypes[2] = AuditLogger.ACTION_REBALANCE;
        actionTypes[3] = AuditLogger.ACTION_EMERGENCY;

        for (uint256 i = 0; i < actionTypes.length; i++) {
            user.simulateAdminAction(actionTypes[i], "");
        }
    }

    // ═══════════════════════════════════════════════════════════════
    //                     CONFIG CHANGE TESTS
    // ═══════════════════════════════════════════════════════════════

    function test_ConfigChange_EmitsEvent() public {
        bytes32 param = keccak256("allocation");
        bytes32 oldVal = bytes32(uint256(2000));
        bytes32 newVal = bytes32(uint256(3000));

        vm.expectEmit(true, true, true, true);
        emit AuditLogger.ConfigurationChanged(
            address(user),
            param,
            oldVal,
            newVal,
            block.timestamp
        );

        user.simulateConfigChange(param, oldVal, newVal);
    }

    // ═══════════════════════════════════════════════════════════════
    //                     SECURITY EVENT TESTS
    // ═══════════════════════════════════════════════════════════════

    function test_SecurityEvent_EmitsEvent() public {
        bytes memory details = abi.encode("unauthorized access attempt");

        vm.expectEmit(true, true, true, true);
        emit AuditLogger.SecurityEvent(
            address(user),
            AuditLogger.SECURITY_UNAUTHORIZED,
            testActor,
            details,
            block.timestamp
        );

        user.simulateSecurityEvent(AuditLogger.SECURITY_UNAUTHORIZED, testActor, details);
    }

    function test_SecurityEvent_AccessGranted() public {
        bytes memory details = abi.encode("admin access granted");

        user.simulateSecurityEvent(AuditLogger.SECURITY_ACCESS_GRANTED, testActor, details);
    }

    function test_SecurityEvent_AccessRevoked() public {
        bytes memory details = abi.encode("admin access revoked");

        user.simulateSecurityEvent(AuditLogger.SECURITY_ACCESS_REVOKED, testActor, details);
    }

    // ═══════════════════════════════════════════════════════════════
    //                     FUNDS MOVEMENT TESTS
    // ═══════════════════════════════════════════════════════════════

    function test_FundsMovement_Deposit() public {
        uint256 amount = 1000e18;
        address from = address(0xABCD);
        address to = address(user);

        vm.expectEmit(true, true, true, true);
        emit AuditLogger.FundsMovement(
            address(user),
            AuditLogger.ACTION_DEPOSIT,
            testToken,
            from,
            to,
            amount,
            block.timestamp
        );

        user.simulateFundsMovement(AuditLogger.ACTION_DEPOSIT, testToken, from, to, amount);
    }

    function test_FundsMovement_Withdraw() public {
        uint256 amount = 500e18;
        address from = address(user);
        address to = address(0xDEAD);

        user.simulateFundsMovement(AuditLogger.ACTION_WITHDRAW, testToken, from, to, amount);
    }

    // ═══════════════════════════════════════════════════════════════
    //                     CROSS-CHAIN TESTS
    // ═══════════════════════════════════════════════════════════════

    function test_CrossChain_EmitsEvent() public {
        uint256 sourceChain = 11155111; // Sepolia
        uint256 destChain = 5318007;    // Lasna
        bytes32 opType = keccak256("ORACLE_UPDATE");
        address sourceContract = address(0x1111);
        address destContract = address(0x2222);
        bytes memory payload = abi.encode(uint256(2000e8));

        vm.expectEmit(true, true, true, true);
        emit AuditLogger.CrossChainActivity(
            sourceChain,
            destChain,
            opType,
            sourceContract,
            destContract,
            payload,
            block.timestamp
        );

        user.simulateCrossChain(sourceChain, destChain, opType, sourceContract, destContract, payload);
    }

    // ═══════════════════════════════════════════════════════════════
    //                     RSC CALLBACK TESTS
    // ═══════════════════════════════════════════════════════════════

    function test_RSCCallback_EmitsEvent() public {
        address rvm = address(0x9999);
        bytes4 selector = bytes4(keccak256("executeRebalance(address,uint256[],uint256[])"));
        bytes memory data = abi.encode(uint256(1), uint256(2000));
        uint256 gasUsed = 150000;

        vm.expectEmit(true, true, true, true);
        emit AuditLogger.RSCCallback(
            rvm,
            selector,
            data,
            gasUsed,
            block.timestamp
        );

        user.simulateRSCCallback(rvm, selector, data, gasUsed);
    }

    // ═══════════════════════════════════════════════════════════════
    //                     CONSTANTS TESTS
    // ═══════════════════════════════════════════════════════════════

    function test_ActionConstants_AreUnique() public pure {
        // Verify all action types are unique
        assertTrue(AuditLogger.ACTION_ASSET_ADDED != AuditLogger.ACTION_ASSET_REMOVED);
        assertTrue(AuditLogger.ACTION_ASSET_ADDED != AuditLogger.ACTION_ALLOCATION_CHANGED);
        assertTrue(AuditLogger.ACTION_ASSET_ADDED != AuditLogger.ACTION_REBALANCE);
        assertTrue(AuditLogger.ACTION_DEPOSIT != AuditLogger.ACTION_WITHDRAW);
    }

    function test_SecurityConstants_AreUnique() public pure {
        assertTrue(AuditLogger.SECURITY_ACCESS_GRANTED != AuditLogger.SECURITY_ACCESS_REVOKED);
        assertTrue(AuditLogger.SECURITY_ACCESS_GRANTED != AuditLogger.SECURITY_CALLBACK_RECEIVED);
        assertTrue(AuditLogger.SECURITY_ACCESS_GRANTED != AuditLogger.SECURITY_UNAUTHORIZED);
    }
}
