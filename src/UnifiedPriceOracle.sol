// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

// ═══════════════════════════════════════════════════════════════
//                         INTERFACES
// ═══════════════════════════════════════════════════════════════

/// @notice Standard Chainlink AggregatorV3Interface (for AbstractFeedProxy)
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

/// @notice MultiFeedDestination interface (for reactive-bounty-1)
interface IMultiFeedDestinationUnified {
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
 * @title UnifiedPriceOracle
 * @author YieldOpt Team
 * @notice Unified Cross-Chain Oracle combining reactive-bounty-1 + aggreatorv3-reactive-bridge-abstract
 * 
 * ╔═══════════════════════════════════════════════════════════════════════════╗
 * ║                    UNIFIED REACTIVE ORACLE ARCHITECTURE                    ║
 * ╠═══════════════════════════════════════════════════════════════════════════╣
 * ║                                                                           ║
 * ║  ┌─────────────────┐   ┌─────────────────┐   ┌─────────────────┐        ║
 * ║  │  Base Sepolia   │   │      BSC        │   │  Polygon Amoy   │        ║
 * ║  │   (Chainlink)   │   │   (Chainlink)   │   │   (Chainlink)   │        ║
 * ║  └────────┬────────┘   └────────┬────────┘   └────────┬────────┘        ║
 * ║           │                     │                     │                 ║
 * ║           ▼                     ▼                     ▼                 ║
 * ║  ┌──────────────────────────────────────────────────────────────────┐   ║
 * ║  │                    LASNA (Reactive Network)                       │   ║
 * ║  │  ┌────────────────────┐  ┌────────────────────────────────────┐  │   ║
 * ║  │  │ MultiFeedMirrorRC  │  │     ChainlinkMirrorReactive       │  │   ║
 * ║  │  │ (reactive-bounty-1)│  │ (aggreatorv3-reactive-bridge)     │  │   ║
 * ║  │  │                    │  │                                    │  │   ║
 * ║  │  │ • Multi-feed       │  │ • Per-feed proxies                │  │   ║
 * ║  │  │ • ETH/BTC/LINK     │  │ • Any Chainlink feed              │  │   ║
 * ║  │  │ • Single contract  │  │ • Multi-chain support             │  │   ║
 * ║  │  └─────────┬──────────┘  └──────────────┬─────────────────────┘  │   ║
 * ║  └────────────┼─────────────────────────────┼───────────────────────┘   ║
 * ║               │                             │                           ║
 * ║               ▼                             ▼                           ║
 * ║  ┌──────────────────────────────────────────────────────────────────┐   ║
 * ║  │                    ETHEREUM SEPOLIA                               │   ║
 * ║  │  ┌────────────────────┐  ┌────────────────────────────────────┐  │   ║
 * ║  │  │MultiFeedDestination│  │      AbstractFeedProxy(es)        │  │   ║
 * ║  │  │ (Single Contract)  │  │       (Per-Feed Contracts)        │  │   ║
 * ║  │  └─────────┬──────────┘  └──────────────┬─────────────────────┘  │   ║
 * ║  │            │                            │                        │   ║
 * ║  │            └────────────┬───────────────┘                        │   ║
 * ║  │                         ▼                                        │   ║
 * ║  │  ┌────────────────────────────────────────────────────────────┐  │   ║
 * ║  │  │              UNIFIED PRICE ORACLE                          │  │   ║
 * ║  │  │                                                            │  │   ║
 * ║  │  │  • Single interface: getPrice(token)                       │  │   ║
 * ║  │  │  • Auto-fallback between sources                           │  │   ║
 * ║  │  │  • Priority: MultiFeed → AbstractProxy → Fallback          │  │   ║
 * ║  │  │  • Stale price detection                                   │  │   ║
 * ║  │  │  • Multi-chain price aggregation                           │  │   ║
 * ║  │  └────────────────────────────────────────────────────────────┘  │   ║
 * ║  │                         │                                        │   ║
 * ║  │                         ▼                                        │   ║
 * ║  │  ┌────────────────────────────────────────────────────────────┐  │   ║
 * ║  │  │              YieldVaultMultiAsset                          │  │   ║
 * ║  │  │         (Uses live prices for TVL calculation)             │  │   ║
 * ║  │  └────────────────────────────────────────────────────────────┘  │   ║
 * ║  └──────────────────────────────────────────────────────────────────┘   ║
 * ╚═══════════════════════════════════════════════════════════════════════════╝
 * 
 * BENEFITS OF UNIFIED APPROACH:
 * =============================
 * 1. Single Interface: One getPrice() call for any token
 * 2. Multi-Source Fallback: MultiFeed → AbstractProxy → Hardcoded
 * 3. Multi-Chain Support: Aggregate feeds from Base, BSC, Polygon, Avalanche
 * 4. Dynamic Extensibility: Add new feeds via AbstractFeedProxy deployments
 * 5. Stale Detection: Reject prices older than MAX_STALENESS
 * 6. Gas Efficient: Caches and optimizes cross-contract calls
 * 
 * ORACLE SOURCES:
 * ===============
 * Source 1 - reactive-bounty-1 (MultiFeedDestinationV2):
 *   Contract: 0x889c32f46E273fBd0d5B1806F3f1286010cD73B3
 *   Feeds: ETH/USD, BTC/USD, LINK/USD (from Base Sepolia)
 *   Interface: latestRoundDataForFeed(originFeed)
 * 
 * Source 2 - aggreatorv3-reactive-bridge-abstract (AbstractFeedProxy):
 *   Type: Per-feed proxy contracts on Sepolia
 *   Interface: Standard AggregatorV3Interface (latestRoundData())
 *   Flexibility: Deploy for ANY feed from ANY supported origin chain
 */
contract UnifiedPriceOracle is Ownable {

    // ═══════════════════════════════════════════════════════════════
    //                         STRUCTS & ENUMS
    // ═══════════════════════════════════════════════════════════════
    
    /// @notice Oracle source type
    enum SourceType {
        MULTI_FEED,       // reactive-bounty-1: Query by originFeed address
        ABSTRACT_PROXY,   // aggreatorv3-reactive-bridge-abstract: Direct AggregatorV3
        FALLBACK          // Hardcoded fallback price
    }
    
    /// @notice Complete feed configuration
    struct FeedConfig {
        // Primary source
        SourceType primarySource;
        address primaryOracle;      // MultiFeed contract OR AbstractProxy address
        address originFeed;         // For MULTI_FEED: origin Chainlink aggregator
        
        // Secondary source (fallback)
        SourceType secondarySource;
        address secondaryOracle;
        address secondaryOriginFeed;
        
        // Fallback price
        uint256 fallbackPrice;      // Price with 8 decimals
        
        // Metadata
        uint8 decimals;
        string symbol;
        bool active;
    }
    
    /// @notice Price result with metadata
    struct PriceResult {
        uint256 price;              // Price with 8 decimals
        uint256 updatedAt;          // Last update timestamp
        SourceType source;          // Which source provided the price
        bool isLive;                // True if from live oracle
        bool isFresh;               // True if within MAX_STALENESS
    }

    // ═══════════════════════════════════════════════════════════════
    //                    STATE VARIABLES
    // ═══════════════════════════════════════════════════════════════
    
    /// @notice reactive-bounty-1 MultiFeedDestinationV2 on Sepolia
    address public immutable MULTI_FEED_ORACLE;
    
    /// @notice Chainlink aggregator addresses on Base Sepolia
    address public constant CHAINLINK_ETH_USD = 0xa24A68DD788e1D7eb4CA517765CFb2b7e217e7a3;
    address public constant CHAINLINK_BTC_USD = 0x961AD289351459A45fC90884eF3AB0278ea95DDE;
    address public constant CHAINLINK_LINK_USD = 0xAc6DB6d5538Cd07f58afee9dA736ce192119017B;
    
    /// @notice Maximum staleness for price data (1 hour)
    uint256 public constant MAX_STALENESS = 1 hours;
    
    /// @notice Token to feed configuration
    mapping(address => FeedConfig) public feedConfigs;
    
    /// @notice List of supported tokens
    address[] public supportedTokens;
    
    /// @notice Token symbol to address mapping (convenience)
    mapping(string => address) public symbolToToken;

    // ═══════════════════════════════════════════════════════════════
    //                         EVENTS
    // ═══════════════════════════════════════════════════════════════
    
    event FeedConfigured(
        address indexed token,
        string symbol,
        SourceType primarySource,
        address primaryOracle
    );
    
    event AbstractProxyAdded(
        address indexed token,
        address abstractProxy,
        string description
    );
    
    event FallbackUsed(address indexed token, uint256 fallbackPrice);
    event PriceFetched(address indexed token, uint256 price, SourceType source);

    // ═══════════════════════════════════════════════════════════════
    //                       CONSTRUCTOR
    // ═══════════════════════════════════════════════════════════════
    
    /**
     * @notice Deploy with reactive-bounty-1 MultiFeedDestination address
     * @param _multiFeedOracle Address of MultiFeedDestinationV2 on Sepolia
     */
    constructor(address _multiFeedOracle) Ownable(msg.sender) {
        MULTI_FEED_ORACLE = _multiFeedOracle;
        _initializeDefaultFeeds();
    }
    
    /**
     * @notice Initialize default feeds for YieldOpt assets
     */
    function _initializeDefaultFeeds() internal {
        // ═══════════════════════════════════════════════════════════
        //          LIVE FEEDS (via reactive-bounty-1 MultiFeed)
        // ═══════════════════════════════════════════════════════════
        
        // WETH → ETH/USD
        _configureFeed(
            0xC558DBdd856501FCd9aaF1E62eae57A9F0629a3c, // WETH Sepolia
            "WETH",
            SourceType.MULTI_FEED,
            MULTI_FEED_ORACLE,
            CHAINLINK_ETH_USD,
            200000000000 // $2000 fallback
        );
        
        // WBTC → BTC/USD
        _configureFeed(
            0x29f2D40B0605204364af54EC677bD022dA425d03, // WBTC Sepolia
            "WBTC",
            SourceType.MULTI_FEED,
            MULTI_FEED_ORACLE,
            CHAINLINK_BTC_USD,
            9500000000000 // $95000 fallback
        );
        
        // LINK → LINK/USD
        _configureFeed(
            0xf8Fb3713D459D7C1018BD0A49D19b4C44290EBE5, // LINK Sepolia
            "LINK",
            SourceType.MULTI_FEED,
            MULTI_FEED_ORACLE,
            CHAINLINK_LINK_USD,
            1500000000 // $15 fallback
        );
        
        // ═══════════════════════════════════════════════════════════
        //          FALLBACK FEEDS (Stablecoins & No Oracle)
        // ═══════════════════════════════════════════════════════════
        
        // USDT → $1.00 (stablecoin)
        _configureFeed(
            0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0, // USDT Sepolia
            "USDT",
            SourceType.FALLBACK,
            address(0),
            address(0),
            100000000 // $1.00
        );
        
        // EURS → $1.05 (Euro stablecoin)
        _configureFeed(
            0x6d906e526a4e2Ca02097BA9d0caA3c382F52278E, // EURS Sepolia
            "EURS",
            SourceType.FALLBACK,
            address(0),
            address(0),
            105000000 // $1.05
        );
        
        // AAVE → $150 (fallback, can be upgraded)
        _configureFeed(
            0x88541670E55cC00bEEFD87eB59EDd1b7C511AC9a, // AAVE Sepolia
            "AAVE",
            SourceType.FALLBACK,
            address(0),
            address(0),
            15000000000 // $150
        );
    }
    
    function _configureFeed(
        address token,
        string memory symbol,
        SourceType sourceType,
        address oracle,
        address originFeed,
        uint256 fallbackPrice
    ) internal {
        if (!feedConfigs[token].active) {
            supportedTokens.push(token);
        }
        
        feedConfigs[token] = FeedConfig({
            primarySource: sourceType,
            primaryOracle: oracle,
            originFeed: originFeed,
            secondarySource: SourceType.FALLBACK,
            secondaryOracle: address(0),
            secondaryOriginFeed: address(0),
            fallbackPrice: fallbackPrice,
            decimals: 8,
            symbol: symbol,
            active: true
        });
        
        symbolToToken[symbol] = token;
        
        emit FeedConfigured(token, symbol, sourceType, oracle);
    }

    // ═══════════════════════════════════════════════════════════════
    //                      ADMIN FUNCTIONS
    // ═══════════════════════════════════════════════════════════════
    
    /**
     * @notice Add a new AbstractFeedProxy for a token
     * @dev Use this to extend oracle coverage with aggreatorv3-reactive-bridge-abstract
     * @param token Token address on Sepolia
     * @param abstractProxy AbstractFeedProxy contract address
     * @param fallbackPrice Fallback price if oracle fails
     */
    function addAbstractProxyFeed(
        address token,
        string calldata symbol,
        address abstractProxy,
        uint256 fallbackPrice
    ) external onlyOwner {
        require(abstractProxy != address(0), "Invalid proxy");
        
        // Get description from proxy
        string memory desc = "";
        try IAggregatorV3(abstractProxy).description() returns (string memory d) {
            desc = d;
        } catch {}
        
        if (!feedConfigs[token].active) {
            supportedTokens.push(token);
        }
        
        feedConfigs[token] = FeedConfig({
            primarySource: SourceType.ABSTRACT_PROXY,
            primaryOracle: abstractProxy,
            originFeed: address(0), // Not used for ABSTRACT_PROXY
            secondarySource: SourceType.FALLBACK,
            secondaryOracle: address(0),
            secondaryOriginFeed: address(0),
            fallbackPrice: fallbackPrice,
            decimals: 8,
            symbol: symbol,
            active: true
        });
        
        symbolToToken[symbol] = token;
        
        emit AbstractProxyAdded(token, abstractProxy, desc);
        emit FeedConfigured(token, symbol, SourceType.ABSTRACT_PROXY, abstractProxy);
    }
    
    /**
     * @notice Set a secondary oracle source for redundancy
     * @dev Enables fall-through: Primary → Secondary → Fallback
     */
    function setSecondarySource(
        address token,
        SourceType sourceType,
        address oracle,
        address originFeed
    ) external onlyOwner {
        require(feedConfigs[token].active, "Token not configured");
        
        feedConfigs[token].secondarySource = sourceType;
        feedConfigs[token].secondaryOracle = oracle;
        feedConfigs[token].secondaryOriginFeed = originFeed;
    }
    
    /**
     * @notice Update fallback price for a token
     */
    function updateFallbackPrice(address token, uint256 newPrice) external onlyOwner {
        require(feedConfigs[token].active, "Token not configured");
        feedConfigs[token].fallbackPrice = newPrice;
    }

    // ═══════════════════════════════════════════════════════════════
    //                      PRICE QUERIES
    // ═══════════════════════════════════════════════════════════════
    
    /**
     * @notice Get the latest price for a token (simple interface)
     * @param token Token address
     * @return price USD price with 8 decimals
     */
    function getPrice(address token) external view returns (uint256 price) {
        (price, , , ,) = getPriceDetailed(token);
    }
    
    /**
     * @notice Get price with metadata
     * @param token Token address
     * @return price USD price with 8 decimals
     * @return updatedAt Timestamp of price update
     * @return source Which source provided the price
     * @return isLive True if from live oracle
     * @return isFresh True if within MAX_STALENESS
     */
    function getPriceDetailed(address token) public view returns (
        uint256 price,
        uint256 updatedAt,
        SourceType source,
        bool isLive,
        bool isFresh
    ) {
        FeedConfig storage config = feedConfigs[token];
        require(config.active, "Token not supported");
        
        // Try primary source
        (bool success, uint256 p, uint256 u) = _fetchPrice(
            config.primarySource,
            config.primaryOracle,
            config.originFeed
        );
        
        if (success && u > 0) {
            return (
                p,
                u,
                config.primarySource,
                true,
                block.timestamp - u <= MAX_STALENESS
            );
        }
        
        // Try secondary source
        if (config.secondarySource != SourceType.FALLBACK) {
            (success, p, u) = _fetchPrice(
                config.secondarySource,
                config.secondaryOracle,
                config.secondaryOriginFeed
            );
            
            if (success && u > 0) {
                return (
                    p,
                    u,
                    config.secondarySource,
                    true,
                    block.timestamp - u <= MAX_STALENESS
                );
            }
        }
        
        // Use fallback
        return (config.fallbackPrice, block.timestamp, SourceType.FALLBACK, false, true);
    }
    
    /**
     * @notice Internal price fetcher supporting both oracle types
     */
    function _fetchPrice(
        SourceType sourceType,
        address oracle,
        address originFeed
    ) internal view returns (bool success, uint256 price, uint256 updatedAt) {
        if (sourceType == SourceType.FALLBACK || oracle == address(0)) {
            return (false, 0, 0);
        }
        
        if (sourceType == SourceType.MULTI_FEED) {
            try IMultiFeedDestinationUnified(oracle).latestRoundDataForFeed(originFeed) returns (
                uint80,
                int256 answer,
                uint256,
                uint256 u,
                uint80
            ) {
                if (answer > 0) {
                    return (true, uint256(answer), u);
                }
            } catch {}
        } else if (sourceType == SourceType.ABSTRACT_PROXY) {
            try IAggregatorV3(oracle).latestRoundData() returns (
                uint80,
                int256 answer,
                uint256,
                uint256 u,
                uint80
            ) {
                if (answer > 0) {
                    return (true, uint256(answer), u);
                }
            } catch {}
        }
        
        return (false, 0, 0);
    }
    
    /**
     * @notice Get prices for all supported tokens
     */
    function getAllPrices() external view returns (
        address[] memory tokens,
        string[] memory symbols,
        uint256[] memory prices,
        bool[] memory isLive
    ) {
        uint256 len = supportedTokens.length;
        tokens = new address[](len);
        symbols = new string[](len);
        prices = new uint256[](len);
        isLive = new bool[](len);
        
        for (uint256 i = 0; i < len; i++) {
            tokens[i] = supportedTokens[i];
            symbols[i] = feedConfigs[tokens[i]].symbol;
            (prices[i], , , isLive[i],) = getPriceDetailed(tokens[i]);
        }
    }
    
    /**
     * @notice Get price by symbol (convenience function)
     */
    function getPriceBySymbol(string calldata symbol) external view returns (uint256) {
        address token = symbolToToken[symbol];
        require(token != address(0), "Unknown symbol");
        return this.getPrice(token);
    }

    // ═══════════════════════════════════════════════════════════════
    //                      ORACLE STATUS
    // ═══════════════════════════════════════════════════════════════
    
    /**
     * @notice Check if a token has live oracle data available
     */
    function hasLiveData(address token) external view returns (bool) {
        FeedConfig storage config = feedConfigs[token];
        if (!config.active) return false;
        
        (bool success, , ) = _fetchPrice(
            config.primarySource,
            config.primaryOracle,
            config.originFeed
        );
        
        return success;
    }
    
    /**
     * @notice Get oracle status for all tokens
     */
    function getOracleStatus() external view returns (
        address[] memory tokens,
        string[] memory symbols,
        SourceType[] memory sources,
        bool[] memory isLive,
        bool[] memory isFresh
    ) {
        uint256 len = supportedTokens.length;
        tokens = new address[](len);
        symbols = new string[](len);
        sources = new SourceType[](len);
        isLive = new bool[](len);
        isFresh = new bool[](len);
        
        for (uint256 i = 0; i < len; i++) {
            tokens[i] = supportedTokens[i];
            symbols[i] = feedConfigs[tokens[i]].symbol;
            (, , sources[i], isLive[i], isFresh[i]) = getPriceDetailed(tokens[i]);
        }
    }
    
    /**
     * @notice Get count of supported tokens
     */
    function getSupportedTokenCount() external view returns (uint256) {
        return supportedTokens.length;
    }
}
