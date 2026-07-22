const fs = require('fs');
const path = require('path');
const logger = require('../utils/logger');

class JsonReportGenerator {
  constructor(outputDir = path.resolve(__dirname, '../reports/JSON')) {
    this.outputDir = outputDir;
    if (!fs.existsSync(this.outputDir)) {
      fs.mkdirSync(this.outputDir, { recursive: true });
    }
  }

  generateJsonReport(testCases, metrics) {
    const filePath = path.join(this.outputDir, 'execution-results.json');
    logger.info(`Generating JSON Report at: ${filePath}`);

    const reportData = {
      metadata: {
        suiteName: 'Arogya AI Android Appium E2E Automation',
        buildNumber: metrics.buildNumber || 'BUILD-2026-001',
        executionDate: new Date().toISOString(),
        environment: {
          deviceName: metrics.deviceName || 'Android_Emulator',
          androidVersion: metrics.androidVersion || '14.0',
          appPackage: metrics.appPackage || 'com.arogya.ai.arogya_ai'
        }
      },
      summary: {
        total: metrics.total || testCases.length,
        executed: metrics.executed || testCases.length,
        passed: metrics.passed || testCases.filter(t => t.status === 'PASSED').length,
        failed: metrics.failed || testCases.filter(t => t.status === 'FAILED').length,
        skipped: metrics.skipped || testCases.filter(t => t.status === 'SKIPPED').length,
        passPercentage: parseFloat(metrics.passRate || '0'),
        durationSec: parseFloat(metrics.durationSec || '0')
      },
      testCases: testCases
    };

    fs.writeFileSync(filePath, JSON.stringify(reportData, null, 2));
    logger.info(`JSON report generated successfully: ${filePath}`);
    return filePath;
  }
}

module.exports = JsonReportGenerator;
