const { By, until } = require('selenium-webdriver');
const config = require('../../config/selenium.config');
const logger = require('../utils/logger');

class BasePage {
  constructor(driver) {
    this.driver = driver;
    this.timeout = config.explicitWaitMs;
  }

  async navigateTo(path = '') {
    const url = `${config.baseUrl}${path}`;
    logger.info(`Navigating browser to: ${url}`);
    await this.driver.get(url);
  }

  async findElement(locator, timeout = this.timeout) {
    return await this.driver.wait(until.elementLocated(locator), timeout);
  }

  async click(locator, timeout = this.timeout) {
    const element = await this.findElement(locator, timeout);
    await this.driver.wait(until.elementIsVisible(element), timeout);
    await element.click();
  }

  async type(locator, text, timeout = this.timeout) {
    const element = await this.findElement(locator, timeout);
    await this.driver.wait(until.elementIsVisible(element), timeout);
    await element.clear();
    await element.sendKeys(text);
  }

  async getText(locator, timeout = this.timeout) {
    const element = await this.findElement(locator, timeout);
    await this.driver.wait(until.elementIsVisible(element), timeout);
    return await element.getText();
  }

  async isDisplayed(locator, timeout = 3000) {
    try {
      const element = await this.findElement(locator, timeout);
      return await element.isDisplayed();
    } catch (e) {
      return false;
    }
  }

  async pause(ms) {
    await this.driver.sleep(ms);
  }
}

module.exports = BasePage;
