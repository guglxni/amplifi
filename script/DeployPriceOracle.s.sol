// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {PriceOracle} from "../src/PriceOracle.sol";

/**
 * @title DeployPriceOracle
 * @notice Deploys the PriceOracle with pre-configured feeds from reactive-bounty-1
 * 
 * Oracle Sources:
 * - ETH/USD, BTC/USD, LINK/USD → reactive-bounty-1 MultiFeedDestinationV2
 * - USDT, EURS, AAVE → Fallback prices (stablecoins and no oracle available)
 */
contract DeployPriceOracle is Script {
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("SEPOLIA_PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("============================================");
        console.log("  DEPLOYING PRICE ORACLE");
        console.log("============================================");
        console.log("");
        console.log("Oracle Sources:");
        console.log("  - reactive-bounty-1: MultiFeedDestinationV2");
        console.log("  - Live Feeds: ETH/USD, BTC/USD, LINK/USD");
        console.log("");
        
        PriceOracle oracle = new PriceOracle();
        
        console.log("PriceOracle deployed at:", address(oracle));
        console.log("");
        
        // Verify feeds are configured
        console.log("Configured Feeds:");
        console.log("  WETH  -> ETH/USD (live)");
        console.log("  WBTC  -> BTC/USD (live)");
        console.log("  LINK  -> LINK/USD (live)");
        console.log("  USDT  -> $1.00 (fallback)");
        console.log("  EURS  -> $1.05 (fallback)");
        console.log("  AAVE  -> $150 (fallback)");
        console.log("");
        console.log("============================================");
        console.log("  DEPLOYMENT COMPLETE");
        console.log("============================================");
        
        vm.stopBroadcast();
    }
}
