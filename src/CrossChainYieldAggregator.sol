// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AbstractReactive} from "@reactive/abstract-base/AbstractReactive.sol";
import {AbstractPayer} from "@reactive/abstract-base/AbstractPayer.sol";
import {IReactive} from "@reactive/interfaces/IReactive.sol";
import {IPayer} from "@reactive/interfaces/IPayer.sol";

/**
 * @title CrossChainYieldAggregator
 * @notice Reactive Smart Contract for true cross-chain yield monitoring
 * @dev Subscribes to Aave events on multiple chains and identifies optimal yield opportunities
 * 
 * Architecture:
 * - Subscribes to ReserveDataUpdated events from Aave pools on multiple chains
 * - Aggregates yield data across all monitored chains
 * - Identifies best yield opportunities and triggers cross-chain migrations
 * 
 * Supported Chains:
 * - Sepolia (Ethereum testnet)
 * - Arbitrum Sepolia
 * - Optimism Sepolia
 * - Base Sepolia
 * 
 * Reference: Reactive Network's cross-chain messaging capabilities
 * and "True Cross-Chain Yield Aggregation" enhancement proposal
 */
contract CrossChainYieldAggregator is IReactive, AbstractReactive {
    // ═══════════════════════════════════════════════════════════════
    //                         CONSTANTS
    // ═══════════════════════════════════════════════════════════════

    /// @notice Chain IDs for supported networks
    uint256 public constant SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant ARBITRUM_SEPOLIA_CHAIN_ID = 421614;
    uint256 public constant OPTIMISM_SEPOLIA_CHAIN_ID = 11155420;
    uint256 public constant BASE_SEPOLIA_CHAIN_ID = 84532;
    
    /// @notice Default callback gas limit
    uint64 private constant CALLBACK_GAS_LIMIT = 400000;
    
    /// @notice Reserve data updated event signature
    /// @dev keccak256("ReserveDataUpdated(address,uint256,uint256,uint256,uint256)")
    bytes32 private constant RESERVE_UPDATED_TOPIC_0 = 
        keccak256("ReserveDataUpdated(address,uint256,uint256,uint256,uint256)");
    
    /// @notice Minimum yield difference to trigger migration (50 bps = 0.5%)
    uint256 public constant MIN_YIELD_DIFF_BPS = 50;
    
    /// @notice Maximum basis points
    uint256 public constant MAX_BPS = 10000;
    
    /// @notice Ray unit for Aave rates (1e27)
    uint256 private constant RAY = 1e27;

    // ═══════════════════════════════════════════════════════════════
    //                         STRUCTS
    // ═══════════════════════════════════════════════════════════════

    /// @notice Chain configuration
    struct ChainConfig {
        uint256 chainId;
        address aavePool;
        address vault;           // Our vault on this chain
        address bridgeAdapter;   // Bridge adapter for this chain
        bool active;
        string name;
    }
    
    /// @notice Yield data for an asset on a chain
    struct YieldData {
        uint256 chainId;
        address asset;
        uint256 supplyRate;      // Current supply APY (in ray)
        uint256 lastUpdated;
        bool stale;
    }
    
    /// @notice Migration request
    struct MigrationRequest {
        uint256 fromChainId;
        uint256 toChainId;
        address asset;
        uint256 amount;
        uint256 expectedYieldGain;
        uint256 timestamp;
        bool executed;
    }

    // ═══════════════════════════════════════════════════════════════
    //                         STATE
    // ═══════════════════════════════════════════════════════════════

    /// @notice Owner address
    address public owner;
    
    /// @notice Current chain (where our primary vault is)
    uint256 public homeChainId;
    
    /// @notice Home vault address
    address public homeVault;
    
    /// @notice Chain configurations
    mapping(uint256 => ChainConfig) public chainConfigs;
    
    /// @notice Active chain IDs for iteration
    uint256[] public activeChains;
    
    /// @notice Yield data: chainId => asset => YieldData
    mapping(uint256 => mapping(address => YieldData)) public yieldData;
    
    /// @notice Tracked assets
    address[] public trackedAssets;
    
    /// @notice Migration request counter
    uint256 public migrationCounter;
    
    /// @notice Migration requests
    mapping(uint256 => MigrationRequest) public migrations;
    
    /// @notice Total migrations executed
    uint256 public totalMigrations;
    
    /// @notice Paused state
    bool public paused;
    
    /// @notice Staleness threshold (1 hour)
    uint256 public stalenessThreshold = 1 hours;

    // ═══════════════════════════════════════════════════════════════
    //                         EVENTS
    // ═══════════════════════════════════════════════════════════════

    event YieldUpdated(
        uint256 indexed chainId,
        address indexed asset,
        uint256 supplyRate,
        uint256 timestamp
    );
    
    event BestYieldIdentified(
        address indexed asset,
        uint256 bestChainId,
        uint256 bestRate,
        uint256 currentChainRate
    );
    
    event MigrationInitiated(
        uint256 indexed migrationId,
        address indexed asset,
        uint256 fromChainId,
        uint256 toChainId,
        uint256 amount
    );
    
    event ChainConfigured(uint256 indexed chainId, address aavePool, address vault);

    // ═══════════════════════════════════════════════════════════════
    //                         ERRORS
    // ═══════════════════════════════════════════════════════════════

    error OnlyOwner();
    error ZeroAddress();
    error ChainNotConfigured();
    error Paused();

    // ═══════════════════════════════════════════════════════════════
    //                         MODIFIERS
    // ═══════════════════════════════════════════════════════════════

    modifier onlyOwner() {
        if (msg.sender != owner) revert OnlyOwner();
        _;
    }
    
    modifier whenNotPaused() {
        if (paused) revert Paused();
        _;
    }

    // ═══════════════════════════════════════════════════════════════
    //                         CONSTRUCTOR
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Initialize the cross-chain yield aggregator
     * @param _homeChainId Primary chain ID
     * @param _homeVault Home vault address
     */
    constructor(
        uint256 _homeChainId,
        address _homeVault
    ) payable {
        if (_homeVault == address(0)) revert ZeroAddress();
        
        owner = msg.sender;
        homeChainId = _homeChainId;
        homeVault = _homeVault;
    }

    // ═══════════════════════════════════════════════════════════════
    //                    CHAIN CONFIGURATION
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Configure a chain for yield monitoring
     * @param chainId Chain ID
     * @param aavePool Aave Pool address on that chain
     * @param vault Our vault address on that chain
     * @param bridgeAdapter Bridge adapter for cross-chain transfers
     * @param name Human-readable chain name
     */
    function configureChain(
        uint256 chainId,
        address aavePool,
        address vault,
        address bridgeAdapter,
        string calldata name
    ) external onlyOwner {
        if (aavePool == address(0)) revert ZeroAddress();
        
        chainConfigs[chainId] = ChainConfig({
            chainId: chainId,
            aavePool: aavePool,
            vault: vault,
            bridgeAdapter: bridgeAdapter,
            active: true,
            name: name
        });
        
        // Add to active chains if not already present
        bool exists = false;
        for (uint256 i = 0; i < activeChains.length; i++) {
            if (activeChains[i] == chainId) {
                exists = true;
                break;
            }
        }
        if (!exists) {
            activeChains.push(chainId);
        }
        
        emit ChainConfigured(chainId, aavePool, vault);
    }
    
    /**
     * @notice Add an asset to track
     * @param asset Asset address
     */
    function addTrackedAsset(address asset) external onlyOwner {
        if (asset == address(0)) revert ZeroAddress();
        trackedAssets.push(asset);
    }

    // ═══════════════════════════════════════════════════════════════
    //                    SUBSCRIPTION MANAGEMENT
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Subscribe to yield events from a specific chain
     * @param chainId Chain ID to subscribe to
     */
    function subscribeToChain(uint256 chainId) external rnOnly {
        ChainConfig storage config = chainConfigs[chainId];
        if (!config.active) revert ChainNotConfigured();
        
        service.subscribe(
            chainId,
            config.aavePool,
            uint256(RESERVE_UPDATED_TOPIC_0),
            REACTIVE_IGNORE,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE
        );
    }
    
    /**
     * @notice Subscribe to all configured chains
     */
    function subscribeToAllChains() external rnOnly {
        for (uint256 i = 0; i < activeChains.length; i++) {
            ChainConfig storage config = chainConfigs[activeChains[i]];
            if (config.active) {
                service.subscribe(
                    config.chainId,
                    config.aavePool,
                    uint256(RESERVE_UPDATED_TOPIC_0),
                    REACTIVE_IGNORE,
                    REACTIVE_IGNORE,
                    REACTIVE_IGNORE
                );
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    //                    REACTIVE FUNCTION
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice React to ReserveDataUpdated events
     * @param log The log record from the event
     */
    function react(IReactive.LogRecord calldata log) external override vmOnly whenNotPaused {
        // Validate origin chain
        ChainConfig storage config = chainConfigs[log.chain_id];
        if (!config.active) {
            return;
        }
        if (log._contract != config.aavePool) {
            return;
        }
        
        // Decode reserve data update
        // Expected: ReserveDataUpdated(address indexed asset, uint256 liquidityRate, ...)
        address asset = address(uint160(uint256(log.topic_1)));
        (uint256 liquidityRate,,,) = abi.decode(log.data, (uint256, uint256, uint256, uint256));
        
        // Update yield data
        _updateYieldData(log.chain_id, asset, liquidityRate);
        
        // Check if migration is beneficial
        _checkMigrationOpportunity(asset);
    }
    
    /**
     * @notice Update yield data for an asset on a chain
     */
    function _updateYieldData(
        uint256 chainId,
        address asset,
        uint256 supplyRate
    ) internal {
        yieldData[chainId][asset] = YieldData({
            chainId: chainId,
            asset: asset,
            supplyRate: supplyRate,
            lastUpdated: block.timestamp,
            stale: false
        });
        
        emit YieldUpdated(chainId, asset, supplyRate, block.timestamp);
    }
    
    /**
     * @notice Check if migration is beneficial for an asset
     */
    function _checkMigrationOpportunity(address asset) internal {
        (uint256 bestChainId, uint256 bestRate) = _findBestYield(asset);
        
        if (bestChainId == 0 || bestChainId == homeChainId) {
            return; // Already on best chain or no data
        }
        
        uint256 currentRate = yieldData[homeChainId][asset].supplyRate;
        
        // Check if yield difference exceeds threshold
        if (bestRate > currentRate) {
            uint256 difference = bestRate - currentRate;
            uint256 diffBps = (difference * MAX_BPS) / (currentRate > 0 ? currentRate : 1);
            
            if (diffBps >= MIN_YIELD_DIFF_BPS) {
                _initiateMigration(asset, homeChainId, bestChainId, bestRate, currentRate);
            }
        }
        
        emit BestYieldIdentified(asset, bestChainId, bestRate, currentRate);
    }
    
    /**
     * @notice Find the best yield for an asset across all chains
     */
    function _findBestYield(address asset) internal view returns (uint256 bestChainId, uint256 bestRate) {
        for (uint256 i = 0; i < activeChains.length; i++) {
            uint256 chainId = activeChains[i];
            YieldData storage data = yieldData[chainId][asset];
            
            if (data.lastUpdated == 0) continue; // No data
            if (block.timestamp - data.lastUpdated > stalenessThreshold) continue; // Stale
            
            if (data.supplyRate > bestRate) {
                bestRate = data.supplyRate;
                bestChainId = chainId;
            }
        }
    }
    
    /**
     * @notice Initiate a cross-chain migration
     */
    function _initiateMigration(
        address asset,
        uint256 fromChainId,
        uint256 toChainId,
        uint256 newRate,
        uint256 oldRate
    ) internal {
        migrationCounter++;
        
        // Calculate expected yield gain (simplified)
        uint256 expectedGain = (newRate - oldRate);
        
        migrations[migrationCounter] = MigrationRequest({
            fromChainId: fromChainId,
            toChainId: toChainId,
            asset: asset,
            amount: 0, // Would be calculated based on vault balance
            expectedYieldGain: expectedGain,
            timestamp: block.timestamp,
            executed: false
        });
        
        // Emit callback to initiate withdrawal on home chain
        ChainConfig storage toConfig = chainConfigs[toChainId];
        
        emit Callback(
            fromChainId,
            homeVault,
            CALLBACK_GAS_LIMIT,
            abi.encodeWithSignature(
                "initiateCrossChainMigration(address,uint256,address)",
                asset,
                toChainId,
                toConfig.vault
            )
        );
        
        totalMigrations++;
        
        emit MigrationInitiated(migrationCounter, asset, fromChainId, toChainId, 0);
    }

    // ═══════════════════════════════════════════════════════════════
    //                    ADMIN FUNCTIONS
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Transfer ownership
     */
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        owner = newOwner;
    }
    
    /**
     * @notice Set home vault
     */
    function setHomeVault(address vault) external onlyOwner {
        if (vault == address(0)) revert ZeroAddress();
        homeVault = vault;
    }
    
    /**
     * @notice Set staleness threshold
     */
    function setStalenessThreshold(uint256 threshold) external onlyOwner {
        stalenessThreshold = threshold;
    }
    
    /**
     * @notice Pause aggregator
     */
    function pause() external onlyOwner {
        paused = true;
    }
    
    /**
     * @notice Unpause aggregator
     */
    function unpause() external onlyOwner {
        paused = false;
    }

    // ═══════════════════════════════════════════════════════════════
    //                    VIEW FUNCTIONS
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Get all active chains
     */
    function getActiveChains() external view returns (uint256[] memory) {
        return activeChains;
    }
    
    /**
     * @notice Get tracked assets
     */
    function getTrackedAssets() external view returns (address[] memory) {
        return trackedAssets;
    }
    
    /**
     * @notice Get yield data for an asset across all chains
     * @param asset Asset address
     */
    function getYieldComparison(address asset) external view returns (
        uint256[] memory chainIds,
        uint256[] memory rates,
        uint256[] memory timestamps
    ) {
        uint256 len = activeChains.length;
        chainIds = new uint256[](len);
        rates = new uint256[](len);
        timestamps = new uint256[](len);
        
        for (uint256 i = 0; i < len; i++) {
            uint256 chainId = activeChains[i];
            chainIds[i] = chainId;
            rates[i] = yieldData[chainId][asset].supplyRate;
            timestamps[i] = yieldData[chainId][asset].lastUpdated;
        }
    }
    
    /**
     * @notice Get migration stats
     */
    function getStats() external view returns (
        uint256 chainCount,
        uint256 assetCount,
        uint256 totalMigs,
        bool isPaused
    ) {
        return (
            activeChains.length,
            trackedAssets.length,
            totalMigrations,
            paused
        );
    }
    
    /**
     * @notice Convert ray rate to APY percentage
     * @param rayRate Rate in ray (1e27)
     */
    function rayToApy(uint256 rayRate) external pure returns (uint256 apyBps) {
        // Simplified conversion: rate * 100 * 10000 / RAY
        return (rayRate * 1000000) / RAY;
    }
    
    /**
     * @notice Receive function for REACT tokens
     */
    receive() external payable override(AbstractPayer, IPayer) {}
}
