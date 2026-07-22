const fs = require('fs');
const path = require('path');
const logger = require('../utils/logger');

class HtmlReportGenerator {
  constructor(outputDir = path.resolve(__dirname, '../reports/HTML')) {
    this.outputDir = outputDir;
    if (!fs.existsSync(this.outputDir)) {
      fs.mkdirSync(this.outputDir, { recursive: true });
    }
  }

  generateReports(testCases, metrics, history = []) {
    logger.info(`Generating Responsive HTML Reports in: ${this.outputDir}`);

    const execReportHtml = this.buildExecutionReport(testCases, metrics);
    const dashboardHtml = this.buildDashboardReport(metrics, testCases);
    const trendsHtml = this.buildTrendsReport(history.length > 0 ? history : [metrics]);

    fs.writeFileSync(path.join(this.outputDir, 'execution-report.html'), execReportHtml);
    fs.writeFileSync(path.join(this.outputDir, 'dashboard.html'), dashboardHtml);
    fs.writeFileSync(path.join(this.outputDir, 'trends.html'), trendsHtml);

    logger.info('HTML reports (execution-report.html, dashboard.html, trends.html) generated successfully.');
  }

  buildExecutionReport(testCases, metrics) {
    const passedCount = metrics.passed || testCases.filter(t => t.status === 'PASSED').length;
    const failedCount = metrics.failed || testCases.filter(t => t.status === 'FAILED').length;
    const skippedCount = metrics.skipped || testCases.filter(t => t.status === 'SKIPPED').length;
    const totalCount = metrics.total || testCases.length;
    const passRate = metrics.passRate || (totalCount > 0 ? ((passedCount / totalCount) * 100).toFixed(1) : '0');

    const testRows = testCases.map(tc => `
      <tr class="test-row ${tc.status.toLowerCase()}" data-module="${tc.module}" data-status="${tc.status}">
        <td><strong>${tc.id}</strong></td>
        <td><span class="badge badge-module">${tc.module}</span></td>
        <td>${tc.name}</td>
        <td><span class="badge badge-prio ${tc.priority.toLowerCase()}">${tc.priority}</span></td>
        <td><span class="badge badge-status ${tc.status.toLowerCase()}">${tc.status}</span></td>
        <td>${tc.duration || 0} ms</td>
        <td>
          ${tc.status === 'FAILED' ? `
            <details>
              <summary class="text-danger font-bold cursor-pointer">View Stack Trace & Screenshot</summary>
              <div class="failure-box mt-2">
                <p><strong>Reason:</strong> ${tc.reason || 'Assertion Failed'}</p>
                ${tc.screenshot ? `<p class="mt-1">📷 Screenshot: <a href="../../${tc.screenshot}" target="_blank" class="link-blue">${tc.screenshot}</a></p>` : ''}
              </div>
            </details>
          ` : '<span class="text-muted">Clean execution</span>'}
        </td>
      </tr>
    `).join('');

    return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Arogya AI Android E2E Execution Report</title>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;600;700;800&display=swap" rel="stylesheet">
  <style>
    :root {
      --bg-color: #0f172a;
      --card-bg: #1e293b;
      --text-color: #f8fafc;
      --border-color: #334155;
      --accent-green: #22c55e;
      --accent-red: #ef4444;
      --accent-yellow: #f59e0b;
      --accent-blue: #3b82f6;
    }
    body { font-family: 'Inter', sans-serif; background: var(--bg-color); color: var(--text-color); margin: 0; padding: 20px; }
    .header { display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid var(--border-color); padding-bottom: 15px; margin-bottom: 25px; }
    .header h1 { font-size: 24px; font-weight: 800; background: linear-gradient(90deg, #38bdf8, #818cf8); -webkit-background-clip: text; -webkit-text-fill-color: transparent; margin: 0; }
    .metrics-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 15px; margin-bottom: 30px; }
    .metric-card { background: var(--card-bg); padding: 20px; border-radius: 12px; border: 1px solid var(--border-color); text-align: center; }
    .metric-value { font-size: 32px; font-weight: 800; margin-top: 5px; }
    .text-green { color: var(--accent-green); }
    .text-red { color: var(--accent-red); }
    .text-yellow { color: var(--accent-yellow); }
    .text-blue { color: var(--accent-blue); }
    .controls { display: flex; gap: 15px; margin-bottom: 20px; flex-wrap: wrap; }
    input, select { background: var(--card-bg); border: 1px solid var(--border-color); color: var(--text-color); padding: 10px 14px; border-radius: 8px; font-size: 14px; outline: none; }
    table { width: 100%; border-collapse: collapse; background: var(--card-bg); border-radius: 12px; overflow: hidden; border: 1px solid var(--border-color); }
    th, td { padding: 14px 18px; text-align: left; border-bottom: 1px solid var(--border-color); }
    th { background: #111827; font-weight: 700; color: #94a3b8; font-size: 13px; text-transform: uppercase; }
    .badge { padding: 4px 10px; border-radius: 20px; font-size: 12px; font-weight: 700; display: inline-block; }
    .badge-status.passed { background: rgba(34, 197, 94, 0.2); color: var(--accent-green); }
    .badge-status.failed { background: rgba(239, 68, 68, 0.2); color: var(--accent-red); }
    .badge-status.skipped { background: rgba(245, 158, 11, 0.2); color: var(--accent-yellow); }
    .badge-module { background: rgba(59, 130, 246, 0.2); color: var(--accent-blue); }
    .failure-box { background: rgba(239, 68, 68, 0.1); border-left: 4px solid var(--accent-red); padding: 12px; border-radius: 6px; font-size: 13px; }
    .link-blue { color: #38bdf8; text-decoration: none; }
  </style>
</head>
<body>
  <div class="header">
    <div>
      <h1>🚀 Arogya AI Android E2E Execution Report</h1>
      <p style="color: #94a3b8; margin: 4px 0 0 0; font-size: 13px;">Build: <strong>${metrics.buildNumber || 'BUILD-2026-001'}</strong> | Timestamp: ${new Date().toLocaleString()} | Device: ${metrics.deviceName || 'Android_Emulator'}</p>
    </div>
    <div>
      <a href="dashboard.html" class="link-blue" style="margin-right: 15px;">📊 Dashboard View</a>
      <a href="trends.html" class="link-blue">📈 Historical Trends</a>
    </div>
  </div>

  <div class="metrics-grid">
    <div class="metric-card"><div>Total Test Cases</div><div class="metric-value text-blue">${totalCount}</div></div>
    <div class="metric-card"><div>Passed</div><div class="metric-value text-green">${passedCount}</div></div>
    <div class="metric-card"><div>Failed</div><div class="metric-value text-red">${failedCount}</div></div>
    <div class="metric-card"><div>Skipped</div><div class="metric-value text-yellow">${skippedCount}</div></div>
    <div class="metric-card"><div>Pass Percentage</div><div class="metric-value text-green">${passRate}%</div></div>
  </div>

  <div class="controls">
    <input type="text" id="searchInput" placeholder="🔍 Search test cases..." onkeyup="filterTests()">
    <select id="statusFilter" onchange="filterTests()">
      <option value="ALL">All Statuses</option>
      <option value="PASSED">Passed</option>
      <option value="FAILED">Failed</option>
      <option value="SKIPPED">Skipped</option>
    </select>
  </div>

  <table>
    <thead>
      <tr>
        <th>Test ID</th>
        <th>Module</th>
        <th>Test Scenario Name</th>
        <th>Priority</th>
        <th>Status</th>
        <th>Duration</th>
        <th>Details / Failure Diagnostics</th>
      </tr>
    </thead>
    <tbody id="testTableBody">
      ${testRows}
    </tbody>
  </table>

  <script>
    function filterTests() {
      const search = document.getElementById('searchInput').value.toLowerCase();
      const status = document.getElementById('statusFilter').value;
      const rows = document.querySelectorAll('.test-row');

      rows.forEach(row => {
        const text = row.innerText.toLowerCase();
        const rowStatus = row.getAttribute('data-status');
        const matchesSearch = text.includes(search);
        const matchesStatus = (status === 'ALL' || rowStatus === status);

        if (matchesSearch && matchesStatus) {
          row.style.display = '';
        } else {
          row.style.display = 'none';
        }
      });
    }
  </script>
</body>
</html>`;
  }

  buildDashboardReport(metrics, testCases) {
    return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Arogya AI Automation Executive Dashboard</title>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600;800&display=swap" rel="stylesheet">
  <style>
    body { font-family: 'Inter', sans-serif; background: #0f172a; color: #f8fafc; margin: 0; padding: 25px; }
    h1 { font-size: 26px; font-weight: 800; color: #38bdf8; }
    .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; margin-top: 20px; }
    .card { background: #1e293b; padding: 25px; border-radius: 12px; border: 1px solid #334155; }
    .gauge { font-size: 48px; font-weight: 800; color: #22c55e; text-align: center; margin: 20px 0; }
  </style>
</head>
<body>
  <h1>📊 Executive Quality Dashboard</h1>
  <p>Build: <strong>${metrics.buildNumber || 'BUILD-2026-001'}</strong> | Target: Android Appium Mobile Suite</p>
  
  <div class="grid">
    <div class="card">
      <h3>Overall Pass Rate</h3>
      <div class="gauge">${metrics.passRate || '100'}%</div>
      <p style="text-align:center; color:#94a3b8;">${metrics.passed || testCases.length} of ${metrics.total || testCases.length} Test Scenarios Passed</p>
    </div>
    <div class="card">
      <h3>Environment Metadata</h3>
      <p>📱 Device: <strong>${metrics.deviceName || 'Android_Emulator'}</strong></p>
      <p>🤖 Android OS: <strong>${metrics.androidVersion || '14.0'}</strong></p>
      <p>⏱️ Total Duration: <strong>${metrics.durationSec || '45'} seconds</strong></p>
      <p>⚡ Concurrent Workers: <strong>4 Threads</strong></p>
    </div>
  </div>
</body>
</html>`;
  }

  buildTrendsReport(history) {
    return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Arogya AI Historical Execution Trends</title>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600;800&display=swap" rel="stylesheet">
  <style>
    body { font-family: 'Inter', sans-serif; background: #0f172a; color: #f8fafc; padding: 25px; }
    h1 { color: #818cf8; font-size: 26px; }
    .card { background: #1e293b; padding: 20px; border-radius: 12px; border: 1px solid #334155; margin-top: 20px; }
  </style>
</head>
<body>
  <h1>📈 Historical Build Stability Trends</h1>
  <div class="card">
    <p>Showing execution history across CI/CD builds:</p>
    <ul>
      ${history.map((h, i) => `<li>Build #${h.buildNumber || i + 1}: ${h.passRate || 100}% Pass Rate (${h.passed || 400} Passed, ${h.failed || 0} Failed)</li>`).join('')}
    </ul>
  </div>
</body>
</html>`;
  }

  static generateSampleReports() {
    const generator = new HtmlReportGenerator();
    const mockTests = Array.from({ length: 430 }, (_, i) => ({
      id: `TC_MOD_${String(i + 1).padStart(3, '0')}`,
      module: ['Authentication', 'Registration', 'Profile', 'Forms', 'Search', 'Emergency'][i % 6],
      name: `Validate functional execution step #${i + 1}`,
      priority: i % 5 === 0 ? 'P1' : 'P2',
      status: i === 12 || i === 45 ? 'FAILED' : 'PASSED',
      duration: Math.floor(Math.random() * 2000) + 500,
      reason: i === 12 || i === 45 ? 'Element locator timeout in UiAutomator2' : null,
      screenshot: i === 12 || i === 45 ? `screenshots/TC_MOD_${String(i + 1).padStart(3, '0')}.png` : null
    }));
    const mockMetrics = {
      buildNumber: 'BUILD-430-ENTERPRISE',
      deviceName: 'Pixel_7_Pro_API_34',
      androidVersion: '14.0',
      total: 430,
      executed: 430,
      passed: 428,
      failed: 2,
      skipped: 0,
      passRate: '99.5',
      durationSec: '124.5'
    };
    generator.generateReports(mockTests, mockMetrics);
  }
}

module.exports = HtmlReportGenerator;
