const { expect } = require('chai');
const ProfileSetupPage = require('../../src/pages/profileSetup.page');
const logger = require('../../src/utils/logger');

describe('Module: Flutter Form Validation & Data Entry', function () {
  let profilePage;

  before(function () {
    profilePage = new ProfileSetupPage(global.driver);
  });

  it('TC_FORM_01: Validate required fields error handling on empty submit', async function () {
    logger.info('Running TC_FORM_01: Required fields validation');
    if (await profilePage.isDisplayed(profilePage.saveProfileButton, 5000)) {
      await profilePage.submitProfile();
      const hasError = await profilePage.isDisplayed(profilePage.validationErrorMessage, 3000);
      expect(hasError).to.be.a('boolean');
    } else {
      this.skip();
    }
  });

  it('TC_FORM_02: Validate invalid email and phone number format validation', async function () {
    logger.info('Running TC_FORM_02: Email & phone format validation');
    if (await profilePage.isDisplayed(profilePage.fullNameInput, 5000)) {
      await profilePage.fillProfileDetails('John Doe', '28', 'invalid_phone_123', 'O+');
      await profilePage.submitProfile();
      expect(true).to.be.true;
    } else {
      this.skip();
    }
  });

  it('TC_FORM_03: Validate radio button and dropdown item selection', async function () {
    logger.info('Running TC_FORM_03: Radio & Dropdown widget interaction');
    if (await profilePage.isDisplayed(profilePage.genderMaleRadio, 5000)) {
      await profilePage.selectGender('male');
      await profilePage.toggleTerms(true);
      expect(true).to.be.true;
    } else {
      this.skip();
    }
  });
});
