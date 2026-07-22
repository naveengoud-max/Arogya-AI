let ExcelJS;
try {
  ExcelJS = require('exceljs');
} catch (e) {
  ExcelJS = require('C:/Users/knave/OneDrive/文档/Arogya AI/arogya_ai_flutter/test_automation/node_modules/exceljs');
}
const path = require('path');
const fs = require('fs');
const logger = require('./logger');

class ExcelReporter {
  constructor() {
    this.reportDir = path.resolve(__dirname, '../../reports');
    if (!fs.existsSync(this.reportDir)) {
      fs.mkdirSync(this.reportDir, { recursive: true });
    }
    this.reportPath = path.join(this.reportDir, 'Web_E2E_Report.xlsx');
  }

  async generateReport(summaryData, testCasesData, failedTestsData, executionLogsData) {
    logger.info(`Generating Excel Web E2E Report at: ${this.reportPath}`);
    const workbook = new ExcelJS.Workbook();
    workbook.creator = 'Arogya AI QA Web Architecture Team';
    workbook.created = new Date();

    // -------------------------------------------------------------
    // Sheet 1 - Executive Summary
    // -------------------------------------------------------------
    const summarySheet = workbook.addWorksheet('Summary', { properties: { tabColor: { argb: 'FF007ACC' } } });
    summarySheet.columns = [
      { header: 'Metric', key: 'metric', width: 28 },
      { header: 'Value', key: 'value', width: 35 }
    ];

    const passRate = summaryData.total > 0
      ? `${((summaryData.passed / summaryData.total) * 100).toFixed(2)}%`
      : '0%';

    summarySheet.addRows([
      { metric: 'Execution Date', value: summaryData.executionDate || new Date().toLocaleString() },
      { metric: 'Browser Engine', value: summaryData.browser || 'Chrome' },
      { metric: 'Target Application URL', value: summaryData.baseUrl || 'http://localhost:5000' },
      { metric: 'Total Scenarios Executed', value: summaryData.total || 0 },
      { metric: 'Passed Scenarios', value: summaryData.passed || 0 },
      { metric: 'Failed Scenarios', value: summaryData.failed || 0 },
      { metric: 'Skipped Scenarios', value: summaryData.skipped || 0 },
      { metric: 'Overall Pass Rate', value: passRate },
      { metric: 'Total Suite Duration (sec)', value: summaryData.durationSec || 0 }
    ]);

    summarySheet.getRow(1).font = { bold: true, color: { argb: 'FFFFFF' }, size: 12 };
    summarySheet.getRow(1).fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FF1F4E79' } };

    // -------------------------------------------------------------
    // Sheet 2 - Test Cases Breakdown
    // -------------------------------------------------------------
    const testCasesSheet = workbook.addWorksheet('Test Cases Breakdown', { properties: { tabColor: { argb: 'FF28A745' } } });
    testCasesSheet.columns = [
      { header: 'Test ID', key: 'id', width: 15 },
      { header: 'Module', key: 'module', width: 22 },
      { header: 'Test Scenario', key: 'scenario', width: 45 },
      { header: 'Status', key: 'status', width: 12 },
      { header: 'Browser', key: 'browser', width: 15 },
      { header: 'Duration (ms)', key: 'duration', width: 15 }
    ];

    (testCasesData || []).forEach((tc, idx) => {
      const row = testCasesSheet.addRow({
        id: tc.id || `WEB_TC_${idx + 1}`,
        module: tc.module || 'Web E2E',
        scenario: tc.scenario || tc.title,
        status: tc.status || (tc.passed ? 'PASSED' : 'FAILED'),
        browser: tc.browser || 'Chrome',
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
    // Sheet 3 - Failed Tests Root Cause
    // -------------------------------------------------------------
    const failedSheet = workbook.addWorksheet('Failure Analysis', { properties: { tabColor: { argb: 'FFDC3545' } } });
    failedSheet.columns = [
      { header: 'Scenario Name', key: 'testName', width: 35 },
      { header: 'Failure Exception / Reason', key: 'reason', width: 55 },
      { header: 'Screenshot File Path', key: 'screenshot', width: 45 }
    ];

    (failedTestsData || []).forEach(ft => {
      failedSheet.addRow({
        testName: ft.testName || ft.title,
        reason: ft.reason || ft.errorMessage,
        screenshot: ft.screenshot || ft.screenshotPath || 'N/A'
      });
    });

    failedSheet.getRow(1).font = { bold: true, color: { argb: 'FFFFFF' }, size: 12 };
    failedSheet.getRow(1).fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFC00000' } };

    // -------------------------------------------------------------
    // Sheet 4 - Audit Logs
    // -------------------------------------------------------------
    const logsSheet = workbook.addWorksheet('Execution Audit Logs', { properties: { tabColor: { argb: 'FF6C757D' } } });
    logsSheet.columns = [
      { header: 'Timestamp', key: 'timestamp', width: 24 },
      { header: 'Test Scenario', key: 'testName', width: 32 },
      { header: 'Step / Event', key: 'step', width: 40 },
      { header: 'Result State', key: 'result', width: 14 },
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
    logger.info(`Excel Web E2E report generated successfully at: ${this.reportPath}`);
    return this.reportPath;
  }

  static async generateSampleReport() {
    const reporter = new ExcelReporter();
    await reporter.generateReport(
      {
        executionDate: new Date().toLocaleString(),
        browser: 'Chrome Headless',
        baseUrl: 'http://localhost:5000',
        total: 10,
        passed: 9,
        failed: 1,
        skipped: 0,
        durationSec: 28.4
      },
      [
        { id: 'WEB_TC_01', module: 'Authentication', scenario: 'Phone OTP Login Flow', status: 'PASSED', duration: 2800 },
        { id: 'WEB_TC_02', module: 'Language Selection', scenario: 'Dynamic Language Switcher', status: 'PASSED', duration: 1500 },
        { id: 'WEB_TC_03', module: 'Symptom Checker', scenario: 'AI Diagnostic Query Submission', status: 'PASSED', duration: 4200 },
        { id: 'WEB_TC_04', module: 'Appointments', scenario: 'Doctor Search & Booking Modal', status: 'PASSED', duration: 3100 },
        { id: 'WEB_TC_05', module: 'Emergency SOS', scenario: 'One-Click SOS Dispatch Trigger', status: 'PASSED', duration: 1900 },
        { id: 'WEB_TC_06', module: 'Hospitals Locator', scenario: 'Nearest Hospital Finder Query', status: 'FAILED', duration: 3800 }
      ],
      [
        {
          testName: 'Hospitals Locator - Nearest Hospital Finder Query',
          reason: 'TimeoutError: Waiting for element #hospital-results-container to be visible',
          screenshot: 'reports/failures/Hospitals_Locator_1700000/screenshot.png'
        }
      ],
      [
        { timestamp: new Date().toISOString(), testName: 'WEB_TC_01', step: 'Navigate to http://localhost:5000', result: 'PASSED', remarks: 'Page loaded in 450ms' },
        { timestamp: new Date().toISOString(), testName: 'WEB_TC_01', step: 'Enter Mobile Number', result: 'PASSED', remarks: 'Typed 9876543210' },
        { timestamp: new Date().toISOString(), testName: 'WEB_TC_01', step: 'Verify OTP', result: 'PASSED', remarks: 'Navigated to Home Dashboard' }
      ]
    );
  }
}

module.exports = ExcelReporter;
