/**
 * Arogya AI - Baseline / Load Testing Script
 * 
 * Target Parameters:
 * - Concurrency: 100 Virtual Users (VUs)
 * - Duration: 60 Seconds (1 minute continuous execution)
 * - Metrics: RPS (Requests per second), Response Times (Min, Max, Avg, p90, p95)
 * 
 * Usage:
 *   node baseline_load_test.js [targetUrl] [concurrency] [durationSeconds]
 * 
 * Example:
 *   node baseline_load_test.js http://localhost:5000/api/health 100 60
 */

const http = require('http');
const https = require('https');
const { URL } = require('url');

const targetUrlStr = process.argv[2] || 'http://localhost:5000/api/health';
const concurrency = parseInt(process.argv[3] || '100', 10);
const durationSeconds = parseInt(process.argv[4] || '60', 10);

const parsedUrl = new URL(targetUrlStr);
const clientModule = parsedUrl.protocol === 'https:' ? https : http;

console.log(`=======================================================`);
console.log(`🚀 Starting Arogya AI Baseline Load Test`);
console.log(`=======================================================`);
console.log(`🎯 Target Endpoint : ${targetUrlStr}`);
console.log(`👥 Virtual Users  : ${concurrency} concurrent VUs`);
console.log(`⏱️  Test Duration  : ${durationSeconds} seconds`);
console.log(`=======================================================\n`);

let totalRequestsSent = 0;
let totalSuccessRequests = 0;
let totalFailedRequests = 0;
const latencies = [];
let isRunning = true;

const agent = new clientModule.Agent({
    keepAlive: true,
    maxSockets: concurrency * 2
});

const requestOptions = {
    hostname: parsedUrl.hostname,
    port: parsedUrl.port || (parsedUrl.protocol === 'https:' ? 443 : 80),
    path: parsedUrl.pathname + parsedUrl.search,
    method: 'GET',
    agent: agent,
    headers: {
        'User-Agent': 'ArogyaAI-LoadTestWorker/1.0',
        'Accept': 'application/json'
    }
};

function sendWorkerRequest(workerId) {
    if (!isRunning) return;

    totalRequestsSent++;
    const startTime = process.hrtime.bigint();

    const req = clientModule.request(requestOptions, (res) => {
        let body = '';
        res.on('data', chunk => body += chunk);
        res.on('end', () => {
            const endTime = process.hrtime.bigint();
            const latencyMs = Number(endTime - startTime) / 1e6;

            if (res.statusCode >= 200 && res.statusCode < 400) {
                totalSuccessRequests++;
                latencies.push(latencyMs);
            } else {
                totalFailedRequests++;
            }

            if (isRunning) {
                setImmediate(() => sendWorkerRequest(workerId));
            }
        });
    });

    req.on('error', (err) => {
        totalFailedRequests++;
        if (isRunning) {
            setImmediate(() => sendWorkerRequest(workerId));
        }
    });

    req.setTimeout(5000, () => {
        req.destroy(new Error('Request Timeout'));
    });

    req.end();
}

const startTimeMillis = Date.now();

// Launch Virtual Users
for (let i = 0; i < concurrency; i++) {
    sendWorkerRequest(i);
}

// Timer display update every 5 seconds
const progressInterval = setInterval(() => {
    const elapsedSec = ((Date.now() - startTimeMillis) / 1000).toFixed(1);
    const currentRps = (totalSuccessRequests / (elapsedSec || 1)).toFixed(1);
    console.log(`[${elapsedSec}s / ${durationSeconds}s] Completed: ${totalSuccessRequests} reqs | Errors: ${totalFailedRequests} | RPS: ${currentRps}`);
}, 5000);

// Stop test after durationSeconds
setTimeout(() => {
    isRunning = false;
    clearInterval(progressInterval);
    const actualDurationSec = (Date.now() - startTimeMillis) / 1000;

    console.log(`\n=======================================================`);
    console.log(`📊 LOAD TEST RESULTS SUMMARY`);
    console.log(`=======================================================`);

    const rps = (totalSuccessRequests / actualDurationSec).toFixed(2);
    
    if (latencies.length === 0) {
        console.log(`❌ No successful responses recorded. Check if server is running at ${targetUrlStr}`);
        process.exit(1);
    }

    latencies.sort((a, b) => a - b);

    const minMs = latencies[0].toFixed(2);
    const maxMs = latencies[latencies.length - 1].toFixed(2);
    const avgMs = (latencies.reduce((acc, val) => acc + val, 0) / latencies.length).toFixed(2);
    
    const p50Ms = latencies[Math.floor(latencies.length * 0.50)].toFixed(2);
    const p90Ms = latencies[Math.floor(latencies.length * 0.90)].toFixed(2);
    const p95Ms = latencies[Math.floor(latencies.length * 0.95)].toFixed(2);
    const p99Ms = latencies[Math.floor(latencies.length * 0.99)].toFixed(2);

    console.log(`🟢 Total Requests Executed : ${totalRequestsSent}`);
    console.log(`✅ Successful Requests    : ${totalSuccessRequests}`);
    console.log(`❌ Failed Requests        : ${totalFailedRequests}`);
    console.log(`⏱️ Actual Test Duration   : ${actualDurationSec.toFixed(2)} seconds`);
    console.log(`-------------------------------------------------------`);
    console.log(`⚡ Throughput (RPS)       : ${rps} req/sec`);
    console.log(`-------------------------------------------------------`);
    console.log(`⏱️ Response Time Breakdown:`);
    console.log(`   • Minimum (Fastest)  : ${minMs} ms`);
    console.log(`   • Average Response   : ${avgMs} ms`);
    console.log(`   • Maximum (Slowest)  : ${maxMs} ms`);
    console.log(`   • 50th Percentile    : ${p50Ms} ms`);
    console.log(`   • 90th Percentile    : ${p90Ms} ms`);
    console.log(`   • 95th Percentile    : ${p95Ms} ms`);
    console.log(`   • 99th Percentile    : ${p99Ms} ms`);
    console.log(`=======================================================\n`);

    process.exit(0);
}, durationSeconds * 1000);
