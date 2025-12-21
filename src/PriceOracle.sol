// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title IAggregatorV3
 * @notice Standard Chainlink AggregatorV3Interface
 * @dev Compatible with both reactive-bounty-1 MultiFeedDestination and 
 *      aggreatorv3-reactive-bridge-abstract AbstractFeedProxy
 */
interface IAggregatorV3 {
    function latestRoundData() external view returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    );
    
    function decimals() external view returns (uint8);
    function description() external view returns (string memory);
}

/**
 * @title IMultiFeedDestination
 * @notice Interface specific to reactive-bounty-1's MultiFeedDestinationV2
 * @dev Allows querying prices by origin feed address
 */
interface IMultiFeedDestination {
    function latestRoundDataForFeed(address originFeed) external view returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    );
    
    function hasFeedData(address originFeed) external view returns (bool);
}

/**
 * @title PriceOracle
 * @notice Aggregates price feeds from multiple Reactive Cross-Chain Oracle sources
 * @dev Supports both:
 *      - reactive-bounty-1: MultiFeedDestinationV2 (multi-feed contract)
 *      - aggreatorv3-reactive-bridge-abstract: AbstractFeedProxy (per-feed contracts)
 * 
 * Oracle Sources:
 * ===============
 * 1. reactive-bounty-1 (MultiFeedDestinationV2)
 *    - Contract: 0x889c32f46E273fBd0d5B1806F3f1286010cD73B3 (Sepolia)
 *    - Feeds: ETH/USD, BTC/USD, LINK/USD (mirrored from Base Sepolia)
 *    - Query: latestRoundDataForFeed(originFeedAddress)
 * 
 * 2. aggreatorv3-reactive-bridge-abstract (AbstractFeedProxy)
 *    - Deploy per-feed proxies for any Chainlink feed
 *    - Supports: Base Sepolia, BSC, Avalanche Fuji, Polygon Amoy → Sepolia
 *    - Query: Standard latestRoundData() per deployed proxy
 * 
 * Asset Price Mapping:
 * ====================
 * - WETH  → ETH/USD feed
 * - WBTC  → BTC/USD feed  
 * - LINK  → LINK/USD feed
 * - USDT  → Fallback to $1.00 (stablecoin)
 * - EURS  → Fallback to $1.05 (euro stablecoin)
 * - AAVE  → Fallback or custom feed
 */
contract PriceOracle is Ownable {
    
    // ═══════════════════════════════════════════════════════════════
    //                         STRUCTS
    // ═══════════════════════════════════════════════════════════════
    
    enum OracleType {
        MULTI_FEED,      // reactive-bounty-1 style (query by origin feed)
        SINGLE_FEED,     // AbstractFeedProxy style (direct latestRoundData)
        FALLBACK         // Hardcoded fallback price
    }
    
    struct PriceFeed {
        OracleType oracleType;
        address oracleContract;    // MultiFeedDestination or AbstractFeedProxy
        address originFeed;        // For MULTI_FEED: the origin Chainlink aggregator
        uint256 fallbackPrice;     // For FALLBACK: price with 8 decimals
        uint256 lastUpdate;        // Timestamp of last successful fetch
        bool active;
    }
    
    // ═══════════════════════════════════════════════════════════════
    //                    STATE VARIABLES
    // ═══════════════════════════════════════════════════════════════
    
    /// @notice reactive-bounty-1 MultiFeedDestinationV2 on Sepolia
    address public constant MULTI_FEED_ORACLE = 0x889c32f46E273fBd0d5B1806F3f1286010cD73B3;
    
    /// @notice Chainlink aggregator addresses on Base Sepolia (for MULTI_FEED queries)
    address public constant CHAINLINK_ETH_USD = 0xa24A68DD788e1D7eb4CA517765CFb2b7e217e7a3;
    address public constant CHAINLINK_BTC_USD = 0x961AD289351459A45fC90884eF3AB0278ea95DDE;
    address public constant CHAINLINK_LINK_USD = 0xAc6DB6d5538Cd07f58afee9dA736ce192119017B;
    
    /// @notice Mapping from token address to price feed configuration
    mapping(address => PriceFeed) public priceFeeds;
    
    /// @notice List of supported tokens
    address[] public supportedTokens;
    
    /// @notice Maximum staleness for price data (1 hour)
    uint256 public constant MAX_STALENESS = 1 hours;
    
    // ═══════════════════════════════════════════════════════════════
    //                         EVENTS
    // ═══════════════════════════════════════════════════════════════
    
    event PriceFeedSet(address indexed token, OracleType oracleType, address oracleContract);
    event PriceUpdated(address indexed token, uint256 price, uint256 timestamp);
    event FallbackUsed(address indexed token, uint256 fallbackPrice);
    
    // ═══════════════════════════════════════════════════════════════
    //                       CONSTRUCTOR
    // ═══════════════════════════════════════════════════════════════
    
    constructor() Ownable(msg.sender) {
        // Pre-configure feeds for YieldOpt assets
        _initializeDefaultFeeds();
    }
    
    function _initializeDefaultFeeds() internal {
        // WETH → ETH/USD via reactive-bounty-1
        _setPriceFeed(
            0xC558DBdd856501FCd9aaF1E62eae57A9F0629a3c, // WETH on Sepolia
            OracleType.MULTI_FEED,
            MULTI_FEED_ORACLE,
            CHAINLINK_ETH_USD,
            0 // No fallback needed
        );
        
        // WBTC → BTC/USD via reactive-bounty-1
        _setPriceFeed(
            0x29f2D40B0605204364af54EC677bD022dA425d03, // WBTC on Sepolia
            OracleType.MULTI_FEED,
            MULTI_FEED_ORACLE,
            CHAINLINK_BTC_USD,
            0
        );
        
        // LINK → LINK/USD via reactive-bounty-1
        _setPriceFeed(
            0xf8Fb3713D459D7C1018BD0A49D19b4C44290EBE5, // LINK on Sepolia
            OracleType.MULTI_FEED,
            MULTI_FEED_ORACLE,
            CHAINLINK_LINK_USD,
            0
        );
        
        // USDT → Fallback $1.00 (stablecoin)
        _setPriceFeed(
            0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0, // USDT on Sepolia
            OracleType.FALLBACK,
            address(0),
            address(0),
            100000000 // $1.00 with 8 decimals
        );
        
        // EURS → Fallback $1.05 (Euro stablecoin)
        _setPriceFeed(
            0x6d906e526a4e2Ca02097BA9d0caA3c382F52278E, // EURS on Sepolia
            OracleType.FALLBACK,
            address(0),
            address(0),
            105000000 // $1.05 with 8 decimals
        );
        
        // AAVE → Fallback $150 (can be upgraded to live feed later)
        _setPriceFeed(
            0x88541670E55cC00bEEFD87eB59EDd1b7C511AC9a, // AAVE on Sepolia
            OracleType.FALLBACK,
            address(0),
            address(0),
            15000000000 // $150 with 8 decimals
        );
    }
    
    // ═══════════════════════════════════════════════════════════════
    //                      ADMIN FUNCTIONS
    // ═══════════════════════════════════════════════════════════════
    
    /**
     * @notice Set a price feed for a token using MULTI_FEED oracle (reactive-bounty-1)
     */
    function setMultiFeedOracle(
        address token,
        address originFeed
    ) external onlyOwner {
        _setPriceFeed(token, OracleType.MULTI_FEED, MULTI_FEED_ORACLE, originFeed, 0);
    }
    
    /**
     * @notice Set a price feed for a token using SINGLE_FEED oracle (AbstractFeedProxy)
     */
    function setSingleFeedOracle(
        address token,
        address abstractFeedProxy
    ) external onlyOwner {
        _setPriceFeed(token, OracleType.SINGLE_FEED, abstractFeedProxy, address(0), 0);
    }
    
    /**
     * @notice Set a fallback price for a token
     */
    function setFallbackPrice(
        address token,
        uint256 priceUsd8Decimals
    ) external onlyOwner {
        _setPriceFeed(token, OracleType.FALLBACK, address(0), address(0), priceUsd8Decimals);
    }
    
    function _setPriceFeed(
        address token,
        OracleType oracleType,
        address oracleContract,
        address originFeed,
        uint256 fallbackPrice
    ) internal {
        if (!priceFeeds[token].active) {
            supportedTokens.push(token);
        }
        
        priceFeeds[token] = PriceFeed({
            oracleType: oracleType,
            oracleContract: oracleContract,
            originFeed: originFeed,
            fallbackPrice: fallbackPrice,
            lastUpdate: block.timestamp,
            active: true
        });
        
        emit PriceFeedSet(token, oracleType, oracleContract);
    }
    
    // ═══════════════════════════════════════════════════════════════
    //                      VIEW FUNCTIONS
    // ═══════════════════════════════════════════════════════════════
    
    /**
     * @notice Get the latest USD price for a token
     * @param token The token address
     * @return price USD price with 8 decimals
     * @return updatedAt Timestamp of the price update
     * @return isLive True if from live oracle, false if fallback
     */
    function getPrice(address token) external view returns (
        uint256 price,
        uint256 updatedAt,
        bool isLive
    ) {
        PriceFeed storage feed = priceFeeds[token];
        require(feed.active, "Token not supported");
        
        if (feed.oracleType == OracleType.MULTI_FEED) {
            return _getMultiFeedPrice(feed);
        } else if (feed.oracleType == OracleType.SINGLE_FEED) {
            return _getSingleFeedPrice(feed);
        } else {
            return (feed.fallbackPrice, block.timestamp, false);
        }
    }
    
    function _getMultiFeedPrice(PriceFeed storage feed) internal view returns (
        uint256 price,
        uint256 updatedAt,
        bool isLive
    ) {
        try IMultiFeedDestination(feed.oracleContract).latestRoundDataForFeed(feed.originFeed) returns (
            uint80,
            int256 answer,
            uint256,
            uint256 _updatedAt,
            uint80
        ) {
            if (answer > 0 && _updatedAt > 0) {
                return (uint256(answer), _updatedAt, true);
            }
        } catch {}
        
        // Fallback
        return (feed.fallbackPrice, block.timestamp, false);
    }
    
    function _getSingleFeedPrice(PriceFeed storage feed) internal view returns (
        uint256 price,
        uint256 updatedAt,
        bool isLive
    ) {
        try IAggregatorV3(feed.oracleContract).latestRoundData() returns (
            uint80,
            int256 answer,
            uint256,
            uint256 _updatedAt,
            uint80
        ) {
            if (answer > 0 && _updatedAt > 0) {
                return (uint256(answer), _updatedAt, true);
            }
        } catch {}
        
        // Fallback
        return (feed.fallbackPrice, block.timestamp, false);
    }
    
    /**
     * @notice Get prices for all supported tokens
     * @return tokens Array of token addresses
     * @return prices Array of USD prices (8 decimals)
     * @return isLive Array indicating if price is live or fallback
     */
    function getAllPrices() external view returns (
        address[] memory tokens,
        uint256[] memory prices,
        bool[] memory isLive
    ) {
        uint256 len = supportedTokens.length;
        tokens = new address[](len);
        prices = new uint256[](len);
        isLive = new bool[](len);
        
        for (uint256 i = 0; i < len; i++) {
            tokens[i] = supportedTokens[i];
            (prices[i], , isLive[i]) = this.getPrice(supportedTokens[i]);
        }
    }
    
    /**
     * @notice Check if a token has live oracle data
     */
    function hasLivePrice(address token) external view returns (bool) {
        PriceFeed storage feed = priceFeeds[token];
        if (!feed.active) return false;
        
        if (feed.oracleType == OracleType.MULTI_FEED) {
            try IMultiFeedDestination(feed.oracleContract).hasFeedData(feed.originFeed) returns (bool has) {
                return has;
            } catch {
                return false;
            }
        } else if (feed.oracleType == OracleType.SINGLE_FEED) {
            try IAggregatorV3(feed.oracleContract).latestRoundData() returns (
                uint80, int256 answer, uint256, uint256, uint80
            ) {
                return answer > 0;
            } catch {
                return false;
            }
        }
        
        return false; // Fallback is not "live"
    }
    
    /**
     * @notice Get count of supported tokens
     */
    function getSupportedTokenCount() external view returns (uint256) {
        return supportedTokens.length;
    }
}
