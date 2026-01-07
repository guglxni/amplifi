# AmpliFi Frontend Enhancement Specifications

> Detailed implementation guide for UI/UX enhancements to showcase Reactive Network capabilities

---

## 1. RSC Activity Dashboard

### Design Concept

The RSC Activity Dashboard provides real-time visibility into all Reactive Smart Contract operations, making the "magic" of automated yield optimization transparent to users.

### UI Components

#### 1.1 Live RSC Status Card

```html
<div class="card rsc-status-card">
    <div class="card-header">
        <span><i class="ph-bold ph-cpu"></i> RSC STATUS</span>
        <span class="badge badge-live"><span class="live-dot"></span> ONLINE</span>
    </div>
    
    <div class="rsc-metrics">
        <div class="metric">
            <div class="metric-label">Balance</div>
            <div class="metric-value" id="rsc-balance">2,345 REACT</div>
        </div>
        <div class="metric">
            <div class="metric-label">Active Subscriptions</div>
            <div class="metric-value" id="rsc-subs">3</div>
        </div>
        <div class="metric">
            <div class="metric-label">Last CRON</div>
            <div class="metric-value" id="last-cron">2 min ago</div>
        </div>
    </div>
    
    <div class="subscription-list">
        <div class="sub-item">
            <i class="ph-bold ph-broadcast"></i>
            <span>YieldSnapshot</span>
            <span class="chain-badge">Sepolia</span>
        </div>
        <div class="sub-item">
            <i class="ph-bold ph-clock"></i>
            <span>CRON (100 blocks)</span>
            <span class="chain-badge">Reactive</span>
        </div>
        <div class="sub-item">
            <i class="ph-bold ph-wallet"></i>
            <span>FundsReceived</span>
            <span class="chain-badge">Sepolia</span>
        </div>
    </div>
</div>
```

#### 1.2 Activity Feed Component

```javascript
class RSCActivityFeed {
    constructor(containerId) {
        this.container = document.getElementById(containerId);
        this.events = [];
        this.maxEvents = 50;
    }
    
    addEvent(event) {
        this.events.unshift({
            ...event,
            timestamp: Date.now()
        });
        
        if (this.events.length > this.maxEvents) {
            this.events.pop();
        }
        
        this.render();
    }
    
    getEventIcon(type) {
        const icons = {
            'CRON': 'ph-clock',
            'YIELD_SNAPSHOT': 'ph-camera',
            'REBALANCE': 'ph-scales',
            'CALLBACK': 'ph-arrow-elbow-right',
            'GAS_REFILL': 'ph-gas-pump',
            'SUBSCRIPTION': 'ph-broadcast'
        };
        return icons[type] || 'ph-info';
    }
    
    getEventColor(type) {
        const colors = {
            'CRON': 'var(--color-secondary)',
            'YIELD_SNAPSHOT': 'var(--color-primary)',
            'REBALANCE': 'var(--color-success)',
            'CALLBACK': 'var(--color-warning)',
            'GAS_REFILL': 'var(--color-accent)',
            'SUBSCRIPTION': 'var(--color-text-muted)'
        };
        return colors[type] || 'var(--color-text-main)';
    }
    
    formatTimestamp(ts) {
        const diff = Date.now() - ts;
        if (diff < 60000) return `${Math.floor(diff/1000)}s ago`;
        if (diff < 3600000) return `${Math.floor(diff/60000)}m ago`;
        return new Date(ts).toLocaleTimeString();
    }
    
    render() {
        this.container.innerHTML = this.events.map(e => `
            <div class="activity-item" style="border-left: 3px solid ${this.getEventColor(e.type)}">
                <div class="activity-icon">
                    <i class="ph-bold ${this.getEventIcon(e.type)}" 
                       style="color: ${this.getEventColor(e.type)}"></i>
                </div>
                <div class="activity-content">
                    <div class="activity-title">${e.title}</div>
                    <div class="activity-details">${e.details || ''}</div>
                </div>
                <div class="activity-time">${this.formatTimestamp(e.timestamp)}</div>
            </div>
        `).join('');
    }
}

// Usage
const feed = new RSCActivityFeed('rsc-activity-feed');

// Simulate events (in production, these come from WebSocket/polling)
feed.addEvent({
    type: 'CRON',
    title: 'CRON Executed',
    details: 'Block #12345678 • No rebalance needed'
});

feed.addEvent({
    type: 'YIELD_SNAPSHOT',
    title: 'Yield Snapshot Received',
    details: 'LINK: 17.37% • WETH: 2.45% • AAVE: 5.12%'
});

feed.addEvent({
    type: 'REBALANCE',
    title: 'Rebalance Triggered',
    details: 'LINK ↑ 25% → 40% • WETH ↓ 25% → 20%'
});
```

#### 1.3 CSS Styling

```css
/* Activity Feed Styles */
.activity-feed {
    background: var(--color-bg-panel);
    border: 1px solid var(--color-border);
    border-radius: 16px;
    padding: 1.5rem;
    max-height: 400px;
    overflow-y: auto;
}

.activity-item {
    display: flex;
    align-items: flex-start;
    gap: 1rem;
    padding: 0.75rem;
    margin-bottom: 0.5rem;
    background: rgba(0, 0, 0, 0.2);
    border-radius: 8px;
    transition: background 0.2s;
}

.activity-item:hover {
    background: rgba(255, 255, 255, 0.03);
}

.activity-icon {
    width: 32px;
    height: 32px;
    display: flex;
    align-items: center;
    justify-content: center;
    background: rgba(255, 255, 255, 0.05);
    border-radius: 8px;
    font-size: 1rem;
}

.activity-content {
    flex: 1;
}

.activity-title {
    font-weight: 600;
    font-size: 0.9rem;
    margin-bottom: 0.25rem;
}

.activity-details {
    font-size: 0.75rem;
    color: var(--color-text-muted);
}

.activity-time {
    font-size: 0.7rem;
    color: var(--color-text-muted);
    white-space: nowrap;
}

/* RSC Status Styles */
.rsc-metrics {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 1rem;
    margin: 1rem 0;
}

.subscription-list {
    background: rgba(0, 0, 0, 0.2);
    border-radius: 12px;
    padding: 1rem;
}

.sub-item {
    display: flex;
    align-items: center;
    gap: 0.75rem;
    padding: 0.5rem 0;
    border-bottom: 1px solid var(--color-border);
}

.sub-item:last-child {
    border-bottom: none;
}

.chain-badge {
    margin-left: auto;
    font-size: 0.65rem;
    padding: 0.2rem 0.5rem;
    background: rgba(129, 140, 248, 0.2);
    border-radius: 4px;
    color: var(--color-secondary);
    text-transform: uppercase;
    letter-spacing: 0.05em;
}
```

---

## 2. CRON Monitoring Panel

### Design Concept

Visualize the CRON subscription mechanism with a timeline showing past executions and next scheduled check.

### UI Components

```html
<div class="card cron-panel">
    <div class="card-header">
        <span><i class="ph-bold ph-timer"></i> CRON MONITORING</span>
        <span class="badge badge-live"><span class="live-dot"></span> ACTIVE</span>
    </div>
    
    <div class="cron-stats">
        <div class="stat">
            <div class="stat-value" id="cron-interval">100</div>
            <div class="stat-label">Blocks Interval</div>
        </div>
        <div class="stat">
            <div class="stat-value" id="cron-next">23</div>
            <div class="stat-label">Blocks Until Next</div>
        </div>
        <div class="stat">
            <div class="stat-value" id="cron-total">1,247</div>
            <div class="stat-label">Total Executions</div>
        </div>
    </div>
    
    <div class="cron-progress">
        <div class="progress-bar">
            <div class="progress-fill" id="cron-progress" style="width: 77%"></div>
        </div>
        <div class="progress-labels">
            <span>Last CRON</span>
            <span>Next CRON</span>
        </div>
    </div>
    
    <div class="cron-history">
        <h4>Recent CRON Executions</h4>
        <div class="history-list" id="cron-history">
            <!-- Populated by JS -->
        </div>
    </div>
</div>
```

### JavaScript Controller

```javascript
class CRONMonitor {
    constructor(config) {
        this.interval = config.interval || 100;
        this.lastExecution = config.lastBlock || 0;
        this.history = [];
    }
    
    async updateFromChain(provider) {
        const currentBlock = await provider.getBlockNumber();
        const blocksSinceLast = currentBlock - this.lastExecution;
        const blocksUntilNext = this.interval - (blocksSinceLast % this.interval);
        const progress = ((this.interval - blocksUntilNext) / this.interval) * 100;
        
        // Update UI
        document.getElementById('cron-next').textContent = blocksUntilNext;
        document.getElementById('cron-progress').style.width = `${progress}%`;
        
        // Animate progress bar color as it approaches
        if (blocksUntilNext < 10) {
            document.getElementById('cron-progress').classList.add('imminent');
        }
    }
    
    renderHistory() {
        const container = document.getElementById('cron-history');
        container.innerHTML = this.history.slice(0, 10).map(h => `
            <div class="history-item ${h.rebalanced ? 'triggered' : ''}">
                <div class="history-block">Block #${h.block}</div>
                <div class="history-result">
                    <i class="ph-bold ${h.rebalanced ? 'ph-check-circle' : 'ph-minus-circle'}"></i>
                    ${h.rebalanced ? 'Rebalanced' : 'No Action'}
                </div>
                <div class="history-gas">${h.gasUsed} gas</div>
            </div>
        `).join('');
    }
}
```

---

## 3. Yield Comparison Visualization

### Design Concept

Interactive chart showing historical yield data and rebalance decision points.

### Implementation

```javascript
class YieldComparisonChart {
    constructor(canvasId) {
        this.ctx = document.getElementById(canvasId).getContext('2d');
        this.data = {
            labels: [],
            datasets: []
        };
        this.rebalanceMarkers = [];
    }
    
    initChart() {
        this.chart = new Chart(this.ctx, {
            type: 'line',
            data: {
                labels: this.data.labels,
                datasets: [
                    {
                        label: 'LINK APY',
                        data: [],
                        borderColor: 'rgba(52, 211, 153, 1)',
                        backgroundColor: 'rgba(52, 211, 153, 0.1)',
                        fill: true,
                        tension: 0.4
                    },
                    {
                        label: 'WETH APY',
                        data: [],
                        borderColor: 'rgba(34, 211, 238, 1)',
                        backgroundColor: 'rgba(34, 211, 238, 0.1)',
                        fill: true,
                        tension: 0.4
                    },
                    {
                        label: 'AAVE APY',
                        data: [],
                        borderColor: 'rgba(182, 80, 158, 1)',
                        backgroundColor: 'rgba(182, 80, 158, 0.1)',
                        fill: true,
                        tension: 0.4
                    }
                ]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: {
                        position: 'top',
                        labels: { color: '#94a3b8' }
                    },
                    annotation: {
                        annotations: this.rebalanceMarkers
                    }
                },
                scales: {
                    x: {
                        grid: { color: 'rgba(148, 163, 184, 0.1)' },
                        ticks: { color: '#94a3b8' }
                    },
                    y: {
                        grid: { color: 'rgba(148, 163, 184, 0.1)' },
                        ticks: { 
                            color: '#94a3b8',
                            callback: (value) => value + '%'
                        }
                    }
                }
            }
        });
    }
    
    addRebalanceMarker(timestamp, description) {
        this.rebalanceMarkers.push({
            type: 'line',
            xMin: timestamp,
            xMax: timestamp,
            borderColor: 'rgba(251, 191, 36, 0.5)',
            borderWidth: 2,
            label: {
                enabled: true,
                content: '⚡ Rebalance',
                position: 'start'
            }
        });
        this.chart.update();
    }
}
```

---

## 4. Health Factor Monitor (Proposed Enhancement)

### Design Concept

Visual gauge showing user's health factor with animated alerts as it approaches liquidation threshold.

### Implementation

```html
<div class="card health-monitor">
    <div class="card-header">
        <span><i class="ph-bold ph-heartbeat"></i> POSITION HEALTH</span>
        <span class="badge" id="hf-status">SAFE</span>
    </div>
    
    <div class="health-gauge-container">
        <svg class="health-gauge" viewBox="0 0 200 120">
            <defs>
                <linearGradient id="healthGradient" x1="0%" y1="0%" x2="100%" y2="0%">
                    <stop offset="0%" style="stop-color:#ef4444" />
                    <stop offset="33%" style="stop-color:#f59e0b" />
                    <stop offset="66%" style="stop-color:#10b981" />
                    <stop offset="100%" style="stop-color:#22d3ee" />
                </linearGradient>
            </defs>
            <!-- Background arc -->
            <path d="M 20 100 A 80 80 0 0 1 180 100" 
                  fill="none" 
                  stroke="rgba(255,255,255,0.1)" 
                  stroke-width="12"
                  stroke-linecap="round"/>
            <!-- Health factor arc -->
            <path id="hf-arc" 
                  d="M 20 100 A 80 80 0 0 1 180 100" 
                  fill="none" 
                  stroke="url(#healthGradient)" 
                  stroke-width="12"
                  stroke-linecap="round"
                  stroke-dasharray="251.2"
                  stroke-dashoffset="50"/>
            <!-- Needle -->
            <line id="hf-needle" x1="100" y1="100" x2="100" y2="30" 
                  stroke="#fff" stroke-width="3" stroke-linecap="round"/>
        </svg>
        
        <div class="health-value">
            <div class="hf-number" id="health-factor-value">1.85</div>
            <div class="hf-label">Health Factor</div>
        </div>
    </div>
    
    <div class="health-zones">
        <div class="zone danger"><span>< 1.0</span> Liquidation</div>
        <div class="zone warning"><span>1.0 - 1.2</span> At Risk</div>
        <div class="zone safe"><span>1.2 - 1.5</span> Moderate</div>
        <div class="zone excellent"><span>> 1.5</span> Safe</div>
    </div>
    
    <div class="protection-config" id="protection-panel">
        <h4>Liquidation Protection</h4>
        <div class="toggle-row">
            <span>Enable Protection</span>
            <label class="toggle">
                <input type="checkbox" id="protection-toggle">
                <span class="slider"></span>
            </label>
        </div>
        <div class="config-row">
            <span>Trigger at HF</span>
            <input type="number" id="trigger-hf" value="1.1" step="0.05" min="1.0" max="1.5">
        </div>
        <div class="config-row">
            <span>Reserve Amount</span>
            <input type="text" id="reserve-amount" value="0.5" placeholder="ETH">
        </div>
    </div>
</div>
```

### JavaScript Controller

```javascript
class HealthFactorMonitor {
    constructor(containerId) {
        this.healthFactor = 2.0;
        this.protectionEnabled = false;
        this.alertThreshold = 1.2;
        
        this.needle = document.getElementById('hf-needle');
        this.valueDisplay = document.getElementById('health-factor-value');
        this.statusBadge = document.getElementById('hf-status');
    }
    
    setHealthFactor(hf) {
        this.healthFactor = hf;
        this.updateDisplay();
        this.checkAlerts();
    }
    
    updateDisplay() {
        // Update value
        this.valueDisplay.textContent = this.healthFactor.toFixed(2);
        
        // Calculate needle rotation (0 degrees = 1.0 HF, 180 degrees = 3.0 HF)
        const normalizedHF = Math.min(Math.max(this.healthFactor, 0.5), 3.0);
        const rotation = -90 + ((normalizedHF - 0.5) / 2.5) * 180;
        this.needle.style.transform = `rotate(${rotation}deg)`;
        this.needle.style.transformOrigin = '100px 100px';
        
        // Update status badge
        if (this.healthFactor < 1.0) {
            this.statusBadge.textContent = 'LIQUIDATION';
            this.statusBadge.className = 'badge badge-danger';
        } else if (this.healthFactor < 1.2) {
            this.statusBadge.textContent = 'AT RISK';
            this.statusBadge.className = 'badge badge-warning';
        } else if (this.healthFactor < 1.5) {
            this.statusBadge.textContent = 'MODERATE';
            this.statusBadge.className = 'badge badge-info';
        } else {
            this.statusBadge.textContent = 'SAFE';
            this.statusBadge.className = 'badge badge-success';
        }
    }
    
    checkAlerts() {
        if (this.healthFactor < this.alertThreshold && this.protectionEnabled) {
            this.showProtectionAlert();
        }
    }
    
    showProtectionAlert() {
        // Trigger visual alert and potentially the protection RSC
        const container = document.querySelector('.health-monitor');
        container.classList.add('alert-pulse');
        
        setTimeout(() => container.classList.remove('alert-pulse'), 2000);
    }
}
```

---

## 5. Transaction Flow Visualizer

### Design Concept

Animated visualization showing the flow of data from Origin → Reactive Network → Destination during RSC operations.

### Implementation

```html
<div class="tx-flow-visualizer">
    <div class="flow-node origin" id="origin-node">
        <div class="node-icon">
            <img src="https://cryptologos.cc/logos/ethereum-eth-logo.png?v=040" alt="Sepolia">
        </div>
        <div class="node-label">Sepolia</div>
        <div class="node-status">YieldSnapshot</div>
    </div>
    
    <div class="flow-connection" id="conn-1">
        <div class="flow-particle"></div>
        <div class="flow-label">Event Log</div>
    </div>
    
    <div class="flow-node reactive" id="reactive-node">
        <div class="node-icon">
            <img src="assets/lasna-logo.png" alt="Reactive">
        </div>
        <div class="node-label">Reactive Network</div>
        <div class="node-status">Processing...</div>
    </div>
    
    <div class="flow-connection" id="conn-2">
        <div class="flow-particle"></div>
        <div class="flow-label">Callback</div>
    </div>
    
    <div class="flow-node destination" id="dest-node">
        <div class="node-icon">
            <img src="https://cryptologos.cc/logos/ethereum-eth-logo.png?v=040" alt="Sepolia">
        </div>
        <div class="node-label">Sepolia</div>
        <div class="node-status">Rebalance</div>
    </div>
</div>
```

### CSS Animation

```css
.tx-flow-visualizer {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 2rem;
    background: linear-gradient(135deg, rgba(0,0,0,0.3), rgba(0,0,0,0.1));
    border-radius: 20px;
    position: relative;
}

.flow-node {
    display: flex;
    flex-direction: column;
    align-items: center;
    padding: 1.5rem;
    background: var(--color-bg-panel);
    border: 1px solid var(--color-border);
    border-radius: 16px;
    min-width: 140px;
    transition: all 0.3s;
}

.flow-node.active {
    border-color: var(--color-primary);
    box-shadow: 0 0 20px rgba(34, 211, 238, 0.3);
}

.flow-node .node-icon img {
    width: 40px;
    height: 40px;
}

.flow-connection {
    flex: 1;
    height: 4px;
    background: rgba(255,255,255,0.1);
    position: relative;
    margin: 0 1rem;
}

.flow-particle {
    position: absolute;
    width: 12px;
    height: 12px;
    background: var(--color-primary);
    border-radius: 50%;
    top: 50%;
    transform: translateY(-50%);
    animation: flowParticle 2s infinite;
    box-shadow: 0 0 10px var(--color-primary);
}

@keyframes flowParticle {
    0% { left: 0; opacity: 0; }
    10% { opacity: 1; }
    90% { opacity: 1; }
    100% { left: calc(100% - 12px); opacity: 0; }
}

.flow-label {
    position: absolute;
    top: -20px;
    left: 50%;
    transform: translateX(-50%);
    font-size: 0.7rem;
    color: var(--color-text-muted);
    text-transform: uppercase;
    letter-spacing: 0.05em;
}
```

---

## 6. Implementation Checklist

### Immediate (Frontend Only)

- [ ] Add RSC Activity Feed to dashboard
- [ ] Implement CRON progress indicator
- [ ] Add subscription list display
- [ ] Create yield comparison chart with annotations
- [ ] Add transaction flow visualizer

### Short-term (Requires Backend/RSC Changes)

- [ ] Health factor monitoring with Aave integration
- [ ] Liquidation protection configuration UI
- [ ] Real-time WebSocket event streaming
- [ ] Historical rebalance data visualization

### Future

- [ ] Stop-loss/take-profit order configuration
- [ ] Cross-chain yield comparison dashboard
- [ ] AI-powered strategy suggestions UI

---

*Document Version: 1.0*
*Created: December 28, 2024*
