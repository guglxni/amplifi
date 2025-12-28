// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/Funder.sol";

/**
 * @title DeployFunder
 * @notice Standalone deployment script for upgraded Funder contract
 * @dev Run with:
 *      forge script script/DeployFunder.s.sol:DeployFunder --rpc-url $SEPOLIA_RPC --broadcast --verify
 */
contract DeployFunder is Script {
    // Current YieldOptimizerRsc on Lasna (target for gas funding)
    address constant TARGET_RSC = 0x98969559717c24b47A2E4365a569c947a88C4767;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("========== FUNDER DEPLOYMENT ==========");
        console.log("Deployer:", deployer);
        console.log("Chain ID:", block.chainid);
        console.log("Target RSC:", TARGET_RSC);
        console.log("");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy new Funder with bridgeToFaucet function
        Funder funder = new Funder(TARGET_RSC);
        console.log("Funder deployed at:", address(funder));
        
        // Initial funding for bridge operations
        uint256 fundAmount = 0.1 ether;
        if (address(deployer).balance >= fundAmount) {
            (bool success,) = address(funder).call{value: fundAmount}("");
            if (success) {
                console.log("Funder funded with 0.1 ETH");
            } else {
                console.log("Warning: Failed to fund Funder contract");
            }
        } else {
            console.log("Warning: Insufficient balance to fund Funder");
        }
        
        vm.stopBroadcast();
        
        // Output deployment info
        console.log("");
        console.log("========== DEPLOYMENT SUMMARY ==========");
        console.log("Funder:", address(funder));
        console.log("Owner:", deployer);
        console.log("Target RSC:", TARGET_RSC);
        console.log("REACTIVE_FAUCET:", funder.REACTIVE_FAUCET());
        console.log("CALLBACK_PROXY:", funder.CALLBACK_PROXY());
        console.log("========================================");
        console.log("");
        console.log("NEXT STEPS:");
        console.log("1. Update frontend CONFIG.FUNDER to:", address(funder));
        console.log("2. Test bridgeToFaucet and coverDebt functions");
        console.log("3. optionally, update YieldVault to use new Funder");
    }
}
