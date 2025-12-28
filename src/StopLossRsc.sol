// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AbstractReactive} from "@reactive/abstract-base/AbstractReactive.sol";
import {AbstractPayer} from "@reactive/abstract-base/AbstractPayer.sol";
import {IReactive} from "@reactive/interfaces/IReactive.sol";
import {IPayer} from "@reactive/interfaces/IPayer.sol";

/**
 * @title StopLossRsc
 * @notice Reactive Smart Contract for decentralized stop-loss and take-profit orders
 * @dev Monitors oracle price updates and triggers swap callbacks when conditions are met
 * 
 * Architecture:
 * - Subscribes to PriceUpdated events from price oracles
 * - Maintains a registry of user orders
 * - Emits callbacks to execute swaps when trigger prices are hit
 * 
 * Order Types:
 * - STOP_LOSS: Sell when price drops below trigger
 * - TAKE_PROFIT: Sell when price rises above trigger
 * - TRAILING_STOP: Dynamic stop-loss that follows price up
 */
contract StopLossRsc is IReactive, AbstractReactive {
    // ═══════════════════════════════════════════════════════════════
    //                         CONSTANTS
    // ═══════════════════════════════════════════════════════════════

    /// @notice Sepolia chain ID
    uint256 private constant SEPOLIA_CHAIN_ID = 11155111;
    
    /// @notice Default callback gas limit
    uint64 private constant CALLBACK_GAS_LIMIT = 400000;
    
    /// @notice Price update event signature
    /// @dev keccak256("PriceUpdated(address,uint256,uint256)")
    uint256 private constant PRICE_UPDATED_TOPIC_0 = 0x0;  // To be computed
    
    /// @notice Maximum orders per user
    uint256 public constant MAX_ORDERS_PER_USER = 10;
    
    /// @notice Minimum order size (0.001 ETH equivalent)
    uint256 public constant MIN_ORDER_SIZE = 0.001 ether;

    // ═══════════════════════════════════════════════════════════════
    //                         ENUMS
    // ═══════════════════════════════════════════════════════════════

    /// @notice Order types
    enum OrderType {
        STOP_LOSS,      // Execute when price < trigger
        TAKE_PROFIT,    // Execute when price > trigger
        TRAILING_STOP   // Dynamic stop that follows price up
    }
    
    /// @notice Order status
    enum OrderStatus {
        PENDING,
        EXECUTED,
        CANCELLED
    }

    // ═══════════════════════════════════════════════════════════════
    //                         STRUCTS
    // ═══════════════════════════════════════════════════════════════

    /// @notice Order configuration
    struct Order {
        uint256 orderId;
        address user;
        address tokenIn;         // Token to sell
        address tokenOut;        // Token to receive
        uint256 amount;          // Amount to swap
        uint256 triggerPrice;    // Price threshold (8 decimals)
        OrderType orderType;
        OrderStatus status;
        uint256 trailingPercent; // For trailing stop (basis points)
        uint256 highestPrice;    // Tracked high for trailing stop
        uint256 createdAt;
    }

    // ═══════════════════════════════════════════════════════════════
    //                         STATE
    // ═══════════════════════════════════════════════════════════════

    /// @notice Owner address
    address public owner;
    
    /// @notice Price oracle address
    address public priceOracle;
    
    /// @notice Swap router address on Sepolia
    address public swapRouter;
    
    /// @notice Order counter
    uint256 public nextOrderId;
    
    /// @notice All orders
    mapping(uint256 => Order) public orders;
    
    /// @notice User's order IDs
    mapping(address => uint256[]) public userOrderIds;
    
    /// @notice Token-specific orders for efficient lookup
    mapping(address => uint256[]) public tokenOrders;
    
    /// @notice Total orders executed
    uint256 public totalExecutions;
    
    /// @notice Paused state
    bool public paused;

    // ═══════════════════════════════════════════════════════════════
    //                         EVENTS
    // ═══════════════════════════════════════════════════════════════

    event OrderCreated(
        uint256 indexed orderId,
        address indexed user,
        address tokenIn,
        address tokenOut,
        uint256 amount,
        uint256 triggerPrice,
        OrderType orderType
    );
    
    event OrderExecuted(
        uint256 indexed orderId,
        address indexed user,
        uint256 executionPrice,
        uint256 amount
    );
    
    event OrderCancelled(uint256 indexed orderId, address indexed user);
    
    event TrailingStopUpdated(uint256 indexed orderId, uint256 newHighest, uint256 newTrigger);
    
    event OwnerUpdated(address indexed oldOwner, address indexed newOwner);

    // ═══════════════════════════════════════════════════════════════
    //                         ERRORS
    // ═══════════════════════════════════════════════════════════════

    error OnlyOwner();
    error ZeroAddress();
    error InvalidPrice();
    error OrderNotFound();
    error OrderAlreadyExecuted();
    error TooManyOrders();
    error OrderTooSmall();
    error Paused();

    // ═══════════════════════════════════════════════════════════════
    //                         MODIFIERS
    // ═══════════════════════════════════════════════════════════════

    modifier onlyOwner() {
        if (msg.sender != owner) revert OnlyOwner();
        _;
    }
    
    modifier whenNotPaused() {
        if (paused) revert Paused();
        _;
    }

    // ═══════════════════════════════════════════════════════════════
    //                         CONSTRUCTOR
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Initialize the stop-loss RSC
     * @param _priceOracle Price oracle address on Sepolia
     * @param _swapRouter Swap router address on Sepolia
     */
    constructor(
        address _priceOracle,
        address _swapRouter
    ) payable {
        if (_priceOracle == address(0)) revert ZeroAddress();
        if (_swapRouter == address(0)) revert ZeroAddress();
        
        owner = msg.sender;
        priceOracle = _priceOracle;
        swapRouter = _swapRouter;
        nextOrderId = 1;
    }

    // ═══════════════════════════════════════════════════════════════
    //                    SUBSCRIPTION MANAGEMENT
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Subscribe to price update events
     */
    function subscribeToPriceUpdates() external rnOnly {
        service.subscribe(
            SEPOLIA_CHAIN_ID,
            priceOracle,
            PRICE_UPDATED_TOPIC_0,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE
        );
    }
    
    /**
     * @notice Unsubscribe from price updates
     */
    function unsubscribe() external rnOnly onlyOwner {
        bytes memory payload = abi.encodeWithSignature(
            "unsubscribe(uint256,address,uint256,uint256,uint256,uint256)",
            SEPOLIA_CHAIN_ID,
            priceOracle,
            PRICE_UPDATED_TOPIC_0,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE
        );
        (bool success,) = address(service).call(payload);
        require(success, "Unsubscribe failed");
    }

    // ═══════════════════════════════════════════════════════════════
    //                    ORDER MANAGEMENT
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Create a new order
     * @param user User address
     * @param tokenIn Token to sell
     * @param tokenOut Token to receive
     * @param amount Amount to swap
     * @param triggerPrice Price threshold
     * @param orderType Type of order
     * @param trailingPercent Trailing stop percentage (0 for non-trailing)
     */
    function createOrder(
        address user,
        address tokenIn,
        address tokenOut,
        uint256 amount,
        uint256 triggerPrice,
        OrderType orderType,
        uint256 trailingPercent
    ) external onlyOwner returns (uint256 orderId) {
        if (user == address(0)) revert ZeroAddress();
        if (triggerPrice == 0) revert InvalidPrice();
        if (amount < MIN_ORDER_SIZE) revert OrderTooSmall();
        if (userOrderIds[user].length >= MAX_ORDERS_PER_USER) revert TooManyOrders();
        
        orderId = nextOrderId++;
        
        orders[orderId] = Order({
            orderId: orderId,
            user: user,
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            amount: amount,
            triggerPrice: triggerPrice,
            orderType: orderType,
            status: OrderStatus.PENDING,
            trailingPercent: trailingPercent,
            highestPrice: triggerPrice, // Initialize to trigger price
            createdAt: block.timestamp
        });
        
        userOrderIds[user].push(orderId);
        tokenOrders[tokenIn].push(orderId);
        
        emit OrderCreated(orderId, user, tokenIn, tokenOut, amount, triggerPrice, orderType);
    }
    
    /**
     * @notice Cancel an order
     * @param orderId Order ID to cancel
     */
    function cancelOrder(uint256 orderId) external onlyOwner {
        Order storage order = orders[orderId];
        if (order.orderId == 0) revert OrderNotFound();
        if (order.status != OrderStatus.PENDING) revert OrderAlreadyExecuted();
        
        order.status = OrderStatus.CANCELLED;
        
        emit OrderCancelled(orderId, order.user);
    }

    // ═══════════════════════════════════════════════════════════════
    //                    REACTIVE FUNCTION
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice React to price update events
     * @param log The log record from the event
     */
    function react(IReactive.LogRecord calldata log) external override vmOnly whenNotPaused {
        // Validate origin
        if (log.chain_id != SEPOLIA_CHAIN_ID) {
            return;
        }
        if (log._contract != priceOracle) {
            return;
        }
        
        // Decode price update
        // Expected: PriceUpdated(address indexed token, uint256 price, uint256 timestamp)
        address token = address(uint160(uint256(log.topic_1)));
        (uint256 newPrice,) = abi.decode(log.data, (uint256, uint256));
        
        // Check all orders for this token
        uint256[] storage orderIds = tokenOrders[token];
        
        for (uint256 i = 0; i < orderIds.length; i++) {
            Order storage order = orders[orderIds[i]];
            
            if (order.status != OrderStatus.PENDING) {
                continue;
            }
            
            bool shouldExecute = _checkTrigger(order, newPrice);
            
            if (shouldExecute) {
                _executeOrder(order, newPrice);
            }
        }
    }
    
    /**
     * @notice Check if order should trigger
     */
    function _checkTrigger(Order storage order, uint256 currentPrice) internal returns (bool) {
        if (order.orderType == OrderType.STOP_LOSS) {
            // Execute when price drops below trigger
            return currentPrice <= order.triggerPrice;
            
        } else if (order.orderType == OrderType.TAKE_PROFIT) {
            // Execute when price rises above trigger
            return currentPrice >= order.triggerPrice;
            
        } else {
            // TRAILING_STOP
            // Update highest price if we have a new high
            if (currentPrice > order.highestPrice) {
                order.highestPrice = currentPrice;
                
                // Recalculate trigger based on trailing percent
                uint256 newTrigger = (currentPrice * (10000 - order.trailingPercent)) / 10000;
                order.triggerPrice = newTrigger;
                
                emit TrailingStopUpdated(order.orderId, currentPrice, newTrigger);
            }
            
            // Execute when price drops below trailing trigger
            return currentPrice <= order.triggerPrice;
        }
    }
    
    /**
     * @notice Execute an order via callback
     */
    function _executeOrder(Order storage order, uint256 executionPrice) internal {
        order.status = OrderStatus.EXECUTED;
        totalExecutions++;
        
        // Emit swap callback
        bytes memory payload = abi.encodeWithSignature(
            "executeSwap(address,address,address,uint256,uint256)",
            order.user,
            order.tokenIn,
            order.tokenOut,
            order.amount,
            executionPrice
        );
        
        emit Callback(
            SEPOLIA_CHAIN_ID,
            swapRouter,
            CALLBACK_GAS_LIMIT,
            payload
        );
        
        emit OrderExecuted(order.orderId, order.user, executionPrice, order.amount);
    }

    // ═══════════════════════════════════════════════════════════════
    //                    ADMIN FUNCTIONS
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Transfer ownership
     */
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address oldOwner = owner;
        owner = newOwner;
        emit OwnerUpdated(oldOwner, newOwner);
    }
    
    /**
     * @notice Update price oracle
     */
    function setPriceOracle(address _oracle) external onlyOwner {
        if (_oracle == address(0)) revert ZeroAddress();
        priceOracle = _oracle;
    }
    
    /**
     * @notice Update swap router
     */
    function setSwapRouter(address _router) external onlyOwner {
        if (_router == address(0)) revert ZeroAddress();
        swapRouter = _router;
    }
    
    /**
     * @notice Pause order execution
     */
    function pause() external onlyOwner {
        paused = true;
    }
    
    /**
     * @notice Unpause order execution
     */
    function unpause() external onlyOwner {
        paused = false;
    }

    // ═══════════════════════════════════════════════════════════════
    //                    VIEW FUNCTIONS
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Get order details
     */
    function getOrder(uint256 orderId) external view returns (Order memory) {
        return orders[orderId];
    }
    
    /**
     * @notice Get user's orders
     */
    function getUserOrders(address user) external view returns (uint256[] memory) {
        return userOrderIds[user];
    }
    
    /**
     * @notice Get pending orders for a token
     */
    function getTokenOrders(address token) external view returns (uint256[] memory) {
        return tokenOrders[token];
    }
    
    /**
     * @notice Get stats
     */
    function getStats() external view returns (
        uint256 totalOrders,
        uint256 executed,
        bool isPaused
    ) {
        return (nextOrderId - 1, totalExecutions, paused);
    }
    
    /**
     * @notice Receive function for REACT tokens
     */
    receive() external payable override(AbstractPayer, IPayer) {}
}
