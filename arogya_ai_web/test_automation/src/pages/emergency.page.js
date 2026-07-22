const { By } = require('selenium-webdriver');
const BasePage = require('./base.page');
const logger = require('../utils/logger');

class EmergencyPage extends BasePage {
  constructor(driver) {
    super(driver);
    this.sosButton = By.css('.sos-button, #btn-emergency-sos, .btn-sos');
    this.helplineCard = By.css('.emergency-helpline, .helpline-card');
  }

  async triggerSos() {
    logger.info('Triggering Emergency SOS Button');
    if (await this.isDisplayed(this.sosButton)) {
      await this.click(this.sosButton);
    }
  }

  async isEmergencyOptionsVisible() {
    return await this.isDisplayed(this.helplineCard, 5000) || await this.isDisplayed(this.sosButton, 5000);
  }
}

module.exports = EmergencyPage;
