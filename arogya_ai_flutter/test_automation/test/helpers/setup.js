const DriverFactory = require('../../src/driver/driverFactory');
const FailureHandler = require('../../src/utils/failureHandler');
const ExcelReporter = require('../../src/utils/excelReporter');
const logger = require('../../src/utils/logger');

const testResultsSummary = [];
const failedTests = [];
const executionLogs = [];
let suiteStartTime = null;

before(async function () {
  this.timeout(180000);
  suiteStartTime = Date.now();
  logger.info('=============== Starting Arogya AI E2E Test Automation Suite ===============');
  try {
    global.driver = await DriverFactory.createDriver();
  } catch (err) {
    logger.error(`Driver setup failed in global before hook: ${err.message}`);
    throw err;
  }
});

beforeEach(function () {
  logger.info(`>>> Launching Scenario: "${this.currentTest.fullTitle()}"`);
  executionLogs.push({
    timestamp: new Date().toISOString(),
    testName: this.currentTest.fullTitle(),
    step: 'Start Scenario',
    result: 'STARTED',
    remarks: 'Test execution initiated'
  });
});

afterEach(async function () {
  const test = this.currentTest;
  const duration = test.duration || 0;
  const isPassed = test.state === 'passed';

  logger.info(`<<< Scenario Outcome: "${test.title}" - Status: ${isPassed ? 'PASSED' : 'FAILED'} (${duration}ms)`);

  testResultsSummary.push({
    id: `TC_${testResultsSummary.length + 1}`,
    module: test.parent ? test.parent.title : 'General',
    scenario: test.title,
    status: isPassed ? 'PASSED' : 'FAILED',
    passed: isPassed,
    device: process.env.DEVICE_NAME || 'Android_Emulator',
    duration
  });

  executionLogs.push({
    timestamp: new Date().toISOString(),
    testName: test.title,
    step: 'End Scenario',
    result: isPassed ? 'PASSED' : 'FAILED',
    remarks: isPassed ? 'Execution clean' : (test.err ? test.err.message : 'Error')
  });

  if (!isPassed && test.err) {
    const failureInfo = await FailureHandler.handleFailure(global.driver, test.title, test.err);
    failedTests.push({
      testName: test.title,
      reason: test.err.message,
      screenshot: failureInfo.screenshotPath || 'N/A',
      device: process.env.DEVICE_NAME || 'Android_Emulator',
      androidVersion: process.env.PLATFORM_VERSION || '14.0'
    });
  }
});

after(async function () {
  this.timeout(60000);
  const suiteEndTime = Date.now();
  const totalDurationSec = ((suiteEndTime - suiteStartTime) / 1000).toFixed(1);

  logger.info('=============== Tear-down and Generating Reports ===============');

  try {
    await DriverFactory.quitDriver();
  } catch (err) {
    logger.warn(`Driver teardown warning: ${err.message}`);
  }

  try {
    const passedCount = testResultsSummary.filter(t => t.passed).length;
    const failedCount = testResultsSummary.filter(t => !t.passed).length;
    const totalCount = testResultsSummary.length;

    const reporter = new ExcelReporter();
    await reporter.generateReport(
      {
        executionDate: new Date().toLocaleString(),
        deviceName: process.env.DEVICE_NAME || 'Android_Emulator',
        androidVersion: process.env.PLATFORM_VERSION || '14.0',
        total: totalCount,
        passed: passedCount,
        failed: failedCount,
        skipped: 0,
        durationSec: totalDurationSec
      },
      testResultsSummary,
      failedTests,
      executionLogs
    );
  } catch (err) {
    logger.error(`Failed to generate Excel report in teardown: ${err.message}`);
  }

  logger.info('=============== Arogya AI Test Suite Execution Finished ===============');
});
