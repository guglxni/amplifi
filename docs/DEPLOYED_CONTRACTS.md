# Deployed Contracts Registry

> All deployed contracts for the Amplifi yield optimizer

---

## Sepolia Testnet (Chain ID: 11155111)

### Core Vault Contracts

| Contract | Address | Description |
|----------|---------|-------------|
| YieldVaultMultiAssetV2 | `0x42437f29E25Ad65E121f4D0f07FD8F5c2005e5d5` | Multi-asset yield vault (WETH, LINK, AAVE, EURS, WBTC) - EURS FIXED |
| VaultFeeCollector | `0x3777Afd270B483cAc21C3234fa72E34b9fed33Cf` | Fee collection for auto-replenishment |
| YieldVaultCompound | `0x13c0a04aa10f9eA0847BbFc00CeaB8b85941951a` | Compound V3 USDC vault |
| Funder | `0x0CabFEE932171171d90D672160cC6939f93b2D39` | Gas funding bridge contract |

### Oracle Contracts

| Contract | Address | Description |
|----------|---------|-------------|
| MultiFeedDestination | `0x889c32f46E273fBd0d5B1806F3f1286010cD73B3` | Unified cross-chain oracle |
| USDC Feed Proxy | `0xdE87eC23198867B298E74d1a2c902Aa02381b6d8` | USDC/USD price feed |
| ETH Feed Proxy | `0xb1aDCca598051EfdaD48217D950EAFf2CA869691` | ETH/USD price feed |
| BTC Feed Proxy | `0x736D13De4d6BF46DC81f89a759D6e3C2FbC9D6b9` | BTC/USD price feed |
| LINK Feed Proxy | `0x6B94668442B97e7dCF1958044a21e42a73D3647b` | LINK/USD price feed |
| EUR Feed Proxy | `0x955e94A600d059789d42ca533fe90c5187f520Af` | EUR/USD price feed |

### Protection Contracts (NEW)

| Contract | Address | Description |
|----------|---------|-------------|
| ProtectionVault | `0x2E9860dDB62d5Be1565877405B92D56a0fB20C90` | Liquidation protection reserve vault |

### Token Addresses

| Token | Address | Aave Status |
|-------|---------|-------------|
| WETH | `0xC558DBdd856501FCd9aaF1E62eae57A9F0629a3c` | ✅ No supply cap |
| LINK | `0xf8Fb3713D459D7C1018BD0A49D19b4C44290EBE5` | ✅ No supply cap |
| AAVE | `0x88541670E55cC00bEEFD87eB59EDd1b7C511AC9a` | ✅ No supply cap |
| EURS | `0x6d906e526a4e2Ca02097BA9d0caA3c382F52278E` | ✅ No supply cap |
| WBTC | `0x29f2D40B0605204364af54EC677bD022dA425d03` | ✅ High supply cap |

---

## Lasna Network (Chain ID: 5318007)

### Reactive Smart Contracts

| Contract | Address | Description |
|----------|---------|-------------|
| YieldOptimizerRsc | `0x98969559717c24b47A2E4365a569c947a88C4767` | Core yield optimization RSC |
| ReactiveFunderRC | `0x1caC802c52Cd82b9988e1163aF46258539280E71` | Auto-replenishment RSC |
| LiquidationProtectorRsc | `0xe6e06F94d1aaa2496b9e33afeE29f01436E9fA4A` | Health factor monitoring RSC |
| StopLossRsc | `0xa5738210F67a0C9c753b63EeC9d090557152df13` | Stop-loss/take-profit RSC |

---

## System Configuration

### Chain IDs
- Sepolia: `11155111`
- Lasna (Reactive): `5318007`

### Key Thresholds
- CRON Interval: 100 blocks (~12 min)
- Rebalance Threshold: 50 bps (0.5%)
- Finality Confirmation: 64 blocks
- Large Rebalance Threshold: 1000 basis points (10%)
- Protection Health Factor: 1.1e18 (1.1)

### External Protocol Addresses

| Protocol | Contract | Address |
|----------|----------|---------|
| Aave V3 | Pool | `0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951` |
| Compound V3 | Comet (USDC) | `0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238` |
| Reactive | Callback Proxy | `0x33Bbb7D0a2F1029550B0e91f653c4055DC9F4Dd8` |

---

## Verification Links

### Sepolia Etherscan
- [YieldVaultMultiAssetV2](https://sepolia.etherscan.io/address/0x38dB47900fb04Ff029Fcb77cD3e231790bf45a90)
- [ProtectionVault](https://sepolia.etherscan.io/address/0x2E9860dDB62d5Be1565877405B92D56a0fB20C90)

### Lasna Explorer
- [YieldOptimizerRsc](https://lasna-explorer.rnk.dev/address/0x98969559717c24b47A2E4365a569c947a88C4767)
- [LiquidationProtectorRsc](https://lasna-explorer.rnk.dev/address/0xe6e06F94d1aaa2496b9e33afeE29f01436E9fA4A)
- [StopLossRsc](https://lasna-explorer.rnk.dev/address/0xa5738210F67a0C9c753b63EeC9d090557152df13)

---

*Last Updated: December 28, 2024*
