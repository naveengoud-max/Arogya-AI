const fs = require('fs');
const path = require('path');
const logger = require('./logger');

class FailureHandler {
  static async handleFailure(driver, testTitle, error) {
    logger.error(`❌ Test Failure Detected: "${testTitle}" | Error: ${error.message}`);
    const timestamp = Date.now();
    const sanitizedTitle = testTitle.replace(/[^a-zA-Z0-9_-]/g, '_');
    const failuresDir = path.resolve(__dirname, '../../reports/failures');

    if (!fs.existsSync(failuresDir)) {
      fs.mkdirSync(failuresDir, { recursive: true });
    }

    const screenshotPath = path.join(failuresDir, `${sanitizedTitle}_${timestamp}.png`);

    try {
      if (driver) {
        const image = await driver.takeScreenshot();
        fs.writeFileSync(screenshotPath, image, 'base64');
        logger.info(`📸 Failure screenshot saved at: ${screenshotPath}`);
      }
    } catch (screenshotError) {
      logger.warn(`Could not capture screenshot: ${screenshotError.message}`);
    }

    return {
      testTitle,
      errorMessage: error.message,
      stackTrace: error.stack,
      screenshotPath
    };
  }
}

module.exports = FailureHandler;
