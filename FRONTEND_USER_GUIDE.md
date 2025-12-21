# YieldOpt Frontend - User Guide

## 🚀 Quick Start

**Frontend URL:** `http://localhost:8080`

To start the frontend:
```bash
cd reactive-yield-optimizer/frontend
python3 -m http.server 8080
```

---

## 📱 Pages Overview

### 1. Dashboard (`index.html`)
The main overview of the entire yield optimization system.

### 2. Vault Operations (`vault.html`)
Deposit and withdraw from yield vaults.

### 3. Reactive Bridge (`bridge.html`)
Monitor and manage cross-chain gas funding.

### 4. Settings (`settings.html`)
View network connections and contract addresses.

---

## 🖥️ Dashboard Features

### **Total Value Locked (TVL)**
Shows the combined value locked across all yield pools (Aave USDC, Aave DAI, Compound V3).

### **Best Yield (Real-Time)**
Displays the highest current APY across all monitored pools with automatic identification of the best-performing pool.

### **APY Comparison Cards**
Three cards showing live APYs for:
- **Aave V3 USDC** - Primary Pool
- **Aave V3 DAI** - Secondary Pool  
- **Compound V3 USDC** - With utilization rate

### **Current Allocation**
Doughnut chart showing the current allocation split between USDC and DAI pools.

### **Yield History Chart**
Line chart plotting historical APY values (in basis points) for all three pools over time.

### **Reactive Status Panel**
Shows the state of the Reactive Smart Contract on Lasna:
- **CRON Monitoring** - Whether automated yield checks are active
- **CRON Interval** - Block interval between automated checks (e.g., 100 blocks)
- **Last Rebalance** - Block number of the last rebalance operation
- **Finality Mode** - Whether finality-aware mode is enabled for large rebalances

### **Funder Gas Tank**
Displays the cross-chain gas funding status:
- **Balance** - Current ETH balance in the Funder contract
- **Total Bridged** - Total ETH bridged to Reactive Network
- **Bridge Count** - Number of bridge operations completed
- **Can Bridge** - Whether threshold is met for a new bridge

### **Reactive Logs**
Live event log showing:
- YieldSnapshot events
- Rebalance operations
- Bridge transactions

---

## 💰 Vault Operations

### **Vault Selection**
Choose between two vault types:

1. **Yield Vault Dual-Asset (Aave)** - Supports USDC and DAI
2. **Compound V3** - Supports USDC only

### **Pool Selection** (Dual-Asset only)
- **USDC (Primary)** - 6 decimal precision
- **DAI (Secondary)** - 18 decimal precision

### **Actions**
- **Deposit** - Add funds to the selected vault/pool
- **Withdraw** - Remove funds from the vault

### **Admin Zone**
- **Trigger Yield Snapshot** - Manually triggers a yield snapshot event that will be processed by the RSC

### **Vault Stats**
- Last Rebalance time
- Minimum rebalance interval
- Current allocation percentages

---

## 🌉 Reactive Bridge

### **Funder Contract Stats**
- Gas tank balance visualization
- Total collected vs bridged amounts
- Bridge threshold and gas reserve settings

### **Bridge Actions**
- **Cover Debt** - Bridge funds to cover RSC debt
- **Bridge to Faucet** - Convert SepETH to REACT via faucet

### **Auto-Refill Settings**
Shows ReactiveFunderRC configuration:
- Refill threshold
- Faucet bridge amount
- Auto-refill enabled status

---

## ⚙️ Settings

### **Network Connections**
- Sepolia RPC status and endpoint
- Lasna RPC status and endpoint

### **Deployed Contracts**
All contract addresses with Etherscan links:
- YieldVaultDualAsset
- YieldVaultCompound
- Funder
- YieldOptimizerReactive (Lasna)
- ReactiveFunderRC (Lasna)

### **Protocol Integrations**
- Aave V3 Pool addresses
- Compound V3 Comet address
- Reactive Faucet address

---

## 🔧 Backend Capabilities Showcased

### **1. Cross-Chain Yield Optimization**
The frontend demonstrates the YieldVaultDualAsset contract's ability to:
- Monitor yields across multiple DeFi protocols (Aave V3, Compound V3)
- Track real-time APY changes from on-chain data
- Maintain allocations based on yield performance

### **2. Reactive Smart Contracts (RSC)**
The YieldOptimizerReactive contract on Lasna:
- **Event-Driven Automation** - Reacts to YieldSnapshot events from Sepolia
- **CRON Subscriptions** - Periodic yield checks via block-based CRON
- **Cross-Chain Callbacks** - Emits rebalance commands back to Sepolia
- **Finality-Aware Operations** - Delays large rebalances for safety

### **3. Self-Sustaining Gas Pattern**
Demonstrated through the Funder + ReactiveFunderRC system:
- **Funder (Sepolia)** - Collects fees, bridges to RSC
- **ReactiveFunderRC (Lasna)** - Monitors and triggers auto-refills
- **Callback Proxy** - System contract for cross-chain deposits

### **4. Dual-State Architecture**
The frontend shows how RSCs maintain:
- **ReactVM State** - Updated by events (yield snapshots)
- **Reactive Network State** - Updated by admin calls

### **5. Protocol Integrations**
Live data from:
- **Aave V3** - getReserveData() for supply APY
- **Compound V3** - getSupplyRate() for yield calculation
- **Reactive Faucet** - SepETH to REACT conversion

---

## 🔗 Wallet Connection

Click **"Connect Wallet"** in the top-right corner. Requirements:
- MetaMask or compatible wallet
- Connected to Sepolia testnet (Chain ID: 11155111)

The app will prompt to switch networks if needed.

---

## 📊 Understanding the Data

### **APY Values**
Displayed as percentages (e.g., 5.76%). Calculated from on-chain data in basis points (BPS), where 1% = 100 BPS.

### **Allocation**
Shown as percentages (e.g., USDC: 50%, DAI: 50%). Based on BPS where total = 10000.

### **ETH Values**
Funder balances shown in ETH format (e.g., 0.0050 ETH).

### **Block Numbers**
Rebalance timing shown as block numbers on Reactive Network.

---

## ⚠️ Important Notes

1. **Aave V3 Sepolia Supply Caps**: The Aave V3 pools on Sepolia have supply caps = 0, which may cause deposits to revert. Compound V3 is fully operational.

2. **Lasna Connectivity**: The Lasna RPC may occasionally be unreachable. The frontend handles this gracefully with "RPC Err" messages.

3. **No Private Keys**: The frontend never stores or handles private keys. All transactions are signed by your connected wallet.

4. **Testnet Only**: All contracts are deployed on Sepolia and Lasna testnets. No real value is at stake.

---

## 🏗️ Contract Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         SEPOLIA                                  │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────────────┐    ┌─────────────────────┐            │
│  │ YieldVaultDualAsset │    │   YieldVaultCompound │            │
│  │  (Aave USDC/DAI)    │    │    (Compound V3)     │            │
│  └──────────┬──────────┘    └──────────┬──────────┘            │
│             │                          │                        │
│             │  YieldSnapshot Events    │                        │
│             └──────────┬───────────────┘                        │
│                        │                                        │
│  ┌─────────────────────▼──────────────────────┐                │
│  │              Funder.sol                     │                │
│  │  - Collects fees from users                 │                │
│  │  - Bridges to RSC via Callback Proxy        │                │
│  │  - Maintains gas reserve                    │                │
│  └─────────────────────┬──────────────────────┘                │
│                        │                                        │
└────────────────────────┼────────────────────────────────────────┘
                         │ Cross-Chain Bridge
┌────────────────────────┼────────────────────────────────────────┐
│                        │         LASNA (Reactive Network)       │
├────────────────────────┼────────────────────────────────────────┤
│  ┌─────────────────────▼──────────────────────┐                │
│  │         YieldOptimizerReactive              │                │
│  │  - Subscribes to YieldSnapshot events       │                │
│  │  - Compares APYs between pools              │                │
│  │  - Emits executeRebalance callbacks         │                │
│  │  - CRON-based periodic checks               │                │
│  │  - Finality-aware for large rebalances      │                │
│  └────────────────────────────────────────────┘                │
│                                                                  │
│  ┌────────────────────────────────────────────┐                │
│  │           ReactiveFunderRC                  │                │
│  │  - Monitors FundsReceived events            │                │
│  │  - Auto-triggers coverDebt() callbacks      │                │
│  │  - Self-sustaining gas pattern              │                │
│  └────────────────────────────────────────────┘                │
└──────────────────────────────────────────────────────────────────┘
```

---

## 🎯 Key Bounty 3 Features Demonstrated

1. **Yield Comparison Logic** - 80/20 allocation to higher-yielding pool
2. **Cross-Chain Event Subscriptions** - Subscribe to Sepolia events from Lasna
3. **Callback Emissions** - Send executeRebalance commands cross-chain
4. **CRON Functionality** - Block-interval based periodic checks
5. **Finality-Aware Mode** - Wait 64 blocks for large rebalances
6. **Self-Sustaining Gas** - Automatic RSC funding via Funder pattern
7. **Rate Limiting** - Minimum blocks between rebalance callbacks
8. **Dual Protocol Support** - Aave V3 and Compound V3 integration

---

## 📞 Support

For issues or questions, refer to:
- [Reactive Network Docs](https://dev.reactive.network/)
- [Reactive Smart Contract Demos](https://github.com/Reactive-Network/reactive-smart-contract-demos)
