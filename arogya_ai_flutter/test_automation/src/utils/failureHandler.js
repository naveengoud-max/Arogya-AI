const fs = require('fs');
const path = require('path');
const logger = require('./logger');

class FailureHandler {
  static async handleFailure(driver, testTitle, error) {
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    const sanitizedTitle = testTitle.replace(/[^a-zA-Z0-9_-]/g, '_');
    const failureFolder = path.resolve(__dirname, '../../reports/failures', `${sanitizedTitle}_${timestamp}`);

    if (!fs.existsSync(failureFolder)) {
      fs.mkdirSync(failureFolder, { recursive: true });
    }

    logger.error(`Handling test failure for: "${testTitle}"`);

    let screenshotPath = null;
    let pageSourcePath = null;
    let logcatPath = null;
    let stackTracePath = null;

    if (driver) {
      try {
        // 1. Capture Screenshot
        screenshotPath = path.join(failureFolder, 'screenshot.png');
        const screenshotBase64 = await driver.takeScreenshot();
        fs.writeFileSync(screenshotPath, screenshotBase64, 'base64');
        logger.info(`Saved failure screenshot: ${screenshotPath}`);
      } catch (err) {
        logger.error(`Failed to take screenshot: ${err.message}`);
      }

      try {
        // 2. Capture Page Source / Widget Tree
        pageSourcePath = path.join(failureFolder, 'widget_tree_or_source.xml');
        const pageSource = await driver.getPageSource();
        fs.writeFileSync(pageSourcePath, pageSource, 'utf8');
        logger.info(`Saved widget tree/page source: ${pageSourcePath}`);
      } catch (err) {
        logger.error(`Failed to capture page source: ${err.message}`);
      }

      try {
        // 3. Capture Device Logs (logcat)
        logcatPath = path.join(failureFolder, 'device_logcat.log');
        const logTypes = await driver.getLogTypes();
        if (logTypes.includes('logcat')) {
          const logs = await driver.getLogs('logcat');
          const formattedLogs = logs.map(l => `[${l.timestamp}] [${l.level}] ${l.message}`).join('\n');
          fs.writeFileSync(logcatPath, formattedLogs, 'utf8');
          logger.info(`Saved device logcat logs: ${logcatPath}`);
        }
      } catch (err) {
        logger.error(`Failed to capture device logcat: ${err.message}`);
      }
    }

    // 4. Capture Error Stack Trace & Context
    try {
      stackTracePath = path.join(failureFolder, 'failure_details.json');
      const details = {
        testTitle,
        timestamp,
        errorMessage: error ? error.message : 'Unknown error',
        stackTrace: error ? error.stack : 'No stack trace available',
        screenshotPath,
        pageSourcePath,
        logcatPath
      };
      fs.writeFileSync(stackTracePath, JSON.stringify(details, null, 2), 'utf8');
      logger.info(`Saved failure details JSON: ${stackTracePath}`);
    } catch (err) {
      logger.error(`Failed to write failure details: ${err.message}`);
    }

    return {
      failureFolder,
      screenshotPath,
      pageSourcePath,
      logcatPath,
      stackTracePath
    };
  }
}

module.exports = FailureHandler;
