// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {AbstractCallback} from "@reactive/abstract-base/AbstractCallback.sol";
import {IAavePool} from "./interfaces/IAavePool.sol";

/**
 * @title YieldVaultMultiAsset
 * @notice Multi-asset yield optimization vault supporting unlimited Aave V3 assets
 * @dev Dynamically manages allocations across multiple yield sources
 * 
 * Features:
 * - Support for unlimited number of assets
 * - Dynamic allocation weights (basis points)
 * - Reactive Network integration for automated rebalancing
 * - Real-time APY tracking per asset
 * - Aggregated TVL calculation
 * 
 * Verified Assets with NO Supply Cap (Sepolia):
 * - WETH: 0xC558DBdd856501FCd9aaF1E62eae57A9F0629a3c
 * - LINK: 0xf8Fb3713D459D7C1018BD0A49D19b4C44290EBE5
 * - AAVE: 0x88541670E55cC00bEEFD87eB59EDd1b7C511AC9a
 * - EURS: 0x6d906e526a4e2Ca02097BA9d0caA3c382F52278E
 */
contract YieldVaultMultiAsset is Ownable, ReentrancyGuard, AbstractCallback {
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

    // ═══════════════════════════════════════════════════════════════
    //                        CONSTRUCTOR
    // ═══════════════════════════════════════════════════════════════

    constructor(
        address _aavePool,
        address _callbackProxy
    ) Ownable(msg.sender) AbstractCallback(_callbackProxy) {
        aavePool = IAavePool(_aavePool);
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
     */
    function deposit(uint256 assetId, uint256 amount) external nonReentrant {
        AssetInfo storage asset = assets[assetId];
        require(asset.active, "Asset not active");
        require(amount > 0, "Amount must be > 0");
        
        IERC20(asset.token).safeTransferFrom(msg.sender, address(this), amount);
        aavePool.supply(asset.token, amount, address(this), 0);
        
        emit Deposited(msg.sender, assetId, asset.token, amount);
        _emitSnapshot();
    }

    /**
     * @notice Deposit tokens by token address (convenience function)
     */
    function depositByToken(address token, uint256 amount) external nonReentrant {
        uint256 assetId = tokenToAssetId[token];
        require(assetId != 0, "Unknown token");
        
        AssetInfo storage asset = assets[assetId];
        require(asset.active, "Asset not active");
        
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

    receive() external payable override {}
}
