---
theme: seriph
background: https://images.unsplash.com/photo-1540575339264-569259387a45?q=80&w=2832
class: text-center
highlighter: shiki
lineNumbers: true
drawings:
  persist: false
transition: slide-left
title: Amplifi - Reactive Yield Optimizer
mdc: true
---

<style>
@import url('https://fonts.googleapis.com/css2?family=Orbitron:wght@400;700;900&family=Rajdhani:wght@400;600;700&display=swap');

:root {
  --cyber-primary: #a855f7;
  --cyber-secondary: #06b6d4;
  --cyber-accent: #ec4899;
}

.slidev-layout {
  background: linear-gradient(135deg, #030305 0%, #0a0a15 100%) !important;
  font-family: 'Rajdhani', sans-serif;
}

h1, h2, h3 {
  font-family: 'Orbitron', sans-serif !important;
  text-transform: uppercase;
  letter-spacing: 0.1em;
}

h1 {
  background: linear-gradient(135deg, #fff 0%, var(--cyber-primary) 50%, var(--cyber-secondary) 100%);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
}

.cyber-card {
  background: rgba(15, 15, 25, 0.8);
  border: 1px solid rgba(6, 182, 212, 0.3);
  padding: 1rem;
  border-radius: 4px;
}

.cyber-card:hover {
  border-color: rgba(168, 85, 247, 0.5);
}

img {
  image-rendering: -webkit-optimize-contrast;
  image-rendering: crisp-edges;
}
</style>

<div class="absolute inset-0 bg-black/60"></div>

<div class="relative z-10">

# AMPLIFI

## REACTIVE YIELD OPTIMIZER

<div class="text-xl tracking-widest text-cyan-400 opacity-80 mb-8">
CROSS-CHAIN | AUTONOMOUS | REACTIVE
</div>

<div class="flex justify-center gap-6 mb-12">
  <div class="cyber-card flex items-center gap-3 px-6 py-3">
    <img src="/logos/eth.png" class="h-8 w-8" />
    <span class="text-lg">Sepolia</span>
  </div>
  <div class="cyber-card flex items-center gap-3 px-6 py-3 border-purple-500/50">
    <img src="/logos/lasna-logo.png" class="h-8 w-8" />
    <span class="text-lg">Lasna</span>
  </div>
</div>

<div class="cyber-card inline-block px-10 py-4 border-cyan-500/50">
  <span class="text-2xl font-bold bg-clip-text text-transparent bg-gradient-to-r from-purple-400 to-cyan-400">
    POWERED BY REACTIVE NETWORK
  </span>
</div>

</div>

---

# THE PROBLEM

<div class="grid grid-cols-2 gap-6 mt-8">

<div class="cyber-card">
  <h3 class="text-cyan-400 text-lg mb-3">Manual Monitoring</h3>
  <p class="text-gray-300 text-base">
    Users must constantly check APY rates across protocols and chains manually.
  </p>
</div>

<div class="cyber-card">
  <h3 class="text-cyan-400 text-lg mb-3">Centralized Keepers</h3>
  <p class="text-gray-300 text-base">
    Reliance on AWS Lambda or cron jobs introduces single points of failure.
  </p>
</div>

<div class="cyber-card">
  <h3 class="text-cyan-400 text-lg mb-3">Cross-Chain Friction</h3>
  <p class="text-gray-300 text-base">
    Synchronizing state and triggers across networks is complex and error-prone.
  </p>
</div>

<div class="cyber-card">
  <h3 class="text-cyan-400 text-lg mb-3">Gas Inefficiency</h3>
  <p class="text-gray-300 text-base">
    Triggering rebalances requires sophisticated, costly off-chain logic.
  </p>
</div>

</div>

---
layout: two-cols
---

# PARADIGM SHIFT

::left::

<div class="cyber-card mr-4 h-full border-red-500/30">
  <h3 class="text-red-400 text-xl mb-4">TRADITIONAL</h3>
  <div class="space-y-3">
    <div class="p-3 border border-red-500/20 rounded bg-red-900/10 text-base">
      Off-chain Infrastructure
    </div>
    <div class="p-3 border border-red-500/20 rounded bg-red-900/10 text-base">
      Trusted Keepers Required
    </div>
    <div class="p-3 border border-red-500/20 rounded bg-red-900/10 text-base">
      High Latency Operations
    </div>
    <div class="p-3 border border-red-500/20 rounded bg-red-900/10 text-base">
      Manual Gas Management
    </div>
  </div>
</div>

::right::

<div class="cyber-card ml-4 h-full border-green-500/30">
  <h3 class="text-green-400 text-xl mb-4">REACTIVE</h3>
  <div class="space-y-3">
    <div class="p-3 border border-green-500/20 rounded bg-green-900/10 text-base">
      100% On-Chain Logic
    </div>
    <div class="p-3 border border-green-500/20 rounded bg-green-900/10 text-base">
      Trustless Automation
    </div>
    <div class="p-3 border border-green-500/20 rounded bg-green-900/10 text-base">
      Event-Driven Execution
    </div>
    <div class="p-3 border border-green-500/20 rounded bg-green-900/10 text-base">
      Self-Sustaining Gas
    </div>
  </div>
</div>

---

# SYSTEM ARCHITECTURE

```mermaid {scale: 0.9, theme: 'dark'}
graph TD
    subgraph Sepolia["SEPOLIA TESTNET"]
        User((User)) -->|Deposit| Vault[Multi-Asset Vault]
        Vault -->|Supply| Aave[Aave V3 Pool]
        Vault -->|0.1% Fee| Collector[Fee Collector]
        Collector -->|Fund| Funder[Funder Contract]
    end
    
    subgraph Lasna["LASNA NETWORK"]
        RSC[YieldOptimizer RSC]
        FunderRSC[ReactiveFunder RSC]
    end
    
    Aave -.->|Yield Events| RSC
    RSC -->|Rebalance Callback| Vault
    Funder -->|Bridge Gas| FunderRSC
    FunderRSC -->|Auto-Refill| RSC
    
    style User fill:#fff,stroke:#06b6d4,color:#000
    style Vault fill:#06b6d4,stroke:#fff,color:#000
    style Aave fill:#8B5CF6,stroke:#fff,color:#fff
    style RSC fill:#ec4899,stroke:#fff,color:#fff
    style FunderRSC fill:#ec4899,stroke:#fff,color:#fff
    style Collector fill:#22c55e,stroke:#fff,color:#000
    style Funder fill:#22c55e,stroke:#fff,color:#000
```

---

# CORE DASHBOARD

<div class="flex justify-center">
  <img src="/screenshots/dashboard.png" class="w-full max-w-4xl rounded-lg border-2 border-cyan-500/30 shadow-2xl shadow-cyan-500/20" />
</div>

<div class="text-center mt-4 text-sm text-gray-400">
  Live Dashboard | Real-time Yield Data | Wallet Integration
</div>

---

# DEPLOYED CONTRACTS

<div class="grid grid-cols-2 gap-8">

<div class="cyber-card">
  <h3 class="text-cyan-400 mb-4">Sepolia Testnet</h3>
  <div class="space-y-3 text-sm">
    <div class="flex justify-between border-b border-gray-700 pb-2">
      <span>YieldVaultMultiAssetV2</span>
      <code class="text-cyan-400">0x4243...e5d5</code>
    </div>
    <div class="flex justify-between border-b border-gray-700 pb-2">
      <span>VaultFeeCollector</span>
      <code class="text-purple-400">0x3777...33Cf</code>
    </div>
    <div class="flex justify-between border-b border-gray-700 pb-2">
      <span>Funder</span>
      <code class="text-blue-400">0x0Cab...2D39</code>
    </div>
    <div class="flex justify-between pb-2">
      <span>MultiFeedDestination</span>
      <code class="text-green-400">0x889c...b3F3</code>
    </div>
  </div>
  <div class="mt-4 text-right">
    <a href="https://sepolia.etherscan.io/address/0x42437f29E25Ad65E121f4D0f07FD8F5c2005e5d5" class="text-cyan-400 hover:text-cyan-300 text-sm">VIEW ON ETHERSCAN >></a>
  </div>
</div>

<div class="cyber-card">
  <h3 class="text-pink-400 mb-4">Lasna Network</h3>
  <div class="space-y-3 text-sm">
    <div class="flex justify-between border-b border-gray-700 pb-2">
      <span>YieldOptimizerRsc</span>
      <span class="text-pink-400">Event Monitor</span>
    </div>
    <div class="flex justify-between border-b border-gray-700 pb-2">
      <span>ReactiveFunderRC</span>
      <span class="text-green-400">Auto-Refill</span>
    </div>
    <div class="flex justify-between border-b border-gray-700 pb-2">
      <span>CRONReactiveContract</span>
      <span class="text-yellow-400">Scheduler</span>
    </div>
    <div class="flex justify-between pb-2">
      <span>ChainlinkMirrorRC</span>
      <span class="text-blue-400">Oracle Bridge</span>
    </div>
  </div>
  <div class="mt-4 text-right">
    <a href="https://lasna.reactscan.net/" class="text-pink-400 hover:text-pink-300 text-sm">VIEW ON REACTSCAN >></a>
  </div>
</div>

</div>

---

# MULTI-ASSET SUPPORT

<div class="grid grid-cols-5 gap-6 mt-8">

<div class="cyber-card text-center py-6 hover:border-cyan-500/50 transition">
  <img src="/logos/eth.png" class="h-16 w-16 mx-auto mb-4" />
  <div class="font-bold text-lg">WETH</div>
  <div class="text-cyan-400 mt-2">25%</div>
</div>

<div class="cyber-card text-center py-6 border-green-500/50 bg-green-900/10">
  <img src="/logos/link.png" class="h-16 w-16 mx-auto mb-4" />
  <div class="font-bold text-lg">LINK</div>
  <div class="text-green-400 mt-2 font-bold">20%</div>
</div>

<div class="cyber-card text-center py-6 hover:border-cyan-500/50 transition">
  <img src="/logos/aave.png" class="h-16 w-16 mx-auto mb-4" />
  <div class="font-bold text-lg">AAVE</div>
  <div class="text-cyan-400 mt-2">20%</div>
</div>

<div class="cyber-card text-center py-6 hover:border-cyan-500/50 transition">
  <img src="/logos/eurs.png" class="h-16 w-16 mx-auto mb-4" />
  <div class="font-bold text-lg">EURS</div>
  <div class="text-cyan-400 mt-2">15%</div>
</div>

<div class="cyber-card text-center py-6 hover:border-cyan-500/50 transition">
  <img src="/logos/wbtc.png" class="h-16 w-16 mx-auto mb-4" />
  <div class="font-bold text-lg">WBTC</div>
  <div class="text-cyan-400 mt-2">20%</div>
</div>

</div>

<div class="mt-8 text-center text-gray-400">
  All assets deposited into Aave V3 Sepolia for yield generation
</div>

---

# CROSS-CHAIN ORACLE

```mermaid {scale: 0.85, theme: 'dark'}
graph LR
    subgraph Origin["ORIGIN CHAIN"]
        CL[Chainlink Feed]
        Mirror[ChainlinkMirrorRC]
    end
    
    subgraph Reactive["REACTIVE NETWORK"]
        RSC[Oracle Bridge RSC]
    end
    
    subgraph Destination["DESTINATION CHAIN"]
        Proxy[AbstractFeedProxy]
        Vault[Amplifi Vault]
    end
    
    CL -->|AnswerUpdated| Mirror
    Mirror -->|Emit Event| RSC
    RSC -->|Cross-Chain Callback| Proxy
    Proxy -->|getLatestPrice| Vault
    
    style CL fill:#375BD2,stroke:#fff,color:#fff
    style Mirror fill:#ec4899,stroke:#fff,color:#fff
    style RSC fill:#ec4899,stroke:#fff,color:#fff
    style Proxy fill:#06b6d4,stroke:#fff,color:#000
    style Vault fill:#06b6d4,stroke:#fff,color:#000
```

<div class="grid grid-cols-4 gap-4 mt-6 text-center">
  <div class="cyber-card py-2">ETH/USD</div>
  <div class="cyber-card py-2">LINK/USD</div>
  <div class="cyber-card py-2">BTC/USD</div>
  <div class="cyber-card py-2">EUR/USD</div>
</div>

---

# ORACLE BRIDGE SEQUENCE

```mermaid {scale: 0.9, theme: 'dark'}
sequenceDiagram
    participant CL as Chainlink Feed
    participant Mirror as Mirror Contract
    participant RSC as Reactive Contract
    participant Proxy as AbstractFeedProxy
    participant App as Amplifi Vault
    
    CL->>Mirror: Price Update Event
    Mirror->>RSC: AnswerUpdated Log
    RSC->>RSC: Verify & Process
    RSC->>Proxy: callback(price, timestamp)
    Proxy->>Proxy: Store New Price
    App->>Proxy: latestRoundData()
    Proxy-->>App: Return Price
```

---

# MULTI-ASSET VAULT UI

<div class="flex justify-center">
  <img src="/screenshots/multiasset.png" class="w-full max-w-4xl rounded-lg border-2 border-purple-500/30 shadow-2xl shadow-purple-500/20" />
</div>

<div class="grid grid-cols-4 gap-4 mt-6 text-center text-sm">
  <div class="cyber-card py-2">Glassmorphism</div>
  <div class="cyber-card py-2">Real-time Data</div>
  <div class="cyber-card py-2">Wallet Connect</div>
  <div class="cyber-card py-2">Tx Tracking</div>
</div>

---

# AUTO-REPLENISHMENT

```mermaid {scale: 0.9, theme: 'dark'}
stateDiagram-v2
    [*] --> Collecting: User Deposits
    Collecting --> Checking: 0.1% Fee Collected
    Checking --> Operating: Balance OK
    Checking --> Bridging: Balance < 0.05 ETH
    Bridging --> Refilled: Cross-Chain Bridge
    Refilled --> Collecting
    Operating --> Collecting: Continue Operations
    
    note right of Bridging: Funder Contract<br/>Bridges ETH to Lasna
    note right of Collecting: VaultFeeCollector<br/>Accumulates Fees
```

<div class="mt-4 cyber-card max-w-xl mx-auto">
  <h3 class="text-green-400 text-center">Self-Sustaining Gas Model</h3>
  <p class="text-gray-300 text-center mt-2">System never runs out of gas - fees fund automation</p>
</div>

---

# RSC STATE MACHINE

```mermaid {scale: 0.9, theme: 'dark'}
stateDiagram-v2
    [*] --> Idle
    Idle --> Snapshot: YieldSnapshot Event
    Idle --> CronTrigger: CRON Block
    CronTrigger --> Snapshot: Capture Yields
    Snapshot --> Calculate: Process APY Data
    Calculate --> Rebalance: Threshold Exceeded
    Calculate --> Idle: No Action Needed
    Rebalance --> Callback: Emit Callback
    Callback --> Confirmed: Success
    Callback --> Retry: Failure
    Retry --> Callback: Retry Logic
    Confirmed --> Idle
```

---

# ON-CHAIN VALIDATION

<div class="grid grid-cols-2 gap-8">
  <div>
    <img src="/screenshots/etherscan_vault.png" class="w-full rounded-lg border border-cyan-500/30" />
    <div class="text-center mt-2 text-cyan-400 text-sm">SEPOLIA - VAULT CONTRACT</div>
  </div>
  <div>
    <img src="/screenshots/lasnascan_rsc.png" class="w-full rounded-lg border border-pink-500/30" />
    <div class="text-center mt-2 text-pink-400 text-sm">LASNA - RSC CONTRACT</div>
  </div>
</div>

---

# ORACLE PAGE

<div class="flex justify-center">
  <img src="/screenshots/oracle.png" class="w-full max-w-4xl rounded-lg border-2 border-cyan-500/30 shadow-2xl" />
</div>

<div class="text-center mt-4 text-gray-400">
  Live Cross-Chain Price Feeds | Powered by Chainlink + Reactive Network
</div>

---

# FUTURE ROADMAP

<div class="grid grid-cols-3 gap-8 mt-8">

<div class="cyber-card relative">
  <div class="absolute -top-3 left-4 bg-black px-3 text-purple-400 text-sm border border-purple-500">PHASE 1</div>
  <h3 class="text-purple-400 mt-4 mb-3">L2 Scaling</h3>
  <p class="text-gray-300">
    Deploying vaults to Arbitrum and Optimism for lower fees and faster finality.
  </p>
</div>

<div class="cyber-card relative">
  <div class="absolute -top-3 left-4 bg-black px-3 text-cyan-400 text-sm border border-cyan-500">PHASE 2</div>
  <h3 class="text-cyan-400 mt-4 mb-3">AI Strategy</h3>
  <p class="text-gray-300">
    Integrating ML models for predictive yield optimization and risk management.
  </p>
</div>

<div class="cyber-card relative">
  <div class="absolute -top-3 left-4 bg-black px-3 text-pink-400 text-sm border border-pink-500">PHASE 3</div>
  <h3 class="text-pink-400 mt-4 mb-3">Insurance</h3>
  <p class="text-gray-300">
    On-chain risk coverage for protocol failures and smart contract exploits.
  </p>
</div>

</div>

---
layout: center
class: text-center
---

# AMPLIFI

<div class="text-xl text-gray-400 mb-8">Cross-Chain Yield Optimization</div>

<div class="flex justify-center gap-8">
  <a href="https://github.com/guglxni/amplifi" class="cyber-card px-8 py-4 hover:border-cyan-500/50">
    <span class="text-lg">GITHUB</span>
  </a>
  <a href="https://reactive.network" class="cyber-card px-8 py-4 border-purple-500/50 hover:border-purple-500">
    <span class="text-lg">REACTIVE</span>
  </a>
  <a href="https://dorahacks.io/hackathon/reactive-bounties-2" class="cyber-card px-8 py-4 hover:border-pink-500/50">
    <span class="text-lg">DORAHACKS</span>
  </a>
</div>

<div class="mt-12 text-sm text-gray-500 font-mono">
  BUILT FOR REACTIVE NETWORK BOUNTY SPRINT
</div>
