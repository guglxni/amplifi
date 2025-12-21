# Reactive Yield Optimizer 🔄💰

> **Cross-Chain Yield Automation for Lenders using Reactive Smart Contracts**
> 
> Built for [Reactive Network Bounty 3](https://dorahacks.io/hackathon/bounty/1317)

## 📋 Overview

The Reactive Yield Optimizer is a vault that **automatically routes funds across different lending pools** to achieve better yields. Using Reactive Smart Contracts, the system monitors yield rates and rebalances allocations without user intervention.

### How It Works

```
User Deposits USDC
       │
       ▼
┌─────────────────────────────────────────────────────────────┐
│                     YieldVault.sol                          │
│  ┌───────────────────┐        ┌───────────────────┐        │
│  │   AAVE V3 USDC    │   ◄──► │  COMPOUND V3 USDC │        │
│  │   APY: 3.5%       │        │   APY: 4.2%       │        │
│  └───────────────────┘        └───────────────────┘        │
│            │ Emits YieldSnapshot events                     │
└────────────┼────────────────────────────────────────────────┘
             ▼
┌─────────────────────────────────────────────────────────────┐
│            YieldOptimizerReactive.sol (Lasna)               │
│  - Monitors yield snapshots from both pools                 │
│  - Compares APYs and determines optimal allocation          │
│  - Triggers rebalance if yield difference > threshold       │
└─────────────────────────────────────────────────────────────┘
             │ Callback
             ▼
        executeRebalance() → Funds move to higher-yield pool
```

## 🎯 Key Features

- **Automatic Yield Optimization** - RSC monitors and rebalances without user action
- **Dual Pool Support** - Aave V3 + Compound V3 on Sepolia
- **Self-Sustaining Gas** - Reactivate pattern for continuous operation
- **Configurable Thresholds** - Minimum yield difference before rebalancing
- **Diversification Rules** - Maintain minimum allocation (20%) for risk management

## 📊 Contract Addresses

### Sepolia Testnet (Chain ID: 11155111)

| Contract | Address | Status |
|----------|---------|--------|
| YieldVaultDualAsset | `0xe6e06F94d1aaa2496b9e33afeE29f01436E9fA4A` | ✅ Deployed |
| YieldVaultCompound | `0x13c0a04aa10f9eA0847BbFc00CeaB8b85941951a` | ✅ Deployed |
| Funder | `0x9f7c78a50379dc4d9703b19c708088d5eac5c923` | ✅ Deployed |
| Aave V3 Pool | `0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951` | ✅ Active |
| Compound V3 cUSDCv3 | `0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238` | ✅ Active |
| Callback Proxy | `0xc9f36411C9897e7F959D99ffca2a0Ba7ee0D7bDA` | ✅ Active |

### Reactive Network Lasna (Chain ID: 5318007)

| Contract | Address | Status |
|----------|---------|--------|
| YieldOptimizerReactive | `0xF040124007bd188F377c0058a58900F31c78B2b6` | ✅ Deployed |
| ReactiveFunderRC | `0xf075E097d7219CC04cE25D659f04d4b1cbD42A7A` | ✅ Deployed |
| System Contract | `0x0000000000000000000000000000000000fffFfF` | ✅ Active |

### ⚠️ Known Testnet Limitation

> **Aave V3 Sepolia Supply Caps = 0**
> 
> All Aave reserves on Sepolia have `Supply Cap = 0`, meaning new supplies are blocked (Error 51: SUPPLY_CAP_EXCEEDED). This is an Aave governance configuration, not a bug in our code.
>
> **Mitigations:**
> - Compound V3 deposit/withdraw is fully tested and working
> - Aave APY queries work correctly (proves integration)
> - 111 unit tests pass including Aave allocation logic
> - Mainnet has active supply caps (7.5B USDC)


## 🚀 Quick Start

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Node.js 18+
- Sepolia ETH (for gas)
- REACT tokens (for Lasna)

### Installation

```bash
# Clone the repository
git clone https://github.com/YOUR_USERNAME/reactive-yield-optimizer.git
cd reactive-yield-optimizer

# Install dependencies
forge install

# Copy environment file
cp .env.example .env
# Edit .env with your keys

# Run tests
forge test -vvv

# Deploy to Sepolia
forge script script/DeployYieldVault.s.sol --rpc-url $SEPOLIA_RPC --broadcast

# Deploy to Lasna
forge script script/DeployYieldOptimizer.s.sol --rpc-url $REACTIVE_RPC --broadcast
```

## 🏗️ Project Structure

```
reactive-yield-optimizer/
├── src/
│   ├── YieldVault.sol              # Main vault contract (Sepolia)
│   ├── YieldOptimizerReactive.sol  # RSC for yield decisions (Lasna)
│   ├── Funder.sol                  # Self-sustaining gas
│   ├── ReactiveFunderRC.sol        # Reactive funder
│   ├── interfaces/
│   │   ├── IAavePool.sol           # Aave V3 interface
│   │   ├── IComet.sol              # Compound V3 interface
│   │   └── IYieldVault.sol
│   └── libraries/
│       └── YieldCalculator.sol
├── script/
│   ├── DeployYieldVault.s.sol
│   ├── DeployYieldOptimizer.s.sol
│   └── TriggerSnapshot.s.sol
├── test/
│   ├── unit/
│   ├── integration/
│   └── fork/
├── docs/
│   ├── ARCHITECTURE.md
│   ├── DEPLOYMENT.md
│   └── COMPOUND_INTEGRATION.md
├── foundry.toml
└── README.md
```

## 📖 Documentation

- [Compound V3 Integration](docs/COMPOUND_INTEGRATION.md)
- [Architecture Overview](docs/ARCHITECTURE.md) (Coming Soon)
- [Deployment Guide](docs/DEPLOYMENT.md) (Coming Soon)

## 🔗 Related Resources

- [Reactive Network Docs](https://dev.reactive.network)
- [Aave V3 Docs](https://docs.aave.com/developers/)
- [Compound V3 (Comet) Docs](https://docs.compound.finance/v3/)
- [Bounty 3 Specification](https://dorahacks.io/hackathon/bounty/1317)

## 🔄 Comparison with Bounty 2 (Auto-Looper)

| Aspect | Bounty 2: Auto-Looper | Bounty 3: Yield Optimizer |
|--------|----------------------|---------------------------|
| **Goal** | Achieve target leverage | Maximize yield returns |
| **Pools** | Aave V3 only | Aave V3 + Compound V3 |
| **Decision** | Health factor + leverage | APY comparison |
| **Action** | Supply/Borrow/Swap cycles | Withdraw/Deposit rebalancing |
| **Complexity** | Higher (multi-step loops) | Lower (simple reallocation) |

## 📅 Bounty Timeline

- **Deadline:** December 28, 2024, 11:59 PM UTC
- **Prize:** TBD

## 📄 License

MIT License - see [LICENSE](LICENSE)

---

*Built with ❤️ for Reactive Network Bounty 3*
