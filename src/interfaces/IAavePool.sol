// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title IAavePool
/// @notice Interface for Aave V3 Pool
interface IAavePool {
    /// @notice Supply an asset to the protocol
    function supply(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode
    ) external;
    
    /// @notice Withdraw an asset from the protocol
    function withdraw(
        address asset,
        uint256 amount,
        address to
    ) external returns (uint256);
    
    /// @notice Get reserve data for an asset
    function getReserveData(address asset) external view returns (ReserveData memory);
    
    /// @notice Get user account data
    function getUserAccountData(address user) external view returns (
        uint256 totalCollateralBase,
        uint256 totalDebtBase,
        uint256 availableBorrowsBase,
        uint256 currentLiquidationThreshold,
        uint256 ltv,
        uint256 healthFactor
    );
    
    struct ReserveData {
        // Configuration
        uint256 configuration;
        // Liquidity index (ray)
        uint128 liquidityIndex;
        // Current supply rate (ray)
        uint128 currentLiquidityRate;
        // Variable borrow index (ray)
        uint128 variableBorrowIndex;
        // Current variable borrow rate (ray)
        uint128 currentVariableBorrowRate;
        // Current stable borrow rate (ray)
        uint128 currentStableBorrowRate;
        // Last update timestamp
        uint40 lastUpdateTimestamp;
        // Id
        uint16 id;
        // aToken address
        address aTokenAddress;
        // Stable debt token address
        address stableDebtTokenAddress;
        // Variable debt token address
        address variableDebtTokenAddress;
        // Interest rate strategy address
        address interestRateStrategyAddress;
        // Accrued to treasury
        uint128 accruedToTreasury;
        // Unbacked
        uint128 unbacked;
        // Isolation mode total debt
        uint128 isolationModeTotalDebt;
    }
}
