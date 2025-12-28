// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {LiquidationProtectorRsc} from "../src/LiquidationProtectorRsc.sol";

/**
 * @title DeployLiquidationProtectorRsc
 * @notice Deployment script for the Liquidation Protector RSC on Lasna Network
 * 
 * Usage:
 * forge script script/DeployLiquidationProtectorRsc.s.sol --rpc-url $LASNA_RPC --broadcast
 */
contract DeployLiquidationProtectorRsc is Script {
    // Sepolia Aave V3 Pool
    address constant AAVE_POOL = 0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951;
    
    // Protection Vault address (deployed on Sepolia)
    address constant PROTECTION_VAULT = 0x2E9860dDB62d5Be1565877405B92D56a0fB20C90;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        console2.log("=== Deploying Liquidation Protector RSC ===");
        console2.log("Aave Pool:", AAVE_POOL);
        console2.log("Protection Vault:", PROTECTION_VAULT);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy with initial REACT for gas
        LiquidationProtectorRsc protector = new LiquidationProtectorRsc{value: 0.5 ether}(
            AAVE_POOL,
            PROTECTION_VAULT
        );
        
        console2.log("LiquidationProtectorRsc deployed at:", address(protector));
        
        // Subscribe to health factor events
        // Note: Call this separately after deployment
        // protector.subscribeToHealthFactor();
        
        vm.stopBroadcast();
        
        console2.log("");
        console2.log("=== Deployment Complete ===");
        console2.log("Next steps:");
        console2.log("1. Deploy ProtectionVault on Sepolia");
        console2.log("2. Call setProtectionVault() with the vault address");
        console2.log("3. Call subscribeToHealthFactor() to start monitoring");
        console2.log("4. Register users for protection with registerProtection()");
    }
}
