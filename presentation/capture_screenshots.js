
import puppeteer from 'puppeteer';
import fs from 'fs';
import path from 'path';

const SCREENSHOT_DIR = 'public/screenshots';
if (!fs.existsSync(SCREENSHOT_DIR)) {
    fs.mkdirSync(SCREENSHOT_DIR, { recursive: true });
}

const URLS = [
    { name: 'dashboard', url: 'http://localhost:8888/index.html' },
    { name: 'multiasset', url: 'http://localhost:8888/multiasset.html' },
    { name: 'oracle', url: 'http://localhost:8888/oracle.html' },
    // External explorers (using specific txs/addresses from the slides)
    { name: 'etherscan_vault', url: 'https://sepolia.etherscan.io/address/0x42437f29E25Ad65E121f4D0f07FD8F5c2005e5d5' },
    { name: 'lasnascan_rsc', url: 'https://lasna.reactscan.net/address/0x6A19266E767E28E9867c4273111f71a08B9B97F7' }
];

async function capture() {
    console.log('Launching browser...');
    const browser = await puppeteer.launch({
        headless: "new",
        args: ['--no-sandbox', '--disable-setuid-sandbox'],
        defaultViewport: {
            width: 1920,
            height: 1080,
            deviceScaleFactor: 2
        }
    });
    const page = await browser.newPage();
    // Viewport is set by defaultViewport, but can force it here too
    await page.setViewport({ width: 1920, height: 1080, deviceScaleFactor: 2 });

    for (const item of URLS) {
        console.log(`Capturing ${item.name}...`);
        try {
            await page.goto(item.url, { waitUntil: 'networkidle2', timeout: 30000 });
            // Add a small delay for animations/rendering
            await new Promise(r => setTimeout(r, 2000));

            await page.screenshot({
                path: path.join(SCREENSHOT_DIR, `${item.name}.png`),
                fullPage: false
            });
            console.log(`Saved ${item.name}.png`);
        } catch (e) {
            console.error(`Failed to capture ${item.name}:`, e.message);
        }
    }

    await browser.close();
    console.log('Done.');
}

capture();
