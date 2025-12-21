// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title MockComet
 * @notice Mock Compound V3 Comet for Sepolia testing
 * @dev Since Compound V3 is not deployed on Sepolia, this mock allows testing
 */
contract MockComet {
    using SafeERC20 for IERC20;
    
    IERC20 public immutable asset;
    mapping(address => uint256) public balanceOf;
    
    // Mock APY of 2.5% (simplified)
    uint256 public constant MOCK_SUPPLY_RATE = 793000000; // ~2.5% annual in per-second
    
    constructor(address _asset) {
        asset = IERC20(_asset);
    }
    
    function supply(address _asset, uint256 amount) external {
        require(_asset == address(asset), "Wrong asset");
        asset.safeTransferFrom(msg.sender, address(this), amount);
        balanceOf[msg.sender] += amount;
    }
    
    function withdraw(address _asset, uint256 amount) external {
        require(_asset == address(asset), "Wrong asset");
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        asset.safeTransfer(msg.sender, amount);
    }
    
    function getUtilization() external pure returns (uint256) {
        return 0.75e18; // 75% utilization mock
    }
    
    function getSupplyRate(uint256) external pure returns (uint256) {
        return MOCK_SUPPLY_RATE;
    }
}
