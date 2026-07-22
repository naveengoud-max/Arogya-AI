let ExcelJS;
try {
  ExcelJS = require('exceljs');
} catch (e) {
  ExcelJS = require('../../test_automation/node_modules/exceljs');
}
const path = require('path');
const fs = require('fs');
const logger = require('../utils/logger');

class ExcelReportGenerator {
  constructor(outputDir = path.resolve(__dirname, '../reports/Excel')) {
    this.outputDir = outputDir;
    if (!fs.existsSync(this.outputDir)) {
      fs.mkdirSync(this.outputDir, { recursive: true });
    }
  }

  async generateMasterWorkbook(allTestCases, metrics) {
    logger.info(`Generating Master Excel Workbook with 7 Sheets in: ${this.outputDir}`);
    const workbook = new ExcelJS.Workbook();
    workbook.creator = 'Arogya AI Enterprise QA Architect';
    workbook.created = new Date();

    const passedCases = allTestCases.filter(t => t.status === 'PASSED');
    const failedCases = allTestCases.filter(t => t.status === 'FAILED');
    const skippedCases = allTestCases.filter(t => t.status === 'SKIPPED');

    // Sheet 1: Executed Test Cases
    const sheet1 = workbook.addWorksheet('Executed Test Cases', { properties: { tabColor: { argb: 'FF007ACC' } } });
    sheet1.columns = [
      { header: 'Test ID', key: 'id', width: 18 },
      { header: 'Module', key: 'module', width: 24 },
      { header: 'Test Name', key: 'name', width: 45 },
      { header: 'Priority', key: 'priority', width: 14 },
      { header: 'Status', key: 'status', width: 14 },
      { header: 'Execution Time (ms)', key: 'duration', width: 20 }
    ];
    allTestCases.forEach(tc => {
      const row = sheet1.addRow(tc);
      const statusCell = row.getCell('status');
      if (tc.status === 'PASSED') statusCell.font = { bold: true, color: { argb: 'FF279B37' } };
      else if (tc.status === 'FAILED') statusCell.font = { bold: true, color: { argb: 'FFDC3545' } };
      else statusCell.font = { bold: true, color: { argb: 'FFFFC107' } };
    });
    sheet1.getRow(1).font = { bold: true, color: { argb: 'FFFFFF' }, size: 12 };
    sheet1.getRow(1).fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FF1F4E79' } };

    // Sheet 2: Passed Tests
    const sheet2 = workbook.addWorksheet('Passed Tests', { properties: { tabColor: { argb: 'FF28A745' } } });
    sheet2.columns = sheet1.columns;
    passedCases.forEach(tc => sheet2.addRow(tc));
    sheet2.getRow(1).font = { bold: true, color: { argb: 'FFFFFF' }, size: 12 };
    sheet2.getRow(1).fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FF2E75B6' } };

    // Sheet 3: Failed Tests
    const sheet3 = workbook.addWorksheet('Failed Tests', { properties: { tabColor: { argb: 'FFDC3545' } } });
    sheet3.columns = [
      { header: 'Test ID', key: 'id', width: 18 },
      { header: 'Module', key: 'module', width: 24 },
      { header: 'Test Name', key: 'name', width: 35 },
      { header: 'Failure Reason', key: 'reason', width: 45 },
      { header: 'Screenshot', key: 'screenshot', width: 35 }
    ];
    failedCases.forEach(tc => sheet3.addRow({
      id: tc.id,
      module: tc.module,
      name: tc.name,
      reason: tc.reason || 'Assertion Failed',
      screenshot: tc.screenshot || 'N/A'
    }));
    sheet3.getRow(1).font = { bold: true, color: { argb: 'FFFFFF' }, size: 12 };
    sheet3.getRow(1).fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFC00000' } };

    // Sheet 4: Skipped Tests
    const sheet4 = workbook.addWorksheet('Skipped Tests', { properties: { tabColor: { argb: 'FFFFC107' } } });
    sheet4.columns = sheet1.columns;
    skippedCases.forEach(tc => sheet4.addRow(tc));
    sheet4.getRow(1).font = { bold: true, color: { argb: 'FFFFFF' }, size: 12 };
    sheet4.getRow(1).fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFD68910' } };

    // Sheet 5: Execution Metrics
    const sheet5 = workbook.addWorksheet('Execution Metrics', { properties: { tabColor: { argb: 'FF6C757D' } } });
    sheet5.columns = [
      { header: 'Metric Name', key: 'metric', width: 30 },
      { header: 'Metric Value', key: 'value', width: 35 }
    ];
    sheet5.addRows([
      { metric: 'Build Number', value: metrics.buildNumber || 'BUILD-2026-001' },
      { metric: 'Execution Timestamp', value: new Date().toLocaleString() },
      { metric: 'Target Device', value: metrics.deviceName || 'Android_Emulator' },
      { metric: 'Android OS Version', value: metrics.androidVersion || '14.0' },
      { metric: 'Total Test Cases', value: metrics.total },
      { metric: 'Executed Count', value: metrics.executed },
      { metric: 'Passed Count', value: metrics.passed },
      { metric: 'Failed Count', value: metrics.failed },
      { metric: 'Skipped Count', value: metrics.skipped },
      { metric: 'Pass Rate (%)', value: `${metrics.passRate}%` },
      { metric: 'Total Duration (sec)', value: metrics.durationSec }
    ]);
    sheet5.getRow(1).font = { bold: true, color: { argb: 'FFFFFF' }, size: 12 };
    sheet5.getRow(1).fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FF595959' } };

    // Sheet 6: Defect Summary
    const sheet6 = workbook.addWorksheet('Defect Summary', { properties: { tabColor: { argb: 'FF900C3F' } } });
    sheet6.columns = [
      { header: 'Defect ID', key: 'defId', width: 15 },
      { header: 'Associated Test', key: 'testId', width: 18 },
      { header: 'Severity', key: 'sev', width: 15 },
      { header: 'Root Cause Description', key: 'desc', width: 55 }
    ];
    failedCases.forEach((tc, idx) => sheet6.addRow({
      defId: `BUG_${idx + 101}`,
      testId: tc.id,
      sev: tc.priority === 'P1' ? 'CRITICAL' : 'HIGH',
      desc: tc.reason || 'Unexpected Assertion Mismatch'
    }));
    sheet6.getRow(1).font = { bold: true, color: { argb: 'FFFFFF' }, size: 12 };
    sheet6.getRow(1).fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FF7D3C98' } };

    // Sheet 7: Pass Rate Summary
    const sheet7 = workbook.addWorksheet('Pass Rate Summary', { properties: { tabColor: { argb: 'FF17A2B8' } } });
    sheet7.columns = [
      { header: 'Module Name', key: 'mod', width: 28 },
      { header: 'Total Tests', key: 'tot', width: 15 },
      { header: 'Passed', key: 'pass', width: 15 },
      { header: 'Failed', key: 'fail', width: 15 },
      { header: 'Module Pass Rate', key: 'rate', width: 20 }
    ];
    const moduleMap = {};
    allTestCases.forEach(tc => {
      if (!moduleMap[tc.module]) moduleMap[tc.module] = { tot: 0, pass: 0, fail: 0 };
      moduleMap[tc.module].tot++;
      if (tc.status === 'PASSED') moduleMap[tc.module].pass++;
      else if (tc.status === 'FAILED') moduleMap[tc.module].fail++;
    });
    Object.keys(moduleMap).forEach(mod => {
      const m = moduleMap[mod];
      const rate = m.tot > 0 ? `${((m.pass / m.tot) * 100).toFixed(1)}%` : '0%';
      sheet7.addRow({ mod, tot: m.tot, pass: m.pass, fail: m.fail, rate });
    });
    sheet7.getRow(1).font = { bold: true, color: { argb: 'FFFFFF' }, size: 12 };
    sheet7.getRow(1).fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FF117A65' } };

    const masterPath = path.join(this.outputDir, 'Automation_Test_Report.xlsx');
    await workbook.xlsx.writeFile(masterPath);

    // Save individual helper workbooks
    await this.saveFilteredWorkbook('Passed_Test_Cases.xlsx', 'Passed Tests', passedCases, sheet1.columns);
    await this.saveFilteredWorkbook('Failed_Test_Cases.xlsx', 'Failed Tests', failedCases, sheet3.columns);
    await this.saveFilteredWorkbook('Execution_Summary.xlsx', 'Summary', metrics, sheet5.columns);

    logger.info(`Excel report files saved successfully under ${this.outputDir}`);
    return masterPath;
  }

  async saveFilteredWorkbook(filename, sheetName, data, columns) {
    const wb = new ExcelJS.Workbook();
    const ws = wb.addWorksheet(sheetName);
    ws.columns = columns;
    if (Array.isArray(data)) {
      data.forEach(item => ws.addRow(item));
    } else {
      ws.addRow(data);
    }
    await wb.xlsx.writeFile(path.join(this.outputDir, filename));
  }

  static async generateSampleWorkbook() {
    const reporter = new ExcelReportGenerator();
    const sampleTests = [
      { id: 'TC_AUTH_001', module: 'Authentication', name: 'Valid Login', priority: 'P1', status: 'PASSED', duration: 1200 },
      { id: 'TC_AUTH_002', module: 'Authentication', name: 'Invalid OTP Verification', priority: 'P1', status: 'FAILED', duration: 1500, reason: 'OTP validation mismatch', screenshot: 'screenshots/TC_AUTH_002.png' },
      { id: 'TC_REG_001', module: 'Registration', name: 'New Patient Signup', priority: 'P1', status: 'PASSED', duration: 2100 },
      { id: 'TC_NOTIF_004', module: 'Notifications', name: 'Push Reminder Alert', priority: 'P3', status: 'SKIPPED', duration: 0 }
    ];
    const sampleMetrics = {
      buildNumber: 'BUILD-400',
      deviceName: 'Pixel_7_Pro_API_34',
      androidVersion: '14.0',
      total: 4,
      executed: 3,
      passed: 2,
      failed: 1,
      skipped: 1,
      passRate: '66.7',
      durationSec: '14.2'
    };
    await reporter.generateMasterWorkbook(sampleTests, sampleMetrics);
  }
}

module.exports = ExcelReportGenerator;
