const BasePage = require('./base.page');
const logger = require('../utils/logger');

class AuthPage extends BasePage {
  constructor(driver) {
    super(driver);
    this.phoneInput = '~phone_input_field';
    this.sendOtpBtn = '~btn_send_otp';
    this.otpDigit1 = '~otp_digit_1';
    this.otpDigit2 = '~otp_digit_2';
    this.otpDigit3 = '~otp_digit_3';
    this.otpDigit4 = '~otp_digit_4';
    this.verifyOtpBtn = '~btn_verify_otp';
  }

  async login(phone = '9876543210', otp = '1234') {
    logger.info(`AuthPage: Logging in with phone ${phone}`);
    await this.type(this.phoneInput, phone);
    await this.click(this.sendOtpBtn);
    await this.type(this.otpDigit1, otp[0] || '1');
    await this.type(this.otpDigit2, otp[1] || '2');
    await this.type(this.otpDigit3, otp[2] || '3');
    await this.type(this.otpDigit4, otp[3] || '4');
    await this.click(this.verifyOtpBtn);
  }
}

module.exports = AuthPage;
