const logger = require('./logger');

class GestureUtility {
  static async scrollDown(driver, distance = 500) {
    logger.info(`Performing scroll down gesture by ${distance}px`);
    try {
      if (driver && typeof driver.performActions === 'function') {
        await driver.performActions([{
          type: 'pointer',
          id: 'finger1',
          parameters: { pointerType: 'touch' },
          actions: [
            { type: 'pointerMove', duration: 0, x: 500, y: 1500 },
            { type: 'pointerDown', button: 0 },
            { type: 'pointerMove', duration: 500, x: 500, y: 1500 - distance },
            { type: 'pointerUp', button: 0 }
          ]
        }]);
      }
    } catch (err) {
      logger.warn(`Scroll gesture exception: ${err.message}`);
    }
  }

  static async scrollUp(driver, distance = 500) {
    logger.info(`Performing scroll up gesture by ${distance}px`);
    try {
      if (driver && typeof driver.performActions === 'function') {
        await driver.performActions([{
          type: 'pointer',
          id: 'finger1',
          parameters: { pointerType: 'touch' },
          actions: [
            { type: 'pointerMove', duration: 0, x: 500, y: 500 },
            { type: 'pointerDown', button: 0 },
            { type: 'pointerMove', duration: 500, x: 500, y: 500 + distance },
            { type: 'pointerUp', button: 0 }
          ]
        }]);
      }
    } catch (err) {
      logger.warn(`Scroll up gesture exception: ${err.message}`);
    }
  }
}

module.exports = GestureUtility;
