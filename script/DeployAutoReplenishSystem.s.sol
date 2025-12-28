// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/YieldVaultDualAssetV2.sol";
import "../src/autoreplenish/VaultFeeCollector.sol";
import "../src/autoreplenish/VaultFunderRSC.sol";

/**
 * @title DeployAutoReplenishSystem
 * @notice Deploys the complete True Auto-Replenishment system
 * @dev Run in sequence:
 *      1. DeploySepoliaContracts - Deploy vault + fee collector on Sepolia
 *      2. DeployReactiveContracts - Deploy VaultFunderRSC on Lasna
 *      3. ConfigureSystem - Link everything together
 * 
 * Architecture Overview:
 * 
 * ┌─────────────────────────────────────────────────────────────────────────────────┐
 * │                              SEPOLIA (Origin Chain)                              │
 * ├─────────────────────────────────────────────────────────────────────────────────┤
 * │                                                                                  │
 * │  ┌─────────────────────┐         ┌───────────────────────────────┐              │
 * │  │                     │  fees   │                               │              │
 * │  │  YieldVaultDualAssetV2 │─────▶│   VaultFeeCollector          │              │
 * │  │                     │◀────────│                               │              │
 * │  │  - deposits ETH fees│  funds  │  - Collects fees             │              │
 * │  │  - receives callbacks│        │  - Funds vault when low      │              │
 * │  │  - pays callback gas│        │  - Emits FeeCollected events │              │
 * │  └─────────────────────┘         └───────────────────────────────┘              │
 * │            │                                │                                   │
 * │            │ YieldSnapshot                  │ FeeCollected                      │
 * │            ▼                                ▼                                   │
 * └─────────────────────────────────────────────────────────────────────────────────┘
 *                                              │
 *                                              │ Events monitored by
 *                                              ▼ Reactive Network
 * ┌─────────────────────────────────────────────────────────────────────────────────┐
 * │                         REACTIVE NETWORK (Lasna)                                │
 * ├─────────────────────────────────────────────────────────────────────────────────┤
 * │                                                                                  │
 * │  ┌─────────────────────────────┐     ┌─────────────────────────────┐            │
 * │  │                             │     │                             │            │
 * │  │   YieldOptimizerReactive   │     │      VaultFunderRSC        │            │
 * │  │                             │     │                             │            │
 * │  │  - Monitors YieldSnapshot   │     │  - Monitors FeeCollected    │            │
 * │  │  - Calculates optimal alloc │     │  - Triggers funding checks  │            │
 * │  │  - Emits rebalance callback │     │  - Emits funding callbacks  │            │
 * │  └─────────────────────────────┘     └─────────────────────────────┘            │
 * │                                                                                  │
 * └─────────────────────────────────────────────────────────────────────────────────┘
 */

/// @notice Deploy Sepolia contracts (Vault + FeeCollector)
contract DeploySepoliaContracts is Script {
    // Sepolia addresses
    address constant USDC = 0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8;
    address constant DAI = 0xFF34B3d4Aee8ddCd6F9AFFFB6Fe49bD371b8a357;
    address constant AAVE_POOL = 0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951;
    address constant AUSDC = 0x16dA4541aD1807f4443d92D26044C1147406EB80;
    address constant ADAI = 0x29598b72eb5CeBd806C5dCD549490FdA35B13cD8;
    address constant CALLBACK_PROXY = 0xc9f36411C9897e7F959D99ffca2a0Ba7ee0D7bDA;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deployer:", deployer);
        console.log("Deployer balance:", deployer.balance);
        console.log("Chain ID:", block.chainid);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. Deploy FeeCollector first (with placeholder vault)
        VaultFeeCollector feeCollector = new VaultFeeCollector{value: 0.1 ether}(deployer);
        console.log("VaultFeeCollector deployed at:", address(feeCollector));
        
        // 2. Deploy Vault with fee collector integration
        YieldVaultDualAssetV2 vault = new YieldVaultDualAssetV2{value: 0.1 ether}(
            USDC,
            DAI,
            AAVE_POOL,
            AUSDC,
            ADAI,
            CALLBACK_PROXY,
            address(feeCollector)
        );
        console.log("YieldVaultDualAssetV2 deployed at:", address(vault));
        
        // 3. Configure FeeCollector to point to the vault
        feeCollector.setVault(address(vault));
        console.log("FeeCollector configured with vault");
        
        vm.stopBroadcast();
        
        // Output deployment info
        console.log("\n========== SEPOLIA DEPLOYMENT SUMMARY ==========");
        console.log("VaultFeeCollector:", address(feeCollector));
        console.log("YieldVaultDualAssetV2:", address(vault));
        console.log("=================================================");
        console.log("\nNEXT STEPS:");
        console.log("1. Export: export VAULT_ADDRESS=", address(vault));
        console.log("2. Export: export FEE_COLLECTOR=", address(feeCollector));
        console.log("3. Run DeployReactiveContracts on Lasna");
    }
}

/// @notice Deploy Reactive contracts (YieldOptimizer + VaultFunder RSCs)
contract DeployReactiveContracts is Script {
    uint256 constant SEPOLIA_CHAIN_ID = 11155111;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        address vault = vm.envAddress("VAULT_ADDRESS");
        address feeCollector = vm.envAddress("FEE_COLLECTOR");
        
        require(vault != address(0), "VAULT_ADDRESS not set");
        require(feeCollector != address(0), "FEE_COLLECTOR not set");
        
        console.log("Deployer:", deployer);
        console.log("Vault:", vault);
        console.log("FeeCollector:", feeCollector);
        console.log("Chain ID:", block.chainid);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. Deploy VaultFunderRSC (auto-replenishment)
        VaultFunderRSC funderRSC = new VaultFunderRSC{value: 2 ether}(
            feeCollector,
            vault
        );
        console.log("VaultFunderRSC deployed at:", address(funderRSC));
        
        // Note: YieldOptimizerReactive should be deployed separately as before
        // This script focuses on the auto-replenishment RSC
        
        vm.stopBroadcast();
        
        // Output deployment info
        console.log("\n========== REACTIVE DEPLOYMENT SUMMARY ==========");
        console.log("VaultFunderRSC:", address(funderRSC));
        console.log("Monitoring FeeCollector:", feeCollector);
        console.log("Target Vault:", vault);
        console.log("=================================================");
        console.log("\nNEXT STEPS:");
        console.log("1. Subscribe to CRON: funderRSC.subscribeToCron(50)");
        console.log("2. Set RVM ID on vault");
        console.log("3. Test with a deposit that includes fee");
    }
}

/// @notice Configure the complete system (run after both deployments)
contract ConfigureSystem is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        address vault = vm.envAddress("VAULT_ADDRESS");
        address feeCollector = vm.envAddress("FEE_COLLECTOR");
        address yieldRSC = vm.envAddress("YIELD_RSC"); // YieldOptimizerReactive
        address funderRSC = vm.envAddress("FUNDER_RSC"); // VaultFunderRSC
        
        console.log("Configuring system...");
        console.log("Vault:", vault);
        console.log("FeeCollector:", feeCollector);
        console.log("YieldRSC:", yieldRSC);
        console.log("FunderRSC:", funderRSC);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Set RVM ID on vault (use deployer address as per Reactive Network docs)
        YieldVaultDualAssetV2(payable(vault)).setRvmId(yieldRSC);
        console.log("Vault RVM ID set to:", yieldRSC);
        
        // Authorize feeCollector to fund vault (already done in deployment, but verify)
        VaultFeeCollector(payable(feeCollector)).setVaultAuthorization(vault, true);
        console.log("FeeCollector authorized for vault");
        
        vm.stopBroadcast();
        
        console.log("\n========== SYSTEM CONFIGURED ==========");
        console.log("True Auto-Replenishment is now active!");
        console.log("========================================");
    }
}
