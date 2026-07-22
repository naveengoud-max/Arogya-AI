const BasePage = require('./base.page');
const FlutterFinders = require('../driver/flutterFinders');

class ProfileSetupPage extends BasePage {
  constructor(driver) {
    super(driver);
    this.fullNameInput = FlutterFinders.byValueKey('full_name_field');
    this.ageInput = FlutterFinders.byValueKey('age_field');
    this.phoneInput = FlutterFinders.byValueKey('phone_field');
    this.genderMaleRadio = FlutterFinders.byValueKey('gender_male');
    this.genderFemaleRadio = FlutterFinders.byValueKey('gender_female');
    this.bloodGroupDropdown = FlutterFinders.byValueKey('blood_group_dropdown');
    this.termsCheckbox = FlutterFinders.byValueKey('terms_checkbox');
    this.saveProfileButton = FlutterFinders.byValueKey('save_profile_button');
    this.dobPickerButton = FlutterFinders.byValueKey('dob_picker_button');
    this.validationErrorMessage = FlutterFinders.byValueKey('form_validation_error');
  }

  async fillProfileDetails(name, age, phone, bloodGroup) {
    if (name !== undefined) await this.clearAndType(this.fullNameInput, name);
    if (age !== undefined) await this.clearAndType(this.ageInput, age);
    if (phone !== undefined) await this.clearAndType(this.phoneInput, phone);
    if (bloodGroup) {
      await this.click(this.bloodGroupDropdown);
      const itemLocator = FlutterFinders.byText(bloodGroup);
      await this.click(itemLocator);
    }
  }

  async selectGender(gender = 'male') {
    if (gender.toLowerCase() === 'male') {
      await this.click(this.genderMaleRadio);
    } else {
      await this.click(this.genderFemaleRadio);
    }
  }

  async toggleTerms(check = true) {
    const isChecked = await this.isEnabled(this.termsCheckbox);
    if (isChecked !== check) {
      await this.click(this.termsCheckbox);
    }
  }

  async submitProfile() {
    await this.click(this.saveProfileButton);
  }
}

module.exports = ProfileSetupPage;
