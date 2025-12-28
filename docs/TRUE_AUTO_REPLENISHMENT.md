# True Auto-Replenishment Pattern

## Overview

This document describes the **True Auto-Replenishment** pattern implemented for the Reactive Yield Optimizer. This pattern solves the critical problem of callback contracts running out of funds on destination chains.

## The Problem

When the Reactive Network sends callbacks to destination chains (like Sepolia), the callback proxy charges fees for gas execution. If the destination contract (vault) doesn't have ETH to pay these fees:

1. The callback executes but the vault accumulates **debt**
2. If debt isn't paid, the contract gets **blocklisted**
3. Future callbacks are **rejected**, breaking the entire system

```
Reactive Network (Lasna)  ──→  Callback Proxy (Sepolia)  ──→  Vault
                                       │
                                       │ "Pay me for gas!"
                                       │
                                       ▼
                               Vault has no ETH?
                                       │
                                       ▼
                              💀 BLOCKLISTED 💀
```

## The Reactivate Pattern (Original)

The original Reactivate pattern (from 2nd place Hackathon winner) focuses on **RSCs on Reactive Network**:

- Monitors RSC balance on Lasna
- Refills with REACT tokens via faucet
- Calls `coverDebt()` on RSC

**Limitation**: This doesn't help callback destination contracts on origin chains!

## True Auto-Replenishment (Our Solution)

We extend the Reactivate pattern to cover **callback destination contracts**:

### Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                              SEPOLIA                                     │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌─────────────────────┐    fees     ┌──────────────────────┐           │
│  │                     │────────────▶│                      │           │
│  │  YieldVaultDualAssetV2 │           │  VaultFeeCollector  │           │
│  │                     │◀────────────│                      │           │
│  │  - Charges 0.1% fee │    funds    │  - Collects fees     │           │
│  │  - Receives callbacks│            │  - Monitors vault    │           │
│  │  - Pays callback gas│            │  - Auto-refills      │           │
│  └─────────────────────┘             │  - Emits events      │           │
│           │                          └──────────────────────┘           │
│           │ YieldSnapshot                     │ FeeCollected            │
│           ▼                                   ▼                         │
└─────────────────────────────────────────────────────────────────────────┘
                                                │
                         Events flow to Reactive Network
                                                ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         REACTIVE NETWORK (Lasna)                         │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌─────────────────────────┐        ┌─────────────────────────┐         │
│  │                         │        │                         │         │
│  │  YieldOptimizerReactive │        │    VaultFunderRSC      │         │
│  │                         │        │                         │         │
│  │  - Rebalancing logic    │        │  - Monitors FeeCollected│         │
│  │  - 80/20 allocation     │        │  - Triggers funding     │         │
│  │  ──▶ executeRebalance() │        │  ──▶ checkAndFundVault()│         │
│  └─────────────────────────┘        └─────────────────────────┘         │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Components

#### 1. VaultFeeCollector (Sepolia)

Deployed on the destination chain, collects fees from vault operations:

```solidity
contract VaultFeeCollector {
    // Fee structure
    uint256 public feePercentageBps = 10;  // 0.1% default
    uint256 public minFee = 0.0001 ether;
    
    // Funding thresholds
    uint256 public fundingThreshold = 0.02 ether;
    uint256 public fundingAmount = 0.05 ether;
    
    // Collect fee from vault operations
    function collectFee(uint256 txValue) external payable {
        // Forward to fee pool
        emit FeeCollected(msg.sender, msg.value, totalFeesCollected);
        _checkAndFundVault();  // Local check
    }
    
    // Fund vault when below threshold
    function _checkAndFundVault() internal {
        if (vault.balance < fundingThreshold) {
            vault.call{value: fundingAmount}("");
            _coverVaultDebt();
        }
    }
}
```

#### 2. YieldVaultDualAssetV2 (Sepolia)

Updated vault that integrates fee collection:

```solidity
contract YieldVaultDualAssetV2 {
    IVaultFeeCollector public feeCollector;
    
    // Deposits now include fee
    function depositPrimary(uint256 amount) external payable {
        _collectFee(amount);  // Forward ETH to fee collector
        // ... rest of deposit logic
    }
    
    function _collectFee(uint256 txValue) internal {
        uint256 requiredFee = feeCollector.calculateFee(txValue);
        feeCollector.collectFee{value: msg.value}(txValue);
    }
}
```

#### 3. VaultFunderRSC (Lasna)

RSC that monitors FeeCollected events and triggers funding:

```solidity
contract VaultFunderRSC is IReactive, AbstractReactive {
    function react(LogRecord calldata log) external override vmOnly {
        // On FeeCollected or CRON
        _triggerFundingCheck("FEE_COLLECTED");
    }
    
    function _triggerFundingCheck(string memory reason) internal {
        // Rate limiting
        if (block.number < lastCallbackBlock + minBlocksBetweenCallbacks) return;
        
        // Emit callback to FeeCollector.checkAndFundVault()
        emit Callback(
            SEPOLIA_CHAIN_ID, 
            feeCollector, 
            CALLBACK_GAS_LIMIT, 
            abi.encodeWithSignature("checkAndFundVault()")
        );
    }
}
```

### Fee Model

| Transaction Value | Fee (0.1%) | Min Fee | Actual Fee |
|------------------|------------|---------|------------|
| 0.001 ETH        | 0.000001   | 0.0001  | **0.0001 ETH** |
| 0.1 ETH          | 0.0001     | 0.0001  | **0.0001 ETH** |
| 10 ETH           | 0.01       | 0.0001  | **0.01 ETH** |
| 100 ETH          | 0.1        | 0.0001  | **0.1 ETH** |

### Sustainability Calculation

With default settings:
- **Funding per top-up**: 0.05 ETH
- **Callbacks per funding**: ~50-100 (depending on gas prices)
- **Fee per deposit**: ~0.0001-0.01 ETH
- **Break-even**: ~5-500 deposits per funding cycle

This ensures the system is **self-sustaining** as long as there's consistent vault activity.

## Deployment

### Step 1: Deploy on Sepolia

```bash
forge script script/DeployAutoReplenishSystem.s.sol:DeploySepoliaContracts \
  --rpc-url $SEPOLIA_RPC \
  --broadcast \
  --verify
```

### Step 2: Deploy on Lasna

```bash
export VAULT_ADDRESS=<from step 1>
export FEE_COLLECTOR=<from step 1>

forge script script/DeployAutoReplenishSystem.s.sol:DeployReactiveContracts \
  --rpc-url https://lasna-rpc.rnk.dev \
  --broadcast
```

### Step 3: Configure System

```bash
cast send $VAULT "setRvmId(address)" $YIELD_RSC --rpc-url $SEPOLIA_RPC --private-key $PRIVATE_KEY
```

## Integration with Existing Vault

To add auto-replenishment to an existing vault:

1. Deploy `VaultFeeCollector` with the vault address
2. Deploy `VaultFunderRSC` with collector and vault addresses
3. Call `vault.setFeeCollector(feeCollectorAddress)`
4. Fund the collector with initial ETH

## Monitoring

### Check Vault Status

```bash
# Vault balance
cast balance $VAULT --rpc-url $SEPOLIA_RPC

# Vault debt
cast call $CALLBACK_PROXY "debt(address)" $VAULT --rpc-url $SEPOLIA_RPC

# Fee collector stats
cast call $FEE_COLLECTOR "getStats()" --rpc-url $SEPOLIA_RPC
```

### Reactscan Dashboard

Monitor VaultFunderRSC at: `https://lasna.reactscan.net/address/<FUNDER_RSC_ADDRESS>`

## Emergency Procedures

### Manual Funding

```bash
# Fund vault directly
cast send $VAULT --value 0.1ether --rpc-url $SEPOLIA_RPC --private-key $KEY

# Cover debt
cast send $VAULT "coverDebt()" --rpc-url $SEPOLIA_RPC --private-key $KEY
```

### Emergency Withdraw from Collector

```bash
cast send $FEE_COLLECTOR "emergencyWithdraw(address,uint256)" $RECIPIENT $AMOUNT \
  --rpc-url $SEPOLIA_RPC --private-key $KEY
```

## Key Learnings from Implementation

1. **Two funding domains**: RSCs on Reactive Network need REACT tokens; callback contracts on origin chains need native tokens (ETH)

2. **Callback payment flow**: Callback Proxy → execute callback → record debt → call `pay()` on contract → if insufficient, accumulate debt

3. **AbstractPayer pattern**: The `pay()` function is called BY the callback proxy AFTER execution, not before

4. **Blocklisting**: Contracts with unpaid debt get blocklisted, preventing future callbacks

5. **Rate limiting**: Essential to prevent callback spam draining funds

## References

- [Reactive Network Economy](https://dev.reactive.network/economy)
- [Reactivate Pattern](https://blog.reactive.network/reactivate-automated-monitoring-and-funding-for-reactive-contracts/)
- [Callbacks Documentation](https://dev.reactive.network/events-&-callbacks)
- [NatX223/Reactivate Implementation](https://github.com/NatX223/Reactivate)
