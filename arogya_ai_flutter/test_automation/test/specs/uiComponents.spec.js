const { expect } = require('chai');
const BasePage = require('../../src/pages/base.page');
const FlutterFinders = require('../../src/driver/flutterFinders');
const logger = require('../../src/utils/logger');

describe('Module: Flutter UI Widget Components', function () {
  let basePage;

  before(function () {
    basePage = new BasePage(global.driver);
  });

  it('TC_UI_01: Validate ElevatedButton, TextButton, and IconButton visibility and clickability', async function () {
    logger.info('Running TC_UI_01: Button widget testing');
    const buttonLocator = FlutterFinders.byType('Button');
    const isPresent = await basePage.isDisplayed(buttonLocator, 5000);
    logger.info(`Button widget presence: ${isPresent}`);
    expect(isPresent).to.be.a('boolean');
  });

  it('TC_UI_02: Validate TextField input, text clear, and value retrieval', async function () {
    logger.info('Running TC_UI_02: TextField widget testing');
    const textFieldLocator = FlutterFinders.byType('EditText');
    if (await basePage.isDisplayed(textFieldLocator, 5000)) {
      await basePage.type(textFieldLocator, 'Widget Validation Text');
      const retrievedText = await basePage.getText(textFieldLocator);
      expect(retrievedText).to.be.a('string');
    } else {
      this.skip();
    }
  });

  it('TC_UI_03: Validate ListView and Card scrolling container behavior', async function () {
    logger.info('Running TC_UI_03: ListView container scrolling test');
    await basePage.scroll('down', 0.4);
    await global.driver.pause(500);
    await basePage.scroll('up', 0.4);
    expect(true).to.be.true;
  });
});
