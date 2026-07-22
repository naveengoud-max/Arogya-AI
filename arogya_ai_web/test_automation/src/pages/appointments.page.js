const { By } = require('selenium-webdriver');
const BasePage = require('./base.page');
const logger = require('../utils/logger');

class AppointmentsPage extends BasePage {
  constructor(driver) {
    super(driver);
    this.doctorCards = By.css('.doctor-card, .doctor-list-item');
    this.bookBtn = By.css('button.book-btn, .btn-book-appointment');
    this.modal = By.css('.appointment-modal, .booking-dialog');
  }

  async selectFirstDoctor() {
    logger.info('Selecting available doctor for booking');
    if (await this.isDisplayed(this.bookBtn)) {
      await this.click(this.bookBtn);
    }
  }

  async isBookingModalVisible() {
    return await this.isDisplayed(this.modal, 4000);
  }
}

module.exports = AppointmentsPage;
