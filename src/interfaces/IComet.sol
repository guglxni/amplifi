// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title IComet
/// @notice Interface for Compound V3 (Comet) protocol
/// @dev Based on https://docs.compound.finance/v3/
interface IComet {
    // ============ Supply & Withdraw ============
    
    /// @notice Supply an asset to the protocol
    /// @param asset The address of the asset to supply
    /// @param amount The amount to supply
    function supply(address asset, uint amount) external;
    
    /// @notice Supply an asset on behalf of another account
    /// @param dst The destination account
    /// @param asset The address of the asset to supply
    /// @param amount The amount to supply
    function supplyTo(address dst, address asset, uint amount) external;
    
    /// @notice Supply from one account to another
    /// @param from The source account
    /// @param dst The destination account
    /// @param asset The address of the asset
    /// @param amount The amount to supply
    function supplyFrom(address from, address dst, address asset, uint amount) external;
    
    /// @notice Withdraw an asset from the protocol
    /// @param asset The address of the asset to withdraw
    /// @param amount The amount to withdraw
    function withdraw(address asset, uint amount) external;
    
    /// @notice Withdraw an asset to another account
    /// @param to The destination address
    /// @param asset The address of the asset to withdraw
    /// @param amount The amount to withdraw
    function withdrawTo(address to, address asset, uint amount) external;
    
    /// @notice Withdraw from one account to another
    /// @param src The source account
    /// @param to The destination address
    /// @param asset The address of the asset
    /// @param amount The amount to withdraw
    function withdrawFrom(address src, address to, address asset, uint amount) external;
    
    // ============ View Functions ============
    
    /// @notice Get the base asset address
    function baseToken() external view returns (address);
    
    /// @notice Get the base token price feed address
    function baseTokenPriceFeed() external view returns (address);
    
    /// @notice Get the current supply rate (per second, scaled by 1e18)
    /// @param utilization The utilization rate to calculate for
    function getSupplyRate(uint utilization) external view returns (uint64);
    
    /// @notice Get the current borrow rate (per second, scaled by 1e18)
    /// @param utilization The utilization rate to calculate for
    function getBorrowRate(uint utilization) external view returns (uint64);
    
    /// @notice Get the current utilization
    function getUtilization() external view returns (uint);
    
    /// @notice Get user's base asset balance (includes accrued interest)
    /// @param account The account to check
    function balanceOf(address account) external view returns (uint256);
    
    /// @notice Get total supply of base asset
    function totalSupply() external view returns (uint256);
    
    /// @notice Get total borrow of base asset
    function totalBorrow() external view returns (uint256);
    
    /// @notice Number of decimals for the base token
    function decimals() external view returns (uint8);
    
    /// @notice Check if account has positive base balance (lender)
    /// @param account The account to check
    function hasPositiveBalance(address account) external view returns (bool);
    
    /// @notice Get the base scale (10 ** baseToken.decimals)
    function baseScale() external view returns (uint);
    
    // ============ Collateral ============
    
    /// @notice Get collateral balance for an account
    /// @param account The account to check
    /// @param asset The collateral asset
    function collateralBalanceOf(address account, address asset) external view returns (uint128);
    
    /// @notice Check if account is liquidatable
    /// @param account The account to check
    function isLiquidatable(address account) external view returns (bool);
    
    // ============ Protocol Info ============
    
    /// @notice Get number of assets in the protocol
    function numAssets() external view returns (uint8);
    
    /// @notice Get asset info by index
    /// @param i The index
    function getAssetInfo(uint8 i) external view returns (AssetInfo memory);
    
    /// @notice Get asset info by address
    /// @param asset The asset address
    function getAssetInfoByAddress(address asset) external view returns (AssetInfo memory);
    
    // ============ Structs ============
    
    struct AssetInfo {
        uint8 offset;
        address asset;
        address priceFeed;
        uint64 scale;
        uint64 borrowCollateralFactor;
        uint64 liquidateCollateralFactor;
        uint64 liquidationFactor;
        uint128 supplyCap;
    }
}
