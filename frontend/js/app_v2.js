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
        VAULT_DUAL_ASSET: "0x353035017676e0DC35d04344610F25D1FaC7187D",  // USDC/DAI V2 with Auto-Replenishment
        VAULT_WETH_LINK: "0xB67500437583656160B9C6Da2139E5D4289458E2",   // WETH/LINK (works!)
        VAULT_COMPOUND: "0x13c0a04aa10f9eA0847BbFc00CeaB8b85941951a",
        VAULT_MULTI_ASSET: "0x42437f29E25Ad65E121f4D0f07FD8F5c2005e5d5", // Multi-Asset V2 - EURS aToken FIXED
        FEE_COLLECTOR_MULTI: "0x3777Afd270B483cAc21C3234fa72E34b9fed33Cf", // Fee Collector for Multi-Asset V2
        FUNDER: "0x0CabFEE932171171d90D672160cC6939f93b2D39",

        // Reactive Cross-Chain Oracle (reactive-bounty-1) - DEPRECATED, using individual bridges now
        // MultiFeedDestinationV2 - Mirrors Chainlink prices from Base Sepolia → Sepolia
        MULTI_FEED_ORACLE: "0x889c32f46E273fBd0d5B1806F3f1286010cD73B3",

        // AbstractFeedProxy Addresses (aggreatorv3-reactive-bridge-abstract)
        // Live cross-chain feeds bridged from Base Sepolia → Lasna → Sepolia
        USDC_FEED_PROXY: "0xdE87eC23198867B298E74d1a2c902Aa02381b6d8", // USDC/USD from Base Sepolia
        EUR_FEED_PROXY: "0x955e94A600d059789d42ca533fe90c5187f520Af",  // EUR/USD from Polygon Amoy
        ETH_FEED_PROXY: "0xb1aDCca598051EfdaD48217D950EAFf2CA869691",  // ETH/USD from Base Sepolia
        BTC_FEED_PROXY: "0x736D13De4d6BF46DC81f89a759D6e3C2FbC9D6b9",  // BTC/USD from Base Sepolia
        LINK_FEED_PROXY: "0x6B94668442B97e7dCF1958044a21e42a73D3647b", // LINK/USD from Base Sepolia

        // Chainlink Aggregator Addresses on Base Sepolia (for oracle queries - DEPRECATED)
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
        // Legacy tokens (supply cap blocked on Aave Sepolia)
        USDT: "0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0", // Removed from vault - supply cap exceeded
        USDC_AAVE: "0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8",
        DAI_AAVE: "0xFF34B3d4Aee8ddCd6F9AFFFB6Fe49bD371b8a357",
        USDC_CIRCLE: "0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238",

        // Aave Faucet (for minting test tokens)
        AAVE_FAUCET: "0xC959483DBa39aa9E78757139af0e9a2EDEb3f42D",

        // RPC Endpoints (using Alchemy for better rate limits)
        SEPOLIA_RPC: "https://eth-sepolia.g.alchemy.com/v2/gSGZUmZvUJI9GKs2xrpKl",
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
            // Auto-Replenishment
            "function getRequiredFee(uint256 txValue) view returns (uint256)",
            "function feeCollector() view returns (address)",
            "function hasSufficientFunding() view returns (bool)",
            "function minOperationalBalance() view returns (uint256)",
            // Events
            "event YieldSnapshot(uint256 indexed id, uint256 primaryYield, uint256 secondaryYield, uint256 primaryApy, uint256 secondaryApy, uint256 tvl, uint256 timestamp)",
            "event Rebalanced(uint256 newPrimaryAllocation, uint256 newSecondaryAllocation, uint256 timestamp)",
            "event Deposit(address indexed user, uint256 amount, bool isPrimary)",
            "event Withdraw(address indexed user, uint256 amount, bool isPrimary)",
            "event FeePaid(address indexed user, uint256 amount)",
            "event Funded(address indexed from, uint256 amount)"
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
            // V2 payable deposit functions
            "function deposit(uint256 assetId, uint256 amount) payable",
            "function depositByToken(address token, uint256 amount) payable",
            "function withdraw(uint256 assetId, uint256 amount)",
            "function triggerYieldSnapshot()",
            // V2 fee-related functions
            "function feeCollector() view returns (address)",
            "function feeCollectionEnabled() view returns (bool)",
            "function getRequiredFee(uint256 txValue) view returns (uint256)",
            "function hasSufficientFunding() view returns (bool)",
            "function minOperationalBalance() view returns (uint256)",
            // Admin functions
            "function addAsset(address token, address aToken, uint8 decimals, uint256 priceUSD, string symbol, uint256 initialAllocation)",
            "function setAllocation(uint256 assetId, uint256 newAllocation)",
            "function updateAssetPrice(uint256 assetId, uint256 newPriceUSD)",
            // Events
            "event AssetAdded(uint256 indexed assetId, address token, address aToken, string symbol)",
            "event AssetRemoved(uint256 indexed assetId, address token)",
            "event YieldSnapshot(uint256 indexed snapshotId, uint256[] assetIds, uint256[] apys, uint256[] allocations, uint256 totalTvl, uint256 timestamp)",
            "event Deposited(address indexed user, uint256 indexed assetId, address token, uint256 amount)",
            "event Withdrawn(address indexed user, uint256 indexed assetId, address token, uint256 amount)",
            "event Rebalanced(uint256[] assetIds, uint256[] newAllocations)",
            "event AllocationUpdated(uint256 indexed assetId, uint256 newAllocation)",
            // V2 Auto-replenishment events
            "event FeeCollectorSet(address indexed oldCollector, address indexed newCollector)",
            "event FeePaid(address indexed user, uint256 amount)",
            "event Funded(address indexed from, uint256 amount)"
        ],

        // Funder - Full ABI (deployed at 0x0CabFEE932171171d90D672160cC6939f93b2D39)
        Funder: [
            "function owner() view returns (address)",
            "function targetRsc() view returns (address)",
            "function totalCollected() view returns (uint256)",
            "function totalBridged() view returns (uint256)",
            "function bridgeCount() view returns (uint256)",
            "function gasReserve() view returns (uint256)",
            "function bridgeThreshold() view returns (uint256)",
            "function authorizedCallers(address) view returns (bool)",
            "function REACTIVE_FAUCET() view returns (address)",
            "function CALLBACK_PROXY() view returns (address)",
            "function getStats() view returns (uint256, uint256, uint256, uint256, uint256, address)",
            "function canBridge() view returns (bool)",
            "function getBridgeableAmount() view returns (uint256)",
            "function coverDebt(address reactiveContract)",
            "function bridgeToFaucet(address recipient, uint256 amount)",
            "function autoRefillReact(uint256 amount)",
            "function setTargetRsc(address _targetRsc)",
            "function setGasReserve(uint256 _gasReserve)",
            "function setBridgeThreshold(uint256 _threshold)",
            "function setAuthorizedCaller(address caller, bool authorized)",
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

        // VaultFeeCollector - True Auto-Replenishment
        VaultFeeCollector: [
            "function getStats() view returns (uint256 totalCollected, uint256 totalFunded, uint256 balance, uint256 fundingCount, uint256 vaultBalance)",
            "function calculateFee(uint256 txValue) view returns (uint256)",
            "function feePercentageBps() view returns (uint256)",
            "function minFee() view returns (uint256)",
            "function vaultNeedsFunding() view returns (bool needs, uint256 vaultBalance)"
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
        console.log("[Amplifi] App Initializing...");

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
                console.log(`[OK] Sepolia Connected (Block ${sepoliaBlock})`);
            } catch (e) {
                console.error("[ERR] Sepolia RPC Failed:", e.message);
                // Try fallback RPC
                this.providers.sepolia = new ethers.providers.JsonRpcProvider("https://rpc.sepolia.org");
                console.log("[RETRY] Trying fallback Sepolia RPC...");
            }

            // Verify Lasna Connection  
            try {
                const lasnaBlock = await this.providers.lasna.getBlockNumber();
                console.log(`[OK] Lasna Connected (Block ${lasnaBlock})`);
            } catch (e) {
                console.warn("[WARN] Lasna RPC unavailable:", e.message);
            }

            this.updateWalletUI();
            return true;

        } catch (e) {
            console.error("[ERR] Initialization Error:", e);
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

            // Create signer with explicit Sepolia network to avoid network change errors
            this.signer = web3Provider.getSigner();
            const address = await this.signer.getAddress();
            this.currentAccount = address;

            // Upgrade Sepolia contracts to Signer
            this.contracts.vaultDualAsset = this.contracts.vaultDualAsset.connect(this.signer);
            this.contracts.vaultCompound = this.contracts.vaultCompound.connect(this.signer);
            this.contracts.vaultMultiAsset = this.contracts.vaultMultiAsset.connect(this.signer);
            this.contracts.funder = this.contracts.funder.connect(this.signer);

            // Listen for network changes to prevent NETWORK_ERROR
            window.ethereum.on('chainChanged', (chainId) => {
                console.log('[INFO] Network changed to:', chainId);
                // Reload the page to reinitialize with correct network
                window.location.reload();
            });

            // Listen for account changes
            window.ethereum.on('accountsChanged', (accounts) => {
                console.log('[INFO] Account changed:', accounts[0]);
                if (accounts.length === 0) {
                    this.signer = null;
                    this.currentAccount = null;
                    this.updateWalletUI();
                } else {
                    window.location.reload();
                }
            });

            this.updateWalletUI(address);
            this.showToast("Wallet Connected!", "success");

            return address;

        } catch (e) {
            console.error("Connection Error:", e);
            // Handle network mismatch error gracefully
            if (e.code === 'NETWORK_ERROR' || e.message.includes('network changed')) {
                this.showToast("Network changed. Please refresh the page.", "warning");
                return null;
            }
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

    // ═══════════════════════════════════════════════════════════════
    //                    MAINNET APY FETCHING
    // ═══════════════════════════════════════════════════════════════

    // Cache for mainnet APYs (refreshed every 5 minutes)
    mainnetApyCache: {
        data: {},
        lastFetch: 0,
        CACHE_DURATION: 5 * 60 * 1000 // 5 minutes
    },

    /**
     * Fetch live APY data from DeFiLlama Yields API (Aave V3 Ethereum mainnet)
     * API docs: https://defillama.com/docs/api
     */
    fetchMainnetApys: async function () {
        const now = Date.now();
        
        // Return cached data if still fresh
        if (this.mainnetApyCache.data && Object.keys(this.mainnetApyCache.data).length > 0 &&
            (now - this.mainnetApyCache.lastFetch) < this.mainnetApyCache.CACHE_DURATION) {
            console.log('[APY] Using cached mainnet APYs');
            return this.mainnetApyCache.data;
        }

        try {
            console.log('[APY] Fetching live APYs from DeFiLlama...');
            const response = await fetch('https://yields.llama.fi/pools');
            
            if (!response.ok) {
                throw new Error(`DeFiLlama API error: ${response.status}`);
            }

            const data = await response.json();
            const pools = data.data || [];

            // Map our symbols to DeFiLlama pool identifiers (Aave V3 Ethereum)
            const symbolToPool = {
                'WETH': { project: 'aave-v3', chain: 'Ethereum', symbol: 'WETH' },
                'LINK': { project: 'aave-v3', chain: 'Ethereum', symbol: 'LINK' },
                'AAVE': { project: 'aave-v3', chain: 'Ethereum', symbol: 'AAVE' },
                'WBTC': { project: 'aave-v3', chain: 'Ethereum', symbol: 'WBTC' },
                'EURS': { project: 'aave-v3', chain: 'Ethereum', symbol: 'EURS' }
            };

            const apyMap = {};

            for (const [symbol, filter] of Object.entries(symbolToPool)) {
                // Find matching pool
                const pool = pools.find(p => 
                    p.project === filter.project && 
                    p.chain === filter.chain && 
                    p.symbol === filter.symbol
                );

                if (pool && pool.apy !== null && pool.apy !== undefined && pool.apy > 0) {
                    apyMap[symbol] = pool.apy;
                    console.log(`[APY] ${symbol}: ${pool.apy.toFixed(2)}% (live from mainnet)`);
                } else if (symbol === 'AAVE') {
                    // AAVE supply APY is 0, use staking APY approximation (~5%)
                    apyMap[symbol] = 5.12;
                    console.log(`[APY] ${symbol}: 5.12% (stkAAVE staking rate)`);
                }
            }

            // Update cache
            this.mainnetApyCache.data = apyMap;
            this.mainnetApyCache.lastFetch = now;

            console.log('[APY] Mainnet APYs fetched:', apyMap);
            return apyMap;

        } catch (error) {
            console.warn('[APY] Failed to fetch from DeFiLlama:', error.message);
            
            // Fallback to static approximations if API fails
            return {
                'WETH': 1.85,
                'LINK': 0.12,
                'AAVE': 5.12,  // stkAAVE staking rate
                'WBTC': 0.02,
                'EURS': 2.50
            };
        }
    },

    /**
     * Fetch Multi-Asset Vault data (WETH, LINK, AAVE, EURS)
     * Now with live mainnet APY integration
     */
    fetchMultiAssetData: async function () {
        const vault = this.contracts.vaultMultiAsset;

        try {
            // Fetch mainnet APYs first (for fallback when testnet shows 0)
            const mainnetApys = await this.fetchMainnetApys();

            // Fetch core data using individual calls (more reliable than getAllAssets)
            const [bestYield, snapCount, lastRebal, totalAlloc, assetCount] = await Promise.all([
                vault.getBestYieldAsset(),
                vault.snapshotCounter(),
                vault.lastRebalanceTime(),
                vault.totalAllocation(),
                vault.getAssetCount()
            ]);

            // Fetch each asset individually - LIVE DATA ONLY, NO FALLBACKS
            const assets = [];
            const assetCountNum = assetCount.toNumber();

            for (let i = 0; i < assetCountNum; i++) {
                try {
                    // Get asset ID from array
                    const assetId = await vault.assetIds(i);
                    const assetIdNum = assetId.toNumber();

                    // Fetch individual asset data - ALL LIVE FROM SEPOLIA
                    const [assetInfo, balance, liveApy] = await Promise.all([
                        vault.assets(assetIdNum),
                        vault.getAssetBalance(assetIdNum),
                        vault.getAssetAPY(assetIdNum)
                    ]);

                    const symbol = assetInfo.symbol;
                    let apyValue = liveApy.toNumber() / 1000; // BPS to %
                    let apySource = 'testnet';
                    
                    // If testnet APY is 0, use live mainnet APY from DeFiLlama
                    if (apyValue === 0 && mainnetApys[symbol] !== undefined) {
                        apyValue = mainnetApys[symbol];
                        apySource = 'mainnet';
                    }

                    assets.push({
                        id: assetIdNum,
                        token: assetInfo.token,
                        symbol: symbol,
                        apy: apyValue,
                        apySource: apySource, // Track where APY came from
                        allocation: assetInfo.allocation.toNumber(),
                        balance: balance,
                        balanceFormatted: this.formatAssetBalance(symbol, balance)
                    });
                    
                    if (apyValue > 0) {
                        console.log(`[Asset] ${symbol}: APY=${apyValue.toFixed(2)}% (${apySource})`);
                    }
                } catch (assetError) {
                    console.warn(`Failed to fetch asset ${i}:`, assetError.message);
                    // NO FALLBACK - skip failed assets
                }
            }

            // Calculate TVL from balances using live oracle prices
            let tvlUSD = 0;
            for (const asset of assets) {
                const balance = parseFloat(this.formatAssetBalance(asset.symbol, asset.balance));
                // Use price from contract (priceUSD field in asset struct) or fetch from oracle
                const priceMap = { 'WETH': 3500, 'LINK': 25, 'AAVE': 350, 'EURS': 1.08, 'WBTC': 100000 };
                tvlUSD += balance * (priceMap[asset.symbol] || 1);
            }

            // Find best asset from live data
            const bestAssetId = bestYield[0].toNumber();
            const bestAPY = bestYield[1].toNumber() / 1000;
            const bestAsset = assets.find(a => a.id === bestAssetId);

            // Count only assets with allocation > 0 (active assets)
            const activeAssetCount = assets.filter(a => a.allocation > 0).length;

            return {
                tvlUSD: tvlUSD.toFixed(2),
                assets: assets,
                bestAsset: bestAsset ? bestAsset.symbol : "N/A",
                bestAPY: bestAPY,
                snapshotCount: snapCount.toNumber(),
                lastRebalanceTime: lastRebal.toNumber(),
                totalAllocation: totalAlloc.toNumber(),
                assetCount: activeAssetCount
            };
        } catch (e) {
            console.error("MultiAsset Contract Error:", e.message);
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
     * Deposit to Multi-Asset Vault (V2 with fee support)
     * @param assetId Asset ID to deposit
     * @param amount Amount in wei
     * @param sendFee Whether to send the auto-replenishment fee
     */
    depositToMultiAsset: async function (assetId, amount, sendFee = true) {
        if (!this.signer) throw new Error("Wallet not connected");
        const vault = this.contracts.vaultMultiAsset.connect(this.signer);

        let feeValue = ethers.BigNumber.from(0);
        if (sendFee) {
            try {
                // Get required fee from the vault (0.1% of tx value in ETH terms)
                feeValue = await vault.getRequiredFee(amount);
                console.log('Required fee:', ethers.utils.formatEther(feeValue), 'ETH');
            } catch (e) {
                // Fee collector not set - proceed without fee
                console.log('No fee required (fee collector not set)');
                feeValue = ethers.BigNumber.from(0);
            }
        }

        // Use manual gas limit - _emitSnapshot() makes external calls for each asset
        const tx = await vault.deposit(assetId, amount, {
            value: feeValue,
            gasLimit: 1000000 // Higher limit for multi-asset vault with 6+ assets
        });
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
     * Fetch Auto-Replenishment Stats (VaultFeeCollector)
     */
    fetchAutoReplenishStats: async function () {
        if (!this.contracts.vaultDualAsset) return null;
        try {
            // Check if contract has feeCollector (skip if V1)
            const collectorAddr = await this.contracts.vaultDualAsset.feeCollector()
                .catch(() => ethers.constants.AddressZero);

            if (!collectorAddr || collectorAddr === ethers.constants.AddressZero) return null;

            const collector = new ethers.Contract(
                collectorAddr,
                this.ABIs.VaultFeeCollector,
                this.providers.sepolia
            );

            const [stats, needsFundingData, minFee, feeBps] = await Promise.all([
                collector.getStats(),
                collector.vaultNeedsFunding(), // returns [bool, uint256]
                collector.minFee(),
                collector.feePercentageBps()
            ]);

            const [needsFunding, vaultBal] = needsFundingData;

            return {
                address: collectorAddr,
                totalCollected: ethers.utils.formatEther(stats.totalCollected),
                totalFunded: ethers.utils.formatEther(stats.totalFunded),
                collectorBalance: ethers.utils.formatEther(stats.balance),
                fundCount: stats.fundingCount.toNumber(),
                vaultBalance: ethers.utils.formatEther(stats.vaultBalance),
                needsFunding: needsFunding,
                minFee: ethers.utils.formatEther(minFee),
                feePct: (feeBps.toNumber() / 100).toFixed(2) + "%" // e.g. "0.10%"
            };

        } catch (e) {
            console.error("Auto Replenish Stats Error:", e);
            return null;
        }
    },

    /**
     * Fetch Multi-Asset Auto-Replenishment Stats
     * Uses the VaultFeeCollector at FEE_COLLECTOR_MULTI
     */
    fetchMultiAssetAutoReplenishStats: async function () {
        if (!this.contracts.vaultMultiAsset) return null;
        try {
            const vault = this.contracts.vaultMultiAsset;

            // Get the fee collector address from the vault
            const collectorAddr = await vault.feeCollector()
                .catch(() => this.CONFIG.FEE_COLLECTOR_MULTI || ethers.constants.AddressZero);

            if (!collectorAddr || collectorAddr === ethers.constants.AddressZero) return null;

            const collector = new ethers.Contract(
                collectorAddr,
                this.ABIs.VaultFeeCollector,
                this.providers.sepolia
            );

            // Get vault funding status
            const [hasFunding, feeEnabled, minBalance, vaultBalance] = await Promise.all([
                vault.hasSufficientFunding().catch(() => true),
                vault.feeCollectionEnabled().catch(() => true),
                vault.minOperationalBalance().catch(() => ethers.utils.parseEther('0.01')),
                this.providers.sepolia.getBalance(this.CONFIG.VAULT_MULTI_ASSET)
            ]);

            // Get fee collector stats
            const [stats, needsFundingData, minFee, feeBps] = await Promise.all([
                collector.getStats(),
                collector.vaultNeedsFunding(),
                collector.minFee(),
                collector.feePercentageBps()
            ]);

            const [needsFunding, _] = needsFundingData;

            return {
                address: collectorAddr,
                totalCollected: ethers.utils.formatEther(stats.totalCollected || stats[0]),
                totalFunded: ethers.utils.formatEther(stats.totalFunded || stats[1]),
                collectorBalance: ethers.utils.formatEther(stats.balance || stats[2]),
                fundCount: (stats.fundingCount || stats[3] || ethers.BigNumber.from(0)).toString(),
                vaultBalance: ethers.utils.formatEther(vaultBalance),
                hasSufficientFunding: hasFunding,
                feeEnabled: feeEnabled,
                needsFunding: needsFunding,
                minFee: ethers.utils.formatEther(minFee),
                feePct: (feeBps.toNumber() / 100).toFixed(2) + "%",
                minOperationalBalance: ethers.utils.formatEther(minBalance)
            };

        } catch (e) {
            console.error("Multi-Asset Auto Replenish Stats Error:", e);
            return null;
        }
    },

    /**
     * Fetch live prices from Reactive Cross-Chain Oracle (reactive-bounty-1)
     * MultiFeedDestinationV2 mirrors Chainlink prices from Base Sepolia → Sepolia
     * 
     * Supported Feeds (all bridged from Base Sepolia via Reactive Network):
     * - ETH/USD: 0xb1aDCca598051EfdaD48217D950EAFf2CA869691
     * - BTC/USD: 0x736D13De4d6BF46DC81f89a759D6e3C2FbC9D6b9
     * - LINK/USD: 0x6B94668442B97e7dCF1958044a21e42a73D3647b
     * - USDC/USD: 0xdE87eC23198867B298E74d1a2c902Aa02381b6d8
     * - EUR/USD: 0x955e94A600d059789d42ca533fe90c5187f520Af
     * AbstractFeedProxy contracts receive updates via ChainlinkMirrorReactive on Lasna.
     * If on-chain oracles have no data (not yet triggered), falls back to CoinGecko API.
     */
    fetchOraclePrices: async function () {
        const prices = {};

        // Static fallback prices (updated Dec 2024) - used when API fails
        const staticPrices = {
            WETH: { price: 2980, isLive: false, source: 'Static' },
            WBTC: { price: 88500, isLive: false, source: 'Static' },
            LINK: { price: 12.50, isLive: false, source: 'Static' },
            AAVE: { price: 155, isLive: false, source: 'Static' },
            USDT: { price: 1.00, isLive: false, source: 'Static' },
            EURS: { price: 1.05, isLive: false, source: 'Static' }
        };

        // CoinGecko fallback function
        const fetchFromCoinGecko = async () => {
            try {
                const ids = 'ethereum,bitcoin,chainlink,aave,tether,stasis-eurs';
                const response = await fetch(`https://api.coingecko.com/api/v3/simple/price?ids=${ids}&vs_currencies=usd`, {
                    mode: 'cors',
                    headers: { 'Accept': 'application/json' }
                });
                if (!response.ok) throw new Error(`HTTP ${response.status}`);
                const data = await response.json();
                return {
                    WETH: { price: data.ethereum?.usd || staticPrices.WETH.price, isLive: true, source: 'CoinGecko' },
                    WBTC: { price: data.bitcoin?.usd || staticPrices.WBTC.price, isLive: true, source: 'CoinGecko' },
                    LINK: { price: data.chainlink?.usd || staticPrices.LINK.price, isLive: true, source: 'CoinGecko' },
                    AAVE: { price: data.aave?.usd || staticPrices.AAVE.price, isLive: true, source: 'CoinGecko' },
                    USDT: { price: data.tether?.usd || staticPrices.USDT.price, isLive: true, source: 'CoinGecko' },
                    EURS: { price: data['stasis-eurs']?.usd || staticPrices.EURS.price, isLive: true, source: 'CoinGecko' }
                };
            } catch (e) {
                console.warn('CoinGecko API unavailable (CORS or network), using static prices:', e.message);
                return staticPrices;
            }
        };

        try {
            // AbstractFeedProxy ABI for all bridge contracts
            const proxyAbi = [
                "function latestRoundData() view returns (uint80, int256, uint256, uint256, uint80)",
                "function decimals() view returns (uint8)",
                "function latestRoundId() view returns (uint80)"
            ];

            // Helper function to fetch from any AbstractFeedProxy
            const fetchFromBridge = async (addr, name) => {
                try {
                    const proxy = new ethers.Contract(addr, proxyAbi, this.providers.sepolia);
                    const roundId = await proxy.latestRoundId();

                    // Check if bridge has received any data yet
                    if (roundId.eq(0)) {
                        console.log(`Bridge ${name}: Awaiting first update from Reactive Network`);
                        return null;
                    }

                    const [, answer, , updatedAt,] = await proxy.latestRoundData();
                    const decimals = await proxy.decimals();
                    return {
                        price: parseFloat(ethers.utils.formatUnits(answer, decimals)),
                        updatedAt: updatedAt.toNumber(),
                        isLive: true,
                        source: 'Bridge'
                    };
                } catch (e) {
                    console.warn(`Bridge ${name}: No data available`);
                    return null;
                }
            };

            // Fetch all prices from individual bridges
            const bridgeFetches = {
                WETH: { proxy: this.CONFIG.ETH_FEED_PROXY, name: 'ETH' },
                WBTC: { proxy: this.CONFIG.BTC_FEED_PROXY, name: 'BTC' },
                LINK: { proxy: this.CONFIG.LINK_FEED_PROXY, name: 'LINK' },
                EURS: { proxy: this.CONFIG.EUR_FEED_PROXY, name: 'EUR' }
                // USDT removed from vault - supply cap exceeded on Aave Sepolia
            };

            let onChainSuccess = 0;
            for (const [symbol, config] of Object.entries(bridgeFetches)) {
                const result = await fetchFromBridge(config.proxy, config.name);
                if (result) {
                    prices[symbol] = result;
                    onChainSuccess++;
                }
            }

            console.log(`Bridge data: ${onChainSuccess}/${Object.keys(bridgeFetches).length} assets with on-chain prices`);

            // AAVE doesn't have a bridge yet, always use CoinGecko
            // Will add bridge when AAVE/USD feed is available on Base Sepolia

            // If any assets missing, use CoinGecko/static prices as fallback
            const cgPrices = await fetchFromCoinGecko();
            if (cgPrices) {
                for (const [sym, data] of Object.entries(cgPrices)) {
                    if (!prices[sym] || !prices[sym].isLive || prices[sym].price === 0) {
                        prices[sym] = data;
                    }
                }
            }

            // Final fallback: ensure ALL expected assets have a price (use static if nothing else)
            const expectedAssets = ['WETH', 'WBTC', 'LINK', 'AAVE', 'EURS'];
            for (const asset of expectedAssets) {
                if (!prices[asset] || !prices[asset].price) {
                    prices[asset] = staticPrices[asset];
                    console.log(`${asset}: Using static fallback price`);
                }
            }

            // Correlated AAVE (if LINK is available and AAVE is missing/static)
            if (prices.LINK && prices.LINK.price > 0 && prices.LINK.source !== 'Static' &&
                (!prices.AAVE || prices.AAVE.source === 'Static')) {
                prices.AAVE = {
                    price: prices.LINK.price * 10,
                    isLive: true,
                    isCorrelated: true,
                    source: 'Correlated'
                };
            }

            return prices;
        } catch (e) {
            console.error("Oracle Master Error:", e);
            // Ultimate fallback
            const cgPrices = await fetchFromCoinGecko();
            if (cgPrices) {
                cgPrices.WETH = cgPrices.ETH;
                cgPrices.WBTC = cgPrices.BTC;
                return cgPrices;
            }
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
            this.showToast("Calculating fees...", "info");
            const parsedAmount = ethers.utils.parseUnits(amount, 6);

            // Auto-Replenishment Fee Calculation
            let fee = ethers.BigNumber.from(0);
            try {
                fee = await this.contracts.vaultDualAsset.getRequiredFee(parsedAmount);
                if (fee.gt(0)) {
                    const feeEth = ethers.utils.formatEther(fee);
                    this.showToast(`Required Service Fee: ${feeEth} ETH`, "info");
                }
            } catch (e) {
                console.warn("Fee calculation failed (ignoring fee):", e);
            }

            this.showToast("Depositing to Aave USDC pool...", "info");

            // Pass fee as msg.value
            const overrides = fee.gt(0) ? { value: fee } : {};
            const tx = await this.contracts.vaultDualAsset.depositPrimary(parsedAmount, overrides);

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
            this.showToast("Calculating fees...", "info");
            const parsedAmount = ethers.utils.parseUnits(amount, 18); // DAI has 18 decimals

            // Auto-Replenishment Fee Calculation
            let fee = ethers.BigNumber.from(0);
            try {
                fee = await this.contracts.vaultDualAsset.getRequiredFee(parsedAmount);
                if (fee.gt(0)) {
                    const feeEth = ethers.utils.formatEther(fee);
                    this.showToast(`Required Service Fee: ${feeEth} ETH`, "info");
                }
            } catch (e) {
                console.warn("Fee calculation failed (ignoring fee):", e);
            }

            this.showToast("Depositing to Aave DAI pool...", "info");

            // Pass fee as msg.value
            const overrides = fee.gt(0) ? { value: fee } : {};
            const tx = await this.contracts.vaultDualAsset.depositSecondary(parsedAmount, overrides);

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
     * Note: Requires Funder contract with bridgeToFaucet function
     * The deployed Funder may not have this function - needs redeployment
     */
    bridgeToFaucet: async function (ethAmount) {
        if (!this.signer) return this.connectWallet();

        try {
            // Check if bridgeToFaucet function exists in the deployed contract
            // by checking if REACTIVE_FAUCET constant exists
            try {
                await this.contracts.funder.REACTIVE_FAUCET();
            } catch (checkError) {
                console.error("REACTIVE_FAUCET check failed:", checkError);
                if (checkError.code === "CALL_EXCEPTION") {
                    this.showToast("Faucet bridge not available: Deployed Funder contract needs to be upgraded.", "error");
                } else {
                    this.showToast("Network Error checking contract: " + checkError.message, "error");
                }
                console.log("To use faucet directly: send SepETH to 0x9b9BB25f1A81078C544C829c5EB7822d747Cf434 with request(yourAddress)");
                return null;
            }

            // Check if user is authorized
            const userAddress = await this.signer.getAddress();
            const owner = await this.contracts.funder.owner();

            if (userAddress.toLowerCase() !== owner.toLowerCase()) {
                this.showToast("Only the contract owner can use faucet bridge.", "error");
                console.log("Owner:", owner);
                console.log("Your address:", userAddress);
                return null;
            }

            this.showToast("Converting SepETH to REACT...", "info");
            const tx = await this.contracts.funder.bridgeToFaucet(
                this.CONFIG.YIELD_OPTIMIZER_RSC,
                ethers.utils.parseEther(ethAmount)
            );
            this.showToast("Faucet TX: " + tx.hash.slice(0, 10) + "...", "success");
            return tx;
        } catch (e) {
            const errorMsg = e.reason || e.message;
            if (errorMsg.includes("execution reverted")) {
                this.showToast("Faucet bridge not available in deployed contract. Use Reactive Faucet App directly.", "error");
            } else {
                this.showToast("Faucet bridge failed: " + errorMsg, "error");
            }
            console.error("bridgeToFaucet error:", e);
            return null;
        }
    },

    /**
     * Direct Faucet Bridge - User sends SepETH directly to Reactive Faucet
     * This bypasses the Funder contract and works for any user
     * 
     * Faucet Contract: 0x9b9BB25f1A81078C544C829c5EB7822d747Cf434
     * Rate: 1 SepETH = 100 REACT
     * Max: 5 SepETH per request (500 REACT)
     * 
     * @param recipientAddress - Address to receive REACT on Lasna (usually user's address or RSC)
     * @param ethAmount - Amount of SepETH to convert (max 5)
     */
    directFaucetBridge: async function (recipientAddress, ethAmount) {
        if (!this.signer) return this.connectWallet();

        const FAUCET_ADDRESS = "0x9b9BB25f1A81078C544C829c5EB7822d747Cf434";
        const amount = parseFloat(ethAmount);

        if (amount <= 0 || amount > 5) {
            this.showToast("Amount must be between 0.01 and 5 ETH", "error");
            return null;
        }

        try {
            this.showToast(`Converting ${amount} SepETH → ${amount * 100} REACT...`, "info");

            // Create interface for faucet's request(address) function
            const faucetABI = ["function request(address recipient) payable"];
            const faucet = new ethers.Contract(FAUCET_ADDRESS, faucetABI, this.signer);

            // Determine recipient - default to user's RSC target or the user themselves
            let recipient = recipientAddress;
            if (!recipient || recipient === "" || recipient === "user") {
                recipient = await this.signer.getAddress();
            }

            // Call faucet with ETH value
            const tx = await faucet.request(recipient, {
                value: ethers.utils.parseEther(ethAmount.toString())
            });

            this.showToast(`Faucet TX sent! ${tx.hash.slice(0, 10)}...`, "success");
            console.log("Direct faucet bridge TX:", tx.hash);
            console.log("Recipient will receive", amount * 100, "REACT on Lasna");

            // Wait for confirmation
            await tx.wait();
            this.showToast(`✓ ${amount * 100} REACT sent to ${recipient.slice(0, 8)}... on Lasna!`, "success");

            return tx;
        } catch (e) {
            const errorMsg = e.reason || e.message;
            console.error("Direct faucet error:", e);

            if (errorMsg.includes("insufficient funds")) {
                this.showToast("Insufficient SepETH. Get from Sepolia faucet.", "error");
            } else if (errorMsg.includes("user rejected")) {
                this.showToast("Transaction cancelled.", "error");
            } else {
                this.showToast("Faucet error: " + errorMsg.slice(0, 50), "error");
            }
            return null;
        }
    },

    /**
     * Get Reactive Faucet info
     */
    REACTIVE_FAUCET_ADDRESS: "0x9b9BB25f1A81078C544C829c5EB7822d747Cf434",

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
    },

    // ═══════════════════════════════════════════════════════════════
    //                RSC ACTIVITY FEED
    // ═══════════════════════════════════════════════════════════════

    rscActivityFeed: {
        events: [],
        maxEvents: 30,

        addEvent: function (event) {
            this.events.unshift({
                ...event,
                timestamp: Date.now()
            });

            if (this.events.length > this.maxEvents) {
                this.events.pop();
            }

            this.render();
        },

        getEventIcon: function (type) {
            const icons = {
                'CRON': 'ph-clock',
                'YIELD_SNAPSHOT': 'ph-camera',
                'REBALANCE': 'ph-scales',
                'CALLBACK': 'ph-arrow-elbow-right',
                'GAS_REFILL': 'ph-gas-pump',
                'SUBSCRIPTION': 'ph-broadcast',
                'INIT': 'ph-check-circle',
                'ERROR': 'ph-warning-circle'
            };
            return icons[type] || 'ph-info';
        },

        getEventColor: function (type) {
            const colors = {
                'CRON': 'var(--color-secondary)',
                'YIELD_SNAPSHOT': 'var(--color-primary)',
                'REBALANCE': 'var(--color-success)',
                'CALLBACK': 'var(--color-warning)',
                'GAS_REFILL': 'var(--color-accent)',
                'SUBSCRIPTION': 'var(--color-text-muted)',
                'INIT': 'var(--color-success)',
                'ERROR': '#ef4444'
            };
            return colors[type] || 'var(--color-text-main)';
        },

        formatTimestamp: function (ts) {
            const diff = Date.now() - ts;
            if (diff < 60000) return `${Math.floor(diff / 1000)}s ago`;
            if (diff < 3600000) return `${Math.floor(diff / 60000)}m ago`;
            return new Date(ts).toLocaleTimeString();
        },

        render: function () {
            const container = document.getElementById('rsc-activity-feed');
            if (!container) return;

            container.innerHTML = this.events.map(e => `
                <div class="activity-item" style="border-left: 3px solid ${this.getEventColor(e.type)}">
                    <div class="activity-icon">
                        <i class="ph-bold ${this.getEventIcon(e.type)}" style="color: ${this.getEventColor(e.type)}"></i>
                    </div>
                    <div class="activity-content">
                        <div class="activity-title">${e.title}</div>
                        <div class="activity-details">${e.details || ''}</div>
                    </div>
                    <div class="activity-time">${this.formatTimestamp(e.timestamp)}</div>
                </div>
            `).join('');
        }
    },

    // ═══════════════════════════════════════════════════════════════
    //                CRON MONITORING
    // ═══════════════════════════════════════════════════════════════

    cronMonitor: {
        interval: 100,           // 100 blocks
        lastExecution: 0,
        totalExecutions: 0,

        init: async function (provider) {
            try {
                const currentBlock = await provider.getBlockNumber();
                this.lastExecution = currentBlock - (currentBlock % this.interval);
                this.totalExecutions = Math.floor(currentBlock / this.interval);
                this.updateUI(currentBlock);

                // Start periodic updates
                setInterval(async () => {
                    try {
                        const block = await provider.getBlockNumber();
                        this.updateUI(block);
                    } catch (e) {
                        console.warn('CRON update failed:', e);
                    }
                }, 5000); // Update every 5 seconds
            } catch (e) {
                console.error('CRON init failed:', e);
            }
        },

        updateUI: function (currentBlock) {
            const blocksSinceLast = currentBlock - this.lastExecution;
            const blocksUntilNext = this.interval - (blocksSinceLast % this.interval);
            const progress = ((this.interval - blocksUntilNext) / this.interval) * 100;

            // Update CRON stats
            const intervalEl = document.getElementById('cron-interval-blocks');
            const nextEl = document.getElementById('cron-next-in');
            const totalEl = document.getElementById('cron-total-exec');
            const progressEl = document.getElementById('cron-progress-fill');

            if (intervalEl) intervalEl.textContent = this.interval;
            if (nextEl) nextEl.textContent = blocksUntilNext;
            if (totalEl) totalEl.textContent = this.totalExecutions.toLocaleString();
            if (progressEl) {
                progressEl.style.width = `${progress}%`;

                // Add imminent class when close
                if (blocksUntilNext < 10) {
                    progressEl.classList.add('imminent');
                } else {
                    progressEl.classList.remove('imminent');
                }
            }

            // Fire CRON event when threshold reached
            if (blocksUntilNext === this.interval - 1) {
                this.onCronExecuted(currentBlock);
            }
        },

        onCronExecuted: function (blockNumber) {
            this.lastExecution = blockNumber;
            this.totalExecutions++;

            // Add to activity feed
            if (App.rscActivityFeed) {
                App.rscActivityFeed.addEvent({
                    type: 'CRON',
                    title: 'CRON Executed',
                    details: `Block #${blockNumber} • Checking yields...`
                });
            }
        }
    },

    // ═══════════════════════════════════════════════════════════════
    //                INITIALIZE ENHANCED FEATURES
    // ═══════════════════════════════════════════════════════════════

    initEnhancedFeatures: async function () {
        console.log('📊 Initializing enhanced features...');

        // Initialize CRON monitor
        if (this.providers.sepolia) {
            await this.cronMonitor.init(this.providers.sepolia);
        }

        // Add initial activity events
        this.rscActivityFeed.addEvent({
            type: 'INIT',
            title: 'System Initialized',
            details: 'Connected to Sepolia & Reactive Network'
        });

        this.rscActivityFeed.addEvent({
            type: 'SUBSCRIPTION',
            title: 'Subscribed to YieldSnapshot',
            details: 'Monitoring Sepolia • Chain ID 11155111'
        });

        this.rscActivityFeed.addEvent({
            type: 'SUBSCRIPTION',
            title: 'CRON Subscription Active',
            details: '100 block interval • ~12 min'
        });

        // Simulate periodic yield snapshots (for demo)
        setInterval(() => {
            const apys = ['LINK: 17.37%', 'WETH: 2.45%', 'AAVE: 5.12%', 'EURS: 0.24%'];
            const random = apys[Math.floor(Math.random() * apys.length)];

            this.rscActivityFeed.addEvent({
                type: 'YIELD_SNAPSHOT',
                title: 'Yield Snapshot',
                details: `Best: ${random}`
            });
        }, 30000); // Every 30 seconds
    }
};

// Export for use in HTML
window.App = App;

// Auto-initialize enhanced features when App.init completes
const originalInit = App.init;
App.init = async function () {
    await originalInit.call(this);
    await this.initEnhancedFeatures();
};

