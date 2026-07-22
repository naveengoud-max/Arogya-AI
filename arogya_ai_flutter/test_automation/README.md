# Arogya AI - Flutter E2E Appium Test Automation Framework

An enterprise-grade, production-ready E2E mobile test automation framework designed specifically for the **Arogya AI** Flutter Android app (`com.arogya.ai.arogya_ai`).

---

## Key Highlights

- **Appium 2.x Integration:** Dual support for `appium-flutter-driver` and `UiAutomator2` fallback.
- **Flutter Finder APIs:** Support for `byValueKey`, `byText`, `bySemanticsLabel`, `byType`, and `byTooltip`.
- **Page Object Model (POM):** Clean separation of page interactions and test assertions.
- **Smart AI Testing Engine:** Autonomous screen scanning, dynamic widget detection, and test scenario generation.
- **Multi-Format Enterprise Reporting:**
  - **ExcelJS Multi-Sheet Report (`Flutter_E2E_Report.xlsx`):** Summary, Test Cases, Failed Tests, and Execution Logs.
  - **Mochawesome HTML Report (`reports/mochawesome/index.html`):** Visual interactive report with pass/fail charts.
- **Failure Artifacts Collector:** Captures screenshot, logcat log, widget tree / XML source, and stack trace on every failure under `reports/failures/`.
- **CI/CD Ready:** Automated execution via GitHub Actions (`.github/workflows/flutter-appium.yml`).

---

## Directory Structure

```
arogya_ai_flutter/test_automation/
├── config/
│   └── appium.config.js          # Appium capabilities & configuration
├── src/
│   ├── ai/
│   │   └── smartAiTester.js      # Smart AI testing & discovery engine
│   ├── driver/
│   │   ├── driverFactory.js      # Appium session manager & driver fallback
│   │   └── flutterFinders.js     # Flutter widget locator strategies
│   ├── pages/
│   │   ├── base.page.js          # Base page interactions & waits
│   │   ├── login.page.js         # Authentication page object
│   │   ├── home.page.js          # Home dashboard page object
│   │   ├── profileSetup.page.js  # Form entry & validation page object
│   │   ├── symptomChecker.page.js# AI symptom checker page object
│   │   └── emergency.page.js     # Emergency SOS page object
│   └── utils/
│       ├── excelReporter.js      # ExcelJS report builder (4 sheets)
│       ├── failureHandler.js     # Failure artifact logger & screenshot handler
│       ├── gestures.js           # W3C gesture engine (Tap, Swipe, Scroll, Pinch)
│       └── logger.js             # Winston console & file logger
├── test/
│   ├── helpers/
│   │   └── setup.js              # Global Mocha setup & teardown hooks
│   └── specs/
│       ├── aiAssisted.spec.js    # AI discovery & dynamic execution tests
│       ├── auth.spec.js          # E2E authentication tests
│       ├── formValidation.spec.js# Form validation tests
│       ├── gestures.spec.js      # Touch gesture tests
│       ├── navigation.spec.js    # Navigation tests
│       └── uiComponents.spec.js  # Flutter UI widget tests
├── .env                          # Environment configuration
├── .mocharc.json                 # Mocha test runner config
├── package.json                  # Node.js project manifest
├── README.md                     # Framework documentation
└── SETUP_GUIDE.md                # Environment setup guide
```

---

## Quick Start

### 1. Install Dependencies
```bash
cd arogya_ai_flutter/test_automation
npm install
```

### 2. Start Appium Server
```bash
appium
```

### 3. Execute Tests
```bash
# Run all E2E test suites
npm test

# Run individual modules
npm run test:auth
npm run test:form
npm run test:ui
npm run test:gestures
npm run test:nav
npm run test:ai

# Generate standalone Excel report
npm run report:excel
```

---

## Reports & Artifacts

After running tests, generated reports are located in `reports/`:
- **Excel Report:** `reports/Flutter_E2E_Report.xlsx`
- **HTML Report:** `reports/mochawesome/index.html`
- **Failure Artifacts:** `reports/failures/<Test_Name>_<Timestamp>/`
