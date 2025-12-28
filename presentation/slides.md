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
css: ./styles.css
mdc: true
---

<div class="absolute top-0 left-0 w-full h-full bg-black/50 z-0"></div>

<div class="relative z-10">

# AMPLIFI

## REACTIVE YIELD OPTIMIZER

<div class="text-xl tracking-widest text-cyan-400 opacity-80 mb-8">
CROSS-CHAIN • AUTONOMOUS • REACTIVE
</div>

<div class="flex justify-center gap-4 mb-12">
    <div class="cyber-card flex items-center gap-2 px-4 py-2">
        <img src="/logos/eth.png" class="h-6" />
        <span>Sepolia</span>
    </div>
    <div class="cyber-card flex items-center gap-2 px-4 py-2 border-purple-500/50">
        <img src="/logos/lasna-logo.png" class="h-6" /> <!-- Make sure this exists or use alt -->
        <span>Lasna</span>
    </div>
</div>

<div class="cyber-card inline-block px-8 py-4">
    <span class="text-xl font-bold bg-clip-text text-transparent bg-gradient-to-r from-purple-400 to-cyan-400">
        POWERED BY REACTIVE NETWORK
    </span>
</div>

</div>

<!-- Lasna logo is needed. I'll assume I copied it or need to -->

---
layout: default
---

# THE PROBLEM

<div class="grid grid-cols-2 gap-8 mt-8">

<div class="cyber-card">
    <h3>Manual Monitoring</h3>
    <div class="opacity-70 text-sm mt-2">
        Users must constantly check APY rates across protocols and chains manually.
    </div>
</div>

<div class="cyber-card">
    <h3>Centralized Keepers</h3>
    <div class="opacity-70 text-sm mt-2">
        Reliance on AWS Lambda or cron jobs introduces single points of failure.
    </div>
</div>

<div class="cyber-card">
    <h3>Cross-Chain Friction</h3>
    <div class="opacity-70 text-sm mt-2">
        Synchronizing state and triggers across networks is complex and error-prone.
    </div>
</div>

<div class="cyber-card">
    <h3>Gas Inefficiency</h3>
    <div class="opacity-70 text-sm mt-2">
        Triggering rebalances requires sophisticated, costly off-chain logic.
    </div>
</div>

</div>

---
layout: two-cols
---

# PARADIGM SHIFT

::left::

<div class="cyber-card mr-4 h-full">
    <h3 class="text-red-400 border-red-500/30">TRADITIONAL ❌</h3>
    <div class="mt-4 flex flex-col gap-4">
        <div class="p-2 border border-red-500/20 rounded bg-red-900/10">
            Off-chain Infrastructure
        </div>
        <div class="p-2 border border-red-500/20 rounded bg-red-900/10">
            Trusted Keepers
        </div>
        <div class="p-2 border border-red-500/20 rounded bg-red-900/10">
            High Latency
        </div>
    </div>
    <div class="mt-8 opacity-50 text-xs">
        Dependent on Web2 servers and manual intervention.
    </div>
</div>

::right::

<div class="cyber-card ml-4 h-full">
    <h3 class="text-green-400 border-green-500/30">REACTIVE ✅</h3>
    <div class="mt-4 flex flex-col gap-4">
        <div class="p-2 border border-green-500/20 rounded bg-green-900/10">
            100% On-Chain
        </div>
        <div class="p-2 border border-green-500/20 rounded bg-green-900/10">
            Trustless Automation
        </div>
        <div class="p-2 border border-green-500/20 rounded bg-green-900/10">
            Event-Driven
        </div>
    </div>
    <div class="mt-8 opacity-50 text-xs">
        Autonomous smart contracts that react to events.
    </div>
</div>

---

# SYSTEM ARCHITECTURE

<div class="flex justify-center">
    <img src="/diagrams/system-architecture.png" class="h-100 object-contain cyber-border" />
</div>

<div class="grid grid-cols-4 gap-4 mt-8">
    <div class="cyber-card text-center text-xs">User Deposits</div>
    <div class="cyber-card text-center text-xs">Vault Collects</div>
    <div class="cyber-card text-center text-xs">RSC Monitors</div>
    <div class="cyber-card text-center text-xs">System Optimizes</div>
</div>

---

# CORE DASHBOARD

<div class="relative">
    <img src="/screenshots/dashboard.png" class="w-full rounded border border-cyan-500/30 shadow-lg shadow-cyan-500/20" />
    <div class="absolute -bottom-4 right-4 cyber-card text-xs">
        Captured from Live Environment
    </div>
</div>

---

# DEPLOYED CONTRACTS

<div class="grid grid-cols-2 gap-8">

<div class="cyber-card">
    <h3>Sepolia Testnet</h3>
    <div class="flex flex-col gap-2 mt-4 text-sm">
        <div class="flex justify-between border-b border-gray-800 pb-2">
            <span>Vault</span>
            <code class="text-cyan-400">0x4243...e5d5</code>
        </div>
        <div class="flex justify-between border-b border-gray-800 pb-2">
            <span>FeeCollector</span>
            <code class="text-purple-400">0x3777...33Cf</code>
        </div>
        <div class="flex justify-between border-b border-gray-800 pb-2">
            <span>Funder</span>
            <code class="text-blue-400">0x0Cab...2D39</code>
        </div>
    </div>
    <div class="mt-4 text-right">
        <a href="https://sepolia.etherscan.io/address/0x42437f29E25Ad65E121f4D0f07FD8F5c2005e5d5" class="text-xs text-cyan-400 hover:text-cyan-300">EXPLORE ON ETHERSCAN >></a>
    </div>
</div>

<div class="cyber-card">
    <h3>Lasna Network</h3>
    <div class="flex flex-col gap-2 mt-4 text-sm">
        <div class="flex justify-between border-b border-gray-800 pb-2">
            <span>YieldOptimizerRsc</span>
            <code class="text-pink-400">Event Monitor</code>
        </div>
        <div class="flex justify-between border-b border-gray-800 pb-2">
            <span>ReactiveFunder</span>
            <code class="text-green-400">Auto-Refill</code>
        </div>
        <div class="flex justify-between border-b border-gray-800 pb-2">
            <span>CRON</span>
            <code class="text-yellow-400">Scheduler</code>
        </div>
    </div>
    <div class="mt-4 text-right">
        <a href="https://lasna.reactscan.net/" class="text-xs text-pink-400 hover:text-pink-300">VIEW ON REACTSCAN >></a>
    </div>
</div>

</div>

---

# MULTI-ASSET SUPPORT

<div class="grid grid-cols-5 gap-4 mt-8">

<div class="cyber-card text-center hover:bg-white/5 transition">
    <img src="/logos/eth.png" class="h-12 w-12 mx-auto mb-4" />
    <div class="font-bold">WETH</div>
    <div class="text-xs text-cyan-400 mt-2">25% Alloc</div>
</div>

<div class="cyber-card text-center hover:bg-white/5 transition border-green-500/50">
    <img src="/logos/link.png" class="h-12 w-12 mx-auto mb-4" />
    <div class="font-bold">LINK</div>
    <div class="text-xs text-green-400 mt-2">20% Alloc</div>
</div>

<div class="cyber-card text-center hover:bg-white/5 transition">
    <img src="/logos/aave.png" class="h-12 w-12 mx-auto mb-4" />
    <div class="font-bold">AAVE</div>
    <div class="text-xs text-cyan-400 mt-2">20% Alloc</div>
</div>

<div class="cyber-card text-center hover:bg-white/5 transition">
    <img src="/logos/eurs.png" class="h-12 w-12 mx-auto mb-4" />
    <div class="font-bold">EURS</div>
    <div class="text-xs text-cyan-400 mt-2">15% Alloc</div>
</div>

<div class="cyber-card text-center hover:bg-white/5 transition">
    <img src="/logos/wbtc.png" class="h-12 w-12 mx-auto mb-4" />
    <div class="font-bold">WBTC</div>
    <div class="text-xs text-cyan-400 mt-2">20% Alloc</div>
</div>

</div>

<div class="mt-8 text-center text-sm opacity-60">
    Integrated with Aave V3 Sepolia Liquidity Pools
</div>

---
layout: two-cols
---

# CROSS-CHAIN ORACLE

::left::

<div class="cyber-card h-full mr-4">
    <h3>Data Aggregation</h3>
    <ul class="list-none pl-0 mt-4 space-y-4 text-sm">
        <li class="flex items-center gap-3">
            <img src="/logos/link.png" class="h-5" />
            <span>Chainlink Direct Feeds</span>
        </li>
        <li class="flex items-center gap-3">
            <div class="h-1 w-1 bg-cyan-400 rounded-full"></div>
            <span>AbstractFeedProxy Mirroring</span>
        </li>
        <li class="flex items-center gap-3">
            <div class="h-1 w-1 bg-cyan-400 rounded-full"></div>
            <span>Reactive Network Bridging</span>
        </li>
    </ul>
    
    <div class="mt-8 code-block text-xs">
        <span class="text-purple-400">function</span> getPrice(...) {
            <div class="pl-4 text-gray-400">// Unified interface</div>
        }
    </div>
</div>

::right::

<div class="relative ml-4">
    <img src="/screenshots/oracle.png" class="rounded shadow-lg border border-cyan-500/30" />
    <img src="/diagrams/oracle-bridge-flow.png" class="absolute -bottom-8 -left-8 w-2/3 rounded border border-purple-500/30 shadow-2xl bg-black" />
</div>

---

# UNIFIED ORACLE ARCHITECTURE

<div class="flex items-center justify-center gap-8">
    <div class="w-1/2">
        <div class="cyber-card">
            <h3>Architecture Flow</h3>
            <div class="space-y-4 text-sm mt-4">
                <div>
                    <strong class="text-cyan-400">1. Origin</strong>
                    <p class="opacity-70">Chainlink feeds update on Sepolia.</p>
                </div>
                <div>
                    <strong class="text-purple-400">2. Reactive</strong>
                    <p class="opacity-70">RSC mirrors price events.</p>
                </div>
                <div>
                    <strong class="text-pink-400">3. Destination</strong>
                    <p class="opacity-70">AbstractFeedProxy updates local state.</p>
                </div>
            </div>
        </div>
    </div>
    <div class="w-1/2">
        <img src="/diagrams/unified-oracle.png" class="w-full rounded cyber-border" />
    </div>
</div>

---

# AUTO-REPLENISHMENT

<div class="grid grid-cols-2 gap-8">
    <div class="relative">
        <img src="/diagrams/gas-funding.png" class="w-full rounded opacity-80" />
        <div class="absolute inset-0 flex items-center justify-center">
            <div class="cyber-card bg-black/80 backdrop-blur">
                <h3 class="text-center mb-0">INFINITE LOOP</h3>
            </div>
        </div>
    </div>
    <div class="cyber-card">
        <h3>The "Reactivate" Pattern</h3>
        <p class="text-sm mt-4 opacity-80">
            A self-sustaining economic model for autonomous agents.
        </p>
        <div class="mt-6 space-y-2">
            <div class="flex justify-between items-center bg-white/5 p-2 rounded">
                <span class="text-xs">Fee Collection</span>
                <span class="text-green-400 font-mono">0.1%</span>
            </div>
            <div class="flex justify-between items-center bg-white/5 p-2 rounded">
                <span class="text-xs">Trigger Threshold</span>
                <span class="text-red-400 font-mono">< 0.05 ETH</span>
            </div>
            <div class="flex justify-between items-center bg-white/5 p-2 rounded">
                <span class="text-xs">Bridge Action</span>
                <span class="text-cyan-400 font-mono">AUTOMATIC</span>
            </div>
        </div>
    </div>
</div>

---

# FRONTEND EXPERIENCE

<div class="flex flex-col gap-8">
    <div class="relative">
        <img src="/screenshots/multiasset.png" class="w-full rounded border-2 border-cyan-500/20" />
    </div>
    <div class="grid grid-cols-4 gap-4">
        <div class="cyber-card text-center py-2">Glassmorphism</div>
        <div class="cyber-card text-center py-2">Real-time Data</div>
        <div class="cyber-card text-center py-2">Wallet Connect</div>
        <div class="cyber-card text-center py-2">Tx Tracking</div>
    </div>
</div>

---

# STATE MACHINE DEEP DIVE

<div class="flex gap-8">
    <div class="w-1/2">
        <img src="/diagrams/rsc-state-machine.png" class="w-full h-full object-contain rounded bg-white/5 p-4" />
    </div>
    <div class="w-1/2 flex flex-col gap-4 justify-center">
        <div class="cyber-card border-l-4 border-l-gray-500">
            <strong>IDLE</strong>
            <div class="text-xs opacity-70">Waiting for triggers</div>
        </div>
        <div class="cyber-card border-l-4 border-l-cyan-500">
            <strong>SNAPSHOT</strong>
            <div class="text-xs opacity-70">Capturing yield data</div>
        </div>
        <div class="cyber-card border-l-4 border-l-purple-500">
            <strong>CALCULATING</strong>
            <div class="text-xs opacity-70">Strategy logic execution</div>
        </div>
        <div class="cyber-card border-l-4 border-l-green-500">
            <strong>CONFIRMED</strong>
            <div class="text-xs opacity-70">Transaction finalized</div>
        </div>
    </div>
</div>

---

# ON-CHAIN VALIDATION

<div class="grid grid-cols-2 gap-8">
    <div>
        <img src="/screenshots/etherscan_vault.png" class="rounded cyber-border opacity-90 hover:opacity-100 transition" />
        <div class="text-center text-xs mt-2 text-cyan-400">SEPOLIA - VAULT</div>
    </div>
    <div>
        <img src="/screenshots/lasnascan_rsc.png" class="rounded cyber-border opacity-90 hover:opacity-100 transition" />
        <div class="text-center text-xs mt-2 text-pink-400">LASNA - RSC</div>
    </div>
</div>

---

# FUTURE ROADMAP

<div class="grid grid-cols-3 gap-6 mt-12">

<div class="cyber-card relative group">
    <div class="absolute -top-3 left-4 bg-black px-2 text-purple-400 text-xs border border-purple-500">PHASE 1</div>
    <h3 class="mt-2">L2 Scaling</h3>
    <div class="text-sm opacity-60 mt-2">
        Deploying vaults to Arbitrum and Optimism for lower fees.
    </div>
</div>

<div class="cyber-card relative group">
    <div class="absolute -top-3 left-4 bg-black px-2 text-cyan-400 text-xs border border-cyan-500">PHASE 2</div>
    <h3 class="mt-2">AI Strategy</h3>
    <div class="text-sm opacity-60 mt-2">
        Integrating ML models for predictive yield optimization.
    </div>
</div>

<div class="cyber-card relative group">
    <div class="absolute -top-3 left-4 bg-black px-2 text-pink-400 text-xs border border-pink-500">PHASE 3</div>
    <h3 class="mt-2">Insurance</h3>
    <div class="text-sm opacity-60 mt-2">
        On-chain risk coverage for protocol failures.
    </div>
</div>

</div>

---
layout: center
class: text-center
---

# AMPLIFI

<div class="mt-8 flex justify-center gap-8">
    <div class="cyber-card px-8 py-4">
        <span>GITHUB</span>
    </div>
    <div class="cyber-card px-8 py-4 border-purple-500/50">
        <span>REACTIVE</span>
    </div>
</div>

<div class="mt-12 text-xs opacity-40 font-mono">
    BUILT FOR REACTIVE NETWORK BOUNTY SPRINT
</div>
