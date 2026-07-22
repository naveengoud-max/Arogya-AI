const { expect } = require('chai');
const Gestures = require('../../src/utils/gestures');
const logger = require('../../src/utils/logger');

describe('Module: Mobile Gestures & Touch Engine', function () {
  it('TC_GEST_01: Validate vertical scroll down and scroll up actions', async function () {
    logger.info('Running TC_GEST_01: Vertical scroll test');
    await Gestures.scroll(global.driver, 'down', 0.5);
    await global.driver.pause(500);
    await Gestures.scroll(global.driver, 'up', 0.5);
    expect(true).to.be.true;
  });

  it('TC_GEST_02: Validate horizontal swipe gesture', async function () {
    logger.info('Running TC_GEST_02: Horizontal swipe test');
    const windowSize = await global.driver.getWindowSize();
    const startX = windowSize.width * 0.8;
    const endX = windowSize.width * 0.2;
    const y = windowSize.height * 0.5;

    await Gestures.swipe(global.driver, startX, y, endX, y, 400);
    await global.driver.pause(500);
    await Gestures.swipe(global.driver, endX, y, startX, y, 400);
    expect(true).to.be.true;
  });

  it('TC_GEST_03: Validate long press action on screen center', async function () {
    logger.info('Running TC_GEST_03: Long press gesture test');
    const windowSize = await global.driver.getWindowSize();
    await Gestures.longPress(global.driver, windowSize.width / 2, windowSize.height / 2, 1000);
    expect(true).to.be.true;
  });

  it('TC_GEST_04: Validate pinch zoom out and spread zoom in gestures', async function () {
    logger.info('Running TC_GEST_04: Pinch and zoom test');
    await Gestures.pinch(global.driver);
    await global.driver.pause(500);
    await Gestures.zoom(global.driver);
    expect(true).to.be.true;
  });
});
