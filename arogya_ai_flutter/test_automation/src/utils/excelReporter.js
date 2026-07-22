const ExcelJS = require('exceljs');
const path = require('path');
const fs = require('fs');
const logger = require('./logger');

class ExcelReporter {
  constructor() {
    this.reportDir = path.resolve(__dirname, '../../reports');
    if (!fs.existsSync(this.reportDir)) {
      fs.mkdirSync(this.reportDir, { recursive: true });
    }
    this.reportPath = path.join(this.reportDir, 'Flutter_E2E_Report.xlsx');
  }

  async generateReport(summaryData, testCasesData, failedTestsData, executionLogsData) {
    logger.info(`Generating Excel E2E Report at: ${this.reportPath}`);
    const workbook = new ExcelJS.Workbook();
    workbook.creator = 'Arogya AI QA Automation Architect';
    workbook.created = new Date();

    // -------------------------------------------------------------
    // Sheet 1 - Summary
    // -------------------------------------------------------------
    const summarySheet = workbook.addWorksheet('Summary', { properties: { tabColor: { argb: 'FF007ACC' } } });
    summarySheet.columns = [
      { header: 'Metric', key: 'metric', width: 25 },
      { header: 'Value', key: 'value', width: 35 }
    ];

    const passRate = summaryData.total > 0
      ? `${((summaryData.passed / summaryData.total) * 100).toFixed(2)}%`
      : '0%';

    summarySheet.addRows([
      { metric: 'Execution Date', value: summaryData.executionDate || new Date().toLocaleString() },
      { metric: 'Device Name', value: summaryData.deviceName || process.env.DEVICE_NAME || 'Android_Emulator' },
      { metric: 'Android Version', value: summaryData.androidVersion || process.env.PLATFORM_VERSION || '14.0' },
      { metric: 'Total Tests', value: summaryData.total || 0 },
      { metric: 'Passed', value: summaryData.passed || 0 },
      { metric: 'Failed', value: summaryData.failed || 0 },
      { metric: 'Skipped', value: summaryData.skipped || 0 },
      { metric: 'Pass Percentage', value: passRate },
      { metric: 'Duration (sec)', value: summaryData.durationSec || 0 }
    ]);

    // Style Summary Sheet Header
    summarySheet.getRow(1).font = { bold: true, color: { argb: 'FFFFFF' }, size: 12 };
    summarySheet.getRow(1).fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FF1F4E79' } };

    // -------------------------------------------------------------
    // Sheet 2 - Test Cases
    // -------------------------------------------------------------
    const testCasesSheet = workbook.addWorksheet('Test Cases', { properties: { tabColor: { argb: 'FF28A745' } } });
    testCasesSheet.columns = [
      { header: 'Test ID', key: 'id', width: 15 },
      { header: 'Module', key: 'module', width: 20 },
      { header: 'Scenario', key: 'scenario', width: 45 },
      { header: 'Status', key: 'status', width: 12 },
      { header: 'Device', key: 'device', width: 20 },
      { header: 'Duration (ms)', key: 'duration', width: 15 }
    ];

    (testCasesData || []).forEach((tc, idx) => {
      const row = testCasesSheet.addRow({
        id: tc.id || `TC_${idx + 1}`,
        module: tc.module || 'General',
        scenario: tc.scenario || tc.title,
        status: tc.status || (tc.passed ? 'PASSED' : 'FAILED'),
        device: tc.device || process.env.DEVICE_NAME || 'Android_Emulator',
        duration: tc.duration || 0
      });

      const statusCell = row.getCell('status');
      if (statusCell.value === 'PASSED') {
        statusCell.font = { bold: true, color: { argb: 'FF279B37' } };
      } else if (statusCell.value === 'FAILED') {
        statusCell.font = { bold: true, color: { argb: 'FFDC3545' } };
      }
    });

    testCasesSheet.getRow(1).font = { bold: true, color: { argb: 'FFFFFF' }, size: 12 };
    testCasesSheet.getRow(1).fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FF2E75B6' } };

    // -------------------------------------------------------------
    // Sheet 3 - Failed Tests
    // -------------------------------------------------------------
    const failedSheet = workbook.addWorksheet('Failed Tests', { properties: { tabColor: { argb: 'FFDC3545' } } });
    failedSheet.columns = [
      { header: 'Test Name', key: 'testName', width: 35 },
      { header: 'Failure Reason', key: 'reason', width: 50 },
      { header: 'Screenshot Path', key: 'screenshot', width: 45 },
      { header: 'Device', key: 'device', width: 20 },
      { header: 'Android Version', key: 'androidVersion', width: 18 }
    ];

    (failedTestsData || []).forEach(ft => {
      failedSheet.addRow({
        testName: ft.testName || ft.title,
        reason: ft.reason || ft.errorMessage,
        screenshot: ft.screenshot || ft.screenshotPath || 'N/A',
        device: ft.device || process.env.DEVICE_NAME || 'Android_Emulator',
        androidVersion: ft.androidVersion || process.env.PLATFORM_VERSION || '14.0'
      });
    });

    failedSheet.getRow(1).font = { bold: true, color: { argb: 'FFFFFF' }, size: 12 };
    failedSheet.getRow(1).fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFC00000' } };

    // -------------------------------------------------------------
    // Sheet 4 - Execution Logs
    // -------------------------------------------------------------
    const logsSheet = workbook.addWorksheet('Execution Logs', { properties: { tabColor: { argb: 'FF6C757D' } } });
    logsSheet.columns = [
      { header: 'Timestamp', key: 'timestamp', width: 22 },
      { header: 'Test Name', key: 'testName', width: 30 },
      { header: 'Step', key: 'step', width: 40 },
      { header: 'Result', key: 'result', width: 12 },
      { header: 'Remarks', key: 'remarks', width: 35 }
    ];

    (executionLogsData || []).forEach(log => {
      logsSheet.addRow({
        timestamp: log.timestamp || new Date().toISOString(),
        testName: log.testName || 'General',
        step: log.step || log.message,
        result: log.result || 'INFO',
        remarks: log.remarks || ''
      });
    });

    logsSheet.getRow(1).font = { bold: true, color: { argb: 'FFFFFF' }, size: 12 };
    logsSheet.getRow(1).fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FF595959' } };

    await workbook.xlsx.writeFile(this.reportPath);
    logger.info(`Excel report saved successfully to ${this.reportPath}`);
    return this.reportPath;
  }

  static async generateSampleReport() {
    const reporter = new ExcelReporter();
    await reporter.generateReport(
      {
        executionDate: new Date().toLocaleString(),
        deviceName: 'Pixel_7_Pro_API_34',
        androidVersion: '14.0',
        total: 12,
        passed: 10,
        failed: 1,
        skipped: 1,
        durationSec: 45.2
      },
      [
        { id: 'TC_01', module: 'Authentication', scenario: 'Valid Login', status: 'PASSED', duration: 3200 },
        { id: 'TC_02', module: 'Authentication', scenario: 'Empty Email Validation', status: 'PASSED', duration: 1800 },
        { id: 'TC_03', module: 'Form Validation', scenario: 'Password Complexity', status: 'FAILED', duration: 4100 },
        { id: 'TC_04', module: 'UI Components', scenario: 'Widget Render Check', status: 'PASSED', duration: 2500 },
        { id: 'TC_05', module: 'Gestures', scenario: 'Scroll & Swipe Action', status: 'PASSED', duration: 3100 },
        { id: 'TC_06', module: 'Navigation', scenario: 'Drawer Menu Navigation', status: 'PASSED', duration: 2900 },
        { id: 'TC_07', module: 'AI Testing', scenario: 'Dynamic Screen Discovery', status: 'PASSED', duration: 5200 }
      ],
      [
        {
          testName: 'Form Validation - Password Complexity',
          reason: 'Expected validation message "Password must contain a special character" not found',
          screenshot: 'reports/failures/Form_Validation_1700000/screenshot.png',
          device: 'Pixel_7_Pro_API_34',
          androidVersion: '14.0'
        }
      ],
      [
        { timestamp: new Date().toISOString(), testName: 'TC_01', step: 'Launch App', result: 'PASSED', remarks: 'APK installed & launched' },
        { timestamp: new Date().toISOString(), testName: 'TC_01', step: 'Enter Email', result: 'PASSED', remarks: 'Typed testuser@arogya.ai' },
        { timestamp: new Date().toISOString(), testName: 'TC_01', step: 'Click Login', result: 'PASSED', remarks: 'Navigated to Home Dashboard' }
      ]
    );
  }
}

module.exports = ExcelReporter;
