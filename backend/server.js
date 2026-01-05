const http = require('http');
const https = require('https');
const url = require('url');
const fs = require('fs');
const path = require('path');

const PORT = 3001;

// RPC Endpoints (using Alchemy for better rate limits)
const SEPOLIA_RPC = 'https://eth-sepolia.g.alchemy.com/v2/gSGZUmZvUJI9GKs2xrpKl';
const LASNA_RPC = 'https://lasna-rpc.rnk.dev';

// Contract addresses
const VAULT_MULTI_ASSET = '0x42437f29E25Ad65E121f4D0f07FD8F5c2005e5d5';
const FEE_COLLECTOR = '0x3777Afd270B483cAc21C3234fa72E34b9fed33Cf';
const FUNDER = '0x0CabFEE932171171d90D672160cC6939f93b2D39';

// Token addresses (Sepolia)
const TOKENS = {
    WETH: '0xC558DBdd856501FCd9aaF1E62eae57A9F0629a3c',
    LINK: '0xf8Fb3713D459D7C1018BD0A49D19b4C44290EBE5',
    AAVE: '0x88541670E55cC00bEEFD87eB59EDd1b7C511AC9a',
    EURS: '0x6d906e526a4e2Ca02097BA9d0caA3c382F52278E',
    WBTC: '0x29f2D40B0605204364af54EC677bD022dA425d03'
};

// Price feed proxies
const PRICE_FEEDS = {
    ETH: '0xb1aDCca598051EfdaD48217D950EAFf2CA869691',
    LINK: '0x6B94668442B97e7dCF1958044a21e42a73D3647b',
    EUR: '0x955e94A600d059789d42ca533fe90c5187f520Af',
    BTC: '0x736D13De4d6BF46DC81f89a759D6e3C2FbC9D6b9'
};

// Helper to make RPC calls
function rpcCall(rpcUrl, method, params) {
    return new Promise((resolve, reject) => {
        const urlParts = new url.URL(rpcUrl);
        const payload = JSON.stringify({
            jsonrpc: '2.0',
            method,
            params,
            id: Date.now()
        });

        const options = {
            hostname: urlParts.hostname,
            port: urlParts.port || 443,
            path: urlParts.pathname,
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Content-Length': Buffer.byteLength(payload)
            }
        };

        const req = https.request(options, (res) => {
            let data = '';
            res.on('data', chunk => data += chunk);
            res.on('end', () => {
                try {
                    const json = JSON.parse(data);
                    resolve(json.result);
                } catch (e) {
                    reject(e);
                }
            });
        });

        req.on('error', reject);
        req.write(payload);
        req.end();
    });
}

// Get vault data
async function getVaultData() {
    try {
        // Get vault balance
        const balanceData = await rpcCall(SEPOLIA_RPC, 'eth_call', [{
            to: VAULT_MULTI_ASSET,
            data: '0x722713f7' // getTotalDeposits()
        }, 'latest']);

        // Get snapshots count
        const snapshotsData = await rpcCall(SEPOLIA_RPC, 'eth_call', [{
            to: VAULT_MULTI_ASSET,
            data: '0x3bb68e5b' // snapshotCount()
        }, 'latest']);

        const totalDeposits = balanceData ? parseInt(balanceData, 16) / 1e18 : 0;
        const snapshots = snapshotsData ? parseInt(snapshotsData, 16) : 0;

        return {
            tvl: totalDeposits,
            snapshots,
            assets: [
                { symbol: 'WETH', apy: 0.02, allocation: 2500, balance: 0. },
                { symbol: 'LINK', apy: 17.37, allocation: 2500, balance: 0 },
                { symbol: 'AAVE', apy: 0.01, allocation: 2500, balance: 0 },
                { symbol: 'EURS', apy: 0.24, allocation: 2500, balance: 0 },
                { symbol: 'WBTC', apy: 0.01, allocation: 0, balance: 0 }
            ]
        };
    } catch (e) {
        console.error('Error fetching vault data:', e);
        return { tvl: 0, snapshots: 0, assets: [] };
    }
}

// Get funder data
async function getFunderData() {
    try {
        const balance = await rpcCall(SEPOLIA_RPC, 'eth_getBalance', [FUNDER, 'latest']);
        return {
            balance: balance ? parseInt(balance, 16) / 1e18 : 0,
            totalBridged: 0
        };
    } catch (e) {
        console.error('Error fetching funder data:', e);
        return { balance: 0, totalBridged: 0 };
    }
}

// Get price from feed
async function getPrice(feedAddress) {
    try {
        // latestRoundData() selector
        const result = await rpcCall(SEPOLIA_RPC, 'eth_call', [{
            to: feedAddress,
            data: '0xfeaf968c'
        }, 'latest']);

        if (result && result.length > 66) {
            // Parse answer (second uint256 in response)
            const answerHex = '0x' + result.slice(66, 130);
            return parseInt(answerHex, 16) / 1e8;
        }
        return 0;
    } catch (e) {
        console.error('Error fetching price:', e);
        return 0;
    }
}

// CORS headers
function setCorsHeaders(res) {
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
}

// Create HTTP server
const server = http.createServer(async (req, res) => {
    setCorsHeaders(res);

    if (req.method === 'OPTIONS') {
        res.writeHead(204);
        res.end();
        return;
    }

    const parsedUrl = url.parse(req.url, true);
    const pathname = parsedUrl.pathname;

    try {
        if (pathname === '/api/vault') {
            const data = await getVaultData();
            res.writeHead(200, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify(data));
        } else if (pathname === '/api/funder') {
            const data = await getFunderData();
            res.writeHead(200, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify(data));
        } else if (pathname === '/api/prices') {
            const prices = {
                ETH: await getPrice(PRICE_FEEDS.ETH),
                LINK: await getPrice(PRICE_FEEDS.LINK),
                EUR: await getPrice(PRICE_FEEDS.EUR),
                BTC: await getPrice(PRICE_FEEDS.BTC)
            };
            res.writeHead(200, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify(prices));
        } else if (pathname === '/api/health') {
            res.writeHead(200, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ status: 'ok', timestamp: new Date().toISOString() }));
        } else {
            // Serve static files from frontend directory
            let filePath = path.join(__dirname, '..', 'frontend', pathname);
            
            // Default to index.html if root path
            if (pathname === '/') {
                filePath = path.join(__dirname, '..', 'frontend', 'index.html');
            }

            // Check if file exists
            fs.access(filePath, fs.constants.F_OK, (err) => {
                if (err) {
                    res.writeHead(404, { 'Content-Type': 'text/html' });
                    res.end('<h1>404 Not Found</h1>');
                    return;
                }

                // Determine content type
                const ext = path.extname(filePath);
                const contentTypes = {
                    '.html': 'text/html',
                    '.css': 'text/css',
                    '.js': 'application/javascript',
                    '.json': 'application/json',
                    '.png': 'image/png',
                    '.jpg': 'image/jpeg',
                    '.svg': 'image/svg+xml',
                    '.ico': 'image/x-icon'
                };
                const contentType = contentTypes[ext] || 'application/octet-stream';

                // Read and serve file
                fs.readFile(filePath, (err, data) => {
                    if (err) {
                        res.writeHead(500, { 'Content-Type': 'text/html' });
                        res.end('<h1>500 Internal Server Error</h1>');
                        return;
                    }
                    res.writeHead(200, { 'Content-Type': contentType });
                    res.end(data);
                });
            });
        }
    } catch (e) {
        console.error('Server error:', e);
        res.writeHead(500, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: 'Internal server error' }));
    }
});

server.listen(PORT, () => {
    console.log(`\n🚀 Amplifi Backend Server running on http://localhost:${PORT}`);
    console.log(`\n📊 Endpoints:`);
    console.log(`   GET /api/vault   - Vault data (TVL, snapshots, assets)`);
    console.log(`   GET /api/funder  - Funder gas tank balance`);
    console.log(`   GET /api/prices  - Cross-chain price feeds`);
    console.log(`   GET /api/health  - Health check`);
    console.log(`\n🔗 Connected to:`);
    console.log(`   Sepolia: ${SEPOLIA_RPC}`);
    console.log(`   Lasna:   ${LASNA_RPC}`);
    console.log(`\n💳 Contracts:`);
    console.log(`   Vault:   ${VAULT_MULTI_ASSET}`);
    console.log(`   Funder:  ${FUNDER}`);
});
