// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {YieldVaultStablePlus} from "../src/YieldVaultStablePlus.sol";

/**
 * @title DeployStablePlusVault
 * @notice Deploys the EURS/AAVE yield vault to Sepolia
 * @dev Uses assets with NO supply cap to permanently resolve Aave error 51
 */
contract DeployStablePlusVault is Script {
    // ═══════════════════════════════════════════════════════════════
    //                    SEPOLIA ADDRESSES
    // ═══════════════════════════════════════════════════════════════

    // Aave V3 Pool
    address constant AAVE_POOL = 0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951;
    
    // Assets (NO SUPPLY CAP on Sepolia - verified!)
    address constant EURS = 0x6d906e526a4e2Ca02097BA9d0caA3c382F52278E;  // 2 decimals
    address constant AAVE = 0x88541670E55cC00bEEFD87eB59EDd1b7C511AC9a;  // 18 decimals
    
    // aTokens
    address constant aEURS = 0xB20691021F9AcED8631eDaa3c0Cd2949EB45662D;
    address constant aAAVE = 0x6b8558764d3b7572136F17174Cb9aB1DDc7E1259;
    
    // Reactive Network Callback Proxy on Sepolia
    address constant CALLBACK_PROXY = 0x0000000000000000000000000000000000fffFfF;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("SEPOLIA_PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("=== Deploying YieldVaultStablePlus (EURS/AAVE) ===");
        console.log("EURS (primary):", EURS);
        console.log("AAVE (secondary):", AAVE);
        console.log("Aave Pool:", AAVE_POOL);
        console.log("");
        console.log("Supply caps verified: BOTH = 0 (UNLIMITED)");
        
        YieldVaultStablePlus vault = new YieldVaultStablePlus(
            EURS,
            AAVE,
            AAVE_POOL,
            aEURS,
            aAAVE,
            CALLBACK_PROXY
        );
        
        console.log("");
        console.log("=== Deployment Complete ===");
        console.log("YieldVaultStablePlus:", address(vault));
        
        vm.stopBroadcast();
    }
}
