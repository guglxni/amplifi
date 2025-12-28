// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/YieldOptimizerReactive.sol";

/**
 * @title DeployYieldOptimizerReactive
 * @notice Deploy RSC to Lasna (Reactive Network)
 * @dev Run with:
 *      forge script script/DeployYieldOptimizerRsc.s.sol:DeployYieldOptimizerReactive \
 *        --rpc-url https://kopli-rpc.reactive.network \
 *        --broadcast -vvv
 */
contract DeployYieldOptimizerReactive is Script {
    // Target vault on Sepolia
    address constant VAULT_DUAL_ASSET = 0xe6e06F94d1aaa2496b9e33afeE29f01436E9fA4A;
    uint256 constant SEPOLIA_CHAIN_ID = 11155111;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("========== RSC DEPLOYMENT TO LASNA ==========");
        console.log("Deployer:", deployer);
        console.log("Target Vault:", VAULT_DUAL_ASSET);
        console.log("Target Chain:", SEPOLIA_CHAIN_ID);
        console.log("");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy with initial ETH for subscriptions and callbacks
        YieldOptimizerReactive rsc = new YieldOptimizerReactive{value: 1 ether}(
            VAULT_DUAL_ASSET,
            SEPOLIA_CHAIN_ID
        );
        
        console.log("YieldOptimizerReactive deployed at:", address(rsc));
        console.log("Owner:", rsc.owner());
        console.log("Cron Enabled:", rsc.cronMonitoringEnabled());
        
        vm.stopBroadcast();
        
        // Output deployment info
        console.log("");
        console.log("========== DEPLOYMENT SUMMARY ==========");
        console.log("RSC Address:", address(rsc));
        console.log("Vault Monitored:", rsc.getVault());
        console.log("Chain ID:", rsc.getChainId());
        console.log("========================================");
        console.log("");
        console.log("NEXT STEPS:");
        console.log("1. Update frontend CONFIG.YIELD_OPTIMIZER_RSC");
        console.log("2. Set RVM ID on vault: setRvmId(", address(rsc), ")");
        console.log("3. Test by calling triggerYieldSnapshot() on vault");
    }
}
