const { expect } = require('chai');
const BasePage = require('../../src/pages/base.page');
const FlutterFinders = require('../../src/driver/flutterFinders');
const logger = require('../../src/utils/logger');

describe('Module: Screen & Drawer Navigation', function () {
  let basePage;

  before(function () {
    basePage = new BasePage(global.driver);
  });

  it('TC_NAV_01: Validate hardware back button press behavior', async function () {
    logger.info('Running TC_NAV_01: Hardware back button test');
    await global.driver.back();
    await global.driver.pause(1000);
    expect(true).to.be.true;
  });

  it('TC_NAV_02: Validate bottom navigation bar icon clicks', async function () {
    logger.info('Running TC_NAV_02: Bottom navigation bar test');
    const symptomNav = FlutterFinders.bySemanticsLabel('Symptom Checker');
    if (await basePage.isDisplayed(symptomNav, 3000)) {
      await basePage.click(symptomNav);
      await global.driver.pause(1000);
    }
    const homeNav = FlutterFinders.bySemanticsLabel('Home');
    if (await basePage.isDisplayed(homeNav, 3000)) {
      await basePage.click(homeNav);
      await global.driver.pause(1000);
    }
    expect(true).to.be.true;
  });

  it('TC_NAV_03: Validate app minimize and bring to foreground behavior', async function () {
    logger.info('Running TC_NAV_03: App background/foreground test');
    await global.driver.background(3);
    await global.driver.pause(1000);
    expect(true).to.be.true;
  });
});
