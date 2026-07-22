const logger = require('../utils/logger');

class FlutterFinders {
  static byValueKey(key) {
    const driverType = (process.env.DRIVER_TYPE || 'UiAutomator2').toLowerCase();
    logger.debug(`Locating element by ValueKey: "${key}" (Driver: ${driverType})`);
    if (driverType === 'flutter') {
      return { finder: 'byValueKey', key };
    }
    // UiAutomator2 fallbacks
    return `//*[@resource-id="${key}" or @content-desc="${key}" or @text="${key}"]`;
  }

  static byText(text) {
    const driverType = (process.env.DRIVER_TYPE || 'UiAutomator2').toLowerCase();
    logger.debug(`Locating element by Text: "${text}" (Driver: ${driverType})`);
    if (driverType === 'flutter') {
      return { finder: 'byText', text };
    }
    return `//*[@text="${text}" or contains(@text, "${text}")]`;
  }

  static bySemanticsLabel(label) {
    const driverType = (process.env.DRIVER_TYPE || 'UiAutomator2').toLowerCase();
    logger.debug(`Locating element by SemanticsLabel: "${label}" (Driver: ${driverType})`);
    if (driverType === 'flutter') {
      return { finder: 'bySemanticsLabel', label };
    }
    return `~${label}`;
  }

  static byType(type) {
    const driverType = (process.env.DRIVER_TYPE || 'UiAutomator2').toLowerCase();
    logger.debug(`Locating element by Type: "${type}" (Driver: ${driverType})`);
    if (driverType === 'flutter') {
      return { finder: 'byType', type };
    }
    return `//*[contains(@class, "${type}")]`;
  }

  static byTooltip(message) {
    const driverType = (process.env.DRIVER_TYPE || 'UiAutomator2').toLowerCase();
    logger.debug(`Locating element by Tooltip: "${message}" (Driver: ${driverType})`);
    if (driverType === 'flutter') {
      return { finder: 'byTooltip', message };
    }
    return `//*[@content-desc="${message}" or @text="${message}"]`;
  }

  static async findElement(driver, locator) {
    if (typeof locator === 'string') {
      return await driver.$(locator);
    }
    if (typeof locator === 'object' && locator.finder) {
      if (locator.finder === 'byValueKey') {
        return await driver.elementByValueKey(locator.key);
      }
      if (locator.finder === 'byText') {
        return await driver.elementByText(locator.text);
      }
      if (locator.finder === 'bySemanticsLabel') {
        return await driver.elementBySemanticsLabel(locator.label);
      }
    }
    return await driver.$(String(locator));
  }
}

module.exports = FlutterFinders;
