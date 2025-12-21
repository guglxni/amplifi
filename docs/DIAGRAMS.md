# YieldOpt Architecture Diagrams

> Visual documentation of the YieldOpt cross-chain yield optimization system

---

## Table of Contents

1. [System Overview](#system-overview)
2. [Oracle Infrastructure](#oracle-infrastructure)
3. [Vault Operations](#vault-operations)
4. [Reactive Smart Contracts](#reactive-smart-contracts)
5. [Self-Sustaining Gas](#self-sustaining-gas)

---

## System Overview

### Unified System Architecture

![System Architecture](./diagrams/system-architecture.png)

The YieldOpt system spans multiple blockchains:
- **Ethereum Sepolia**: Main DeFi operations, Aave V3 integration
- **Lasna (Reactive Network)**: Autonomous monitoring and callbacks
- **Base Sepolia & Polygon Amoy**: Chainlink price feed sources

### Contract Relationships

![Contract Classes](./diagrams/contract-classes.png)

Key contract interactions:
- `YieldVaultMultiAsset` ← monitors → `YieldOptimizerRsc`
- `UnifiedPriceOracle` ← queries → `AbstractFeedProxy`
- `Funder` ← monitors → `ReactiveFunderRC`

---

## Oracle Infrastructure

### Unified Cross-Chain Oracle

![Unified Oracle](./diagrams/unified-oracle.png)

The `UnifiedPriceOracle` aggregates prices from multiple sources:
- **MultiFeed** (reactive-bounty-1): ETH, BTC, LINK from Base Sepolia
- **AbstractFeedProxy** (aggreatorv3-bridge): USDC, EUR from multiple chains
- **Correlated**: AAVE derived from LINK × 10x

### Oracle Bridge Flow

![Oracle Bridge Flow](./diagrams/oracle-bridge-flow.png)

Cross-chain price bridging architecture:
1. Chainlink emits `AnswerUpdated` on origin chain
2. `ChainlinkMirrorReactive` on Lasna detects event
3. Callback triggers `updateFromBridge` on `AbstractFeedProxy`
4. `UnifiedPriceOracle` queries updated price

### Multi-Asset Support

![Multi-Asset Support](./diagrams/multi-asset-support.png)

All 6 supported assets with their oracle sources and live prices.

---

## Vault Operations

### Deposit & Withdraw Flow

![Vault Operations](./diagrams/vault-operations.png)

User interaction with the multi-asset vault:
1. User approves token spending
2. User deposits to vault
3. Vault supplies to Aave V3
4. Vault issues vault shares
5. User can withdraw anytime

### Yield Optimization Flow

![Yield Flow](./diagrams/yield-flow.png)

Complete yield optimization sequence from detection to execution.

---

## Reactive Smart Contracts

### RSC State Machine

![RSC State Machine](./diagrams/rsc-state-machine.png)

The YieldOptimizerRsc lifecycle states:
- **Idle**: Waiting for events
- **Monitoring**: Processing CRON or YieldSnapshot
- **Comparing**: Analyzing APY differences
- **PendingFinality**: Waiting for block finality (large rebalances)
- **Executing**: Triggering rebalance callback

### CRON-Based Monitoring

![CRON Monitoring](./diagrams/cron-monitoring.png)

Periodic yield monitoring flow:
- CRON subscription triggers every ~12 minutes
- RSC requests yield snapshot from vault
- Vault collects APY data from Aave
- RSC compares and decides on rebalancing

### Rebalancing Logic

![Rebalancing Logic](./diagrams/rebalancing-logic.png)

Detailed rebalancing sequence:
1. Collect APYs from both pools
2. Compare yield difference
3. Skip if < 0.5% difference
4. Queue large rebalances for finality
5. Execute via callback for normal rebalances

---

## Self-Sustaining Gas

### Reactivate Pattern

![Reactivate Pattern](./diagrams/reactivate-pattern.png)

The Reactivate pattern ensures RSCs never run out of gas:
1. Users pay fees to `Funder` contract
2. `ReactiveFunderRC` detects fee payments
3. Triggers bridge to convert SepETH → REACT
4. Auto-refills RSC when balance drops below threshold

### Gas Funding Flow

![Gas Funding](./diagrams/gas-funding.png)

Complete gas funding sequence ensuring continuous autonomous operation.

---

## Deployed Contracts

### Sepolia (11155111)

| Contract | Address | Purpose |
|----------|---------|---------|
| YieldVaultMultiAsset | `0x...` | Multi-asset vault |
| UnifiedPriceOracle | `0x...` | Price aggregation |
| Funder | `0x...` | Fee collection |
| AbstractFeedProxy (USDC) | `0x60d6a73A46b8bEC9905A9f9E6289EA3E4D40BE0D` | USDC/USD prices |
| AbstractFeedProxy (EUR) | `0x12c343722303F4B53644661FDC9B8b5B77b10f36` | EUR/USD prices |

### Lasna (5318007)

| Contract | Address | Purpose |
|----------|---------|---------|
| YieldOptimizerRsc | `0x98969559717c24b47A2E4365a569c947a88C4767` | Yield monitoring |
| ReactiveFunderRC | `0x...` | Gas funding |
| ChainlinkMirrorReactive (USDC) | `0xA43DC30AfCbb1449278F014d6c4655ACE6883e45` | USDC/USD bridge |
| ChainlinkMirrorReactive (EUR) | `0xd9a09674C4d86A44C2000e519CDcf33690A207a9` | EUR/USD bridge |

---

## View Raw Mermaid Source

All diagrams are created using Mermaid and can be found in `docs/diagrams/`:

| Diagram | Source File |
|---------|-------------|
| System Architecture | `system-architecture.mmd` |
| Unified Oracle | `unified-oracle.mmd` |
| Oracle Bridge Flow | `oracle-bridge-flow.mmd` |
| Multi-Asset Support | `multi-asset-support.mmd` |
| Vault Operations | `vault-operations.mmd` |
| Yield Flow | `yield-flow.mmd` |
| RSC State Machine | `rsc-state-machine.mmd` |
| CRON Monitoring | `cron-monitoring.mmd` |
| Rebalancing Logic | `rebalancing-logic.mmd` |
| Reactivate Pattern | `reactivate-pattern.mmd` |
| Gas Funding | `gas-funding.mmd` |
| Contract Classes | `contract-classes.mmd` |

To regenerate PNGs from Mermaid source:
```bash
cd docs/diagrams
mmdc -i diagram-name.mmd -o diagram-name.png -b transparent
```
