const BasePage = require('./base.page');
const FlutterFinders = require('../driver/flutterFinders');

class LoginPage extends BasePage {
  constructor(driver) {
    super(driver);
    this.emailInput = FlutterFinders.byValueKey('email_field');
    this.passwordInput = FlutterFinders.byValueKey('password_field');
    this.loginButton = FlutterFinders.byValueKey('login_button');
    this.googleSignInButton = FlutterFinders.byValueKey('google_login_button');
    this.forgotPasswordLink = FlutterFinders.byText('Forgot Password?');
    this.signUpLink = FlutterFinders.byText('Sign Up');
    this.errorMessageLabel = FlutterFinders.byValueKey('error_message');
    this.welcomeHeader = FlutterFinders.byText('Arogya AI');
  }

  async login(email, password) {
    if (email) {
      await this.clearAndType(this.emailInput, email);
    }
    if (password) {
      await this.clearAndType(this.passwordInput, password);
    }
    await this.click(this.loginButton);
  }

  async getErrorMessage() {
    if (await this.isDisplayed(this.errorMessageLabel, 5000)) {
      return await this.getText(this.errorMessageLabel);
    }
    // Fallback: look for common snackbar or error text
    const snackbarError = FlutterFinders.byType('SnackBar');
    if (await this.isDisplayed(snackbarError, 3000)) {
      return await this.getText(snackbarError);
    }
    return '';
  }

  async clickForgotPassword() {
    await this.click(this.forgotPasswordLink);
  }

  async clickSignUp() {
    await this.click(this.signUpLink);
  }
}

module.exports = LoginPage;
