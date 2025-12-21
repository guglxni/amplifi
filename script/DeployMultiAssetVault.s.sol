// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {YieldVaultMultiAsset} from "../src/YieldVaultMultiAsset.sol";

/**
 * @title DeployMultiAssetVault
 * @notice Deploys the multi-asset yield vault and configures all unlimited-cap assets
 * @dev Pre-configures WETH, LINK, AAVE, EURS - all verified to have no supply caps
 */
contract DeployMultiAssetVault is Script {
    // ═══════════════════════════════════════════════════════════════
    //                    SEPOLIA ADDRESSES
    // ═══════════════════════════════════════════════════════════════

    // Aave V3 Pool
    address constant AAVE_POOL = 0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951;
    
    // Reactive Network Callback Proxy on Sepolia
    address constant CALLBACK_PROXY = 0x0000000000000000000000000000000000fffFfF;
    
    // ═══════════════════════════════════════════════════════════════
    //              ASSETS WITH NO SUPPLY CAP (VERIFIED!)
    // ═══════════════════════════════════════════════════════════════

    // WETH - 18 decimals
    address constant WETH = 0xC558DBdd856501FCd9aaF1E62eae57A9F0629a3c;
    address constant aWETH = 0x5b071b590a59395fE4025A0Ccc1FcC931AAc1830;
    uint256 constant WETH_PRICE_USD = 200000000000; // $2000 * 10^8
    
    // LINK - 18 decimals  
    address constant LINK = 0xf8Fb3713D459D7C1018BD0A49D19b4C44290EBE5;
    address constant aLINK = 0x3FfAf50D4F4E96eB78f2407c090b72e86eCaed24;
    uint256 constant LINK_PRICE_USD = 1500000000; // $15 * 10^8
    
    // AAVE - 18 decimals
    address constant AAVE_TOKEN = 0x88541670E55cC00bEEFD87eB59EDd1b7C511AC9a;
    address constant aAAVE = 0x6b8558764d3b7572136F17174Cb9aB1DDc7E1259;
    uint256 constant AAVE_PRICE_USD = 10000000000; // $100 * 10^8
    
    // EURS - 2 decimals (Euro stablecoin)
    address constant EURS = 0x6d906e526a4e2Ca02097BA9d0caA3c382F52278E;
    address constant aEURS = 0xB20691021F9AcED8631eDaa3c0Cd2949EB45662D;
    uint256 constant EURS_PRICE_USD = 105000000; // $1.05 * 10^8

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("SEPOLIA_PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("============================================");
        console.log("  DEPLOYING MULTI-ASSET YIELD VAULT");
        console.log("============================================");
        console.log("");
        console.log("All assets verified to have supplyCap = 0 (UNLIMITED)");
        console.log("");
        
        // Deploy the vault
        YieldVaultMultiAsset vault = new YieldVaultMultiAsset(
            AAVE_POOL,
            CALLBACK_PROXY
        );
        
        console.log("Vault deployed at:", address(vault));
        console.log("");
        console.log("Adding assets...");
        
        // Add WETH (25% allocation)
        vault.addAsset(
            WETH,
            aWETH,
            18,
            WETH_PRICE_USD,
            "WETH",
            2500  // 25%
        );
        console.log("  [1] WETH added - 25% allocation");
        
        // Add LINK (25% allocation)
        vault.addAsset(
            LINK,
            aLINK,
            18,
            LINK_PRICE_USD,
            "LINK",
            2500  // 25%
        );
        console.log("  [2] LINK added - 25% allocation");
        
        // Add AAVE (25% allocation)
        vault.addAsset(
            AAVE_TOKEN,
            aAAVE,
            18,
            AAVE_PRICE_USD,
            "AAVE",
            2500  // 25%
        );
        console.log("  [3] AAVE added - 25% allocation");
        
        // Add EURS (25% allocation)
        vault.addAsset(
            EURS,
            aEURS,
            2,
            EURS_PRICE_USD,
            "EURS",
            2500  // 25%
        );
        console.log("  [4] EURS added - 25% allocation");
        
        console.log("");
        console.log("============================================");
        console.log("  DEPLOYMENT COMPLETE");
        console.log("============================================");
        console.log("YieldVaultMultiAsset:", address(vault));
        console.log("Total Assets: 4 (WETH, LINK, AAVE, EURS)");
        console.log("Total Allocation: 10000 BPS (100%)");
        console.log("");
        
        vm.stopBroadcast();
    }
}
