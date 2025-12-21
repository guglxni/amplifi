// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {UnifiedPriceOracle} from "../src/UnifiedPriceOracle.sol";

/**
 * @title DeployUnifiedOracle
 * @notice Deploys the Unified Cross-Chain Oracle
 * 
 * This oracle combines:
 * 1. reactive-bounty-1 (MultiFeedDestinationV2) - Pre-deployed feeds
 * 2. aggreatorv3-reactive-bridge-abstract (AbstractFeedProxy) - Extensible feeds
 */
contract DeployUnifiedOracle is Script {
    
    // reactive-bounty-1 MultiFeedDestination on Sepolia
    address constant MULTI_FEED_ORACLE = 0x889c32f46E273fBd0d5B1806F3f1286010cD73B3;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("SEPOLIA_PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("============================================");
        console.log("  DEPLOYING UNIFIED CROSS-CHAIN ORACLE");
        console.log("============================================");
        console.log("");
        console.log("Combining two Reactive Oracle sources:");
        console.log("");
        console.log("Source 1: reactive-bounty-1 (MultiFeed)");
        console.log("  Contract: 0x889c32f46E273fBd0d5B1806F3f1286010cD73B3");
        console.log("  Feeds: ETH/USD, BTC/USD, LINK/USD");
        console.log("  Origin: Base Sepolia -> Sepolia");
        console.log("");
        console.log("Source 2: aggreatorv3-reactive-bridge-abstract");
        console.log("  Type: Per-feed AbstractFeedProxy contracts");
        console.log("  Origins: Base Sepolia, BSC, Polygon, Avalanche");
        console.log("  Flexibility: Add ANY Chainlink feed dynamically");
        console.log("");
        
        UnifiedPriceOracle oracle = new UnifiedPriceOracle(MULTI_FEED_ORACLE);
        
        console.log("UnifiedPriceOracle deployed at:", address(oracle));
        console.log("");
        console.log("Pre-configured Live Feeds:");
        console.log("  WETH  -> ETH/USD (MultiFeed)");
        console.log("  WBTC  -> BTC/USD (MultiFeed)");
        console.log("  LINK  -> LINK/USD (MultiFeed)");
        console.log("");
        console.log("Pre-configured Fallback Feeds:");
        console.log("  USDT  -> $1.00 (stablecoin)");
        console.log("  EURS  -> $1.05 (euro stablecoin)");
        console.log("  AAVE  -> $150 (fallback)");
        console.log("");
        console.log("============================================");
        console.log("  DEPLOYMENT COMPLETE");
        console.log("============================================");
        console.log("");
        console.log("To add new AbstractFeedProxy feeds, call:");
        console.log("  oracle.addAbstractProxyFeed(token, symbol, proxyAddress, fallbackPrice)");
        console.log("");
        
        vm.stopBroadcast();
    }
}
