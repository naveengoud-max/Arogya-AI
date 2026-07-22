const fs = require('fs');
const path = require('path');
const logger = require('./logger');

class ScreenshotUtility {
  static async captureScreenshot(driver, testCaseId, failureReason = '') {
    const timestamp = Date.now();
    const sanitizedId = testCaseId.replace(/[^a-zA-Z0-9_-]/g, '_');
    const screenshotDir = path.resolve(__dirname, '../screenshots');

    if (!fs.existsSync(screenshotDir)) {
      fs.mkdirSync(screenshotDir, { recursive: true });
    }

    const filename = `${sanitizedId}_${timestamp}.png`;
    const filepath = path.join(screenshotDir, filename);

    try {
      if (driver && typeof driver.saveScreenshot === 'function') {
        await driver.saveScreenshot(filepath);
        logger.info(`📸 Screenshot captured: ${filepath}`);
        return { filename, filepath, relativePath: `screenshots/${filename}` };
      }
    } catch (err) {
      logger.warn(`Could not save screenshot for ${testCaseId}: ${err.message}`);
    }

    // Mock screenshot fallback for report rendering in dry-run
    fs.writeFileSync(filepath, 'MOCK_SCREENSHOT_DATA_BINARY');
    return { filename, filepath, relativePath: `screenshots/${filename}` };
  }
}

module.exports = ScreenshotUtility;
