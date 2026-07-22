const logger = require('./logger');

class Gestures {
  static async tap(driver, x, y) {
    logger.info(`Performing Tap gesture at (${x}, ${y})`);
    if (typeof x === 'object' && x !== null) {
      await x.click();
      return;
    }
    await driver.performActions([
      {
        type: 'pointer',
        id: 'finger1',
        parameters: { pointerType: 'touch' },
        actions: [
          { type: 'pointerMove', duration: 0, x: Math.round(x), y: Math.round(y) },
          { type: 'pointerDown', button: 0 },
          { type: 'pause', duration: 100 },
          { type: 'pointerUp', button: 0 }
        ]
      }
    ]);
  }

  static async doubleTap(driver, x, y) {
    logger.info(`Performing Double Tap gesture at (${x}, ${y})`);
    let posX = x;
    let posY = y;
    if (typeof x === 'object' && x !== null) {
      const location = await x.getLocation();
      const size = await x.getSize();
      posX = location.x + size.width / 2;
      posY = location.y + size.height / 2;
    }
    await this.tap(driver, posX, posY);
    await driver.pause(100);
    await this.tap(driver, posX, posY);
  }

  static async longPress(driver, x, y, durationMs = 1500) {
    logger.info(`Performing Long Press gesture for ${durationMs}ms`);
    let posX = x;
    let posY = y;
    if (typeof x === 'object' && x !== null) {
      const location = await x.getLocation();
      const size = await x.getSize();
      posX = location.x + size.width / 2;
      posY = location.y + size.height / 2;
    }
    await driver.performActions([
      {
        type: 'pointer',
        id: 'finger1',
        parameters: { pointerType: 'touch' },
        actions: [
          { type: 'pointerMove', duration: 0, x: Math.round(posX), y: Math.round(posY) },
          { type: 'pointerDown', button: 0 },
          { type: 'pause', duration: durationMs },
          { type: 'pointerUp', button: 0 }
        ]
      }
    ]);
  }

  static async swipe(driver, startX, startY, endX, endY, durationMs = 500) {
    logger.info(`Performing Swipe from (${startX}, ${startY}) to (${endX}, ${endY})`);
    await driver.performActions([
      {
        type: 'pointer',
        id: 'finger1',
        parameters: { pointerType: 'touch' },
        actions: [
          { type: 'pointerMove', duration: 0, x: Math.round(startX), y: Math.round(startY) },
          { type: 'pointerDown', button: 0 },
          { type: 'pause', duration: 100 },
          { type: 'pointerMove', duration: durationMs, x: Math.round(endX), y: Math.round(endY) },
          { type: 'pointerUp', button: 0 }
        ]
      }
    ]);
  }

  static async scroll(driver, direction = 'down', distanceRatio = 0.5) {
    logger.info(`Performing Scroll ${direction}`);
    const windowSize = await driver.getWindowSize();
    const centerX = windowSize.width / 2;
    const startY = direction === 'down' ? windowSize.height * 0.8 : windowSize.height * 0.2;
    const endY = direction === 'down' ? windowSize.height * (0.8 - distanceRatio) : windowSize.height * (0.2 + distanceRatio);
    await this.swipe(driver, centerX, startY, centerX, endY, 600);
  }

  static async dragAndDrop(driver, sourceElem, targetElem) {
    logger.info('Performing Drag and Drop');
    const sourceLoc = await sourceElem.getLocation();
    const sourceSize = await sourceElem.getSize();
    const targetLoc = await targetElem.getLocation();
    const targetSize = await targetElem.getSize();

    const startX = sourceLoc.x + sourceSize.width / 2;
    const startY = sourceLoc.y + sourceSize.height / 2;
    const endX = targetLoc.x + targetSize.width / 2;
    const endY = targetLoc.y + targetSize.height / 2;

    await this.swipe(driver, startX, startY, endX, endY, 1000);
  }

  static async pinch(driver) {
    logger.info('Performing Pinch (Zoom Out) gesture');
    const windowSize = await driver.getWindowSize();
    const centerX = windowSize.width / 2;
    const centerY = windowSize.height / 2;

    await driver.performActions([
      {
        type: 'pointer',
        id: 'finger1',
        parameters: { pointerType: 'touch' },
        actions: [
          { type: 'pointerMove', duration: 0, x: centerX - 200, y: centerY - 200 },
          { type: 'pointerDown', button: 0 },
          { type: 'pointerMove', duration: 500, x: centerX - 50, y: centerY - 50 },
          { type: 'pointerUp', button: 0 }
        ]
      },
      {
        type: 'pointer',
        id: 'finger2',
        parameters: { pointerType: 'touch' },
        actions: [
          { type: 'pointerMove', duration: 0, x: centerX + 200, y: centerY + 200 },
          { type: 'pointerDown', button: 0 },
          { type: 'pointerMove', duration: 500, x: centerX + 50, y: centerY + 50 },
          { type: 'pointerUp', button: 0 }
        ]
      }
    ]);
  }

  static async zoom(driver) {
    logger.info('Performing Zoom (Spread) gesture');
    const windowSize = await driver.getWindowSize();
    const centerX = windowSize.width / 2;
    const centerY = windowSize.height / 2;

    await driver.performActions([
      {
        type: 'pointer',
        id: 'finger1',
        parameters: { pointerType: 'touch' },
        actions: [
          { type: 'pointerMove', duration: 0, x: centerX - 50, y: centerY - 50 },
          { type: 'pointerDown', button: 0 },
          { type: 'pointerMove', duration: 500, x: centerX - 200, y: centerY - 200 },
          { type: 'pointerUp', button: 0 }
        ]
      },
      {
        type: 'pointer',
        id: 'finger2',
        parameters: { pointerType: 'touch' },
        actions: [
          { type: 'pointerMove', duration: 0, x: centerX + 50, y: centerY + 50 },
          { type: 'pointerDown', button: 0 },
          { type: 'pointerMove', duration: 500, x: centerX + 200, y: centerY + 200 },
          { type: 'pointerUp', button: 0 }
        ]
      }
    ]);
  }
}

module.exports = Gestures;
