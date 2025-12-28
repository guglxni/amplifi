// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AbstractReactive} from "@reactive/abstract-base/AbstractReactive.sol";
import {AbstractPayer} from "@reactive/abstract-base/AbstractPayer.sol";
import {IReactive} from "@reactive/interfaces/IReactive.sol";
import {IPayer} from "@reactive/interfaces/IPayer.sol";

/**
 * @title FeeDistributorRsc
 * @notice Reactive Smart Contract for automated fee distribution
 * @dev Monitors fee collection events and triggers automatic distribution
 * 
 * Architecture:
 * - Subscribes to FeeCollected events from VaultFeeCollector
 * - Accumulates fees until threshold is reached
 * - Triggers distribution callbacks to treasury, stakers, and RSC funding
 * 
 * Inspired by Reactive Network's "Automated Buyback and Burn" use case
 * Reference: https://blog.reactive.network/automated-buyback
 */
contract FeeDistributorRsc is IReactive, AbstractReactive {
    // ═══════════════════════════════════════════════════════════════
    //                         CONSTANTS
    // ═══════════════════════════════════════════════════════════════

    /// @notice Sepolia chain ID
    uint256 private constant SEPOLIA_CHAIN_ID = 11155111;
    
    /// @notice Default callback gas limit
    uint64 private constant CALLBACK_GAS_LIMIT = 250000;
    
    /// @notice Fee collected event signature
    /// @dev keccak256("FeeCollected(address,uint256,uint256)")
    bytes32 private constant FEE_COLLECTED_TOPIC_0 = keccak256("FeeCollected(address,uint256,uint256)");
    
    /// @notice Minimum distribution threshold (0.1 ETH)
    uint256 public constant MIN_DISTRIBUTION_THRESHOLD = 0.1 ether;
    
    /// @notice Maximum basis points (100%)
    uint256 public constant MAX_BPS = 10000;

    // ═══════════════════════════════════════════════════════════════
    //                      DISTRIBUTION RATIOS
    // ═══════════════════════════════════════════════════════════════

    /// @notice RSC gas funding percentage (default 20%)
    uint256 public rscFundingBps = 2000;
    
    /// @notice Treasury percentage (default 30%)
    uint256 public treasuryBps = 3000;
    
    /// @notice Stakers reward percentage (default 50%)
    uint256 public stakersBps = 5000;

    // ═══════════════════════════════════════════════════════════════
    //                         STATE
    // ═══════════════════════════════════════════════════════════════

    /// @notice Owner address
    address public owner;
    
    /// @notice Fee collector contract address
    address public feeCollector;
    
    /// @notice Distribution threshold
    uint256 public distributionThreshold;
    
    /// @notice Pending fees awaiting distribution
    uint256 public pendingFees;
    
    /// @notice Treasury address
    address public treasury;
    
    /// @notice Staking rewards contract
    address public stakingRewards;
    
    /// @notice RSC funding address (Funder contract)
    address public rscFunder;
    
    /// @notice Total distributions executed
    uint256 public totalDistributions;
    
    /// @notice Total fees distributed
    uint256 public totalFeesDistributed;
    
    /// @notice Paused state
    bool public paused;

    // ═══════════════════════════════════════════════════════════════
    //                         EVENTS
    // ═══════════════════════════════════════════════════════════════

    event FeeAccumulated(address indexed source, uint256 amount, uint256 pending);
    
    event DistributionTriggered(
        uint256 indexed distributionId,
        uint256 totalAmount,
        uint256 toTreasury,
        uint256 toStakers,
        uint256 toRscFunding
    );
    
    event RatiosUpdated(uint256 rscBps, uint256 treasuryBps, uint256 stakersBps);
    
    event ThresholdUpdated(uint256 oldThreshold, uint256 newThreshold);
    
    event AddressesUpdated(address treasury, address stakingRewards, address rscFunder);

    // ═══════════════════════════════════════════════════════════════
    //                         ERRORS
    // ═══════════════════════════════════════════════════════════════

    error OnlyOwner();
    error ZeroAddress();
    error InvalidRatios();
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
     * @notice Initialize the fee distributor RSC
     * @param _feeCollector Fee collector contract address
     * @param _treasury Treasury address
     * @param _stakingRewards Staking rewards contract
     * @param _rscFunder RSC funder address
     */
    constructor(
        address _feeCollector,
        address _treasury,
        address _stakingRewards,
        address _rscFunder
    ) payable {
        if (_feeCollector == address(0)) revert ZeroAddress();
        if (_treasury == address(0)) revert ZeroAddress();
        if (_stakingRewards == address(0)) revert ZeroAddress();
        if (_rscFunder == address(0)) revert ZeroAddress();
        
        owner = msg.sender;
        feeCollector = _feeCollector;
        treasury = _treasury;
        stakingRewards = _stakingRewards;
        rscFunder = _rscFunder;
        distributionThreshold = MIN_DISTRIBUTION_THRESHOLD;
    }

    // ═══════════════════════════════════════════════════════════════
    //                    SUBSCRIPTION MANAGEMENT
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Subscribe to fee collection events
     */
    function subscribeToFees() external rnOnly {
        service.subscribe(
            SEPOLIA_CHAIN_ID,
            feeCollector,
            uint256(FEE_COLLECTED_TOPIC_0),
            REACTIVE_IGNORE,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE
        );
    }
    
    /**
     * @notice Unsubscribe from fee events
     */
    function unsubscribe() external rnOnly onlyOwner {
        bytes memory payload = abi.encodeWithSignature(
            "unsubscribe(uint256,address,uint256,uint256,uint256,uint256)",
            SEPOLIA_CHAIN_ID,
            feeCollector,
            uint256(FEE_COLLECTED_TOPIC_0),
            REACTIVE_IGNORE,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE
        );
        (bool success,) = address(service).call(payload);
        require(success, "Unsubscribe failed");
    }

    // ═══════════════════════════════════════════════════════════════
    //                    REACTIVE FUNCTION
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice React to FeeCollected events
     * @param log The log record from the event
     */
    function react(IReactive.LogRecord calldata log) external override vmOnly whenNotPaused {
        // Validate origin
        if (log.chain_id != SEPOLIA_CHAIN_ID) {
            return;
        }
        if (log._contract != feeCollector) {
            return;
        }
        
        // Decode fee amount
        // Expected: FeeCollected(address indexed vault, uint256 amount, uint256 timestamp)
        (, uint256 feeAmount,) = abi.decode(log.data, (address, uint256, uint256));
        
        // Accumulate fees
        pendingFees += feeAmount;
        
        emit FeeAccumulated(log._contract, feeAmount, pendingFees);
        
        // Check if threshold is reached
        if (pendingFees >= distributionThreshold) {
            _triggerDistribution();
        }
    }

    // ═══════════════════════════════════════════════════════════════
    //                    DISTRIBUTION LOGIC
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Trigger fee distribution
     */
    function _triggerDistribution() internal {
        uint256 amountToDistribute = pendingFees;
        
        // Calculate distribution amounts
        uint256 toRscFunding = (amountToDistribute * rscFundingBps) / MAX_BPS;
        uint256 toTreasury = (amountToDistribute * treasuryBps) / MAX_BPS;
        uint256 toStakers = amountToDistribute - toRscFunding - toTreasury;
        
        // Reset pending fees (in RN state)
        if (!vm) {
            pendingFees = 0;
            totalDistributions++;
            totalFeesDistributed += amountToDistribute;
        }
        
        // Emit callback to distribute to RSC funder
        if (toRscFunding > 0) {
            emit Callback(
                SEPOLIA_CHAIN_ID,
                rscFunder,
                CALLBACK_GAS_LIMIT,
                abi.encodeWithSignature("receiveFunding(uint256)", toRscFunding)
            );
        }
        
        // Emit callback to distribute to treasury
        if (toTreasury > 0) {
            emit Callback(
                SEPOLIA_CHAIN_ID,
                treasury,
                CALLBACK_GAS_LIMIT,
                abi.encodeWithSignature("receiveFees(uint256)", toTreasury)
            );
        }
        
        // Emit callback to distribute to stakers
        if (toStakers > 0) {
            emit Callback(
                SEPOLIA_CHAIN_ID,
                stakingRewards,
                CALLBACK_GAS_LIMIT,
                abi.encodeWithSignature("notifyRewardAmount(uint256)", toStakers)
            );
        }
        
        emit DistributionTriggered(
            totalDistributions,
            amountToDistribute,
            toTreasury,
            toStakers,
            toRscFunding
        );
    }
    
    /**
     * @notice Force distribution (owner only)
     */
    function forceDistribute() external onlyOwner {
        require(pendingFees > 0, "No pending fees");
        _triggerDistribution();
    }

    // ═══════════════════════════════════════════════════════════════
    //                    ADMIN FUNCTIONS
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Update distribution ratios
     * @param _rscBps RSC funding percentage in basis points
     * @param _treasuryBps Treasury percentage in basis points
     * @param _stakersBps Stakers percentage in basis points
     */
    function setRatios(
        uint256 _rscBps,
        uint256 _treasuryBps,
        uint256 _stakersBps
    ) external onlyOwner {
        if (_rscBps + _treasuryBps + _stakersBps != MAX_BPS) revert InvalidRatios();
        
        rscFundingBps = _rscBps;
        treasuryBps = _treasuryBps;
        stakersBps = _stakersBps;
        
        emit RatiosUpdated(_rscBps, _treasuryBps, _stakersBps);
    }
    
    /**
     * @notice Update distribution threshold
     * @param _threshold New threshold in wei
     */
    function setThreshold(uint256 _threshold) external onlyOwner {
        require(_threshold >= MIN_DISTRIBUTION_THRESHOLD, "Below minimum");
        
        uint256 oldThreshold = distributionThreshold;
        distributionThreshold = _threshold;
        
        emit ThresholdUpdated(oldThreshold, _threshold);
    }
    
    /**
     * @notice Update distribution addresses
     */
    function setAddresses(
        address _treasury,
        address _stakingRewards,
        address _rscFunder
    ) external onlyOwner {
        if (_treasury == address(0)) revert ZeroAddress();
        if (_stakingRewards == address(0)) revert ZeroAddress();
        if (_rscFunder == address(0)) revert ZeroAddress();
        
        treasury = _treasury;
        stakingRewards = _stakingRewards;
        rscFunder = _rscFunder;
        
        emit AddressesUpdated(_treasury, _stakingRewards, _rscFunder);
    }
    
    /**
     * @notice Transfer ownership
     */
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        owner = newOwner;
    }
    
    /**
     * @notice Pause distribution
     */
    function pause() external onlyOwner {
        paused = true;
    }
    
    /**
     * @notice Unpause distribution
     */
    function unpause() external onlyOwner {
        paused = false;
    }

    // ═══════════════════════════════════════════════════════════════
    //                    VIEW FUNCTIONS
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Get current distribution ratios
     */
    function getRatios() external view returns (
        uint256 rscBps,
        uint256 treasBps,
        uint256 stakeBps
    ) {
        return (rscFundingBps, treasuryBps, stakersBps);
    }
    
    /**
     * @notice Get distribution stats
     */
    function getStats() external view returns (
        uint256 pending,
        uint256 threshold,
        uint256 distributions,
        uint256 totalDistributed
    ) {
        return (pendingFees, distributionThreshold, totalDistributions, totalFeesDistributed);
    }
    
    /**
     * @notice Get distribution targets
     */
    function getTargets() external view returns (
        address _treasury,
        address _stakingRewards,
        address _rscFunder
    ) {
        return (treasury, stakingRewards, rscFunder);
    }
    
    /**
     * @notice Receive function for REACT tokens
     */
    receive() external payable override(AbstractPayer, IPayer) {}
}
