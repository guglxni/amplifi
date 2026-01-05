// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {DebtClearerRSC} from "../src/autoreplenish/DebtClearerRSC.sol";

/**
 * @title DeployDebtClearer
 * @notice Deploy the DebtClearerRSC contract to Lasna
 * @dev Run with: forge script script/DeployDebtClearer.s.sol --rpc-url https://lasna-rpc.rnk.dev --broadcast -vvvv
 */
contract DeployDebtClearer is Script {
    // Oracle Mirror RSCs on Lasna (from oracle-bridge deployments)
    address constant ETH_MIRROR_RSC = 0x1CdD260983f23c2A29a91134442C499cd3cc29cF;
    address constant BTC_MIRROR_RSC = 0xA17c0A6aBAC640ee401FF767EfA1cBf31966A848;
    address constant LINK_MIRROR_RSC = 0xDb0a8ab7Ea10f2D9E1BE242718699BEE43131274;

    // Other RSCs that might need monitoring
    address constant YIELD_OPTIMIZER_RSC = 0x98969559717c24b47A2E4365a569c947a88C4767;
    address constant REACTIVE_FUNDER_RC = 0x1caC802c52Cd82b9988e1163aF46258539280E71;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("REACTIVE_PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy with initial funding (1 REACT)
        DebtClearerRSC debtClearer = new DebtClearerRSC{value: 1 ether}();

        console.log("=== DebtClearerRSC Deployed ===");
        console.log("Address:", address(debtClearer));
        console.log("Owner:", debtClearer.owner());
        console.log("Balance:", address(debtClearer).balance);

        // Register Oracle Mirror RSCs
        console.log("\n=== Registering Oracle Mirror RSCs ===");

        address[] memory rscs = new address[](3);
        string[] memory names = new string[](3);

        rscs[0] = ETH_MIRROR_RSC;
        names[0] = "ETH Mirror RSC";

        rscs[1] = BTC_MIRROR_RSC;
        names[1] = "BTC Mirror RSC";

        rscs[2] = LINK_MIRROR_RSC;
        names[2] = "LINK Mirror RSC";

        debtClearer.registerRscBatch(rscs, names);

        console.log("Registered:", debtClearer.getRscCount(), "RSCs");

        // Get stats
        (
            uint256 totalRscs,
            uint256 totalDebtCleared,
            uint256 totalOps,
            bool cronEnabled,
            uint256 cronInterval
        ) = debtClearer.getStats();

        console.log("\n=== DebtClearer Stats ===");
        console.log("Total RSCs:", totalRscs);
        console.log("Total Debt Cleared:", totalDebtCleared);
        console.log("Total Operations:", totalOps);
        console.log("Cron Enabled:", cronEnabled);
        console.log("Cron Interval:", cronInterval, "blocks");

        vm.stopBroadcast();

        console.log("\n=== Next Steps ===");
        console.log("1. Call subscribeToCron() to enable periodic debt checking");
        console.log("2. Fund the contract with REACT for gas");
        console.log("3. Monitor via clearAllDebts() or let cron handle it");
    }
}

/**
 * @title RegisterMoreRSCs
 * @notice Add more RSCs to the DebtClearer
 */
contract RegisterMoreRSCs is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address debtClearerAddr = vm.envAddress("DEBT_CLEARER_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        DebtClearerRSC debtClearer = DebtClearerRSC(payable(debtClearerAddr));

        // Add more RSCs as needed
        // debtClearer.registerRsc(address, "name");

        console.log("RSC Count:", debtClearer.getRscCount());

        vm.stopBroadcast();
    }
}

/**
 * @title ManualDebtClear
 * @notice Manually trigger debt clearing
 */
contract ManualDebtClear is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address debtClearerAddr = vm.envAddress("DEBT_CLEARER_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        DebtClearerRSC debtClearer = DebtClearerRSC(payable(debtClearerAddr));

        // Get all debt status first
        (
            address[] memory rscs,
            uint256[] memory debts,
            uint256[] memory balances,
            bool[] memory canClear
        ) = debtClearer.getAllDebtStatus();

        console.log("=== RSC Debt Status ===");
        for (uint256 i = 0; i < rscs.length; i++) {
            console.log("RSC:", rscs[i]);
            console.log("  Debt:", debts[i]);
            console.log("  Balance:", balances[i]);
            console.log("  Can Clear:", canClear[i]);
        }

        // Clear all debts
        debtClearer.clearAllDebts();
        console.log("\nCleared all debts!");

        vm.stopBroadcast();
    }
}
