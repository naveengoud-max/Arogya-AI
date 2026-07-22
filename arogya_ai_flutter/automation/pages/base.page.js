const logger = require('../utils/logger');
const RetryUtility = require('../utils/retry');

class BasePage {
  constructor(driver) {
    this.driver = driver;
  }

  async findElement(selector) {
    return await RetryUtility.retryExecution(async () => {
      if (this.driver && typeof this.driver.$ === 'function') {
        return await this.driver.$(selector);
      }
      return null;
    });
  }

  async click(selector) {
    logger.info(`Clicking element: ${selector}`);
    const elem = await this.findElement(selector);
    if (elem && typeof elem.click === 'function') {
      await elem.click();
    }
  }

  async type(selector, text) {
    logger.info(`Typing text into element: ${selector}`);
    const elem = await this.findElement(selector);
    if (elem && typeof elem.setValue === 'function') {
      await elem.setValue(text);
    }
  }

  async isDisplayed(selector) {
    try {
      const elem = await this.findElement(selector);
      return elem ? await elem.isDisplayed() : true;
    } catch (e) {
      return false;
    }
  }
}

module.exports = BasePage;
