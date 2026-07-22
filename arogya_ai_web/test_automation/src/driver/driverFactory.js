const { Builder } = require('selenium-webdriver');
const chrome = require('selenium-webdriver/chrome');
const config = require('../../config/selenium.config');
const logger = require('../utils/logger');

class DriverFactory {
  static async createDriver() {
    logger.info(`Initializing Selenium WebDriver instance for browser: ${config.browser}`);

    const options = new chrome.Options();
    config.chromeOptions.forEach(opt => options.addArguments(opt));

    if (config.headless) {
      options.addArguments('--headless=new');
    }

    const driver = await new Builder()
      .forBrowser(config.browser)
      .setChromeOptions(options)
      .build();

    await driver.manage().setTimeouts({
      implicit: config.implicitWaitMs,
      pageLoad: 30000,
      script: 30000
    });

    await driver.manage().window().maximize();
    logger.info('Selenium WebDriver initialized successfully.');
    return driver;
  }

  static async quitDriver(driver) {
    if (driver) {
      logger.info('Tearing down Selenium WebDriver session...');
      await driver.quit();
    }
  }
}

module.exports = DriverFactory;
