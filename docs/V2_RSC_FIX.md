# V2 RSC Fix - Aggregator vs Proxy Subscription

## Recent Updates (January 7, 2026)

### TVL Coherency Fix
**Issue:** Dashboard showed $11,420.77 TVL while Multi-Asset page showed $11,419.77 ($1 difference)

**Cause:** Dashboard was including deprecated YieldVaultCompound ($1 TVL) in total calculation

**Solution:** Removed Compound vault from TVL aggregation in [index.html](../frontend/index.html). Both pages now show identical Multi-Asset vault TVL.

**Files Modified:**
- `frontend/index.html` - Removed `fetchCompoundData()` and Compound TVL from total
- `docs/DEPLOYED_CONTRACTS.md` - Marked Compound vault as DEPRECATED
- `docs/BOUNTY_COMPLIANCE.md` - Marked Compound vault as DEPRECATED
- `docs/DIAGRAMS.md` - Marked Compound vault as DEPRECATED

### JavaScript Syntax Fix (Oracle Page)
**Issue:** Oracle page stuck on "Loading prices..." 

**Cause:** Duplicate closing brace `}` at line 1156 in oracle.html causing parse failure

**Solution:** Removed extra brace, verified 326 open = 326 close braces. Simplified `getRscDebtStatus()` to use direct JSON-RPC instead of ethers.js.

**Files Modified:**
- `frontend/oracle.html` - Fixed brace balance, added timeout handling

### Bridge V2 RSC Address Update
**Issue:** Bridge dropdown had old V2 RSC addresses from initial deployment

**Solution:** Updated dropdown with correct V2 addresses deployed January 6, 2026

**Files Modified:**
- `frontend/bridge.html` - Updated ETH/BTC/LINK V2 RSC addresses in dropdown

---

## Original V2 RSC Fix (January 6, 2026)

## Problem
V2 RSCs were showing "Round ID: Pending" despite being correctly deployed and funded. No Chainlink price updates were being received.

## Root Cause
**The V2 RSCs were subscribing to Chainlink PROXY addresses, but `AnswerUpdated` events are emitted by the underlying AGGREGATOR contracts.**

Chainlink price feeds on Ethereum have a proxy pattern:
- **Proxy Contract**: User-facing address that forwards calls to the aggregator
- **Aggregator Contract**: Internal contract that actually stores data and emits events

| Feed | Proxy Address (❌ Does NOT emit events) | Aggregator Address (✅ Emits events) |
|------|----------------------------------------|-------------------------------------|
| ETH/USD | 0x694AA1769357215DE4FAC081bf1f309aDC325306 | 0x719E22E3D4b690E5d96cCb40619180B5427F14AE |
| BTC/USD | 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43 | 0x17Dac87b07EAC97De4E182Fc51C925ebB7E723e2 |
| LINK/USD | 0xc59E3633BAAC79493d908e63626716e204A45EdF | 0x5A2734CC0341ea6564dF3D00171cc99C63B1A7d3 |

## Solution
Deployed new V2 RSCs that subscribe to the **AGGREGATOR** addresses instead of the proxy addresses.

### New V2 RSC Addresses (FIXED)

| Feed | Old V2 RSC (❌ Wrong subscription) | New V2 RSC (✅ Correct subscription) |
|------|-----------------------------------|-------------------------------------|
| ETH V2 | 0x4090B8BCcf477eDe37F5A5E7502A68c635579A89 | **0x4217702423754A49AC1e5cc1c1105210bbf7Ba0C** |
| BTC V2 | 0xd0E5F6f73254dd3AD42615b46073e4F3752E37b2 | **0x4272e8ad2b63c36CC1a9f2CF10aE077478BF55e0** |
| LINK V2 | 0x24F5b5525e4b598078d1D9965E68596E69c5bdE9 | **0x4139e3A69bC30d97335a0794983F51c9622FDeBB** |

> **Note:** These RSCs were deployed 2025-01-06 with correct Sepolia aggregator subscriptions.

## Verification

To get the aggregator address from a Chainlink proxy:
```bash
cast call <PROXY_ADDRESS> "aggregator()(address)" --rpc-url https://ethereum-sepolia-rpc.publicnode.com
```

To verify events are emitted by the aggregator:
```bash
cast logs --from-block 9980000 --address <AGGREGATOR_ADDRESS> "AnswerUpdated(int256,uint256,uint256)" --rpc-url https://ethereum-sepolia-rpc.publicnode.com
```

## Files Updated
1. **oracle-bridge/script/DeployMirrorV2Fixed.s.sol** - New deployment script with aggregator addresses
2. **frontend/oracle.html** - Updated V2 RSC addresses in config
3. **frontend/bridge.html** - Updated V2 RSC addresses in dropdown and config
4. **SUBMISSION.md** - Updated deployed contract addresses

## Expected Behavior
Once the next Chainlink price update occurs on Sepolia:
1. The aggregator contract emits `AnswerUpdated(answer, roundId, updatedAt)`
2. Reactive Network detects this event (V2 RSCs are subscribed to correct address)
3. V2 RSC's `react()` function is called with the log data
4. RSC emits a `Callback` to the destination chain with the price data
5. AbstractFeedProxy on Sepolia receives the update and stores the price

The `lastMirroredRoundId` should change from `0` to the actual Chainlink round ID.

## Lesson Learned
When subscribing to external protocol events, always verify which contract actually emits the events. Proxy contracts often just forward calls without emitting their own events.
