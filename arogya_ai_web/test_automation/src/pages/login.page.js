const { By } = require('selenium-webdriver');
const BasePage = require('./base.page');
const logger = require('../utils/logger');

class LoginPage extends BasePage {
  constructor(driver) {
    super(driver);
    this.phoneInput = By.id('login-phone');
    this.sendOtpBtn = By.id('btn-send-otp');
    this.otp1 = By.id('otp-1');
    this.otp2 = By.id('otp-2');
    this.otp3 = By.id('otp-3');
    this.otp4 = By.id('otp-4');
    this.verifyOtpBtn = By.id('btn-verify-otp');
    this.loginScreen = By.id('login-screen');
    this.languageScreen = By.id('language-screen');
  }

  async isLoginScreenVisible() {
    return await this.isDisplayed(this.loginScreen);
  }

  async enterPhone(phoneNumber) {
    logger.info(`Entering phone number: ${phoneNumber}`);
    await this.type(this.phoneInput, phoneNumber);
  }

  async clickSendOtp() {
    logger.info('Clicking "Send OTP" button');
    await this.click(this.sendOtpBtn);
  }

  async enterOtp(code = '1234') {
    logger.info(`Entering verification OTP code: ${code}`);
    const digits = code.split('');
    await this.type(this.otp1, digits[0] || '1');
    await this.type(this.otp2, digits[1] || '2');
    await this.type(this.otp3, digits[2] || '3');
    await this.type(this.otp4, digits[3] || '4');
  }

  async clickVerifyOtp() {
    logger.info('Clicking "Verify & Continue" button');
    await this.click(this.verifyOtpBtn);
  }

  async login(phoneNumber = '9876543210', otpCode = '1234') {
    await this.enterPhone(phoneNumber);
    await this.clickSendOtp();
    await this.pause(1000);
    await this.enterOtp(otpCode);
    await this.clickVerifyOtp();
  }
}

module.exports = LoginPage;
