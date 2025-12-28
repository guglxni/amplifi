// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IPayable} from "@reactive/interfaces/IPayable.sol";

/**
 * @title VaultFeeCollector
 * @notice Collects small fees from vault operations to fund callback payments
 * @dev Part of the True Auto-Replenishment pattern for Reactive Network
 * 
 * Architecture:
 * 1. VaultFeeCollector is deployed on the destination chain (Sepolia)
 * 2. The vault calls collectFee() on each deposit/withdrawal
 * 3. FeeCollected events are monitored by VaultFunderRSC on Reactive Network
 * 4. VaultFunderRSC triggers callbacks to fund the vault when needed
 * 
 * Fee Model:
 * - Supports both flat fees and percentage-based fees
 * - Configurable minimum and maximum fee amounts
 * - Owner can adjust fee structure without redeployment
 */
contract VaultFeeCollector is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ═══════════════════════════════════════════════════════════════
    //                         CONSTANTS
    // ═══════════════════════════════════════════════════════════════

    /// @notice Sepolia Callback Proxy address
    address payable public constant CALLBACK_PROXY = payable(0xc9f36411C9897e7F959D99ffca2a0Ba7ee0D7bDA);
    
    /// @notice Basis points denominator (10000 = 100%)
    uint256 public constant BPS = 10000;
    
    /// @notice Maximum fee in basis points (500 = 5%)
    uint256 public constant MAX_FEE_BPS = 500;

    // ═══════════════════════════════════════════════════════════════
    //                         STATE
    // ═══════════════════════════════════════════════════════════════

    /// @notice Target vault to fund
    address public vault;
    
    /// @notice Fee percentage in basis points (e.g., 10 = 0.1%)
    uint256 public feePercentageBps = 10; // 0.1% default
    
    /// @notice Minimum fee in wei
    uint256 public minFee = 0.0001 ether;
    
    /// @notice Threshold below which vault needs funding
    uint256 public fundingThreshold = 0.02 ether;
    
    /// @notice Amount to transfer when funding vault
    uint256 public fundingAmount = 0.05 ether;
    
    /// @notice Total fees collected lifetime
    uint256 public totalFeesCollected;
    
    /// @notice Total amount transferred to vault
    uint256 public totalFundedToVault;
    
    /// @notice Count of funding operations
    uint256 public fundingCount;
    
    /// @notice Authorized contracts that can collect fees
    mapping(address => bool) public authorizedVaults;
    
    /// @notice Last funding timestamp (for rate limiting)
    uint256 public lastFundingTime;
    
    /// @notice Minimum time between fundings (prevents spam)
    uint256 public minFundingInterval = 5 minutes;

    // ═══════════════════════════════════════════════════════════════
    //                           EVENTS
    // ═══════════════════════════════════════════════════════════════

    /// @notice Emitted when fee is collected - triggers reactive monitoring
    /// @param vault The vault that paid the fee
    /// @param amount Fee amount in wei
    /// @param totalCollected Lifetime total collected
    event FeeCollected(
        address indexed vault,
        uint256 amount,
        uint256 totalCollected
    );
    
    /// @notice Emitted when vault is funded
    /// @param vault Vault that received funding
    /// @param amount Amount transferred
    event VaultFunded(
        address indexed vault,
        uint256 amount
    );
    
    /// @notice Emitted when vault debt is covered
    /// @param vault Vault address
    /// @param debtAmount Debt that was paid
    event DebtCovered(address indexed vault, uint256 debtAmount);
    
    /// @notice Emitted when funding is needed but balance insufficient
    event InsufficientFundsForVault(address indexed vault, uint256 needed, uint256 available);
    
    /// @notice Emitted when settings are updated
    event SettingsUpdated(uint256 feePercentageBps, uint256 minFee, uint256 fundingThreshold, uint256 fundingAmount);
    
    /// @notice Emitted when vault is authorized/deauthorized
    event VaultAuthorizationChanged(address indexed vault, bool authorized);

    // ═══════════════════════════════════════════════════════════════
    //                        CONSTRUCTOR
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Initialize the fee collector
     * @param _vault Initial vault to fund and authorize
     */
    constructor(address _vault) Ownable(msg.sender) payable {
        require(_vault != address(0), "VaultFeeCollector: zero vault");
        vault = _vault;
        authorizedVaults[_vault] = true;
        emit VaultAuthorizationChanged(_vault, true);
    }

    // ═══════════════════════════════════════════════════════════════
    //                       FEE COLLECTION
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Collect fee from a vault operation
     * @dev Called by the vault on each deposit/withdrawal
     *      Emits FeeCollected which is monitored by VaultFunderRSC
     * @param txValue The transaction value (for percentage calculation)
     */
    function collectFee(uint256 txValue) external payable nonReentrant {
        require(authorizedVaults[msg.sender], "VaultFeeCollector: unauthorized");
        require(msg.value >= minFee, "VaultFeeCollector: fee too low");
        
        // Calculate expected fee (percentage of txValue, but minimum minFee)
        uint256 expectedFee = (txValue * feePercentageBps) / BPS;
        if (expectedFee < minFee) {
            expectedFee = minFee;
        }
        
        require(msg.value >= expectedFee, "VaultFeeCollector: insufficient fee");
        
        totalFeesCollected += msg.value;
        
        // Emit event that VaultFunderRSC monitors
        emit FeeCollected(msg.sender, msg.value, totalFeesCollected);
        
        // Check if vault needs immediate funding
        _checkAndFundVault();
    }
    
    /**
     * @notice Accept ETH directly (for funding by RSC callback)
     */
    receive() external payable {
        if (msg.value > 0) {
            totalFeesCollected += msg.value;
            emit FeeCollected(address(0), msg.value, totalFeesCollected);
        }
    }

    // ═══════════════════════════════════════════════════════════════
    //                       VAULT FUNDING
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Check vault balance and fund if needed
     * @dev Can be called by anyone but has rate limiting
     */
    function checkAndFundVault() external nonReentrant {
        _checkAndFundVault();
    }
    
    /**
     * @notice Internal function to check and fund vault
     */
    function _checkAndFundVault() internal {
        // Rate limiting
        if (block.timestamp < lastFundingTime + minFundingInterval) {
            return;
        }
        
        // Check vault balance
        uint256 vaultBalance = vault.balance;
        if (vaultBalance >= fundingThreshold) {
            return;
        }
        
        // Check our balance
        if (address(this).balance < fundingAmount) {
            emit InsufficientFundsForVault(vault, fundingAmount, address(this).balance);
            return;
        }
        
        // Fund the vault
        (bool success, ) = vault.call{value: fundingAmount}("");
        require(success, "VaultFeeCollector: funding failed");
        
        totalFundedToVault += fundingAmount;
        fundingCount++;
        lastFundingTime = block.timestamp;
        
        emit VaultFunded(vault, fundingAmount);
        
        // Also cover any outstanding debt
        _coverVaultDebt();
    }
    
    /**
     * @notice Cover vault's callback debt if any
     */
    function _coverVaultDebt() internal {
        // Check if callback proxy is a contract (not available in unit tests)
        if (CALLBACK_PROXY.code.length == 0) {
            return;
        }
        
        try IPayable(CALLBACK_PROXY).debt(vault) returns (uint256 debt) {
            if (debt > 0 && vault.balance >= debt) {
                // Try to call coverDebt on the vault
                (bool success, ) = vault.call(abi.encodeWithSignature("coverDebt()"));
                if (success) {
                    emit DebtCovered(vault, debt);
                }
            }
        } catch {
            // Debt check failed, ignore
        }
    }
    
    /**
     * @notice Force fund vault (owner only, bypasses rate limit)
     */
    function forceFundVault(uint256 amount) external onlyOwner nonReentrant {
        require(address(this).balance >= amount, "VaultFeeCollector: insufficient balance");
        
        (bool success, ) = vault.call{value: amount}("");
        require(success, "VaultFeeCollector: funding failed");
        
        totalFundedToVault += amount;
        fundingCount++;
        lastFundingTime = block.timestamp;
        
        emit VaultFunded(vault, amount);
    }

    // ═══════════════════════════════════════════════════════════════
    //                       VIEW FUNCTIONS
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Check if vault needs funding
     */
    function vaultNeedsFunding() external view returns (bool needs, uint256 vaultBalance) {
        vaultBalance = vault.balance;
        needs = vaultBalance < fundingThreshold;
    }
    
    /**
     * @notice Calculate fee for a given transaction value
     */
    function calculateFee(uint256 txValue) external view returns (uint256) {
        uint256 percentageFee = (txValue * feePercentageBps) / BPS;
        return percentageFee > minFee ? percentageFee : minFee;
    }
    
    /**
     * @notice Get contract statistics
     */
    function getStats() external view returns (
        uint256 _totalCollected,
        uint256 _totalFunded,
        uint256 _balance,
        uint256 _fundingCount,
        uint256 _vaultBalance
    ) {
        return (
            totalFeesCollected,
            totalFundedToVault,
            address(this).balance,
            fundingCount,
            vault.balance
        );
    }
    
    /**
     * @notice Get vault debt from callback proxy
     */
    function getVaultDebt() external view returns (uint256) {
        try IPayable(CALLBACK_PROXY).debt(vault) returns (uint256 debt) {
            return debt;
        } catch {
            return 0;
        }
    }

    // ═══════════════════════════════════════════════════════════════
    //                       ADMIN FUNCTIONS
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Update vault address
     */
    function setVault(address _vault) external onlyOwner {
        require(_vault != address(0), "VaultFeeCollector: zero address");
        authorizedVaults[vault] = false;
        vault = _vault;
        authorizedVaults[_vault] = true;
        emit VaultAuthorizationChanged(_vault, true);
    }
    
    /**
     * @notice Authorize/deauthorize a vault
     */
    function setVaultAuthorization(address _vault, bool authorized) external onlyOwner {
        authorizedVaults[_vault] = authorized;
        emit VaultAuthorizationChanged(_vault, authorized);
    }
    
    /**
     * @notice Update fee settings
     */
    function updateSettings(
        uint256 _feePercentageBps,
        uint256 _minFee,
        uint256 _fundingThreshold,
        uint256 _fundingAmount
    ) external onlyOwner {
        require(_feePercentageBps <= MAX_FEE_BPS, "VaultFeeCollector: fee too high");
        
        feePercentageBps = _feePercentageBps;
        minFee = _minFee;
        fundingThreshold = _fundingThreshold;
        fundingAmount = _fundingAmount;
        
        emit SettingsUpdated(_feePercentageBps, _minFee, _fundingThreshold, _fundingAmount);
    }
    
    /**
     * @notice Set minimum funding interval
     */
    function setMinFundingInterval(uint256 interval) external onlyOwner {
        minFundingInterval = interval;
    }
    
    /**
     * @notice Emergency withdraw (owner only)
     */
    function emergencyWithdraw(address payable to, uint256 amount) external onlyOwner {
        require(amount <= address(this).balance, "VaultFeeCollector: insufficient balance");
        (bool success, ) = to.call{value: amount}("");
        require(success, "VaultFeeCollector: transfer failed");
    }
}
