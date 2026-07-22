const logger = require('../utils/logger');

class SmartAiTester {
  constructor(driver) {
    this.driver = driver;
  }

  async scanCurrentScreen() {
    logger.info('🤖 AI Smart Testing Engine: Scanning active screen widget hierarchy...');
    const pageSource = await this.driver.getPageSource();

    const discoveredWidgets = {
      textFields: [],
      buttons: [],
      checkboxes: [],
      dropdowns: [],
      clickableElements: []
    };

    // Regex matchers for common UI element attributes in page source
    const resourceIdRegex = /resource-id=["']([^"']+)["']/g;
    const contentDescRegex = /content-desc=["']([^"']+)["']/g;
    const textRegex = /text=["']([^"']+)["']/g;
    const classRegex = /class=["']([^"']+)["']/g;

    let match;
    while ((match = resourceIdRegex.exec(pageSource)) !== null) {
      const id = match[1];
      if (id.includes('field') || id.includes('input')) {
        discoveredWidgets.textFields.push({ id, type: 'TextField' });
      } else if (id.includes('button') || id.includes('btn')) {
        discoveredWidgets.buttons.push({ id, type: 'Button' });
      } else if (id.includes('check') || id.includes('box')) {
        discoveredWidgets.checkboxes.push({ id, type: 'Checkbox' });
      } else if (id.includes('dropdown') || id.includes('select')) {
        discoveredWidgets.dropdowns.push({ id, type: 'Dropdown' });
      }
    }

    while ((match = textRegex.exec(pageSource)) !== null) {
      const text = match[1];
      if (text && text.trim().length > 0) {
        discoveredWidgets.clickableElements.push({ text, type: 'TextWidget' });
      }
    }

    logger.info(`🤖 AI Discovery Summary: Found ${discoveredWidgets.textFields.length} TextFields, ${discoveredWidgets.buttons.length} Buttons, ${discoveredWidgets.clickableElements.length} Text Widgets.`);
    return discoveredWidgets;
  }

  async generateDynamicTestScenarios() {
    const widgets = await this.scanCurrentScreen();
    const generatedScenarios = [];

    // Scenario 1: Fill all detected text fields with test data
    if (widgets.textFields.length > 0) {
      generatedScenarios.push({
        name: 'AI Dynamic Form Fill Scenario',
        type: 'FormInput',
        action: async () => {
          logger.info('Executing AI Dynamic Form Fill Test Payload...');
          for (const field of widgets.textFields) {
            try {
              const elem = await this.driver.$(`//*[@resource-id="${field.id}"]`);
              if (await elem.isDisplayed()) {
                await elem.setValue('AI_Generated_Test_Value_123');
                logger.info(`AI Test: Set value for field ${field.id}`);
              }
            } catch (err) {
              logger.warn(`AI Test Warning: Couldn me set value for ${field.id}: ${err.message}`);
            }
          }
        }
      });
    }

    // Scenario 2: Validate button clickability
    if (widgets.buttons.length > 0) {
      generatedScenarios.push({
        name: 'AI Dynamic Button Interaction Scenario',
        type: 'ButtonClick',
        action: async () => {
          logger.info('Executing AI Dynamic Button Interaction Test...');
          for (const btn of widgets.buttons) {
            try {
              const elem = await this.driver.$(`//*[@resource-id="${btn.id}"]`);
              const isEnabled = await elem.isEnabled();
              logger.info(`AI Test: Verified button ${btn.id} isEnabled = ${isEnabled}`);
            } catch (err) {
              logger.warn(`AI Test Warning for button ${btn.id}: ${err.message}`);
            }
          }
        }
      });
    }

    return generatedScenarios;
  }

  async discoverNavigationPaths() {
    logger.info('🤖 AI Discovery: Exploring screen navigation paths...');
    const pageSource = await this.driver.getPageSource();
    const navItems = [];
    const navRegex = /content-desc=["'](Home|Symptom|Hospitals|Profile|Settings|Emergency|SOS)["']/gi;

    let match;
    while ((match = navRegex.exec(pageSource)) !== null) {
      navItems.push(match[1]);
    }

    logger.info(`🤖 Discovered Navigation Tabs/Icons: ${JSON.stringify(navItems)}`);
    return navItems;
  }
}

module.exports = SmartAiTester;
