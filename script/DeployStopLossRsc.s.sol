// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {StopLossRsc} from "../src/StopLossRsc.sol";

/**
 * @title DeployStopLossRsc
 * @notice Deployment script for the Stop-Loss RSC on Lasna Network
 * 
 * Usage:
 * forge script script/DeployStopLossRsc.s.sol --rpc-url $REACTIVE_RPC --broadcast
 */
contract DeployStopLossRsc is Script {
    // Unified Price Oracle on Sepolia
    address constant PRICE_ORACLE = 0x889c32f46E273fBd0d5B1806F3f1286010cD73B3;
    
    // Uniswap V2 Router on Sepolia (for swaps)
    address constant SWAP_ROUTER = 0xC532a74256D3Db42D0Bf7a0400fEFDbad7694008;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        console2.log("=== Deploying Stop-Loss RSC ===");
        console2.log("Price Oracle:", PRICE_ORACLE);
        console2.log("Swap Router:", SWAP_ROUTER);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy with initial REACT for gas
        StopLossRsc stopLoss = new StopLossRsc{value: 0.3 ether}(
            PRICE_ORACLE,
            SWAP_ROUTER
        );
        
        console2.log("StopLossRsc deployed at:", address(stopLoss));
        
        vm.stopBroadcast();
        
        console2.log("");
        console2.log("=== Deployment Complete ===");
        console2.log("Next steps:");
        console2.log("1. Call subscribeToPriceUpdates() to start monitoring");
        console2.log("2. Create orders via createOrder()");
    }
}
