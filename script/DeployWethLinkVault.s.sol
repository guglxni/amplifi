// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {YieldVaultWethLink} from "../src/YieldVaultWethLink.sol";

/**
 * @title DeployWethLinkVault
 * @notice Deploys the WETH/LINK yield vault to Sepolia
 * @dev Uses assets with no supply cap to avoid Aave error 51
 */
contract DeployWethLinkVault is Script {
    // ═══════════════════════════════════════════════════════════════
    //                    SEPOLIA ADDRESSES
    // ═══════════════════════════════════════════════════════════════

    // Aave V3 Pool
    address constant AAVE_POOL = 0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951;
    
    // Assets (NO SUPPLY CAP on Sepolia)
    address constant WETH = 0xC558DBdd856501FCd9aaF1E62eae57A9F0629a3c;
    address constant LINK = 0xf8Fb3713D459D7C1018BD0A49D19b4C44290EBE5;
    
    // aTokens
    address constant aWETH = 0x5b071b590a59395fE4025A0Ccc1FcC931AAc1830;
    address constant aLINK = 0x3FfAf50D4F4E96eB78f2407c090b72e86eCaed24;
    
    // Reactive Network Callback Proxy on Sepolia
    address constant CALLBACK_PROXY = 0x0000000000000000000000000000000000fffFfF;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("SEPOLIA_PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("=== Deploying YieldVaultWethLink ===");
        console.log("WETH:", WETH);
        console.log("LINK:", LINK);
        console.log("Aave Pool:", AAVE_POOL);
        
        YieldVaultWethLink vault = new YieldVaultWethLink(
            WETH,
            LINK,
            AAVE_POOL,
            aWETH,
            aLINK,
            CALLBACK_PROXY
        );
        
        console.log("\n=== Deployment Complete ===");
        console.log("YieldVaultWethLink:", address(vault));
        
        vm.stopBroadcast();
    }
}
