# Reactive Network RSC Debugging Report

## Summary

Investigation into why Chainlink price oracle RSCs weren't receiving events despite being subscribed.

## Findings

### Original RSCs (V1) - Base Sepolia Origin

**Configuration:**
- Origin Chain: Base Sepolia (84532)
- Destination Chain: Sepolia (11155111)
- Subscription Method: Separate `subscribe()` function called after deployment

**Issue:**
- RSCs show `subscribed=true` but `lastMirroredRoundId=0`
- `react()` has NEVER been called
- Subscription event was emitted on Dec 24, 2025
- Base Sepolia Chainlink feed IS actively updating (verified via cast)

**V1 RSC Addresses (Lasna):**
- ETH Mirror: `0x1CdD260983f23c2A29a91134442C499cd3cc29cF`
- BTC Mirror: `0xA17c0A6aBAC640ee401FF767EfA1cBf31966A848`
- LINK Mirror: `0xDb0a8ab7Ea10f2D9E1BE242718699BEE43131274`

### V2 RSC - Sepolia Origin

**Configuration:**
- Origin Chain: Sepolia (11155111) - Full origin+destination support
- Destination Chain: Sepolia (11155111) 
- Subscription Method: Constructor subscription using `if (!vm)` pattern

**V2 RSC Address (Lasna):**
- ETH Mirror V2: `0x4090B8BCcf477eDe37F5A5E7502A68c635579A89`

**Deployment TX:** `0x9b2812750c13317c0bae0327e8d283230b1de93dceb2965dc2f482baa180f765`

## Key Differences Between V1 and V2

### Subscription Pattern

**V1 (Failed):**
```solidity
constructor(...) payable {
    // NO subscription in constructor
}

function subscribe() external rnOnly onlyOwner {
    service.subscribe(...);
}
```

**V2 (Testing):**
```solidity
constructor(...) payable {
    if (!vm) {
        service.subscribe(...);
    }
}
```

The V2 pattern matches all official Reactive Network demos.

### Origin Chain

**V1:** Base Sepolia (84532) - Origin ONLY (no callback proxy)
**V2:** Sepolia (11155111) - Full Origin + Destination support

## Reactive Network Chain Support

From https://dev.reactive.network/origins-and-destinations:

| Chain | Origin | Destination |
|-------|--------|-------------|
| Sepolia | ✅ | ✅ |
| Base Sepolia | ✅ | ➖ |
| Polygon Amoy | ✅ | ➖ |
| Reactive Lasna | ✅ | ✅ |

## Next Steps

1. **Wait for Sepolia Chainlink update** - V2 RSC should receive the next AnswerUpdated event
2. **Monitor V2 RSC** - Check `lastMirroredRoundId` and events
3. **If V2 works**, deploy additional BTC/LINK V2 mirrors
4. **Update frontend** to use V2 RSC addresses

## Monitoring Commands

```bash
# Check V2 RSC status
cast call 0x4090B8BCcf477eDe37F5A5E7502A68c635579A89 "lastMirroredRoundId()(uint80)" --rpc-url https://lasna-rpc.rnk.dev

# Check V2 RSC events
cast logs --from-block 1 --address 0x4090B8BCcf477eDe37F5A5E7502A68c635579A89 --rpc-url https://lasna-rpc.rnk.dev

# Check Sepolia Chainlink feed timestamp
cast call 0x694AA1769357215DE4FAC081bf1f309aDC325306 "latestRoundData()(uint80,int256,uint256,uint256,uint80)" --rpc-url https://eth-sepolia.g.alchemy.com/v2/YOUR_KEY
```

## Technical Details

### AnswerUpdated Event Signature
```
event AnswerUpdated(int256 indexed current, uint256 indexed roundId, uint256 updatedAt);
```
Topic0: `0x0559884fd3a460db3073b7fc896cc77986f16e378210ded43186175bf646fc5f`

### Expected Event Flow
1. Chainlink emits `AnswerUpdated` on Sepolia
2. Reactive Network indexer captures event
3. Indexer calls `react()` on V2 RSC in ReactVM
4. RSC emits `Callback` event
5. Reactive Network executes callback on destination (Sepolia feed proxy)
6. Feed proxy updates with new price

## Conclusion

The issue appears to be related to either:
1. **Subscription timing** - V1 subscriptions done in separate transactions may not be properly indexed
2. **Base Sepolia indexing** - The Reactive Network may have incomplete indexing for origin-only chains

V2 RSC follows the exact pattern from official demos and uses a fully-supported chain. If events still don't arrive after Chainlink updates, the issue is on the Reactive Network side.

---
Generated: Jan 5, 2026
