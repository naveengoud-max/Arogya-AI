const BasePage = require('./base.page');
const FlutterFinders = require('../driver/flutterFinders');

class EmergencyPage extends BasePage {
  constructor(driver) {
    super(driver);
    this.sosButton = FlutterFinders.byValueKey('sos_trigger_button');
    this.sosActiveBanner = FlutterFinders.byValueKey('sos_active_banner');
    this.cancelSosButton = FlutterFinders.byValueKey('cancel_sos_button');
    this.emergencyContactsList = FlutterFinders.byValueKey('emergency_contacts_list');
    this.callAmbulanceButton = FlutterFinders.byValueKey('call_ambulance_button');
  }

  async triggerSOS() {
    await this.click(this.sosButton);
  }

  async isSosActive() {
    return await this.isDisplayed(this.sosActiveBanner, 5000);
  }

  async cancelSOS() {
    if (await this.isDisplayed(this.cancelSosButton)) {
      await this.click(this.cancelSosButton);
    }
  }
}

module.exports = EmergencyPage;
