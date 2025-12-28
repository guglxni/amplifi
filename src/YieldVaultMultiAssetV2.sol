// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {AbstractCallback} from "@reactive/abstract-base/AbstractCallback.sol";
import {IAavePool} from "./interfaces/IAavePool.sol";

/**
 * @title IVaultFeeCollector
 * @notice Interface for the fee collector
 */
interface IVaultFeeCollector {
    function collectFee(uint256 txValue) external payable;
    function calculateFee(uint256 txValue) external view returns (uint256);
}

/**
 * @title YieldVaultMultiAssetV2
 * @notice Multi-asset yield optimization vault with True Auto-Replenishment
 * @dev Enhanced version with fee collection to ensure sustainable callback payments
 * 
 * Auto-Replenishment Pattern:
 * 1. Users pay small ETH fees on deposits (0.1% of tx value in ETH terms)
 * 2. Fees are forwarded to VaultFeeCollector
 * 3. VaultFeeCollector emits FeeCollected event
 * 4. VaultFunderRSC on Lasna detects the event
 * 5. RSC triggers callback to fund this vault when ETH is low
 * 6. This ensures vault always has ETH for Reactive Network callbacks
 * 
 * Features:
 * - Support for unlimited number of assets
 * - Dynamic allocation weights (basis points)
 * - Reactive Network integration for automated rebalancing
 * - Real-time APY tracking per asset
 * - TRUE Auto-Replenishment via VaultFeeCollector
 */
contract YieldVaultMultiAssetV2 is Ownable, ReentrancyGuard, AbstractCallback {
    using SafeERC20 for IERC20;

    // ═══════════════════════════════════════════════════════════════
    //                         STRUCTS
    // ═══════════════════════════════════════════════════════════════

    struct AssetInfo {
        address token;           // Underlying token address
        address aToken;          // Aave aToken address
        uint8 decimals;          // Token decimals
        uint256 allocation;      // Current allocation in basis points (0-10000)
        uint256 priceUSD;        // Price in USD with 8 decimals (for TVL calc)
        bool active;             // Is this asset active
        string symbol;           // Token symbol for display
    }

    // ═══════════════════════════════════════════════════════════════
    //                         STATE VARIABLES
    // ═══════════════════════════════════════════════════════════════

    /// @notice Aave V3 Pool
    IAavePool public immutable aavePool;
    
    /// @notice Array of all asset IDs
    uint256[] public assetIds;
    
    /// @notice Mapping from asset ID to asset info
    mapping(uint256 => AssetInfo) public assets;
    
    /// @notice Mapping from token address to asset ID (for quick lookup)
    mapping(address => uint256) public tokenToAssetId;
    
    /// @notice Next asset ID
    uint256 public nextAssetId = 1;
    
    /// @notice Total allocation (must equal 10000 BPS)
    uint256 public totalAllocation;
    
    /// @notice Snapshot counter for events
    uint256 public snapshotCounter;
    
    /// @notice Last rebalance timestamp
    uint256 public lastRebalanceTime;
    
    /// @notice Minimum time between rebalances
    uint256 public constant MIN_REBALANCE_INTERVAL = 5 minutes;

    /// @notice Minimum ETH required for callback payments
    uint256 public constant MIN_CALLBACK_FUNDING = 0.05 ether;

    // ═══════════════════════════════════════════════════════════════
    //                     AUTO-REPLENISHMENT STATE
    // ═══════════════════════════════════════════════════════════════

    /// @notice Fee collector contract address
    IVaultFeeCollector public feeCollector;
    
    /// @notice Whether fee collection is enabled
    bool public feeCollectionEnabled = true;
    
    /// @notice Minimum required ETH balance before accepting fee-paying operations
    uint256 public minOperationalBalance = 0.01 ether;

    // ═══════════════════════════════════════════════════════════════
    //                           EVENTS
    // ═══════════════════════════════════════════════════════════════

    event AssetAdded(
        uint256 indexed assetId,
        address token,
        address aToken,
        string symbol
    );

    event AssetRemoved(uint256 indexed assetId, address token);

    event YieldSnapshot(
        uint256 indexed snapshotId,
        uint256[] assetIds,
        uint256[] apys,
        uint256[] allocations,
        uint256 totalTvl,
        uint256 timestamp
    );

    event Deposited(
        address indexed user, 
        uint256 indexed assetId,
        address token, 
        uint256 amount
    );

    event Withdrawn(
        address indexed user, 
        uint256 indexed assetId,
        address token, 
        uint256 amount
    );

    event Rebalanced(uint256[] assetIds, uint256[] newAllocations);

    event AllocationUpdated(uint256 indexed assetId, uint256 newAllocation);

    /// @notice Auto-replenishment events
    event FeeCollectorSet(address indexed oldCollector, address indexed newCollector);
    event FeePaid(address indexed user, uint256 amount);
    event FeeCollectionToggled(bool enabled);
    event Funded(address indexed from, uint256 amount);

    // ═══════════════════════════════════════════════════════════════
    //                        CONSTRUCTOR
    // ═══════════════════════════════════════════════════════════════

    /**
     * @param _aavePool Aave V3 Pool address
     * @param _callbackProxy Reactive Network callback proxy on this chain
     * @param _feeCollector VaultFeeCollector address (can be zero initially)
     * @dev Must be deployed with at least 0.05 ETH for callback payment
     */
    constructor(
        address _aavePool,
        address _callbackProxy,
        address _feeCollector
    ) payable Ownable(msg.sender) AbstractCallback(_callbackProxy) {
        // Require minimum ETH for callback fees to prevent blocklisting
        require(msg.value >= MIN_CALLBACK_FUNDING, "Insufficient callback funding: need >= 0.05 ETH");
        
        aavePool = IAavePool(_aavePool);
        
        if (_feeCollector != address(0)) {
            feeCollector = IVaultFeeCollector(_feeCollector);
            emit FeeCollectorSet(address(0), _feeCollector);
        }
    }

    // ═══════════════════════════════════════════════════════════════
    //                     ASSET MANAGEMENT
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Add a new asset to the vault
     * @param token Underlying token address
     * @param aToken Aave aToken address
     * @param decimals Token decimals
     * @param priceUSD Price in USD (8 decimals)
     * @param symbol Token symbol
     * @param initialAllocation Initial allocation in BPS
     */
    function addAsset(
        address token,
        address aToken,
        uint8 decimals,
        uint256 priceUSD,
        string calldata symbol,
        uint256 initialAllocation
    ) external onlyOwner {
        require(token != address(0), "Invalid token");
        require(aToken != address(0), "Invalid aToken");
        require(tokenToAssetId[token] == 0, "Asset already exists");
        
        uint256 assetId = nextAssetId++;
        
        assets[assetId] = AssetInfo({
            token: token,
            aToken: aToken,
            decimals: decimals,
            allocation: initialAllocation,
            priceUSD: priceUSD,
            active: true,
            symbol: symbol
        });
        
        assetIds.push(assetId);
        tokenToAssetId[token] = assetId;
        totalAllocation += initialAllocation;
        
        // Approve Aave Pool for this token
        IERC20(token).approve(address(aavePool), type(uint256).max);
        
        emit AssetAdded(assetId, token, aToken, symbol);
    }

    /**
     * @notice Remove an asset from the vault
     * @dev Only removes if balance is zero
     */
    function removeAsset(uint256 assetId) external onlyOwner {
        AssetInfo storage asset = assets[assetId];
        require(asset.active, "Asset not active");
        require(
            IERC20(asset.aToken).balanceOf(address(this)) == 0,
            "Withdraw balance first"
        );
        
        // Reset token mapping (allowing re-add)
        delete tokenToAssetId[asset.token];
        
        asset.active = false;
        totalAllocation -= asset.allocation;
        asset.allocation = 0;
        
        // Remove from assetIds array
        for (uint256 i = 0; i < assetIds.length; i++) {
            if (assetIds[i] == assetId) {
                assetIds[i] = assetIds[assetIds.length - 1];
                assetIds.pop();
                break;
            }
        }
        
        emit AssetRemoved(assetId, asset.token);
    }

    /**
     * @notice Update USD price for an asset (for TVL calculation)
     */
    function updateAssetPrice(uint256 assetId, uint256 newPriceUSD) external onlyOwner {
        require(assets[assetId].active, "Asset not active");
        assets[assetId].priceUSD = newPriceUSD;
    }

    // ═══════════════════════════════════════════════════════════════
    //                      DEPOSIT/WITHDRAW
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Deposit tokens into the vault
     * @param assetId ID of the asset to deposit
     * @param amount Amount to deposit (in token's native decimals)
     * @dev Requires msg.value to cover fee for auto-replenishment
     */
    function deposit(uint256 assetId, uint256 amount) external payable nonReentrant {
        AssetInfo storage asset = assets[assetId];
        require(asset.active, "Asset not active");
        require(amount > 0, "Amount must be > 0");
        
        // Collect fee for auto-replenishment
        _collectFee(amount);
        
        IERC20(asset.token).safeTransferFrom(msg.sender, address(this), amount);
        aavePool.supply(asset.token, amount, address(this), 0);
        
        emit Deposited(msg.sender, assetId, asset.token, amount);
        _emitSnapshot();
    }

    /**
     * @notice Deposit tokens by token address (convenience function)
     * @dev Requires msg.value to cover fee for auto-replenishment
     */
    function depositByToken(address token, uint256 amount) external payable nonReentrant {
        uint256 assetId = tokenToAssetId[token];
        require(assetId != 0, "Unknown token");
        
        AssetInfo storage asset = assets[assetId];
        require(asset.active, "Asset not active");
        
        // Collect fee for auto-replenishment
        _collectFee(amount);
        
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        aavePool.supply(token, amount, address(this), 0);
        
        emit Deposited(msg.sender, assetId, token, amount);
        _emitSnapshot();
    }

    /**
     * @notice Withdraw tokens from the vault
     * @param assetId ID of the asset to withdraw
     * @param amount Amount to withdraw
     */
    function withdraw(uint256 assetId, uint256 amount) external nonReentrant onlyOwner {
        AssetInfo storage asset = assets[assetId];
        require(asset.active, "Asset not active");
        
        aavePool.withdraw(asset.token, amount, msg.sender);
        
        emit Withdrawn(msg.sender, assetId, asset.token, amount);
    }

    // ═══════════════════════════════════════════════════════════════
    //                      FEE COLLECTION
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Collect fee and forward to fee collector
     * @param txValue Transaction value for percentage calculation
     */
    function _collectFee(uint256 txValue) internal {
        if (!feeCollectionEnabled || address(feeCollector) == address(0)) {
            return;
        }
        
        // Calculate required fee
        uint256 requiredFee = feeCollector.calculateFee(txValue);
        
        if (msg.value > 0) {
            if (msg.value >= requiredFee) {
                // Forward fee to collector
                feeCollector.collectFee{value: msg.value}(txValue);
                emit FeePaid(msg.sender, msg.value);
            } else {
                // Partial fee - keep it in vault for self-funding
                emit FeePaid(msg.sender, msg.value);
            }
        }
    }

    /**
     * @notice Get required fee for a transaction
     * @param txValue Transaction value 
     * @return Required fee in ETH
     */
    function getRequiredFee(uint256 txValue) external view returns (uint256) {
        if (address(feeCollector) == address(0)) return 0;
        return feeCollector.calculateFee(txValue);
    }

    /**
     * @notice Check if vault has sufficient funding
     */
    function hasSufficientFunding() external view returns (bool) {
        return address(this).balance >= minOperationalBalance;
    }

    // ═══════════════════════════════════════════════════════════════
    //                      YIELD SNAPSHOT
    // ═══════════════════════════════════════════════════════════════

    function triggerYieldSnapshot() external {
        _emitSnapshot();
    }

    function _emitSnapshot() internal {
        uint256 assetCount = assetIds.length;
        uint256[] memory apys = new uint256[](assetCount);
        uint256[] memory allocations = new uint256[](assetCount);
        
        for (uint256 i = 0; i < assetCount; i++) {
            uint256 assetId = assetIds[i];
            apys[i] = getAssetAPY(assetId);
            allocations[i] = assets[assetId].allocation;
        }
        
        snapshotCounter++;
        
        emit YieldSnapshot(
            snapshotCounter,
            assetIds,
            apys,
            allocations,
            getTotalValueLockedUSD(),
            block.timestamp
        );
    }

    // ═══════════════════════════════════════════════════════════════
    //                   REBALANCE (RSC Callback)
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Rebalance allocations across all assets
     * @dev Called by Reactive Network Smart Contract
     * @param newAllocations Array of new allocations (must sum to 10000)
     */
    function executeRebalance(
        address /* _rvm */,
        uint256[] calldata assetIdsToRebalance,
        uint256[] calldata newAllocations
    ) external authorizedSenderOnly {
        require(
            block.timestamp >= lastRebalanceTime + MIN_REBALANCE_INTERVAL,
            "Rebalance too soon"
        );
        require(
            assetIdsToRebalance.length == newAllocations.length,
            "Array length mismatch"
        );
        
        // Calculate new total and update allocations
        uint256 newTotal = 0;
        for (uint256 i = 0; i < assetIdsToRebalance.length; i++) {
            uint256 assetId = assetIdsToRebalance[i];
            require(assets[assetId].active, "Asset not active");
            
            totalAllocation -= assets[assetId].allocation;
            assets[assetId].allocation = newAllocations[i];
            totalAllocation += newAllocations[i];
            newTotal += newAllocations[i];
            
            emit AllocationUpdated(assetId, newAllocations[i]);
        }
        
        require(totalAllocation == 10000, "Total allocation must be 10000");
        
        lastRebalanceTime = block.timestamp;
        
        emit Rebalanced(assetIdsToRebalance, newAllocations);
        _emitSnapshot();
    }

    /**
     * @notice Update allocation for a single asset
     * @dev For manual adjustments
     */
    function setAllocation(uint256 assetId, uint256 newAllocation) external onlyOwner {
        require(assets[assetId].active, "Asset not active");
        
        totalAllocation -= assets[assetId].allocation;
        assets[assetId].allocation = newAllocation;
        totalAllocation += newAllocation;
        
        emit AllocationUpdated(assetId, newAllocation);
    }

    // ═══════════════════════════════════════════════════════════════
    //                      VIEW FUNCTIONS
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Get APY for a specific asset
     * @return APY in basis points (1% = 100)
     */
    function getAssetAPY(uint256 assetId) public view returns (uint256) {
        AssetInfo storage asset = assets[assetId];
        if (!asset.active) return 0;
        
        IAavePool.ReserveData memory data = aavePool.getReserveData(asset.token);
        // liquidityRate is in RAY (1e27), convert to basis points
        return data.currentLiquidityRate / 1e23;
    }

    /**
     * @notice Get balance of a specific asset in the vault
     */
    function getAssetBalance(uint256 assetId) public view returns (uint256) {
        AssetInfo storage asset = assets[assetId];
        if (!asset.active) return 0;
        return IERC20(asset.aToken).balanceOf(address(this));
    }

    /**
     * @notice Get total value locked in USD (6 decimals)
     */
    function getTotalValueLockedUSD() public view returns (uint256) {
        uint256 totalUSD = 0;
        
        for (uint256 i = 0; i < assetIds.length; i++) {
            uint256 assetId = assetIds[i];
            AssetInfo storage asset = assets[assetId];
            
            if (!asset.active) continue;
            
            uint256 balance = IERC20(asset.aToken).balanceOf(address(this));
            
            // Normalize to 6 decimal USD value
            // balance * priceUSD (8 decimals) / 10^(decimals + 2)
            uint256 valueUSD = (balance * asset.priceUSD) / (10 ** (asset.decimals + 2));
            totalUSD += valueUSD;
        }
        
        return totalUSD;
    }

    /**
     * @notice Get the best performing asset by APY
     * @return bestAssetId ID of best performing asset
     * @return bestAPY APY in basis points
     */
    function getBestYieldAsset() public view returns (uint256 bestAssetId, uint256 bestAPY) {
        for (uint256 i = 0; i < assetIds.length; i++) {
            uint256 assetId = assetIds[i];
            uint256 apy = getAssetAPY(assetId);
            
            if (apy > bestAPY) {
                bestAPY = apy;
                bestAssetId = assetId;
            }
        }
    }

    /**
     * @notice Get all asset information
     */
    function getAllAssets() external view returns (
        uint256[] memory ids,
        address[] memory tokens,
        string[] memory symbols,
        uint256[] memory apys,
        uint256[] memory allocations,
        uint256[] memory balances
    ) {
        uint256 count = assetIds.length;
        
        ids = new uint256[](count);
        tokens = new address[](count);
        symbols = new string[](count);
        apys = new uint256[](count);
        allocations = new uint256[](count);
        balances = new uint256[](count);
        
        for (uint256 i = 0; i < count; i++) {
            uint256 assetId = assetIds[i];
            AssetInfo storage asset = assets[assetId];
            
            ids[i] = assetId;
            tokens[i] = asset.token;
            symbols[i] = asset.symbol;
            apys[i] = getAssetAPY(assetId);
            allocations[i] = asset.allocation;
            balances[i] = IERC20(asset.aToken).balanceOf(address(this));
        }
    }

    /**
     * @notice Get count of active assets
     */
    function getAssetCount() external view returns (uint256) {
        return assetIds.length;
    }

    // ═══════════════════════════════════════════════════════════════
    //                      ADMIN FUNCTIONS
    // ═══════════════════════════════════════════════════════════════

    function setRvmId(address _rvmId) external onlyOwner {
        rvm_id = _rvmId;
    }

    /**
     * @notice Set the fee collector contract
     */
    function setFeeCollector(address _feeCollector) external onlyOwner {
        address old = address(feeCollector);
        feeCollector = IVaultFeeCollector(_feeCollector);
        emit FeeCollectorSet(old, _feeCollector);
    }

    /**
     * @notice Toggle fee collection on/off
     */
    function setFeeCollectionEnabled(bool enabled) external onlyOwner {
        feeCollectionEnabled = enabled;
        emit FeeCollectionToggled(enabled);
    }

    /**
     * @notice Update minimum operational balance
     */
    function setMinOperationalBalance(uint256 _minBalance) external onlyOwner {
        minOperationalBalance = _minBalance;
    }

    /**
     * @notice Allow the contract to receive ETH for callback funding
     */
    receive() external payable override {
        emit Funded(msg.sender, msg.value);
    }
}
