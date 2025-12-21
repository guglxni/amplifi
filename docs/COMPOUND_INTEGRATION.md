# Compound V3 Integration on Sepolia

> Technical guide for integrating Compound V3 (Comet) as the second yield pool

## 📍 Contract Addresses

### Compound V3 Sepolia USDC Market

| Contract | Address | Description |
|----------|---------|-------------|
| **cUSDCv3 (Comet Proxy)** | `0x285617313887d43256F852cAE0Ee4de4b68D45B0` | Main interaction point |
| cUSDCv3 Implementation | `0x528c57A87706C31765001779168b42f24c694E1b` | Logic contract |
| Configurator | `0x316f9708bB98af7dA9c68C1C3b5e79039cD336E3` | Protocol configuration |
| Configurator Impl | `0xcFC1fA6b7ca982176529899D99af6473aD80DF4F` | Config logic |
| Proxy Admin | `0x1EC63B5883C3481134FD50D5DAebc83Ecd2E8779` | Upgrade admin |
| Comet Factory | `0xa7F7De6cCad4D83d81676717053883337aC2c1b4` | Factory contract |
| CometWrapper (ERC-4626) | `0xC3836072018B4D590488b851d574556f2EeB895a` | ERC-4626 wrapper |

### Compound V3 Sepolia WETH Market

| Contract | Address | Description |
|----------|---------|-------------|
| **cWETHv3 (Comet Proxy)** | `0xc3d688B66703497DAA19211EEdff47f25384cdc3` | Main interaction point |

---

## 🔧 Comet Interface

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title IComet
/// @notice Interface for Compound V3 (Comet) protocol
interface IComet {
    /// @notice Supply an asset to the protocol
    /// @param asset The address of the asset to supply
    /// @param amount The amount to supply
    function supply(address asset, uint amount) external;
    
    /// @notice Supply an asset on behalf of another account
    /// @param dst The destination account
    /// @param asset The address of the asset to supply
    /// @param amount The amount to supply
    function supplyTo(address dst, address asset, uint amount) external;
    
    /// @notice Withdraw an asset from the protocol
    /// @param asset The address of the asset to withdraw
    /// @param amount The amount to withdraw
    function withdraw(address asset, uint amount) external;
    
    /// @notice Withdraw an asset to another account
    /// @param to The destination address
    /// @param asset The address of the asset to withdraw
    /// @param amount The amount to withdraw
    function withdrawTo(address to, address asset, uint amount) external;
    
    /// @notice Get the base asset address
    function baseToken() external view returns (address);
    
    /// @notice Get the current supply rate (per second, scaled by 1e18)
    function getSupplyRate(uint utilization) external view returns (uint64);
    
    /// @notice Get the current utilization
    function getUtilization() external view returns (uint);
    
    /// @notice Get user's base asset balance
    function balanceOf(address account) external view returns (uint256);
    
    /// @notice Get total supply of base asset
    function totalSupply() external view returns (uint256);
    
    /// @notice Number of decimals for the base token
    function decimals() external view returns (uint8);
    
    /// @notice Check if account has positive base balance
    function hasPositiveBalance(address account) external view returns (bool);
}
```

---

## 📊 APY Calculation

### Getting Supply Rate

```solidity
/// @notice Get Compound V3 supply APY
/// @param comet The Comet contract address
/// @return apy Annual percentage yield (scaled by 1e18)
function getCompoundAPY(IComet comet) public view returns (uint256) {
    // Get current utilization
    uint256 utilization = comet.getUtilization();
    
    // Get supply rate (per second, scaled by 1e18)
    uint64 supplyRatePerSecond = comet.getSupplyRate(utilization);
    
    // Convert to annual rate
    // APY = (1 + rate_per_second)^(seconds_per_year) - 1
    // Simplified: APY ≈ rate_per_second * seconds_per_year
    uint256 secondsPerYear = 365 days;
    uint256 apy = uint256(supplyRatePerSecond) * secondsPerYear;
    
    return apy;
}
```

### Comparison with Aave

```solidity
/// @notice Compare APYs between Aave and Compound
function compareAPYs() public view returns (
    uint256 aaveAPY,
    uint256 compoundAPY,
    address higherYieldPool
) {
    // Aave V3 uses "ray" units (1e27) for rates
    // Aave's currentLiquidityRate is already annual
    DataTypes.ReserveData memory aaveData = aavePool.getReserveData(USDC);
    aaveAPY = aaveData.currentLiquidityRate; // Already annualized, in ray (1e27)
    
    // Compound V3 uses per-second rate (1e18)
    compoundAPY = getCompoundAPY(IComet(COMPOUND_COMET));
    
    // Normalize for comparison (convert Aave from ray to 1e18)
    uint256 aaveNormalized = aaveAPY / 1e9; // 1e27 -> 1e18
    
    if (aaveNormalized > compoundAPY) {
        higherYieldPool = address(aavePool);
    } else {
        higherYieldPool = COMPOUND_COMET;
    }
    
    return (aaveAPY, compoundAPY, higherYieldPool);
}
```

---

## 🔄 Supply & Withdraw Operations

### Supplying to Compound V3

```solidity
function _depositToCompound(uint256 amount) internal {
    // 1. Approve Comet to spend USDC
    IERC20(USDC).approve(COMPOUND_COMET, amount);
    
    // 2. Supply USDC to Comet
    IComet(COMPOUND_COMET).supply(USDC, amount);
    
    // Note: Unlike Aave, Compound V3 doesn't give you a separate aToken.
    // Your balance is tracked internally by the Comet contract.
}
```

### Withdrawing from Compound V3

```solidity
function _withdrawFromCompound(uint256 amount) internal returns (uint256) {
    // Get current balance
    uint256 balance = IComet(COMPOUND_COMET).balanceOf(address(this));
    
    // Withdraw min of requested and available
    uint256 withdrawAmount = amount > balance ? balance : amount;
    
    // Withdraw USDC
    IComet(COMPOUND_COMET).withdraw(USDC, withdrawAmount);
    
    return withdrawAmount;
}
```

---

## ⚠️ Key Differences from Aave

| Aspect | Aave V3 | Compound V3 |
|--------|---------|-------------|
| **Token Representation** | Separate aTokens (aUSDC) | Internal balance tracking |
| **Rate Units** | Ray (1e27), annualized | Per-second (1e18) |
| **Supply Function** | `supply(asset, amount, onBehalfOf, referralCode)` | `supply(asset, amount)` |
| **Withdraw Function** | `withdraw(asset, amount, to)` returns uint256 | `withdraw(asset, amount)` |
| **Balance Check** | Query aToken balance | Call `balanceOf` on Comet |
| **Interest Accrual** | Rebasing aToken balance | Internal balance updates |

---

## 🧪 Testing Considerations

### Testnet Liquidity

Compound V3 on Sepolia may have limited liquidity. Strategies:

1. **Fork Testing**: Use Foundry's fork mode with `deal()` cheatcodes
2. **Mock Contract**: Deploy a mock Comet for predictable APY
3. **Small Amounts**: Test with small deposit amounts

### Mock Comet for Testing

```solidity
// For testing when real liquidity is limited
contract MockComet {
    uint64 public mockSupplyRate = 4e16; // 4% APY (per second scaled)
    mapping(address => uint256) public balances;
    
    function supply(address asset, uint amount) external {
        IERC20(asset).transferFrom(msg.sender, address(this), amount);
        balances[msg.sender] += amount;
    }
    
    function withdraw(address asset, uint amount) external {
        require(balances[msg.sender] >= amount, "Insufficient balance");
        balances[msg.sender] -= amount;
        IERC20(asset).transfer(msg.sender, amount);
    }
    
    function balanceOf(address account) external view returns (uint256) {
        return balances[account];
    }
    
    function getSupplyRate(uint) external view returns (uint64) {
        return mockSupplyRate;
    }
    
    function getUtilization() external pure returns (uint) {
        return 8e17; // 80% utilization
    }
    
    function setMockRate(uint64 rate) external {
        mockSupplyRate = rate;
    }
}
```

---

## 📚 Resources

- [Compound V3 Documentation](https://docs.compound.finance/v3/)
- [Comet GitHub Repository](https://github.com/compound-finance/comet)
- [Compound V3 Sepolia Deployment](https://docs.compound.finance/v3/technical-references/deployed-contracts/#sepolia)
- [Comet Interface Reference](https://docs.compound.finance/v3/technical-references/comet-interface/)

---

## ✅ Integration Checklist

- [ ] Add IComet interface to `src/interfaces/`
- [ ] Implement `_depositToCompound()` in YieldVault
- [ ] Implement `_withdrawFromCompound()` in YieldVault
- [ ] Implement `getCompoundAPY()` in YieldCalculator
- [ ] Normalize APY units for comparison (ray vs per-second)
- [ ] Write unit tests for Compound operations
- [ ] Write fork tests against real Sepolia Compound
- [ ] Deploy and verify integration
