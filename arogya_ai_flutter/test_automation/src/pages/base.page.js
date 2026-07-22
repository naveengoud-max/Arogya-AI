const FlutterFinders = require('../driver/flutterFinders');
const Gestures = require('../utils/gestures');
const logger = require('../utils/logger');

class BasePage {
  constructor(driver) {
    this.driver = driver;
  }

  async getElement(locator) {
    return await FlutterFinders.findElement(this.driver, locator);
  }

  async waitForDisplayed(locator, timeoutMs = 15000) {
    logger.debug(`Waiting for element to be displayed: ${JSON.stringify(locator)}`);
    const elem = await this.getElement(locator);
    await elem.waitForDisplayed({ timeout: timeoutMs });
    return elem;
  }

  async click(locator, timeoutMs = 15000) {
    logger.info(`Clicking element: ${JSON.stringify(locator)}`);
    const elem = await this.waitForDisplayed(locator, timeoutMs);
    await elem.click();
  }

  async type(locator, text, timeoutMs = 15000) {
    logger.info(`Typing "${text}" into element: ${JSON.stringify(locator)}`);
    const elem = await this.waitForDisplayed(locator, timeoutMs);
    await elem.setValue(text);
  }

  async clearAndType(locator, text, timeoutMs = 15000) {
    logger.info(`Clearing and typing "${text}" into element: ${JSON.stringify(locator)}`);
    const elem = await this.waitForDisplayed(locator, timeoutMs);
    await elem.clearValue();
    await elem.setValue(text);
  }

  async getText(locator, timeoutMs = 15000) {
    const elem = await this.waitForDisplayed(locator, timeoutMs);
    const text = await elem.getText();
    logger.debug(`Retrieved text "${text}" from element: ${JSON.stringify(locator)}`);
    return text;
  }

  async isDisplayed(locator, timeoutMs = 5000) {
    try {
      const elem = await this.getElement(locator);
      return await elem.isDisplayed();
    } catch (err) {
      return false;
    }
  }

  async isEnabled(locator, timeoutMs = 5000) {
    try {
      const elem = await this.getElement(locator);
      return await elem.isEnabled();
    } catch (err) {
      return false;
    }
  }

  async scroll(direction = 'down', distance = 0.5) {
    await Gestures.scroll(this.driver, direction, distance);
  }

  async swipe(startX, startY, endX, endY, durationMs = 500) {
    await Gestures.swipe(this.driver, startX, startY, endX, endY, durationMs);
  }

  async longPress(locator, durationMs = 1500) {
    const elem = await this.waitForDisplayed(locator);
    await Gestures.longPress(this.driver, elem, null, durationMs);
  }

  async takeScreenshot(fileName = 'screenshot.png') {
    return await this.driver.saveScreenshot(fileName);
  }
}

module.exports = BasePage;
