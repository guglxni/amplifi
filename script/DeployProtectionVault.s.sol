// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {ProtectionVault} from "../src/ProtectionVault.sol";

/**
 * @title DeployProtectionVault
 * @notice Deployment script for the Protection Vault on Sepolia
 * 
 * Usage:
 * forge script script/DeployProtectionVault.s.sol --rpc-url $SEPOLIA_RPC --broadcast
 */
contract DeployProtectionVault is Script {
    // Sepolia Aave V3 Pool
    address constant AAVE_POOL = 0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951;
    
    // Callback Proxy on Sepolia (from Reactive Network)
    address constant CALLBACK_PROXY = 0x33Bbb7D0a2F1029550B0e91f653c4055DC9F4Dd8;
    
    // Token addresses (Sepolia)
    address constant WETH = 0xC558DBdd856501FCd9aaF1E62eae57A9F0629a3c;
    address constant USDC = 0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        console2.log("=== Deploying Protection Vault ===");
        console2.log("Aave Pool:", AAVE_POOL);
        console2.log("Callback Proxy:", CALLBACK_PROXY);
        console2.log("Collateral (WETH):", WETH);
        console2.log("Debt (USDC):", USDC);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy with initial ETH for callback fees
        ProtectionVault vault = new ProtectionVault{value: 0.1 ether}(
            AAVE_POOL,
            CALLBACK_PROXY,
            WETH,
            USDC
        );
        
        console2.log("ProtectionVault deployed at:", address(vault));
        
        vm.stopBroadcast();
        
        console2.log("");
        console2.log("=== Deployment Complete ===");
        console2.log("Next steps:");
        console2.log("1. Deploy LiquidationProtectorRsc on Lasna");
        console2.log("2. Users deposit reserves via depositReserve()");
        console2.log("3. Admin registers users on RSC via registerProtection()");
    }
}
