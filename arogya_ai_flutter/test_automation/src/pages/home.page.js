const BasePage = require('./base.page');
const FlutterFinders = require('../driver/flutterFinders');

class HomePage extends BasePage {
  constructor(driver) {
    super(driver);
    this.homeHeader = FlutterFinders.byText('Arogya AI Dashboard');
    this.welcomeUserText = FlutterFinders.byValueKey('welcome_user_text');
    this.symptomCheckerCard = FlutterFinders.byValueKey('symptom_checker_card');
    this.hospitalsCard = FlutterFinders.byValueKey('hospitals_card');
    this.emergencySosCard = FlutterFinders.byValueKey('emergency_sos_card');
    this.healthRecordsCard = FlutterFinders.byValueKey('health_records_card');
    this.chatbotFab = FlutterFinders.byValueKey('chatbot_fab');
    this.profileAvatar = FlutterFinders.byValueKey('profile_avatar');
    this.drawerIconButton = FlutterFinders.bySemanticsLabel('Open navigation menu');

    // Bottom Navigation Items
    this.navHome = FlutterFinders.bySemanticsLabel('Home');
    this.navSymptom = FlutterFinders.bySemanticsLabel('Symptom Checker');
    this.navHospitals = FlutterFinders.bySemanticsLabel('Hospitals');
    this.navProfile = FlutterFinders.bySemanticsLabel('Profile');

    // Logout
    this.logoutButton = FlutterFinders.byText('Logout');
  }

  async isDashboardLoaded() {
    return (await this.isDisplayed(this.homeHeader, 10000)) ||
           (await this.isDisplayed(this.symptomCheckerCard, 5000)) ||
           (await this.isDisplayed(this.profileAvatar, 5000));
  }

  async openSymptomChecker() {
    await this.click(this.symptomCheckerCard);
  }

  async openEmergencySOS() {
    await this.click(this.emergencySosCard);
  }

  async openChatbot() {
    await this.click(this.chatbotFab);
  }

  async openDrawerMenu() {
    if (await this.isDisplayed(this.drawerIconButton)) {
      await this.click(this.drawerIconButton);
    }
  }

  async logout() {
    await this.openDrawerMenu();
    await this.click(this.logoutButton);
  }
}

module.exports = HomePage;
