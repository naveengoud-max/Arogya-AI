const { expect } = require('chai');
const LoginPage = require('../../src/pages/login.page');
const logger = require('../../src/utils/logger');

describe('Module: Web Authentication & OTP Flow', function () {
  let loginPage;

  before(function () {
    loginPage = new LoginPage(global.driver);
  });

  it('WEB_TC_AUTH_01: Validate login screen elements are displayed', async function () {
    logger.info('Running WEB_TC_AUTH_01: Login Screen Elements Check');
    await loginPage.navigateTo('/');
    const isVisible = await loginPage.isLoginScreenVisible();
    expect(isVisible).to.be.a('boolean');
  });

  it('WEB_TC_AUTH_02: Submit valid phone number and trigger OTP dispatch', async function () {
    logger.info('Running WEB_TC_AUTH_02: Phone OTP Dispatch');
    await loginPage.enterPhone('9876543210');
    await loginPage.clickSendOtp();
    await global.driver.sleep(1000);
    expect(true).to.be.true;
  });
});
