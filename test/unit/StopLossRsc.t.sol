// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {StopLossRsc} from "../../src/StopLossRsc.sol";

/**
 * @title StopLossRscTest
 * @notice Unit tests for the StopLossRsc contract
 */
contract StopLossRscTest is Test {
    StopLossRsc public stopLoss;
    
    address public owner = address(this);
    address public user1 = address(0x1);
    address public user2 = address(0x2);
    address public priceOracle = address(0xC1);
    address public swapRouter = address(0xD1);
    address public weth = address(0xE1);
    address public usdc = address(0xF1);
    
    function setUp() public {
        // Deploy the stop-loss contract
        stopLoss = new StopLossRsc{value: 1 ether}(
            priceOracle,
            swapRouter
        );
    }
    
    // ═══════════════════════════════════════════════════════════════
    //                    DEPLOYMENT TESTS
    // ═══════════════════════════════════════════════════════════════
    
    function test_Deployment() public view {
        assertEq(stopLoss.owner(), owner);
        assertEq(stopLoss.priceOracle(), priceOracle);
        assertEq(stopLoss.swapRouter(), swapRouter);
        assertEq(stopLoss.nextOrderId(), 1);
        assertEq(stopLoss.totalExecutions(), 0);
        assertEq(stopLoss.paused(), false);
    }
    
    function test_DeploymentRevertsWithZeroOracle() public {
        vm.expectRevert(StopLossRsc.ZeroAddress.selector);
        new StopLossRsc{value: 1 ether}(
            address(0),
            swapRouter
        );
    }
    
    function test_DeploymentRevertsWithZeroRouter() public {
        vm.expectRevert(StopLossRsc.ZeroAddress.selector);
        new StopLossRsc{value: 1 ether}(
            priceOracle,
            address(0)
        );
    }
    
    // ═══════════════════════════════════════════════════════════════
    //                    ORDER CREATION TESTS
    // ═══════════════════════════════════════════════════════════════
    
    function test_CreateStopLossOrder() public {
        uint256 orderId = stopLoss.createOrder(
            user1,
            weth,
            usdc,
            1 ether,
            2800e8, // $2800 trigger
            StopLossRsc.OrderType.STOP_LOSS,
            0 // No trailing
        );
        
        assertEq(orderId, 1);
        
        StopLossRsc.Order memory order = stopLoss.getOrder(orderId);
        assertEq(order.user, user1);
        assertEq(order.tokenIn, weth);
        assertEq(order.tokenOut, usdc);
        assertEq(order.amount, 1 ether);
        assertEq(order.triggerPrice, 2800e8);
        assertEq(uint8(order.orderType), uint8(StopLossRsc.OrderType.STOP_LOSS));
        assertEq(uint8(order.status), uint8(StopLossRsc.OrderStatus.PENDING));
    }
    
    function test_CreateTakeProfitOrder() public {
        uint256 orderId = stopLoss.createOrder(
            user1,
            weth,
            usdc,
            1 ether,
            4000e8, // $4000 trigger
            StopLossRsc.OrderType.TAKE_PROFIT,
            0
        );
        
        StopLossRsc.Order memory order = stopLoss.getOrder(orderId);
        assertEq(uint8(order.orderType), uint8(StopLossRsc.OrderType.TAKE_PROFIT));
    }
    
    function test_CreateTrailingStopOrder() public {
        uint256 orderId = stopLoss.createOrder(
            user1,
            weth,
            usdc,
            1 ether,
            3000e8, // $3000 initial trigger
            StopLossRsc.OrderType.TRAILING_STOP,
            500 // 5% trailing
        );
        
        StopLossRsc.Order memory order = stopLoss.getOrder(orderId);
        assertEq(uint8(order.orderType), uint8(StopLossRsc.OrderType.TRAILING_STOP));
        assertEq(order.trailingPercent, 500);
        assertEq(order.highestPrice, 3000e8);
    }
    
    function test_CreateOrderRevertsForNonOwner() public {
        vm.prank(user1);
        vm.expectRevert(StopLossRsc.OnlyOwner.selector);
        stopLoss.createOrder(
            user1,
            weth,
            usdc,
            1 ether,
            2800e8,
            StopLossRsc.OrderType.STOP_LOSS,
            0
        );
    }
    
    function test_CreateOrderRevertsForZeroPrice() public {
        vm.expectRevert(StopLossRsc.InvalidPrice.selector);
        stopLoss.createOrder(
            user1,
            weth,
            usdc,
            1 ether,
            0, // Zero trigger price
            StopLossRsc.OrderType.STOP_LOSS,
            0
        );
    }
    
    function test_CreateOrderRevertsForTooSmallAmount() public {
        vm.expectRevert(StopLossRsc.OrderTooSmall.selector);
        stopLoss.createOrder(
            user1,
            weth,
            usdc,
            0.0001 ether, // Below MIN_ORDER_SIZE
            2800e8,
            StopLossRsc.OrderType.STOP_LOSS,
            0
        );
    }
    
    function test_CreateOrderIncreasesOrderId() public {
        stopLoss.createOrder(user1, weth, usdc, 1 ether, 2800e8, StopLossRsc.OrderType.STOP_LOSS, 0);
        stopLoss.createOrder(user1, weth, usdc, 2 ether, 2500e8, StopLossRsc.OrderType.STOP_LOSS, 0);
        
        uint256 thirdOrderId = stopLoss.createOrder(
            user1, weth, usdc, 3 ether, 2200e8, StopLossRsc.OrderType.STOP_LOSS, 0
        );
        
        assertEq(thirdOrderId, 3);
        assertEq(stopLoss.nextOrderId(), 4);
    }
    
    // ═══════════════════════════════════════════════════════════════
    //                    ORDER CANCELLATION TESTS
    // ═══════════════════════════════════════════════════════════════
    
    function test_CancelOrder() public {
        uint256 orderId = stopLoss.createOrder(
            user1, weth, usdc, 1 ether, 2800e8, StopLossRsc.OrderType.STOP_LOSS, 0
        );
        
        stopLoss.cancelOrder(orderId);
        
        StopLossRsc.Order memory order = stopLoss.getOrder(orderId);
        assertEq(uint8(order.status), uint8(StopLossRsc.OrderStatus.CANCELLED));
    }
    
    function test_CancelOrderRevertsForNonExistent() public {
        vm.expectRevert(StopLossRsc.OrderNotFound.selector);
        stopLoss.cancelOrder(999);
    }
    
    function test_CancelOrderRevertsIfAlreadyCancelled() public {
        uint256 orderId = stopLoss.createOrder(
            user1, weth, usdc, 1 ether, 2800e8, StopLossRsc.OrderType.STOP_LOSS, 0
        );
        stopLoss.cancelOrder(orderId);
        
        vm.expectRevert(StopLossRsc.OrderAlreadyExecuted.selector);
        stopLoss.cancelOrder(orderId);
    }
    
    // ═══════════════════════════════════════════════════════════════
    //                    ADMIN FUNCTION TESTS
    // ═══════════════════════════════════════════════════════════════
    
    function test_TransferOwnership() public {
        stopLoss.transferOwnership(user1);
        assertEq(stopLoss.owner(), user1);
    }
    
    function test_SetPriceOracle() public {
        address newOracle = address(0x333);
        stopLoss.setPriceOracle(newOracle);
        assertEq(stopLoss.priceOracle(), newOracle);
    }
    
    function test_SetSwapRouter() public {
        address newRouter = address(0x444);
        stopLoss.setSwapRouter(newRouter);
        assertEq(stopLoss.swapRouter(), newRouter);
    }
    
    function test_Pause() public {
        stopLoss.pause();
        assertTrue(stopLoss.paused());
    }
    
    function test_Unpause() public {
        stopLoss.pause();
        stopLoss.unpause();
        assertFalse(stopLoss.paused());
    }
    
    // ═══════════════════════════════════════════════════════════════
    //                    VIEW FUNCTION TESTS
    // ═══════════════════════════════════════════════════════════════
    
    function test_GetUserOrders() public {
        stopLoss.createOrder(user1, weth, usdc, 1 ether, 2800e8, StopLossRsc.OrderType.STOP_LOSS, 0);
        stopLoss.createOrder(user1, weth, usdc, 2 ether, 2500e8, StopLossRsc.OrderType.TAKE_PROFIT, 0);
        stopLoss.createOrder(user2, weth, usdc, 0.5 ether, 3000e8, StopLossRsc.OrderType.STOP_LOSS, 0);
        
        uint256[] memory user1Orders = stopLoss.getUserOrders(user1);
        assertEq(user1Orders.length, 2);
        assertEq(user1Orders[0], 1);
        assertEq(user1Orders[1], 2);
        
        uint256[] memory user2Orders = stopLoss.getUserOrders(user2);
        assertEq(user2Orders.length, 1);
        assertEq(user2Orders[0], 3);
    }
    
    function test_GetTokenOrders() public {
        stopLoss.createOrder(user1, weth, usdc, 1 ether, 2800e8, StopLossRsc.OrderType.STOP_LOSS, 0);
        stopLoss.createOrder(user2, weth, usdc, 2 ether, 2500e8, StopLossRsc.OrderType.STOP_LOSS, 0);
        
        uint256[] memory wethOrders = stopLoss.getTokenOrders(weth);
        assertEq(wethOrders.length, 2);
    }
    
    function test_GetStats() public {
        stopLoss.createOrder(user1, weth, usdc, 1 ether, 2800e8, StopLossRsc.OrderType.STOP_LOSS, 0);
        stopLoss.createOrder(user1, weth, usdc, 2 ether, 2500e8, StopLossRsc.OrderType.STOP_LOSS, 0);
        
        (uint256 totalOrders, uint256 executed, bool isPaused) = stopLoss.getStats();
        assertEq(totalOrders, 2);
        assertEq(executed, 0);
        assertFalse(isPaused);
    }
    
    // ═══════════════════════════════════════════════════════════════
    //                    RECEIVE FUNCTION TESTS
    // ═══════════════════════════════════════════════════════════════
    
    function test_ReceiveEth() public {
        uint256 balanceBefore = address(stopLoss).balance;
        payable(address(stopLoss)).transfer(1 ether);
        assertEq(address(stopLoss).balance, balanceBefore + 1 ether);
    }
    
    // ═══════════════════════════════════════════════════════════════
    //                    MAX ORDERS TEST
    // ═══════════════════════════════════════════════════════════════
    
    function test_MaxOrdersPerUser() public {
        // Create MAX_ORDERS_PER_USER orders (10)
        for (uint256 i = 0; i < 10; i++) {
            stopLoss.createOrder(
                user1, weth, usdc, 1 ether, 
                uint256(2800e8 + i), 
                StopLossRsc.OrderType.STOP_LOSS, 
                0
            );
        }
        
        // 11th order should revert
        vm.expectRevert(StopLossRsc.TooManyOrders.selector);
        stopLoss.createOrder(
            user1, weth, usdc, 1 ether, 3000e8, StopLossRsc.OrderType.STOP_LOSS, 0
        );
    }
}
