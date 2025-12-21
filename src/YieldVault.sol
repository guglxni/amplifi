// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AbstractCallback} from "@reactive/abstract-base/AbstractCallback.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IAavePool} from "./interfaces/IAavePool.sol";
import {IComet} from "./interfaces/IComet.sol";
import {YieldCalculator} from "./libraries/YieldCalculator.sol";

/**
 * @title YieldVault
 * @notice Cross-chain yield optimization vault for Reactive Network Bounty 3
 * @dev Automatically routes funds between Aave V3 and Compound V3 based on yield
 *      RSC on Lasna monitors YieldSnapshot events and triggers rebalancing via callbacks
 * 
 * Features:
 * - Dual pool support (Aave V3 + Compound V3)
 * - CRON-triggered yield snapshots
 * - RSC callback for rebalancing
 * - Self-sustaining gas integration (Funder)
 */
contract YieldVault is AbstractCallback, ReentrancyGuard, Ownable, Pausable {
    using SafeERC20 for IERC20;
    using YieldCalculator for uint256;

    // ═══════════════════════════════════════════════════════════════
    //                           CONSTANTS
    // ═══════════════════════════════════════════════════════════════

    /// @notice Basis points constant (100% = 10000)
    uint256 public constant BPS = 10000;
    
    /// @notice Minimum blocks between rebalances (rate limiting)
    uint256 public constant MIN_REBALANCE_INTERVAL = 100;
    
    /// @notice Minimum deposit amount
    uint256 public constant MIN_DEPOSIT = 1e6; // 1 USDC (6 decimals)

    // ═══════════════════════════════════════════════════════════════
    //                           IMMUTABLES
    // ═══════════════════════════════════════════════════════════════

    /// @notice The underlying asset (e.g., USDC)
    IERC20 public immutable asset;
    
    /// @notice Aave V3 Pool address
    IAavePool public immutable aavePool;
    
    /// @notice Aave aToken address for the asset
    IERC20 public immutable aToken;
    
    /// @notice Compound V3 Comet address
    IComet public immutable compoundComet;

    // ═══════════════════════════════════════════════════════════════
    //                           STATE
    // ═══════════════════════════════════════════════════════════════

    /// @notice Current allocation to Aave (basis points)
    uint256 public aaveAllocation;
    
    /// @notice Current allocation to Compound (basis points)
    uint256 public compoundAllocation;
    
    /// @notice Total deposits in vault (accounting)
    uint256 public totalDeposits;
    
    /// @notice User deposit balances
    mapping(address => uint256) public userDeposits;
    
    /// @notice Snapshot counter for unique IDs
    uint256 public snapshotCounter;
    
    /// @notice Last rebalance block (for rate limiting)
    uint256 public lastRebalanceBlock;
    
    /// @notice Minimum yield difference for rebalance (basis points)
    uint256 public minYieldDiffBps = 50; // 0.5% default
    
    /// @notice Minimum allocation per pool (basis points)
    uint256 public minAllocationBps = 2000; // 20% default
    
    /// @notice Funder contract for gas management
    address public funderContract;

    // ═══════════════════════════════════════════════════════════════
    //                           EVENTS
    // ═══════════════════════════════════════════════════════════════

    /// @notice Primary event for RSC to react to
    /// @dev snapshotId is indexed for subscription filtering
    event YieldSnapshot(
        uint256 indexed snapshotId,
        uint256 aaveAPY,           // Aave APY (RAY units: 1e27)
        uint256 compoundAPY,       // Compound APY (scaled: 1e18)
        uint256 aaveAllocation,    // Current % in Aave (basis points)
        uint256 compoundAllocation,// Current % in Compound (basis points)
        uint256 totalValueLocked,  // Total TVL in vault
        uint256 timestamp
    );

    /// @notice Emitted when user deposits
    event Deposit(address indexed user, uint256 amount, uint256 newBalance);
    
    /// @notice Emitted when user withdraws
    event Withdraw(address indexed user, uint256 amount, uint256 newBalance);
    
    /// @notice Emitted when rebalancing occurs
    event Rebalanced(
        uint256 newAavePct,
        uint256 newCompoundPct,
        uint256 aaveBalance,
        uint256 compoundBalance
    );
    
    /// @notice Emitted when yield snapshot is requested (CRON trigger)
    event SnapshotRequested(address indexed requester, uint256 snapshotId);

    // ═══════════════════════════════════════════════════════════════
    //                           ERRORS
    // ═══════════════════════════════════════════════════════════════

    error AmountTooSmall();
    error InsufficientBalance();
    error AllocationMismatch();
    error RebalanceTooSoon();
    error ZeroAddress();

    // ═══════════════════════════════════════════════════════════════
    //                         CONSTRUCTOR
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Initialize the yield vault
     * @param _asset Underlying asset (USDC)
     * @param _aavePool Aave V3 Pool address
     * @param _aToken Aave aToken address
     * @param _compoundComet Compound V3 Comet address
     * @param _callbackProxy Reactive Network callback proxy
     */
    constructor(
        address _asset,
        address _aavePool,
        address _aToken,
        address _compoundComet,
        address _callbackProxy
    ) AbstractCallback(_callbackProxy) Ownable(msg.sender) {
        if (_asset == address(0) || _aavePool == address(0) || 
            _aToken == address(0) || _compoundComet == address(0)) {
            revert ZeroAddress();
        }
        
        asset = IERC20(_asset);
        aavePool = IAavePool(_aavePool);
        aToken = IERC20(_aToken);
        compoundComet = IComet(_compoundComet);
        
        // Default 50/50 allocation
        aaveAllocation = 5000;
        compoundAllocation = 5000;
    }

    // ═══════════════════════════════════════════════════════════════
    //                       USER FUNCTIONS
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Deposit assets into the vault
     * @param amount Amount to deposit
     */
    function deposit(uint256 amount) external nonReentrant whenNotPaused {
        if (amount < MIN_DEPOSIT) revert AmountTooSmall();
        
        // Transfer asset from user
        asset.safeTransferFrom(msg.sender, address(this), amount);
        
        // Update accounting
        userDeposits[msg.sender] += amount;
        totalDeposits += amount;
        
        // Allocate funds according to current split
        _allocateFunds(amount);
        
        emit Deposit(msg.sender, amount, userDeposits[msg.sender]);
        
        // Emit yield snapshot for RSC
        _emitYieldSnapshot();
    }

    /**
     * @notice Withdraw assets from the vault
     * @param amount Amount to withdraw
     */
    function withdraw(uint256 amount) external nonReentrant whenNotPaused {
        if (userDeposits[msg.sender] < amount) revert InsufficientBalance();
        
        // Update accounting first
        userDeposits[msg.sender] -= amount;
        totalDeposits -= amount;
        
        // Withdraw proportionally from both pools
        _withdrawFunds(amount);
        
        // Transfer to user
        asset.safeTransfer(msg.sender, amount);
        
        emit Withdraw(msg.sender, amount, userDeposits[msg.sender]);
    }

    /**
     * @notice Trigger a yield snapshot (for CRON or manual testing)
     * @dev Can be called by anyone, used by CRON trigger from RSC
     */
    function triggerYieldSnapshot() external {
        snapshotCounter++;
        emit SnapshotRequested(msg.sender, snapshotCounter);
        _emitYieldSnapshot();
    }

    // ═══════════════════════════════════════════════════════════════
    //                     CALLBACK FUNCTION
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Execute rebalancing triggered by RSC
     * @dev Only callable via Reactive Network callback
     * @param rvm_id The ReactVM ID (auto-injected)
     * @param newAavePct New allocation for Aave (basis points)
     * @param newCompoundPct New allocation for Compound (basis points)
     */
    function executeRebalance(
        address rvm_id,
        uint256 newAavePct,
        uint256 newCompoundPct
    ) external authorizedSenderOnly rvmIdOnly(rvm_id) nonReentrant whenNotPaused {
        // Validate allocations
        if (newAavePct + newCompoundPct != BPS) revert AllocationMismatch();
        
        // Rate limiting
        if (block.number < lastRebalanceBlock + MIN_REBALANCE_INTERVAL) {
            revert RebalanceTooSoon();
        }
        
        // Get current balances
        uint256 aaveBalance = _getAaveBalance();
        uint256 compoundBalance = _getCompoundBalance();
        uint256 totalBalance = aaveBalance + compoundBalance;
        
        if (totalBalance == 0) {
            // Nothing to rebalance
            return;
        }
        
        // Withdraw all from both pools
        if (aaveBalance > 0) {
            _withdrawFromAave(aaveBalance);
        }
        if (compoundBalance > 0) {
            _withdrawFromCompound(compoundBalance);
        }
        
        // Get actual withdrawn amount (may differ due to rounding)
        uint256 actualBalance = asset.balanceOf(address(this));
        
        // Reallocate
        uint256 toAave = (actualBalance * newAavePct) / BPS;
        uint256 toCompound = actualBalance - toAave;
        
        if (toAave > 0) {
            _depositToAave(toAave);
        }
        if (toCompound > 0) {
            _depositToCompound(toCompound);
        }
        
        // Update state
        aaveAllocation = newAavePct;
        compoundAllocation = newCompoundPct;
        lastRebalanceBlock = block.number;
        
        emit Rebalanced(newAavePct, newCompoundPct, toAave, toCompound);
        
        // Emit snapshot after rebalance
        _emitYieldSnapshot();
    }

    // ═══════════════════════════════════════════════════════════════
    //                      VIEW FUNCTIONS
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Get current Aave supply APY
     * @return apy APY in RAY format (1e27)
     */
    function getAaveAPY() public view returns (uint256 apy) {
        // Get reserve data from Aave
        IAavePool.ReserveData memory data = aavePool.getReserveData(address(asset));
        // liquidityRate is the current supply APY in RAY
        apy = uint256(data.currentLiquidityRate);
    }

    /**
     * @notice Get current Compound supply APY
     * @return apy APY scaled (need to convert from per-second rate)
     */
    function getCompoundAPY() public view returns (uint256 apy) {
        // Compound returns supply rate per second
        uint256 supplyRate = compoundComet.getSupplyRate(compoundComet.getUtilization());
        // Convert to annual: rate * seconds_per_year * 1e9 to match RAY scale roughly
        // Compound rate is in 1e18, convert to approximate RAY scale
        uint256 SECONDS_PER_YEAR = 31557600;
        apy = supplyRate * SECONDS_PER_YEAR;
    }

    /**
     * @notice Get total value locked in vault
     * @return tvl Total value across both pools
     */
    function getTotalValueLocked() public view returns (uint256 tvl) {
        tvl = _getAaveBalance() + _getCompoundBalance();
    }

    /**
     * @notice Get user's share of the vault
     * @param user User address
     * @return share User's deposit amount
     */
    function getUserBalance(address user) external view returns (uint256 share) {
        share = userDeposits[user];
    }

    /**
     * @notice Get current pool balances
     * @return aaveBalance Balance in Aave
     * @return compoundBalance Balance in Compound
     */
    function getPoolBalances() external view returns (uint256 aaveBalance, uint256 compoundBalance) {
        aaveBalance = _getAaveBalance();
        compoundBalance = _getCompoundBalance();
    }

    // ═══════════════════════════════════════════════════════════════
    //                    INTERNAL FUNCTIONS
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Allocate new funds according to current allocation
     */
    function _allocateFunds(uint256 amount) internal {
        uint256 toAave = (amount * aaveAllocation) / BPS;
        uint256 toCompound = amount - toAave;
        
        if (toAave > 0) {
            _depositToAave(toAave);
        }
        if (toCompound > 0) {
            _depositToCompound(toCompound);
        }
    }

    /**
     * @notice Withdraw funds proportionally from both pools
     */
    function _withdrawFunds(uint256 amount) internal {
        uint256 totalValue = getTotalValueLocked();
        if (totalValue == 0) return;
        
        uint256 aaveBalance = _getAaveBalance();
        uint256 compoundBalance = _getCompoundBalance();
        
        // Withdraw proportionally
        uint256 fromAave = (amount * aaveBalance) / totalValue;
        uint256 fromCompound = amount - fromAave;
        
        if (fromAave > 0 && aaveBalance > 0) {
            _withdrawFromAave(fromAave);
        }
        if (fromCompound > 0 && compoundBalance > 0) {
            _withdrawFromCompound(fromCompound);
        }
    }

    /**
     * @notice Deposit to Aave V3
     */
    function _depositToAave(uint256 amount) internal {
        asset.forceApprove(address(aavePool), amount);
        aavePool.supply(address(asset), amount, address(this), 0);
    }

    /**
     * @notice Withdraw from Aave V3
     */
    function _withdrawFromAave(uint256 amount) internal {
        aavePool.withdraw(address(asset), amount, address(this));
    }

    /**
     * @notice Deposit to Compound V3
     */
    function _depositToCompound(uint256 amount) internal {
        asset.forceApprove(address(compoundComet), amount);
        compoundComet.supply(address(asset), amount);
    }

    /**
     * @notice Withdraw from Compound V3
     */
    function _withdrawFromCompound(uint256 amount) internal {
        compoundComet.withdraw(address(asset), amount);
    }

    /**
     * @notice Get current balance in Aave
     */
    function _getAaveBalance() internal view returns (uint256) {
        return aToken.balanceOf(address(this));
    }

    /**
     * @notice Get current balance in Compound
     */
    function _getCompoundBalance() internal view returns (uint256) {
        return compoundComet.balanceOf(address(this));
    }

    /**
     * @notice Emit yield snapshot event
     */
    function _emitYieldSnapshot() internal {
        emit YieldSnapshot(
            snapshotCounter,
            getAaveAPY(),
            getCompoundAPY(),
            aaveAllocation,
            compoundAllocation,
            getTotalValueLocked(),
            block.timestamp
        );
    }

    // ═══════════════════════════════════════════════════════════════
    //                      ADMIN FUNCTIONS
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Set minimum yield difference for rebalancing
     * @param newMinDiff New minimum in basis points
     */
    function setMinYieldDiff(uint256 newMinDiff) external onlyOwner {
        minYieldDiffBps = newMinDiff;
    }

    /**
     * @notice Set minimum allocation per pool
     * @param newMinAlloc New minimum in basis points
     */
    function setMinAllocation(uint256 newMinAlloc) external onlyOwner {
        require(newMinAlloc <= 5000, "Max 50%");
        minAllocationBps = newMinAlloc;
    }

    /**
     * @notice Set funder contract for gas management
     * @param _funder Funder contract address
     */
    function setFunderContract(address _funder) external onlyOwner {
        funderContract = _funder;
    }

    /**
     * @notice Set authorized RVM ID for callbacks
     * @dev Must be called after deploying the reactive contract on Reactive Network
     * @param _rvmId The reactive contract deployer address on Reactive Network
     */
    function setRvmId(address _rvmId) external onlyOwner {
        rvm_id = _rvmId;
    }

    /**
     * @notice Pause the vault
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpause the vault
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @notice Emergency withdraw all funds
     * @dev Only for emergency situations
     */
    function emergencyWithdraw() external onlyOwner {
        uint256 aaveBalance = _getAaveBalance();
        uint256 compoundBalance = _getCompoundBalance();
        
        if (aaveBalance > 0) {
            aavePool.withdraw(address(asset), type(uint256).max, address(this));
        }
        if (compoundBalance > 0) {
            compoundComet.withdraw(address(asset), compoundBalance);
        }
        
        // Transfer all to owner
        uint256 balance = asset.balanceOf(address(this));
        if (balance > 0) {
            asset.safeTransfer(owner(), balance);
        }
    }

    /**
     * @notice Receive ETH for gas operations
     */
    receive() external payable override {}
}
