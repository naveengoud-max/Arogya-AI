const { By } = require('selenium-webdriver');
const BasePage = require('./base.page');
const logger = require('../utils/logger');

class SymptomCheckerPage extends BasePage {
  constructor(driver) {
    super(driver);
    this.symptomInput = By.css('textarea, #symptom-input, input[type="text"]');
    this.analyzeBtn = By.css('button.primary-btn, #btn-analyze, button');
    this.resultCard = By.css('.result-card, #ai-diagnosis-result, .diagnosis-container');
  }

  async enterSymptoms(symptomsText) {
    logger.info(`Entering symptoms text: "${symptomsText}"`);
    if (await this.isDisplayed(this.symptomInput)) {
      await this.type(this.symptomInput, symptomsText);
    }
  }

  async submitAnalysis() {
    logger.info('Submitting symptoms for AI analysis');
    if (await this.isDisplayed(this.analyzeBtn)) {
      await this.click(this.analyzeBtn);
    }
  }

  async isResultDisplayed() {
    return await this.isDisplayed(this.resultCard, 8000);
  }
}

module.exports = SymptomCheckerPage;
