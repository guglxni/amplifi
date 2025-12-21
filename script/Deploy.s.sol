// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/YieldVault.sol";
import "../src/YieldOptimizerReactive.sol";
import "../src/Funder.sol";

/**
 * @title DeployYieldOptimizer
 * @notice Deployment script for Bounty 3 - Cross-Chain Yield Optimizer
 * @dev Run with:
 *      Sepolia: forge script script/Deploy.s.sol:DeployYieldOptimizer --rpc-url $SEPOLIA_RPC_URL --broadcast
 *      Lasna:   forge script script/Deploy.s.sol:DeployReactive --rpc-url $LASNA_RPC_URL --broadcast
 */
contract DeployYieldOptimizer is Script {
    // ═══════════════════════════════════════════════════════════════
    //                    SEPOLIA ADDRESSES
    // ═══════════════════════════════════════════════════════════════
    
    // Aave V3 Sepolia
    address constant AAVE_POOL = 0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951;
    address constant AAVE_USDC_ATOKEN = 0x16dA4541aD1807f4443d92D26044C1147406EB80;
    
    // Compound V3 Sepolia
    address constant COMPOUND_COMET_USDC = 0x285617313887d43256F852cAE0Ee4de4b68D45B0;
    
    // Reactive Network Callback Proxy (Sepolia)
    address constant CALLBACK_PROXY = 0xc9f36411C9897e7F959D99ffca2a0Ba7ee0D7bDA;
    
    // USDC on Sepolia
    address constant USDC = 0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deployer:", deployer);
        console.log("Chain ID:", block.chainid);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. Deploy YieldVault first (needed for Funder target)
        YieldVault vault = new YieldVault(
            USDC,
            AAVE_POOL,
            AAVE_USDC_ATOKEN,
            COMPOUND_COMET_USDC,
            CALLBACK_PROXY
        );
        console.log("YieldVault deployed at:", address(vault));
        
        // 2. Deploy Funder with vault as target RSC
        Funder funder = new Funder(address(vault));
        console.log("YieldVault deployed at:", address(vault));
        
        // 3. Configure vault
        vault.setFunderContract(address(funder));
        console.log("Funder contract set on vault");
        
        // 4. Fund contracts
        if (address(deployer).balance >= 0.2 ether) {
            // Fund vault for callbacks
            (bool success1,) = address(vault).call{value: 0.1 ether}("");
            require(success1, "Failed to fund vault");
            console.log("Vault funded with 0.1 ETH");
            
            // Fund funder for gas replenishment
            (bool success2,) = address(funder).call{value: 0.1 ether}("");
            require(success2, "Failed to fund funder");
            console.log("Funder funded with 0.1 ETH");
        }
        
        vm.stopBroadcast();
        
        // Output deployment info
        console.log("\n========== DEPLOYMENT SUMMARY ==========");
        console.log("YieldVault:", address(vault));
        console.log("Funder:", address(funder));
        console.log("=========================================");
        console.log("\nNEXT STEPS:");
        console.log("1. Deploy YieldOptimizerReactive to Lasna with vault address");
        console.log("2. Set RVM ID on vault: vault.setRvmId(<deployer_address>)");
        console.log("3. Subscribe RSC to CRON events");
    }
}

/**
 * @title DeployReactive
 * @notice Deploy the RSC to Reactive Network (Lasna)
 */
contract DeployReactive is Script {
    uint256 constant SEPOLIA_CHAIN_ID = 11155111;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        // Get vault address from environment or previous deployment
        address vault = vm.envAddress("VAULT_ADDRESS");
        require(vault != address(0), "VAULT_ADDRESS not set");
        
        console.log("Deployer:", deployer);
        console.log("Vault:", vault);
        console.log("Target Chain ID:", SEPOLIA_CHAIN_ID);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy RSC with initial ETH for subscriptions
        YieldOptimizerReactive reactive = new YieldOptimizerReactive{value: 0.5 ether}(
            vault,
            SEPOLIA_CHAIN_ID
        );
        console.log("YieldOptimizerReactive deployed at:", address(reactive));
        
        // Subscribe to CRON (100 blocks interval)
        // Note: This requires rnOnly modifier, so it must be done via RN environment
        // reactive.subscribeToCron(100);
        
        vm.stopBroadcast();
        
        // Output deployment info
        console.log("\n========== RSC DEPLOYMENT SUMMARY ==========");
        console.log("YieldOptimizerReactive:", address(reactive));
        console.log("Monitoring Vault:", vault);
        console.log("Target Chain:", SEPOLIA_CHAIN_ID);
        console.log("=============================================");
        console.log("\nNEXT STEPS:");
        console.log("1. Call subscribeToCron(100) on RSC via Reactive Network");
        console.log("2. Set RVM ID on Sepolia vault");
        console.log("3. Test yield snapshot and rebalancing");
    }
}
