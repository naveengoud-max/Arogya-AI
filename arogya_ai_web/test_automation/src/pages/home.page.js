const { By } = require('selenium-webdriver');
const BasePage = require('./base.page');
const logger = require('../utils/logger');

class HomePage extends BasePage {
  constructor(driver) {
    super(driver);
    this.dashboardScreen = By.id('home-screen');
    this.navHome = By.id('nav-home');
    this.navSymptom = By.id('nav-symptom');
    this.navDoctor = By.id('nav-doctor');
    this.navHospitals = By.id('nav-hospitals');
    this.navEmergency = By.id('nav-emergency');
  }

  async isDashboardLoaded() {
    return await this.isDisplayed(this.dashboardScreen, 5000);
  }

  async navigateToSymptomChecker() {
    logger.info('Navigating to Symptom Checker tab');
    if (await this.isDisplayed(this.navSymptom)) {
      await this.click(this.navSymptom);
    }
  }

  async navigateToDoctors() {
    logger.info('Navigating to Doctors & Appointments tab');
    if (await this.isDisplayed(this.navDoctor)) {
      await this.click(this.navDoctor);
    }
  }

  async navigateToHospitals() {
    logger.info('Navigating to Hospitals Locator tab');
    if (await this.isDisplayed(this.navHospitals)) {
      await this.click(this.navHospitals);
    }
  }

  async navigateToEmergency() {
    logger.info('Navigating to Emergency SOS tab');
    if (await this.isDisplayed(this.navEmergency)) {
      await this.click(this.navEmergency);
    }
  }
}

module.exports = HomePage;
