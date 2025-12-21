// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {AbstractCallback} from "@reactive/abstract-base/AbstractCallback.sol";
import {IComet} from "./interfaces/IComet.sol";

/**
 * @title YieldVaultCompound
 * @notice Single-pool vault for Compound V3 (live deployment)
 * @dev Uses Circle USDC on Sepolia for Compound V3 integration
 */
contract YieldVaultCompound is Ownable, ReentrancyGuard, AbstractCallback {
    using SafeERC20 for IERC20;

    // ═══════════════════════════════════════════════════════════════
    //                         STATE VARIABLES
    // ═══════════════════════════════════════════════════════════════

    /// @notice Circle USDC token
    IERC20 public immutable usdc;
    
    /// @notice Compound V3 Comet (cUSDCv3)
    IComet public immutable comet;
    
    /// @notice Snapshot counter for events
    uint256 public snapshotCounter;
    
    /// @notice Last snapshot timestamp
    uint256 public lastSnapshotTime;

    // ═══════════════════════════════════════════════════════════════
    //                           EVENTS
    // ═══════════════════════════════════════════════════════════════

    event YieldSnapshot(
        uint256 indexed snapshotId,
        uint256 compoundAPY,
        uint256 utilization,
        uint256 tvl,
        uint256 timestamp
    );

    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);

    // ═══════════════════════════════════════════════════════════════
    //                        CONSTRUCTOR
    // ═══════════════════════════════════════════════════════════════

    constructor(
        address _usdc,           // Circle USDC: 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238
        address _comet,          // cUSDCv3: 0xAec1F48e02Cfb822Be958B68C7957156EB3F0b6e
        address _callbackProxy
    ) Ownable(msg.sender) AbstractCallback(_callbackProxy) {
        usdc = IERC20(_usdc);
        comet = IComet(_comet);
        
        // Approve Comet for max
        IERC20(_usdc).approve(_comet, type(uint256).max);
    }

    // ═══════════════════════════════════════════════════════════════
    //                      DEPOSIT/WITHDRAW
    // ═══════════════════════════════════════════════════════════════

    function deposit(uint256 amount) external nonReentrant {
        usdc.safeTransferFrom(msg.sender, address(this), amount);
        comet.supply(address(usdc), amount);
        emit Deposited(msg.sender, amount);
        _emitSnapshot();
    }

    function withdraw(uint256 amount) external nonReentrant onlyOwner {
        comet.withdraw(address(usdc), amount);
        usdc.safeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    // ═══════════════════════════════════════════════════════════════
    //                      YIELD SNAPSHOT
    // ═══════════════════════════════════════════════════════════════

    function triggerYieldSnapshot() external {
        _emitSnapshot();
    }

    function _emitSnapshot() internal {
        uint256 utilization = comet.getUtilization();
        uint256 supplyRate = comet.getSupplyRate(utilization);
        uint256 tvl = comet.balanceOf(address(this));
        
        // Convert supply rate to APY (per-second rate * seconds/year)
        // supplyRate is in 1e18 per second
        uint256 apy = (supplyRate * 365 days) / 1e14; // Convert to bps
        
        snapshotCounter++;
        lastSnapshotTime = block.timestamp;
        
        emit YieldSnapshot(
            snapshotCounter,
            apy,
            utilization,
            tvl,
            block.timestamp
        );
    }

    // ═══════════════════════════════════════════════════════════════
    //                      VIEW FUNCTIONS
    // ═══════════════════════════════════════════════════════════════

    function getCompoundAPY() public view returns (uint256) {
        uint256 utilization = comet.getUtilization();
        uint256 supplyRate = comet.getSupplyRate(utilization);
        return (supplyRate * 365 days) / 1e14; // bps
    }

    function getUtilization() public view returns (uint256) {
        return comet.getUtilization();
    }

    function getTotalValueLocked() public view returns (uint256) {
        return comet.balanceOf(address(this));
    }

    // ═══════════════════════════════════════════════════════════════
    //                      ADMIN FUNCTIONS
    // ═══════════════════════════════════════════════════════════════

    function setRvmId(address _rvmId) external onlyOwner {
        rvm_id = _rvmId;
    }

    receive() external payable override {}
}
