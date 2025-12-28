// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/YieldVaultMultiAssetV2.sol";
import "../src/autoreplenish/VaultFeeCollector.sol";

/**
 * @title DeployMultiAssetV2
 * @notice Deploys YieldVaultMultiAssetV2 with True Auto-Replenishment on Sepolia
 * 
 * Full deployment steps:
 * 
 * Step 1 - Deploy vault first (with zero fee collector):
 *   source .env && forge script script/DeployMultiAssetV2.s.sol:DeployMultiAssetV2 \
 *     --rpc-url $SEPOLIA_RPC_URL --broadcast
 * 
 * Step 2 - Deploy FeeCollector pointing to the vault:
 *   export VAULT_ADDRESS=<new_vault_address>
 *   source .env && forge script script/DeployMultiAssetV2.s.sol:DeployFeeCollectorForMultiAsset \
 *     --rpc-url $SEPOLIA_RPC_URL --broadcast
 * 
 * Step 3 - Link the vault to the fee collector:
 *   cast send <vault_address> "setFeeCollector(address)" <fee_collector_address> \
 *     --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
 */

// Sepolia Configuration
contract SepoliaConfig {
    // Aave V3 Sepolia
    address constant AAVE_POOL = 0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951;
    
    // Reactive Network Callback Proxy on Sepolia (correct checksum)
    address constant CALLBACK_PROXY = 0x0000000000000000000000000000000000fffFfF;
    
    // Assets with NO supply cap issues on Aave V3 Sepolia
    struct AssetConfig {
        address token;
        address aToken;
        uint8 decimals;
        uint256 priceUSD;  // 8 decimals
        string symbol;
        uint256 allocation; // BPS
    }
    
    function getAssets() internal pure returns (AssetConfig[5] memory) {
        return [
            AssetConfig({
                token: 0xC558DBdd856501FCd9aaF1E62eae57A9F0629a3c,  // WETH
                aToken: 0x5b071b590a59395fE4025A0Ccc1FcC931AAc1830,
                decimals: 18,
                priceUSD: 350000000000, // $3500
                symbol: "WETH",
                allocation: 2500 // 25%
            }),
            AssetConfig({
                token: 0xf8Fb3713D459D7C1018BD0A49D19b4C44290EBE5,  // LINK
                aToken: 0x3FfAf50D4F4E96eB78f2407c090b72e86eCaed24,
                decimals: 18,
                priceUSD: 2500000000, // $25
                symbol: "LINK",
                allocation: 2000 // 20%
            }),
            AssetConfig({
                token: 0x88541670E55cC00bEEFD87eB59EDd1b7C511AC9a,  // AAVE
                aToken: 0x6b8558764d3b7572136F17174Cb9aB1DDc7E1259,
                decimals: 18,
                priceUSD: 35000000000, // $350
                symbol: "AAVE",
                allocation: 2000 // 20%
            }),
            AssetConfig({
                token: 0x6d906e526a4e2Ca02097BA9d0caA3c382F52278E,  // EURS
                aToken: 0xB20691021F9AcED8631eDaa3c0Cd2949EB45662D, // CORRECTED aToken from Aave getReserveData
                decimals: 2,
                priceUSD: 108000000, // $1.08
                symbol: "EURS",
                allocation: 1500 // 15%
            }),
            AssetConfig({
                token: 0x29f2D40B0605204364af54EC677bD022dA425d03,  // WBTC
                aToken: 0x1804Bf30507dc2EB3bDEbbbdd859991EAeF6EefF,
                decimals: 8,
                priceUSD: 10000000000000, // $100,000
                symbol: "WBTC",
                allocation: 2000 // 20%
            })
        ];
    }
}

/**
 * @title DeployMultiAssetV2
 * @notice Deploy YieldVaultMultiAssetV2 with fee collector and add assets
 */
contract DeployMultiAssetV2 is Script, SepoliaConfig {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address feeCollectorAddr = vm.envOr("FEE_COLLECTOR", address(0));
        
        console.log("Deployer:", deployer);
        console.log("Fee Collector:", feeCollectorAddr);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy the vault with 0.1 ETH for callback funding
        YieldVaultMultiAssetV2 vault = new YieldVaultMultiAssetV2{value: 0.1 ether}(
            AAVE_POOL,
            CALLBACK_PROXY,
            feeCollectorAddr
        );
        
        console.log("Vault deployed at:", address(vault));
        
        // Add all assets
        SepoliaConfig.AssetConfig[5] memory assetConfigs = getAssets();
        
        for (uint256 i = 0; i < assetConfigs.length; i++) {
            SepoliaConfig.AssetConfig memory cfg = assetConfigs[i];
            vault.addAsset(
                cfg.token,
                cfg.aToken,
                cfg.decimals,
                cfg.priceUSD,
                cfg.symbol,
                cfg.allocation
            );
            console.log("Added asset:", cfg.symbol);
        }
        
        vm.stopBroadcast();
        
        console.log("");
        console.log("=== YieldVaultMultiAssetV2 Deployed ===");
        console.log("Vault Address:", address(vault));
        console.log("Fee Collector:", feeCollectorAddr);
        console.log("Assets Added: 5 (WETH, LINK, AAVE, EURS, WBTC)");
        console.log("Total Allocation:", vault.totalAllocation(), "BPS");
        console.log("");
        if (feeCollectorAddr == address(0)) {
            console.log("Next steps:");
            console.log("1. Deploy VaultFeeCollector pointing to this vault");
            console.log("2. Call vault.setFeeCollector(feeCollectorAddress)");
            console.log("3. Deploy/update VaultFunderRSC on Lasna");
        }
    }
}

/**
 * @title DeployFeeCollectorForMultiAsset
 * @notice Deploy a new VaultFeeCollector for the Multi-Asset Vault
 */
contract DeployFeeCollectorForMultiAsset is Script, SepoliaConfig {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address vaultAddr = vm.envAddress("VAULT_ADDRESS");
        
        console.log("Deployer:", deployer);
        console.log("Vault:", vaultAddr);
        console.log("Deploying VaultFeeCollector for Multi-Asset Vault...");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // VaultFeeCollector takes only vault address
        VaultFeeCollector feeCollector = new VaultFeeCollector{value: 0.01 ether}(
            vaultAddr
        );
        
        vm.stopBroadcast();
        
        console.log("");
        console.log("=== VaultFeeCollector Deployed ===");
        console.log("Address:", address(feeCollector));
        console.log("Vault:", vaultAddr);
        console.log("");
        console.log("Next steps:");
        console.log("1. Link fee collector to vault:");
        console.log("   cast send", vaultAddr, "setFeeCollector(address)", address(feeCollector));
        console.log("2. Deploy VaultFunderRSC on Lasna pointing to this FeeCollector");
    }
}

