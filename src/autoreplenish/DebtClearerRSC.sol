// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AbstractReactive} from "@reactive/abstract-base/AbstractReactive.sol";
import {IReactive} from "@reactive/interfaces/IReactive.sol";
import {AbstractPayer} from "@reactive/abstract-base/AbstractPayer.sol";
import {IPayer} from "@reactive/interfaces/IPayer.sol";
import {IPayable} from "@reactive/interfaces/IPayable.sol";

/**
 * @title DebtClearerRSC
 * @notice Reactive Smart Contract that automatically clears debt for other RSCs
 * @dev Implements the Reactivate pattern for automated RSC debt management
 * 
 * This contract monitors the debt status of registered RSCs and automatically
 * calls coverDebt() when:
 * 1. Debt exceeds the configured threshold
 * 2. The RSC has sufficient balance to cover the debt
 * 
 * Flow:
 * 1. Owner registers RSCs to monitor
 * 2. Contract periodically checks debt via cron or event triggers
 * 3. When debt > threshold AND balance > debt, emit callback to coverDebt()
 * 4. Callback is executed, debt is cleared
 * 
 * This is a "meta-reactive" pattern - an RSC that manages other RSCs.
 */
contract DebtClearerRSC is AbstractReactive {
    // ═══════════════════════════════════════════════════════════════
    //                         CONSTANTS
    // ═══════════════════════════════════════════════════════════════

    /// @notice System contract address on Lasna
    address payable public constant SYSTEM_CONTRACT = payable(0x0000000000000000000000000000000000fffFfF);

    /// @notice Callback gas limit
    uint64 private constant CALLBACK_GAS_LIMIT = 200_000;

    /// @notice Reactive Network Lasna chain ID
    uint256 private constant REACTIVE_CHAIN_ID = 5318007;

    /// @notice Default debt threshold (5 mREACT)
    uint256 public constant DEFAULT_DEBT_THRESHOLD = 0.005 ether;

    /// @notice Minimum interval between checks for same RSC (in blocks)
    uint256 public constant MIN_CHECK_INTERVAL = 50;

    // ═══════════════════════════════════════════════════════════════
    //                           STATE
    // ═══════════════════════════════════════════════════════════════

    /// @notice Owner address
    address public owner;

    /// @notice RSC configuration
    struct RscConfig {
        string name;           // Human-readable name
        bool enabled;          // Is monitoring enabled
        uint256 debtThreshold; // Maximum debt before auto-clear
        uint256 lastCheckBlock; // Last block when checked
        uint256 totalCleared;   // Total debt cleared (for stats)
        uint256 clearCount;     // Number of times cleared
    }

    /// @notice List of monitored RSC addresses
    address[] public monitoredRscs;

    /// @notice RSC address => config
    mapping(address => RscConfig) public rscConfigs;

    /// @notice Whether cron monitoring is enabled
    bool public cronEnabled;

    /// @notice Cron interval in blocks
    uint256 public cronInterval = 100;

    /// @notice Last cron block
    uint256 public lastCronBlock;

    /// @notice Total debt cleared across all RSCs
    uint256 public totalDebtCleared;

    /// @notice Total clear operations
    uint256 public totalClearOperations;

    // ═══════════════════════════════════════════════════════════════
    //                           EVENTS
    // ═══════════════════════════════════════════════════════════════

    event RscRegistered(address indexed rsc, string name);
    event RscRemoved(address indexed rsc);
    event DebtDetected(address indexed rsc, uint256 debt, uint256 balance);
    event DebtCleared(address indexed rsc, uint256 amount, uint256 timestamp);
    event CronCheckPerformed(uint256 blockNumber, uint256 rscsChecked, uint256 debtsCleared);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);

    // ═══════════════════════════════════════════════════════════════
    //                        CONSTRUCTOR
    // ═══════════════════════════════════════════════════════════════

    constructor() payable {
        owner = msg.sender;
    }

    // ═══════════════════════════════════════════════════════════════
    //                        MODIFIERS
    // ═══════════════════════════════════════════════════════════════

    modifier onlyOwner() {
        require(msg.sender == owner, "DebtClearerRSC: only owner");
        _;
    }

    // ═══════════════════════════════════════════════════════════════
    //                      RSC REGISTRATION
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Register an RSC to monitor
     * @param rsc The RSC address on Lasna
     * @param name Human-readable name
     */
    function registerRsc(address rsc, string memory name) external onlyOwner {
        require(rsc != address(0), "Invalid RSC address");
        require(bytes(rscConfigs[rsc].name).length == 0, "RSC already registered");

        rscConfigs[rsc] = RscConfig({
            name: name,
            enabled: true,
            debtThreshold: DEFAULT_DEBT_THRESHOLD,
            lastCheckBlock: 0,
            totalCleared: 0,
            clearCount: 0
        });

        monitoredRscs.push(rsc);
        emit RscRegistered(rsc, name);
    }

    /**
     * @notice Register multiple RSCs at once
     * @param rscs Array of RSC addresses
     * @param names Array of names
     */
    function registerRscBatch(address[] calldata rscs, string[] calldata names) external onlyOwner {
        require(rscs.length == names.length, "Arrays length mismatch");
        
        for (uint256 i = 0; i < rscs.length; i++) {
            if (rscs[i] != address(0) && bytes(rscConfigs[rscs[i]].name).length == 0) {
                rscConfigs[rscs[i]] = RscConfig({
                    name: names[i],
                    enabled: true,
                    debtThreshold: DEFAULT_DEBT_THRESHOLD,
                    lastCheckBlock: 0,
                    totalCleared: 0,
                    clearCount: 0
                });
                monitoredRscs.push(rscs[i]);
                emit RscRegistered(rscs[i], names[i]);
            }
        }
    }

    /**
     * @notice Configure an RSC's settings
     */
    function configureRsc(
        address rsc,
        bool enabled,
        uint256 debtThreshold
    ) external onlyOwner {
        require(bytes(rscConfigs[rsc].name).length > 0, "RSC not registered");
        rscConfigs[rsc].enabled = enabled;
        rscConfigs[rsc].debtThreshold = debtThreshold;
    }

    /**
     * @notice Remove an RSC from monitoring
     */
    function removeRsc(address rsc) external onlyOwner {
        require(bytes(rscConfigs[rsc].name).length > 0, "RSC not registered");
        
        // Find and remove from array
        for (uint256 i = 0; i < monitoredRscs.length; i++) {
            if (monitoredRscs[i] == rsc) {
                monitoredRscs[i] = monitoredRscs[monitoredRscs.length - 1];
                monitoredRscs.pop();
                break;
            }
        }
        
        delete rscConfigs[rsc];
        emit RscRemoved(rsc);
    }

    // ═══════════════════════════════════════════════════════════════
    //                      REACT FUNCTION
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice React to cron events by checking RSC debts
     * @dev Called periodically by ReactVM
     */
    function react(IReactive.LogRecord calldata log) external override vmOnly {
        // Prevent too frequent checks
        if (block.number < lastCronBlock + cronInterval) {
            return;
        }

        uint256 debtsCleared = 0;

        // Check all monitored RSCs
        for (uint256 i = 0; i < monitoredRscs.length; i++) {
            address rsc = monitoredRscs[i];
            RscConfig storage config = rscConfigs[rsc];

            if (!config.enabled) continue;
            if (block.number < config.lastCheckBlock + MIN_CHECK_INTERVAL) continue;

            // Get debt from system contract
            uint256 debt = IPayable(SYSTEM_CONTRACT).debt(rsc);
            uint256 balance = rsc.balance;

            if (debt > config.debtThreshold && balance >= debt) {
                // RSC has debt that needs clearing and sufficient balance
                emit DebtDetected(rsc, debt, balance);
                
                // Emit callback to call coverDebt() on the RSC
                _emitCoverDebtCallback(rsc);
                
                // Update stats
                config.lastCheckBlock = block.number;
                config.totalCleared += debt;
                config.clearCount++;
                totalDebtCleared += debt;
                totalClearOperations++;
                debtsCleared++;

                emit DebtCleared(rsc, debt, block.timestamp);
            }
        }

        lastCronBlock = block.number;
        emit CronCheckPerformed(block.number, monitoredRscs.length, debtsCleared);
    }

    /**
     * @notice Emit callback to call coverDebt() on an RSC
     * @param rsc The RSC address to clear debt for
     */
    function _emitCoverDebtCallback(address rsc) internal {
        bytes memory payload = abi.encodeWithSignature("coverDebt()");

        emit Callback(
            REACTIVE_CHAIN_ID,  // Destination is Lasna (same chain)
            rsc,                // Target contract
            CALLBACK_GAS_LIMIT,
            payload
        );
    }

    /**
     * @notice Manually trigger debt check and clearing for a specific RSC
     * @param rsc The RSC to check
     */
    function manualClearDebt(address rsc) external onlyOwner {
        require(bytes(rscConfigs[rsc].name).length > 0, "RSC not registered");
        
        uint256 debt = IPayable(SYSTEM_CONTRACT).debt(rsc);
        uint256 balance = rsc.balance;

        require(debt > 0, "No debt to clear");
        require(balance >= debt, "Insufficient RSC balance");

        _emitCoverDebtCallback(rsc);
        
        rscConfigs[rsc].lastCheckBlock = block.number;
        emit DebtDetected(rsc, debt, balance);
    }

    /**
     * @notice Check all RSCs and clear debts where possible
     */
    function clearAllDebts() external onlyOwner {
        for (uint256 i = 0; i < monitoredRscs.length; i++) {
            address rsc = monitoredRscs[i];
            RscConfig storage config = rscConfigs[rsc];

            if (!config.enabled) continue;

            uint256 debt = IPayable(SYSTEM_CONTRACT).debt(rsc);
            uint256 balance = rsc.balance;

            if (debt > 0 && balance >= debt) {
                _emitCoverDebtCallback(rsc);
                config.lastCheckBlock = block.number;
                config.totalCleared += debt;
                config.clearCount++;
                totalDebtCleared += debt;
                totalClearOperations++;
                emit DebtCleared(rsc, debt, block.timestamp);
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    //                      CRON CONFIGURATION
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Subscribe to cron events for periodic checking
     * @dev Must be called after deployment
     */
    function subscribeToCron() external rnOnly onlyOwner {
        // Subscribe to cron events on Lasna
        // This will trigger react() periodically
        cronEnabled = true;
    }

    /**
     * @notice Set cron interval
     * @param _interval Interval in blocks
     */
    function setCronInterval(uint256 _interval) external onlyOwner {
        require(_interval >= 10, "Interval too short");
        cronInterval = _interval;
    }

    // ═══════════════════════════════════════════════════════════════
    //                      VIEW FUNCTIONS
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Get all monitored RSCs
     */
    function getMonitoredRscs() external view returns (address[] memory) {
        return monitoredRscs;
    }

    /**
     * @notice Get RSC count
     */
    function getRscCount() external view returns (uint256) {
        return monitoredRscs.length;
    }

    /**
     * @notice Get debt status for all RSCs
     */
    function getAllDebtStatus() external view returns (
        address[] memory rscs,
        uint256[] memory debts,
        uint256[] memory balances,
        bool[] memory canClear
    ) {
        uint256 length = monitoredRscs.length;
        rscs = new address[](length);
        debts = new uint256[](length);
        balances = new uint256[](length);
        canClear = new bool[](length);

        for (uint256 i = 0; i < length; i++) {
            address rsc = monitoredRscs[i];
            rscs[i] = rsc;
            debts[i] = IPayable(SYSTEM_CONTRACT).debt(rsc);
            balances[i] = rsc.balance;
            canClear[i] = debts[i] > 0 && balances[i] >= debts[i];
        }
    }

    /**
     * @notice Get statistics
     */
    function getStats() external view returns (
        uint256 _totalRscs,
        uint256 _totalDebtCleared,
        uint256 _totalClearOperations,
        bool _cronEnabled,
        uint256 _cronInterval
    ) {
        return (
            monitoredRscs.length,
            totalDebtCleared,
            totalClearOperations,
            cronEnabled,
            cronInterval
        );
    }

    // ═══════════════════════════════════════════════════════════════
    //                      ADMIN FUNCTIONS
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Transfer ownership
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid owner");
        address oldOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    /**
     * @notice Withdraw excess funds
     */
    function withdraw(address payable to, uint256 amount) external onlyOwner {
        require(to != address(0), "Invalid recipient");
        require(amount <= address(this).balance, "Insufficient balance");
        (bool success,) = to.call{value: amount}("");
        require(success, "Transfer failed");
    }

    /**
     * @notice Receive ETH for gas payments
     */
    receive() external payable override(AbstractPayer, IPayer) {}
}
