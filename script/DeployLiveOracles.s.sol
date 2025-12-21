// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";

/**
 * @title DeployLiveOracles
 * @notice Deploy live AbstractFeedProxy contracts via aggreatorv3-reactive-bridge-abstract
 * 
 * This script deploys REAL cross-chain oracle bridges for:
 * - USDT/USD from Polygon Amoy
 * - EUR/USD from Polygon Amoy (for EURS pricing)
 * 
 * Prerequisites:
 * 1. Clone aggreatorv3-reactive-bridge-abstract repository
 * 2. Set up environment variables
 * 3. Deploy using their scripts
 * 
 * Architecture:
 * Polygon Amoy (Chainlink) --> Lasna (ChainlinkMirrorReactive) --> Sepolia (AbstractFeedProxy)
 */
contract DeployLiveOracles is Script {
    
    // Polygon Amoy Chainlink Feed Addresses (LIVE)
    address constant USDT_USD_POLYGON_AMOY = 0x4D1763c3750a9dA215788f9bEE514D7085B7d46c;
    address constant EUR_USD_POLYGON_AMOY = 0xd8d927e5d52Bb7cdb2C0ae6f55ACcB18e9a2B9D7;
    
    // Chain IDs
    uint256 constant POLYGON_AMOY_CHAIN_ID = 80002;
    uint256 constant SEPOLIA_CHAIN_ID = 11155111;
    uint256 constant LASNA_CHAIN_ID = 5318007;
    
    // Reactive Network System Contracts
    address constant CALLBACK_PROXY_SEPOLIA = 0x0000000000000000000000000000000000fffFfF;
    
    function run() external view {
        console.log("============================================");
        console.log("  LIVE ORACLE DEPLOYMENT INSTRUCTIONS");
        console.log("============================================");
        console.log("");
        console.log("This script provides instructions to deploy LIVE");
        console.log("cross-chain oracle bridges using aggreatorv3-reactive-bridge-abstract");
        console.log("");
        console.log("--------------------------------------------");
        console.log("STEP 1: Clone the oracle bridge repository");
        console.log("--------------------------------------------");
        console.log("git clone https://github.com/tirth2004/aggreatorv3-reactive-bridge-abstract");
        console.log("cd aggreatorv3-reactive-bridge-abstract");
        console.log("");
        console.log("--------------------------------------------");
        console.log("STEP 2: Set environment variables");
        console.log("--------------------------------------------");
        console.log("export PRIVATE_KEY=<your-private-key>");
        console.log("export SEPOLIA_RPC=<sepolia-rpc-url>");
        console.log("export LASNA_RPC=https://kopli-rpc.reactive.network");
        console.log("");
        console.log("--------------------------------------------");
        console.log("STEP 3: Deploy USDT/USD Bridge");
        console.log("--------------------------------------------");
        console.log("Origin Chain: Polygon Amoy (80002)");
        console.log("Origin Feed:", USDT_USD_POLYGON_AMOY);
        console.log("Destination: Sepolia");
        console.log("");
        console.log("Commands:");
        console.log("1. Deploy AbstractFeedProxy on Sepolia:");
        console.log("   forge script script/DeployAbstractFeedProxy.s.sol \\");
        console.log("     --rpc-url $SEPOLIA_RPC --broadcast \\");
        console.log("     --sig 'run(address,uint8)' \\");
        console.log("     0x4D1763c3750a9dA215788f9bEE514D7085B7d46c 8");
        console.log("");
        console.log("2. Deploy ChainlinkMirrorReactive on Lasna:");
        console.log("   forge script script/DeployChainlinkMirrorReactive.s.sol \\");
        console.log("     --rpc-url $LASNA_RPC --broadcast");
        console.log("");
        console.log("--------------------------------------------");
        console.log("STEP 4: Deploy EUR/USD Bridge (for EURS)");
        console.log("--------------------------------------------");
        console.log("Origin Chain: Polygon Amoy (80002)");
        console.log("Origin Feed:", EUR_USD_POLYGON_AMOY);
        console.log("");
        console.log("Repeat same process with feed address:");
        console.log("0xd8d927e5d52Bb7cdb2C0ae6f55ACcB18e9a2B9D7");
        console.log("");
        console.log("--------------------------------------------");
        console.log("STEP 5: Integrate with UnifiedPriceOracle");
        console.log("--------------------------------------------");
        console.log("After deploying AbstractFeedProxy contracts,");
        console.log("call upgradeFeedToAbstractProxy() on UnifiedPriceOracle:");
        console.log("");
        console.log("// For USDT");
        console.log("oracle.upgradeFeedToAbstractProxy(");
        console.log("  0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0, // USDT Sepolia");
        console.log("  <deployed-usdt-abstractfeedproxy-address>");
        console.log(");");
        console.log("");
        console.log("// For EURS (using EUR/USD)");
        console.log("oracle.upgradeFeedToAbstractProxy(");
        console.log("  0x6d906e526a4e2Ca02097BA9d0caA3c382F52278E, // EURS Sepolia");
        console.log("  <deployed-eur-abstractfeedproxy-address>");
        console.log(");");
        console.log("");
        console.log("============================================");
        console.log("  CURRENT LIVE FEED STATUS");
        console.log("============================================");
        console.log("");
        console.log("Already Live (via reactive-bounty-1 MultiFeed):");
        console.log("  - WETH: ETH/USD from Base Sepolia");
        console.log("  - WBTC: BTC/USD from Base Sepolia");
        console.log("  - LINK: LINK/USD from Base Sepolia");
        console.log("");
        console.log("To Be Deployed (via aggreatorv3-bridge):");
        console.log("  - USDT: USDT/USD from Polygon Amoy");
        console.log("  - EURS: EUR/USD from Polygon Amoy");
        console.log("");
        console.log("No Testnet Feed Available:");
        console.log("  - AAVE: Uses fallback (mainnet has live feed)");
        console.log("");
    }
}
