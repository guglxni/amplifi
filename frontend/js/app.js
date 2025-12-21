/**
 * YieldOpt Application Core
 * Comprehensive Frontend Integration for Reactive Yield Optimizer
 * 
 * Features Supported:
 * - YieldVaultDualAsset (Aave USDC vs DAI)
 * - YieldVaultCompound (Compound V3)
 * - Funder (Gas Tank + Bridge)
 * - YieldOptimizerReactive (Lasna RSC)
 * - ReactiveFunderRC (Auto-Refill)
 */

const App = {
    // ═══════════════════════════════════════════════════════════════
    //                     CONFIGURATION
    // ═══════════════════════════════════════════════════════════════

    CONFIG: {
        // Sepolia Contracts - All Vaults
        VAULT_DUAL_ASSET: "0xe6e06F94d1aaa2496b9e33afeE29f01436E9fA4A",  // USDC/DAI (supply cap blocked)
        VAULT_WETH_LINK: "0xB67500437583656160B9C6Da2139E5D4289458E2",   // WETH/LINK (works!)
        VAULT_COMPOUND: "0x13c0a04aa10f9eA0847BbFc00CeaB8b85941951a",
        VAULT_MULTI_ASSET: "0x9015fb507E9bE03fB59514ba7a913122e5Fa2e7d", // Multi-Asset (WETH, LINK, AAVE, EURS, WBTC, USDT)
        FUNDER: "0x9f7c78a50379dc4d9703b19c708088d5eac5c923",

        // Reactive Cross-Chain Oracle (reactive-bounty-1)
        // MultiFeedDestinationV2 - Mirrors Chainlink prices from Base Sepolia → Sepolia
        MULTI_FEED_ORACLE: "0x889c32f46E273fBd0d5B1806F3f1286010cD73B3",

        // Chainlink Aggregator Addresses on Base Sepolia (for oracle queries)
        CHAINLINK_ETH_USD: "0xa24A68DD788e1D7eb4CA517765CFb2b7e217e7a3",
        CHAINLINK_BTC_USD: "0x961AD289351459A45fC90884eF3AB0278ea95DDE",
        CHAINLINK_LINK_USD: "0xAc6DB6d5538Cd07f58afee9dA736ce192119017B",

        // Lasna Contracts (Reactive Network)
        YIELD_OPTIMIZER_RSC: "0x98969559717c24b47A2E4365a569c947a88C4767",
        REACTIVE_FUNDER_RC: "0x1caC802c52Cd82b9988e1163aF46258539280E71",

        // Token Addresses (Sepolia) - Assets with NO supply cap
        WETH: "0xC558DBdd856501FCd9aaF1E62eae57A9F0629a3c",
        LINK: "0xf8Fb3713D459D7C1018BD0A49D19b4C44290EBE5",
        AAVE: "0x88541670E55cC00bEEFD87eB59EDd1b7C511AC9a",
        EURS: "0x6d906e526a4e2Ca02097BA9d0caA3c382F52278E",
        WBTC: "0x29f2D40B0605204364af54EC677bD022dA425d03",
        USDT: "0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0",

        // Legacy tokens (supply cap blocked on Aave)
        USDC_AAVE: "0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8",
        DAI_AAVE: "0xFF34B3d4Aee8ddCd6F9AFFFB6Fe49bD371b8a357",
        USDC_CIRCLE: "0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238",

        // Aave Faucet (for minting test tokens)
        AAVE_FAUCET: "0xC959483DBa39aa9E78757139af0e9a2EDEb3f42D",

        // RPCs - Using reliable public endpoints
        SEPOLIA_RPC: "https://ethereum-sepolia.publicnode.com",
        LASNA_RPC: "https://lasna-rpc.rnk.dev",

        // Chain IDs
        SEPOLIA_CHAIN_ID: 11155111,
        LASNA_CHAIN_ID: 5318007
    },

    // ═══════════════════════════════════════════════════════════════
    //                       STATE
    // ═══════════════════════════════════════════════════════════════

    providers: {
        sepolia: null,
        lasna: null
    },
    signer: null,
    contracts: {
        vaultDualAsset: null,
        vaultCompound: null,
        funder: null,
        yieldOptimizerRsc: null,
        reactiveFunderRc: null
    },

    // ═══════════════════════════════════════════════════════════════
    //                    COMPLETE ABIs
    // ═══════════════════════════════════════════════════════════════

    ABIs: {
        // YieldVaultDualAsset - Full ABI
        VaultDualAsset: [
            // Views
            "function getPrimaryAPY() view returns (uint256)",
            "function getSecondaryAPY() view returns (uint256)",
            "function primaryAllocation() view returns (uint256)",
            // Note: secondaryAllocation = 10000 - primaryAllocation (calculated, not stored)
            "function getTotalValueLocked() view returns (uint256)",
            "function lastRebalanceTime() view returns (uint256)",
            "function snapshotCounter() view returns (uint256)",
            "function MIN_REBALANCE_INTERVAL() view returns (uint256)",
            "function owner() view returns (address)",
            "function rvm_id() view returns (address)",
            // Actions
            "function depositPrimary(uint256 amount)",
            "function depositSecondary(uint256 amount)",
            "function withdrawPrimary(uint256 amount)",
            "function withdrawSecondary(uint256 amount)",
            "function triggerYieldSnapshot()",
            "function setRvmId(address _rvmId)",
            // Events
            "event YieldSnapshot(uint256 indexed id, uint256 primaryYield, uint256 secondaryYield, uint256 primaryApy, uint256 secondaryApy, uint256 tvl, uint256 timestamp)",
            "event Rebalanced(uint256 newPrimaryAllocation, uint256 newSecondaryAllocation, uint256 timestamp)",
            "event Deposit(address indexed user, uint256 amount, bool isPrimary)",
            "event Withdraw(address indexed user, uint256 amount, bool isPrimary)"
        ],

        // YieldVaultCompound - Full ABI
        VaultCompound: [
            "function getCompoundAPY() view returns (uint256)",
            "function getUtilization() view returns (uint256)",
            "function getTotalValueLocked() view returns (uint256)",
            "function snapshotCounter() view returns (uint256)",
            "function lastSnapshotTime() view returns (uint256)",
            "function deposit(uint256 amount)",
            "function withdraw(uint256 amount)",
            "function triggerYieldSnapshot()",
            "event YieldSnapshot(uint256 indexed snapshotId, uint256 compoundAPY, uint256 utilization, uint256 tvl, uint256 timestamp)",
            "event Deposited(address indexed user, uint256 amount)",
            "event Withdrawn(address indexed user, uint256 amount)"
        ],

        // YieldVaultWethLink - WETH/LINK vault (NO SUPPLY CAP issues!)
        VaultWethLink: [
            "function getPrimaryAPY() view returns (uint256)",
            "function getSecondaryAPY() view returns (uint256)",
            "function primaryAllocation() view returns (uint256)",
            "function getTotalValueLocked() view returns (uint256)",
            "function getTotalValueLockedUSD() view returns (uint256)",
            "function lastRebalanceTime() view returns (uint256)",
            "function snapshotCounter() view returns (uint256)",
            "function MIN_REBALANCE_INTERVAL() view returns (uint256)",
            "function owner() view returns (address)",
            "function depositPrimary(uint256 amount)",
            "function depositSecondary(uint256 amount)",
            "function withdrawPrimary(uint256 amount)",
            "function withdrawSecondary(uint256 amount)",
            "function triggerYieldSnapshot()",
            "event YieldSnapshot(uint256 indexed id, uint256 primaryAPY, uint256 secondaryAPY, uint256 primaryAlloc, uint256 secondaryAlloc, uint256 tvl, uint256 timestamp)",
            "event Rebalanced(uint256 newPrimaryAlloc, uint256 newSecondaryAlloc)",
            "event Deposited(address indexed user, address token, uint256 amount)",
            "event Withdrawn(address indexed user, address token, uint256 amount)"
        ],

        // YieldVaultMultiAsset - Dynamic multi-asset vault (WETH, LINK, AAVE, EURS)
        VaultMultiAsset: [
            "function aavePool() view returns (address)",
            "function getAssetCount() view returns (uint256)",
            "function assetIds(uint256 index) view returns (uint256)",
            "function assets(uint256 assetId) view returns (address token, address aToken, uint8 decimals, uint256 allocation, uint256 priceUSD, bool active, string symbol)",
            "function tokenToAssetId(address token) view returns (uint256)",
            "function totalAllocation() view returns (uint256)",
            "function snapshotCounter() view returns (uint256)",
            "function lastRebalanceTime() view returns (uint256)",
            "function getAssetAPY(uint256 assetId) view returns (uint256)",
            "function getAssetBalance(uint256 assetId) view returns (uint256)",
            "function getTotalValueLockedUSD() view returns (uint256)",
            "function getBestYieldAsset() view returns (uint256 bestAssetId, uint256 bestAPY)",
            "function getAllAssets() view returns (uint256[] ids, address[] tokens, string[] symbols, uint256[] apys, uint256[] allocations, uint256[] balances)",
            "function deposit(uint256 assetId, uint256 amount)",
            "function depositByToken(address token, uint256 amount)",
            "function withdraw(uint256 assetId, uint256 amount)",
            "function triggerYieldSnapshot()",
            "function addAsset(address token, address aToken, uint8 decimals, uint256 priceUSD, string symbol, uint256 initialAllocation)",
            "function setAllocation(uint256 assetId, uint256 newAllocation)",
            "function updateAssetPrice(uint256 assetId, uint256 newPriceUSD)",
            "event AssetAdded(uint256 indexed assetId, address token, address aToken, string symbol)",
            "event AssetRemoved(uint256 indexed assetId, address token)",
            "event YieldSnapshot(uint256 indexed snapshotId, uint256[] assetIds, uint256[] apys, uint256[] allocations, uint256 totalTvl, uint256 timestamp)",
            "event Deposited(address indexed user, uint256 indexed assetId, address token, uint256 amount)",
            "event Withdrawn(address indexed user, uint256 indexed assetId, address token, uint256 amount)",
            "event Rebalanced(uint256[] assetIds, uint256[] newAllocations)",
            "event AllocationUpdated(uint256 indexed assetId, uint256 newAllocation)"
        ],

        // Funder - Full ABI
        Funder: [
            "function owner() view returns (address)",
            "function targetRsc() view returns (address)",
            "function totalReceived() view returns (uint256)",
            "function totalBridged() view returns (uint256)",
            "function bridgeCount() view returns (uint256)",
            "function gasReserve() view returns (uint256)",
            "function bridgeThreshold() view returns (uint256)",
            "function getStats() view returns (uint256, uint256, uint256, uint256, uint256, address)",
            "function canBridge() view returns (bool)",
            "function getBridgeableAmount() view returns (uint256)",
            "function coverDebt(address reactiveContract)",
            "function bridgeToFaucet(address recipient, uint256 amount)",
            "function autoRefillReact(uint256 amount)",
            "function setTargetRsc(address _targetRsc)",
            "function setGasReserve(uint256 _gasReserve)",
            "function setBridgeThreshold(uint256 _threshold)",
            "function addAuthorizedCaller(address caller)",
            "event FundsReceived(address indexed sender, uint256 amount)",
            "event FundsBridged(address indexed reactiveContract, uint256 amount)",
            "event BridgeFailed(address indexed reactiveContract, uint256 amount, string reason)"
        ],

        // YieldOptimizerReactive - Lasna RSC
        // NOTE: These match the actual YieldOptimizerReactive.sol contract
        YieldOptimizerRsc: [
            "function owner() view returns (address)",
            "function getVault() view returns (address)",
            "function cronMonitoringEnabled() view returns (bool)",
            "function cronInterval() view returns (uint256)",
            "function finalityAwareEnabled() view returns (bool)",
            "function getLastRebalanceBlock() view returns (uint256)",
            "function getChainId() view returns (uint256)",
            "event RebalanceCallbackTriggered(uint256 aaveAPY, uint256 compoundAPY, uint256 newAavePct, uint256 newCompoundPct)",
            "event CronYieldCheckExecuted(uint256 snapshotId, uint256 aaveAPY, uint256 compoundAPY)"
        ],

        // ReactiveFunderRC - Lasna Auto-Refill
        // NOTE: These match the actual ReactiveFunderRC.sol contract
        ReactiveFunderRc: [
            "function owner() view returns (address)",
            "function getFunderContract() view returns (address)",
            "function refillThreshold() view returns (uint256)",
            "function faucetBridgeAmount() view returns (uint256)",
            "function autoRefillEnabled() view returns (bool)",
            "function totalBridged() view returns (uint256)",
            "function bridgeCount() view returns (uint256)",
            "function getStats() view returns (uint256, uint256, address, address)",
            "event BridgeTriggered(address originalSender, uint256 amount, uint256 bridgeAmount, uint256 timestamp)",
            "event AutoRefillTriggered(address recipient, uint256 amount)"
        ],

        // ERC20 Standard
        ERC20: [
            "function approve(address spender, uint256 amount) returns (bool)",
            "function allowance(address owner, address spender) view returns (uint256)",
            "function balanceOf(address account) view returns (uint256)",
            "function decimals() view returns (uint8)",
            "function symbol() view returns (string)"
        ],

        // MultiFeedDestination - Reactive Cross-Chain Oracle (reactive-bounty-1)
        // Mirrors Chainlink prices from Base Sepolia → Ethereum Sepolia
        MultiFeedOracle: [
            "function latestRoundDataForFeed(address originFeed) view returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)",
            "function hasFeedData(address originFeed) view returns (bool)",
            "function decimalsForFeed(address originFeed) view returns (uint8)"
        ]
    },

    // ═══════════════════════════════════════════════════════════════
    //                     INITIALIZATION
    // ═══════════════════════════════════════════════════════════════

    init: async function () {
        console.log("🚀 YieldOpt App Initializing...");

        try {
            // IMPORTANT: ALWAYS use JsonRpcProvider for read operations
            // This ensures data loads even without MetaMask or when wallet is not connected
            // Web3Provider is ONLY used when signer is needed for transactions

            this.providers.sepolia = new ethers.providers.JsonRpcProvider(this.CONFIG.SEPOLIA_RPC);
            this.providers.lasna = new ethers.providers.JsonRpcProvider(this.CONFIG.LASNA_RPC);

            // Initialize Sepolia Contracts with read-only provider
            this.contracts.vaultDualAsset = new ethers.Contract(
                this.CONFIG.VAULT_DUAL_ASSET,
                this.ABIs.VaultDualAsset,
                this.providers.sepolia
            );

            this.contracts.vaultCompound = new ethers.Contract(
                this.CONFIG.VAULT_COMPOUND,
                this.ABIs.VaultCompound,
                this.providers.sepolia
            );

            // WETH/LINK Vault - Works with Aave (no supply cap issues!)
            this.contracts.vaultWethLink = new ethers.Contract(
                this.CONFIG.VAULT_WETH_LINK,
                this.ABIs.VaultWethLink,
                this.providers.sepolia
            );

            // Multi-Asset Vault - Dynamic portfolio (WETH, LINK, AAVE, EURS)
            this.contracts.vaultMultiAsset = new ethers.Contract(
                this.CONFIG.VAULT_MULTI_ASSET,
                this.ABIs.VaultMultiAsset,
                this.providers.sepolia
            );

            this.contracts.funder = new ethers.Contract(
                this.CONFIG.FUNDER,
                this.ABIs.Funder,
                this.providers.sepolia
            );

            // Initialize Lasna Contracts
            this.contracts.yieldOptimizerRsc = new ethers.Contract(
                this.CONFIG.YIELD_OPTIMIZER_RSC,
                this.ABIs.YieldOptimizerRsc,
                this.providers.lasna
            );

            this.contracts.reactiveFunderRc = new ethers.Contract(
                this.CONFIG.REACTIVE_FUNDER_RC,
                this.ABIs.ReactiveFunderRc,
                this.providers.lasna
            );

            // Verify Sepolia Connection
            try {
                const sepoliaBlock = await this.providers.sepolia.getBlockNumber();
                console.log(`✅ Sepolia Connected (Block ${sepoliaBlock})`);
            } catch (e) {
                console.error("❌ Sepolia RPC Failed:", e.message);
                // Try fallback RPC
                this.providers.sepolia = new ethers.providers.JsonRpcProvider("https://rpc.sepolia.org");
                console.log("🔄 Trying fallback Sepolia RPC...");
            }

            // Verify Lasna Connection  
            try {
                const lasnaBlock = await this.providers.lasna.getBlockNumber();
                console.log(`✅ Lasna Connected (Block ${lasnaBlock})`);
            } catch (e) {
                console.warn("⚠️ Lasna RPC unavailable:", e.message);
            }

            this.updateWalletUI();
            return true;

        } catch (e) {
            console.error("❌ Initialization Error:", e);
            this.showToast("Initialization failed: " + e.message, "error");
            return false;
        }
    },

    // ═══════════════════════════════════════════════════════════════
    //                   WALLET CONNECTION
    // ═══════════════════════════════════════════════════════════════

    connectWallet: async function () {
        if (!window.ethereum) {
            this.showToast("Please install MetaMask to connect.", "error");
            return null;
        }

        try {
            await window.ethereum.request({ method: 'eth_requestAccounts' });
            const web3Provider = new ethers.providers.Web3Provider(window.ethereum);
            const network = await web3Provider.getNetwork();

            if (network.chainId !== this.CONFIG.SEPOLIA_CHAIN_ID) {
                this.showToast("Switching to Sepolia...", "info");
                try {
                    await window.ethereum.request({
                        method: 'wallet_switchEthereumChain',
                        params: [{ chainId: '0xaa36a7' }]
                    });
                } catch (e) {
                    this.showToast("Please switch to Sepolia manually.", "error");
                    return null;
                }
            }

            this.signer = web3Provider.getSigner();
            const address = await this.signer.getAddress();

            // Upgrade Sepolia contracts to Signer
            this.contracts.vaultDualAsset = this.contracts.vaultDualAsset.connect(this.signer);
            this.contracts.vaultCompound = this.contracts.vaultCompound.connect(this.signer);
            this.contracts.funder = this.contracts.funder.connect(this.signer);

            this.updateWalletUI(address);
            this.showToast("Wallet Connected!", "success");

            return address;

        } catch (e) {
            console.error("Connection Error:", e);
            this.showToast("Connection failed: " + e.message, "error");
            return null;
        }
    },

    // ═══════════════════════════════════════════════════════════════
    //                    DATA FETCHERS
    // ═══════════════════════════════════════════════════════════════

    /**
     * Fetch all data from YieldVaultDualAsset
     */
    fetchDualAssetData: async function () {
        const vault = this.contracts.vaultDualAsset;
        try {
            // Note: secondaryAllocation is calculated, not stored in contract
            const [pAPY, sAPY, pAlloc, tvl, lastRebal, snapCount] = await Promise.all([
                vault.getPrimaryAPY(),
                vault.getSecondaryAPY(),
                vault.primaryAllocation(),
                vault.getTotalValueLocked(),
                vault.lastRebalanceTime(),
                vault.snapshotCounter()
            ]);

            const primaryAllocNum = pAlloc.toNumber();
            const secondaryAllocNum = 10000 - primaryAllocNum; // Calculate secondary

            return {
                primaryAPY: pAPY.toNumber() / 1000,      // BPS to %
                secondaryAPY: sAPY.toNumber() / 1000,
                primaryAllocation: primaryAllocNum,       // BPS
                secondaryAllocation: secondaryAllocNum,   // Calculated
                tvl: ethers.utils.formatUnits(tvl, 6),   // USDC decimals
                lastRebalanceTime: lastRebal.toNumber(),
                snapshotCount: snapCount.toNumber()
            };
        } catch (e) {
            console.error("DualAsset Fetch Error:", e);
            return null;
        }
    },

    /**
     * Fetch all data from YieldVaultCompound
     */
    fetchCompoundData: async function () {
        const vault = this.contracts.vaultCompound;
        try {
            const [apy, util, tvl, snapCount, lastSnap] = await Promise.all([
                vault.getCompoundAPY(),
                vault.getUtilization(),
                vault.getTotalValueLocked(),
                vault.snapshotCounter(),
                vault.lastSnapshotTime()
            ]);

            // Handle large BigNumbers safely using formatUnits
            // Compound APY might be in 18 decimals or BPS depending on implementation
            let apyValue;
            try {
                // If APY is small enough for toNumber (BPS format)
                apyValue = apy.toNumber() / 1000;
            } catch (e) {
                // If overflow, treat as 18-decimal precision (RAY-like)
                apyValue = parseFloat(ethers.utils.formatUnits(apy, 18)) * 100;
            }

            // Handle utilization similarly
            let utilValue;
            try {
                utilValue = util.toNumber() / 1e16;
            } catch (e) {
                utilValue = parseFloat(ethers.utils.formatUnits(util, 18)) * 100;
            }

            return {
                apy: apyValue,
                utilization: utilValue,
                tvl: ethers.utils.formatUnits(tvl, 6),
                snapshotCount: snapCount.toNumber(),
                lastSnapshotTime: lastSnap.toNumber()
            };
        } catch (e) {
            console.error("Compound Fetch Error:", e);
            return null;
        }
    },

    /**
     * Fetch WETH/LINK Vault Data (Works with Aave - no supply cap!)
     */
    fetchWethLinkData: async function () {
        const vault = this.contracts.vaultWethLink;
        try {
            const [pAPY, sAPY, pAlloc, tvl, tvlUSD, lastRebal, snapCount] = await Promise.all([
                vault.getPrimaryAPY(),
                vault.getSecondaryAPY(),
                vault.primaryAllocation(),
                vault.getTotalValueLocked(),
                vault.getTotalValueLockedUSD(),
                vault.lastRebalanceTime(),
                vault.snapshotCounter()
            ]);

            const primaryAllocNum = pAlloc.toNumber();
            const secondaryAllocNum = 10000 - primaryAllocNum;

            return {
                primaryAPY: pAPY.toNumber() / 1000,      // BPS to %
                secondaryAPY: sAPY.toNumber() / 1000,
                primaryAllocation: primaryAllocNum,
                secondaryAllocation: secondaryAllocNum,
                tvl: ethers.utils.formatEther(tvl),       // 18 decimals (ETH)
                tvlUSD: ethers.utils.formatUnits(tvlUSD, 6), // 6 decimals (USD)
                lastRebalanceTime: lastRebal.toNumber(),
                snapshotCount: snapCount.toNumber(),
                primaryAsset: "WETH",
                secondaryAsset: "LINK"
            };
        } catch (e) {
            console.error("WethLink Fetch Error:", e);
            return null;
        }
    },

    /**
     * Fetch Multi-Asset Vault data (WETH, LINK, AAVE, EURS)
     */
    fetchMultiAssetData: async function () {
        const vault = this.contracts.vaultMultiAsset;
        try {
            // Fetch all core data
            const [tvlUSD, bestYield, allAssets, snapCount, lastRebal, totalAlloc] = await Promise.all([
                vault.getTotalValueLockedUSD(),
                vault.getBestYieldAsset(),
                vault.getAllAssets(),
                vault.snapshotCounter(),
                vault.lastRebalanceTime(),
                vault.totalAllocation()
            ]);

            // Parse the getAllAssets return
            const [ids, tokens, symbols, apys, allocations, balances] = allAssets;

            // Build asset array
            const assets = [];
            for (let i = 0; i < ids.length; i++) {
                assets.push({
                    id: ids[i].toNumber(),
                    token: tokens[i],
                    symbol: symbols[i],
                    apy: apys[i].toNumber() / 1000, // BPS to %
                    allocation: allocations[i].toNumber(),
                    balance: balances[i],
                    balanceFormatted: this.formatAssetBalance(symbols[i], balances[i])
                });
            }

            // Find best asset
            const bestAssetId = bestYield[0].toNumber();
            const bestAPY = bestYield[1].toNumber() / 1000;
            const bestAsset = assets.find(a => a.id === bestAssetId);

            return {
                tvlUSD: ethers.utils.formatUnits(tvlUSD, 6),
                assets: assets,
                bestAsset: bestAsset ? bestAsset.symbol : "N/A",
                bestAPY: bestAPY,
                snapshotCount: snapCount.toNumber(),
                lastRebalanceTime: lastRebal.toNumber(),
                totalAllocation: totalAlloc.toNumber(),
                assetCount: ids.length
            };
        } catch (e) {
            console.error("MultiAsset Fetch Error:", e);
            return null;
        }
    },

    /**
     * Format asset balance based on symbol (handles different decimals)
     */
    formatAssetBalance: function (symbol, balance) {
        const decimalsMap = {
            "WETH": 18,
            "LINK": 18,
            "AAVE": 18,
            "EURS": 2,
            "WBTC": 8,
            "USDT": 6
        };
        const decimals = decimalsMap[symbol] || 18;
        return parseFloat(ethers.utils.formatUnits(balance, decimals)).toFixed(4);
    },

    /**
     * Deposit to Multi-Asset Vault
     */
    depositToMultiAsset: async function (assetId, amount) {
        if (!this.signer) throw new Error("Wallet not connected");
        const vault = this.contracts.vaultMultiAsset.connect(this.signer);
        const tx = await vault.deposit(assetId, amount);
        return tx.wait();
    },

    /**
     * Approve token for Multi-Asset Vault
     */
    approveForMultiAsset: async function (tokenAddress, amount) {
        if (!this.signer) throw new Error("Wallet not connected");
        const token = new ethers.Contract(tokenAddress, this.ABIs.ERC20, this.signer);
        const tx = await token.approve(this.CONFIG.VAULT_MULTI_ASSET, amount);
        return tx.wait();
    },

    /**
     * Trigger yield snapshot on Multi-Asset Vault
     */
    triggerMultiAssetSnapshot: async function () {
        if (!this.signer) throw new Error("Wallet not connected");
        const vault = this.contracts.vaultMultiAsset.connect(this.signer);
        const tx = await vault.triggerYieldSnapshot();
        return tx.wait();
    },

    /**
     * Fetch Funder stats and balance
     * getStats() returns: totalCollected, totalBridged, currentBalance, bridgeThreshold, bridgeCount, targetRsc
     */
    fetchFunderData: async function () {
        const funder = this.contracts.funder;
        try {
            const [balance, stats, canBridge, bridgeable, gasReserve] = await Promise.all([
                this.providers.sepolia.getBalance(this.CONFIG.FUNDER),
                funder.getStats(),
                funder.canBridge(),
                funder.getBridgeableAmount(),
                funder.gasReserve()
            ]);

            // getStats returns: [0]totalCollected, [1]totalBridged, [2]currentBalance, [3]bridgeThreshold, [4]bridgeCount, [5]targetRsc
            return {
                balance: ethers.utils.formatEther(balance),
                totalReceived: ethers.utils.formatEther(stats[0]),  // totalCollected
                totalBridged: ethers.utils.formatEther(stats[1]),   // totalBridged
                currentBalance: ethers.utils.formatEther(stats[2]), // from contract view
                bridgeThreshold: ethers.utils.formatEther(stats[3]),
                bridgeCount: stats[4].toNumber(),                   // Fixed: index 4
                targetRsc: stats[5],
                gasReserve: ethers.utils.formatEther(gasReserve),
                canBridge: canBridge,
                bridgeableAmount: ethers.utils.formatEther(bridgeable)
            };
        } catch (e) {
            console.error("Funder Fetch Error:", e);
            return null;
        }
    },

    /**
     * Fetch Lasna RSC data
     * Uses actual contract functions from YieldOptimizerReactive.sol and ReactiveFunderRC.sol
     */
    fetchRscData: async function () {
        try {
            const rsc = this.contracts.yieldOptimizerRsc;
            const funderRc = this.contracts.reactiveFunderRc;

            // YieldOptimizerReactive functions (actual contract)
            const [cronEnabled, cronInterval, finalityEnabled, lastRebalBlock] = await Promise.all([
                rsc.cronMonitoringEnabled(),
                rsc.cronInterval(),
                rsc.finalityAwareEnabled(),
                rsc.getLastRebalanceBlock()
            ]);

            // ReactiveFunderRc functions (actual contract)
            const [refillThresh, faucetAmt, autoEnabled, rcBridged, rcCount] = await Promise.all([
                funderRc.refillThreshold(),
                funderRc.faucetBridgeAmount(),
                funderRc.autoRefillEnabled(),
                funderRc.totalBridged(),
                funderRc.bridgeCount()
            ]);

            return {
                cronMonitoringEnabled: cronEnabled,
                cronInterval: cronInterval.toNumber(),
                lastRebalanceBlock: lastRebalBlock.toNumber(),
                finalityAwareEnabled: finalityEnabled,
                refillThreshold: ethers.utils.formatEther(refillThresh),
                faucetBridgeAmount: ethers.utils.formatEther(faucetAmt),
                autoRefillEnabled: autoEnabled,
                totalBridgedRc: ethers.utils.formatEther(rcBridged),
                bridgeCountRc: rcCount.toNumber()
            };
        } catch (e) {
            console.warn("RSC Fetch Error (Lasna may be offline):", e);
            return null;
        }
    },

    /**
     * Fetch live prices from Reactive Cross-Chain Oracle (reactive-bounty-1)
     * MultiFeedDestinationV2 mirrors Chainlink prices from Base Sepolia → Sepolia
     * 
     * Supported Feeds:
     * - ETH/USD: 0xa24A68DD788e1D7eb4CA517765CFb2b7e217e7a3
     * - BTC/USD: 0x961AD289351459A45fC90884eF3AB0278ea95DDE
     * - LINK/USD: 0xAc6DB6d5538Cd07f58afee9dA736ce192119017B
     */
    fetchOraclePrices: async function () {
        try {
            const oracle = new ethers.Contract(
                this.CONFIG.MULTI_FEED_ORACLE,
                this.ABIs.MultiFeedOracle,
                this.providers.sepolia
            );

            const feeds = {
                ETH: this.CONFIG.CHAINLINK_ETH_USD,
                BTC: this.CONFIG.CHAINLINK_BTC_USD,
                LINK: this.CONFIG.CHAINLINK_LINK_USD
            };

            const prices = {};

            for (const [symbol, feedAddress] of Object.entries(feeds)) {
                try {
                    const [, answer, , updatedAt,] = await oracle.latestRoundDataForFeed(feedAddress);
                    prices[symbol] = {
                        price: parseFloat(ethers.utils.formatUnits(answer, 8)),
                        priceRaw: answer.toString(),
                        updatedAt: updatedAt.toNumber(),
                        isLive: true
                    };
                } catch (e) {
                    console.warn(`Oracle price fetch failed for ${symbol}:`, e.message);
                    prices[symbol] = { price: 0, isLive: false };
                }
            }

            // Add fallback prices for assets without oracle feeds
            prices.USDT = { price: 1.00, isLive: false, isFallback: true };
            prices.EURS = { price: 1.05, isLive: false, isFallback: true };
            prices.AAVE = { price: 150.00, isLive: false, isFallback: true };

            // Map WETH and WBTC
            prices.WETH = prices.ETH;
            prices.WBTC = prices.BTC;

            return prices;
        } catch (e) {
            console.error("Oracle Fetch Error:", e);
            return null;
        }
    },

    /**
     * Check if oracle has live data for a feed
     */
    hasOracleData: async function (feedAddress) {
        try {
            const oracle = new ethers.Contract(
                this.CONFIG.MULTI_FEED_ORACLE,
                this.ABIs.MultiFeedOracle,
                this.providers.sepolia
            );
            return await oracle.hasFeedData(feedAddress);
        } catch (e) {
            return false;
        }
    },

    // ═══════════════════════════════════════════════════════════════
    //                      ACTIONS
    // ═══════════════════════════════════════════════════════════════

    /**
     * Trigger Yield Snapshot on DualAsset Vault
     */
    triggerSnapshot: async function () {
        if (!this.signer) return this.connectWallet();

        try {
            this.showToast("Triggering Yield Snapshot...", "info");
            const tx = await this.contracts.vaultDualAsset.triggerYieldSnapshot();
            this.showToast("Snapshot TX: " + tx.hash.slice(0, 10) + "...", "success");
            return tx;
        } catch (e) {
            this.showToast("Snapshot failed: " + (e.reason || e.message), "error");
            return null;
        }
    },

    /**
     * Deposit to Primary Pool (Aave USDC)
     */
    depositPrimary: async function (amount) {
        if (!this.signer) return this.connectWallet();

        try {
            this.showToast("Depositing to Aave USDC pool...", "info");
            const tx = await this.contracts.vaultDualAsset.depositPrimary(
                ethers.utils.parseUnits(amount, 6)
            );
            this.showToast("Deposit TX: " + tx.hash.slice(0, 10) + "...", "success");
            return tx;
        } catch (e) {
            this.showToast("Deposit failed: " + (e.reason || e.message), "error");
            return null;
        }
    },

    /**
     * Deposit to Secondary Pool (Aave DAI)
     */
    depositSecondary: async function (amount) {
        if (!this.signer) return this.connectWallet();

        try {
            this.showToast("Depositing to Aave DAI pool...", "info");
            const tx = await this.contracts.vaultDualAsset.depositSecondary(
                ethers.utils.parseUnits(amount, 18) // DAI has 18 decimals
            );
            this.showToast("Deposit TX: " + tx.hash.slice(0, 10) + "...", "success");
            return tx;
        } catch (e) {
            this.showToast("Deposit failed: " + (e.reason || e.message), "error");
            return null;
        }
    },

    /**
     * Deposit to Compound V3 Vault
     */
    depositCompound: async function (amount) {
        if (!this.signer) return this.connectWallet();

        try {
            this.showToast("Depositing to Compound V3...", "info");
            const tx = await this.contracts.vaultCompound.deposit(
                ethers.utils.parseUnits(amount, 6)
            );
            this.showToast("Deposit TX: " + tx.hash.slice(0, 10) + "...", "success");
            return tx;
        } catch (e) {
            this.showToast("Deposit failed: " + (e.reason || e.message), "error");
            return null;
        }
    },

    /**
     * Send ETH to Funder (Refill Gas Tank)
     */
    refillFunder: async function (ethAmount) {
        if (!this.signer) return this.connectWallet();

        try {
            this.showToast("Refilling Funder Gas Tank...", "info");
            const tx = await this.signer.sendTransaction({
                to: this.CONFIG.FUNDER,
                value: ethers.utils.parseEther(ethAmount)
            });
            this.showToast("Refill TX: " + tx.hash.slice(0, 10) + "...", "success");
            return tx;
        } catch (e) {
            this.showToast("Refill failed: " + (e.reason || e.message), "error");
            return null;
        }
    },

    /**
     * Trigger coverDebt on Funder
     */
    coverDebt: async function () {
        if (!this.signer) return this.connectWallet();

        try {
            this.showToast("Bridging funds to RSC...", "info");
            const tx = await this.contracts.funder.coverDebt(this.CONFIG.YIELD_OPTIMIZER_RSC);
            this.showToast("Bridge TX: " + tx.hash.slice(0, 10) + "...", "success");
            return tx;
        } catch (e) {
            this.showToast("Bridge failed: " + (e.reason || e.message), "error");
            return null;
        }
    },

    /**
     * Bridge to Faucet (SepETH → REACT)
     */
    bridgeToFaucet: async function (ethAmount) {
        if (!this.signer) return this.connectWallet();

        try {
            this.showToast("Converting SepETH to REACT...", "info");
            const tx = await this.contracts.funder.bridgeToFaucet(
                this.CONFIG.YIELD_OPTIMIZER_RSC,
                ethers.utils.parseEther(ethAmount)
            );
            this.showToast("Faucet TX: " + tx.hash.slice(0, 10) + "...", "success");
            return tx;
        } catch (e) {
            this.showToast("Faucet bridge failed: " + (e.reason || e.message), "error");
            return null;
        }
    },

    // ═══════════════════════════════════════════════════════════════
    //                    UI UTILITIES
    // ═══════════════════════════════════════════════════════════════

    showToast: function (msg, type) {
        let toast = document.getElementById('app-toast');
        if (!toast) {
            toast = document.createElement('div');
            toast.id = 'app-toast';
            toast.style.cssText = `
                position: fixed; top: 20px; right: 20px; padding: 1rem 1.5rem; 
                background: var(--color-bg-panel); border: 1px solid var(--color-border); 
                border-radius: 12px; backdrop-filter: blur(12px); z-index: 9999;
                box-shadow: 0 4px 12px rgba(0,0,0,0.3); transition: all 0.3s ease;
                transform: translateY(-20px); opacity: 0; color: var(--color-text-main); 
                font-weight: 600; max-width: 400px;
            `;
            document.body.appendChild(toast);
        }

        const colors = {
            success: 'var(--color-success)',
            error: '#ef4444',
            info: 'var(--color-primary)'
        };

        toast.style.borderLeft = `4px solid ${colors[type] || colors.info}`;
        toast.innerText = msg;

        requestAnimationFrame(() => {
            toast.style.transform = 'translateY(0)';
            toast.style.opacity = '1';
        });

        setTimeout(() => {
            toast.style.transform = 'translateY(-20px)';
            toast.style.opacity = '0';
        }, 4000);
    },

    updateWalletUI: function (address) {
        const dot = document.getElementById('status-dot');
        const txt = document.getElementById('wallet-text');
        const btn = document.getElementById('wallet-btn');

        if (address) {
            if (dot) dot.classList.remove('offline');
            if (txt) txt.innerText = `${address.slice(0, 6)}...${address.slice(-4)}`;
        } else {
            if (dot) dot.classList.add('offline');
            if (txt) txt.innerText = "Connect Wallet";
            if (btn) btn.onclick = () => this.connectWallet();
        }
    },

    // ═══════════════════════════════════════════════════════════════
    //                    FORMATTING UTILITIES
    // ═══════════════════════════════════════════════════════════════

    formatAPY: (apy) => apy.toFixed(2) + "%",
    formatUSD: (val) => "$" + parseFloat(val).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 }),
    formatETH: (val) => parseFloat(val).toFixed(4) + " ETH",
    formatBPS: (bps) => (bps / 100).toFixed(1) + "%",
    formatTimestamp: (ts) => {
        if (ts === 0) return "Never";
        const d = new Date(ts * 1000);
        return d.toLocaleString();
    },
    timeAgo: (ts) => {
        if (ts === 0) return "Never";
        const seconds = Math.floor(Date.now() / 1000) - ts;
        if (seconds < 60) return seconds + "s ago";
        if (seconds < 3600) return Math.floor(seconds / 60) + "m ago";
        if (seconds < 86400) return Math.floor(seconds / 3600) + "h ago";
        return Math.floor(seconds / 86400) + "d ago";
    }
};

// Export for use in HTML
window.App = App;
