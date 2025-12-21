// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {YieldVaultMultiAsset} from "../src/YieldVaultMultiAsset.sol";

interface IFaucet {
    function mint(address token, address to, uint256 amount) external returns (uint256);
}

/**
 * @title AddAssets
 * @notice Adds WBTC and USDT to the multi-asset vault
 */
contract AddAssets is Script {
    // Vault Address
    address constant VAULT = 0x9015fb507E9bE03fB59514ba7a913122e5Fa2e7d;
    
    // Aave Faucet
    address constant FAUCET = 0xC959483DBa39aa9E78757139af0e9a2EDEb3f42D;

    // Assets
    address constant WBTC = 0x29f2D40B0605204364af54EC677bD022dA425d03;
    address constant aWBTC = 0x1804Bf30507dc2EB3bDEbbbdd859991EAeF6EefF;
    uint256 constant WBTC_PRICE_USD = 9500000000000; // $95,000 * 10^8

    address constant USDT = 0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0;
    address constant aUSDT = 0x16dA4541aD1807f4443d92D26044C1147406EB80;
    uint256 constant USDT_PRICE_USD = 100000000; // $1 * 10^8

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("SEPOLIA_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("Adding assets to vault at:", VAULT);
        YieldVaultMultiAsset vault = YieldVaultMultiAsset(payable(VAULT));

        // 1. Add WBTC (0 allocation initial)
        console.log("Adding WBTC...");
        vault.addAsset(WBTC, aWBTC, 8, WBTC_PRICE_USD, "WBTC", 0);

        // 2. Add USDT (0 allocation initial)
        console.log("Adding USDT...");
        vault.addAsset(USDT, aUSDT, 6, USDT_PRICE_USD, "USDT", 0);

        // 3. Mint test tokens to deployer (try-catch block conceptually, but script will fail if revert)
        // We do this to ensure we can verify later or deposit
        console.log("Minting test tokens...");
        try IFaucet(FAUCET).mint(WBTC, deployer, 100000000) { // 1 WBTC
            console.log("Minted 1 WBTC");
        } catch {
            console.log("Failed to mint WBTC - maybe faucet limits");
        }

        try IFaucet(FAUCET).mint(USDT, deployer, 1000000000) { // 1000 USDT
            console.log("Minted 1000 USDT");
        } catch {
            console.log("Failed to mint USDT - maybe faucet limits");
        }

        // 4. Update Allocations
        // Target: WETH(20), LINK(20), AAVE(20), EURS(10), WBTC(15), USDT(15)
        // Sum: 20+20+20+10+15+15 = 100%
        
        console.log("Updating allocations...");
        // Asset IDs: 1=WETH, 2=LINK, 3=AAVE, 4=EURS, 5=WBTC, 6=USDT
        
        vault.setAllocation(1, 2000); // WETH
        vault.setAllocation(2, 2000); // LINK
        vault.setAllocation(3, 2000); // AAVE
        vault.setAllocation(4, 1000); // EURS
        vault.setAllocation(5, 1500); // WBTC
        vault.setAllocation(6, 1500); // USDT
        
        console.log("Assets added and allocations updated!");
        
        vm.stopBroadcast();
    }
}
