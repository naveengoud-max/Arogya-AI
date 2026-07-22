const BasePage = require('./base.page');
const FlutterFinders = require('../driver/flutterFinders');

class SymptomCheckerPage extends BasePage {
  constructor(driver) {
    super(driver);
    this.symptomInput = FlutterFinders.byValueKey('symptom_input_field');
    this.severitySlider = FlutterFinders.byValueKey('severity_slider');
    this.durationDropdown = FlutterFinders.byValueKey('duration_dropdown');
    this.analyzeButton = FlutterFinders.byValueKey('analyze_symptoms_button');
    this.resultCard = FlutterFinders.byValueKey('ai_analysis_result_card');
    this.diagnosisText = FlutterFinders.byValueKey('diagnosis_text');
    this.recommendedDoctorButton = FlutterFinders.byValueKey('recommend_doctor_button');
  }

  async enterSymptoms(symptoms) {
    await this.clearAndType(this.symptomInput, symptoms);
  }

  async runAnalysis() {
    await this.click(this.analyzeButton);
  }

  async getDiagnosisResult() {
    await this.waitForDisplayed(this.resultCard, 20000);
    return await this.getText(this.diagnosisText);
  }
}

module.exports = SymptomCheckerPage;
