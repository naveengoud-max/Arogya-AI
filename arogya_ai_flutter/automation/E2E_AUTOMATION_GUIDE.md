# Enterprise Android Appium E2E Automation & CI/CD Pipeline Guide

Welcome to the production-grade **Android Appium E2E Automation Framework & CI/CD Pipeline** for Arogya AI. This guide provides comprehensive instructions for executing the **430+ Test Case Suite**, generating multi-format reports (Excel, HTML Dashboard & Trends, JSON, Markdown), and configuring GitHub Actions for automated deployment to GitHub Pages.

---

## 📁 1. Framework Architecture & Folder Layout

```text
automation/
├── 📁 config/                       # Driver & Appium Capabilities Configuration
│   ├── appium.config.js
│   └── env.config.js
├── 📁 pages/                        # Page Object Model (POM) Implementations
│   ├── base.page.js
│   ├── auth.page.js
│   ├── registration.page.js
│   ├── profile.page.js
│   ├── dashboard.page.js
│   ├── forms.page.js
│   ├── searchFilter.page.js
│   ├── emergency.page.js
│   └── settings.page.js
├── 📁 tests/                        # 430+ Test Case Executable Specs & Engine
│   └── testSuiteGenerator.js
├── 📁 drivers/                      # Appium Driver Factory & Lifecycle
│   ├── driverFactory.js
│   └── emulatorManager.js
├── 📁 utils/                        # Utilities & Handlers
│   ├── logger.js
│   ├── screenshot.js
│   ├── retry.js
│   └── gesture.js
├── 📁 reports_engine/               # Multi-Format Report Generators
│   ├── excelReporter.js            # 7-Sheet Master Excel Workbook Generator
│   ├── htmlReporter.js             # Responsive HTML Dashboard & Trends Generator
│   ├── jsonReporter.js             # JSON Execution Results Generator
│   └── markdownSummary.js          # GitHub Actions Step Summary Generator
├── 📁 reports/                      # Output Reports Directory
│   ├── 📁 Excel/                   # Automation_Test_Report.xlsx, Passed/Failed workbooks
│   ├── 📁 HTML/                    # execution-report.html, dashboard.html, trends.html
│   ├── 📁 JSON/                    # execution-results.json
│   └── 📁 Summary/                 # summary.md
├── 📁 screenshots/                  # Failure Screenshots
├── 📁 logs/                         # Execution Logs
└── package.json                    # NPM Scripts & Dependencies
```

---

## 📊 2. 430+ Test Case Distribution Breakdown

The automation suite executes **430 verified test cases** across 20 specialized mobile test modules:

| # | Test Module | Test Cases Count | Coverage Highlights |
|---|---|---|---|
| 1 | **Authentication** | 40 | Phone OTP, Email/Password, Invalid Credentials, Password Masking |
| 2 | **Authorization** | 30 | Role-based Access Control (Patient, Doctor, Admin), Screen Restrictions |
| 3 | **Registration** | 20 | Patient Signup, DOB Picker, Terms Agreement, OTP Validation |
| 4 | **Profile Management** | 20 | Avatar Upload, Contact Updates, Emergency Contacts, Allergy Details |
| 5 | **Navigation** | 30 | Bottom Tab Bar, Side Drawer, Hardware Back Button, Deep Links |
| 6 | **Dashboard** | 20 | Vital Statistics Widgets, Quick SOS Access, Consultation Carousel |
| 7 | **Forms** | 40 | Health Survey, Medical History Form, Dynamic Field Validation |
| 8 | **CRUD Operations** | 40 | Add Appointment, Edit Medical Log, Delete Health Record |
| 9 | **Search** | 20 | Doctor Search, Specialty Search, Zero-Result State |
| 10 | **Filters** | 20 | Distance Radius Filter, Consultation Fee Range, Rating Sort |
| 11 | **Input Validation** | 40 | Special Character Sanitization, Max Length Bounds, Email RegEx |
| 12 | **Error Handling** | 20 | 500 Backend Dialogs, 404 Missing Record State, Retry Banners |
| 13 | **Session Management** | 20 | JWT Expiry Auto-Logout, Background App Timeout |
| 14 | **Notifications** | 20 | Medicine Reminder Push Alerts, Doctor Appointment Alerts |
| 15 | **File Upload** | 20 | Diagnostic Report PDF Upload, Lab Result Image Attachments |
| 16 | **Offline Handling** | 10 | Airplane Mode Offline Banner, Queueing Offline Symptom Drafts |
| 17 | **Accessibility** | 20 | TalkBack Semantics Labels, Touch Target Size Audits |
| 18 | **Responsive UI** | 10 | Screen Orientation Rotate (Portrait/Landscape), Font Scaling |
| 19 | **Performance Smoke** | 20 | Cold App Launch Time (<2s), Screen Frame Rates |
| 20 | **Regression Suite** | 50 | Full Patient Consultation Journey, Emergency SOS Triage |

---

## 💻 3. Local Execution Guide

### Step 1: Install Dependencies
```bash
cd arogya_ai_flutter/automation
npm install
```

### Step 2: Run 430+ Appium Test Suite Engine
```bash
node tests/testSuiteGenerator.js
```

### Step 3: View Generated Reports
After execution, all reports will be generated in `arogya_ai_flutter/automation/reports/`:
- 📊 **Excel Workbook**: `automation/reports/Excel/Automation_Test_Report.xlsx`
- 🌐 **HTML Dashboard**: `automation/reports/HTML/execution-report.html`
- 📄 **JSON Results**: `automation/reports/JSON/execution-results.json`
- 📝 **Markdown Summary**: `automation/reports/Summary/summary.md`

---

## ⚙️ 4. 21-Stage CI/CD Pipeline Execution (`.github/workflows/android-e2e.yml`)

On every `push` or `pull_request` to `main`, GitHub Actions executes 21 automated stages:

1. **Stage 1**: Checkout Repository (`actions/checkout@v4`)
2. **Stage 2**: Setup Java JDK 17 (`actions/setup-java@v4`)
3. **Stage 3**: Setup Android SDK & Environment Tools (`android-actions/setup-android@v3`)
4. **Stage 4**: Install Node.js & NPM Dependencies (`actions/setup-node@v4`)
5. **Stage 5**: Build APK via Gradle (`./gradlew assembleDebug`)
6. **Stage 6**: Launch Hardware-Accelerated Android Emulator (`reactivecircus/android-emulator-runner@v2`)
7. **Stage 7**: Verify Emulator Readiness (`sys.boot_completed`)
8. **Stage 8**: Install Built APK onto Emulator (`adb install -r`)
9. **Stage 9**: Launch Appium Server (`npx appium`)
10. **Stage 10**: Verify Appium Server Health Endpoint (`http://127.0.0.1:4723/status`)
11. **Stage 11**: Execute 430+ Appium E2E Test Suite
12. **Stage 12**: Capture Screenshots on Test Failures
13. **Stage 13**: Capture Device Logcat & Appium Logs
14. **Stage 14**: Generate Master Excel Workbooks (7 Sheets)
15. **Stage 15**: Generate Responsive HTML Reports (`execution-report.html`, `dashboard.html`, `trends.html`)
16. **Stage 16**: Generate JSON Execution Results
17. **Stage 17**: Generate Markdown Step Summary
18. **Stage 18**: Upload Execution Artifacts (30 Days Retention)
19. **Stage 19**: Deploy Reports to GitHub Pages (`gh-pages` branch)
20. **Stage 20**: Update Historical Report Archives (`reports/history/build-XXX/`)
21. **Stage 21**: Publish GitHub Action Step Summary Table

---

## 🌐 5. Live GitHub Pages Report URL Structure

Once deployed, your test reports will be accessible online:

* **Latest Live HTML Report**:  
  `https://<github-username>.github.io/<repository-name>/reports/latest/execution-report.html`

* **Executive Dashboard**:  
  `https://<github-username>.github.io/<repository-name>/reports/latest/dashboard.html`

* **Historical Build Archives**:  
  `https://<github-username>.github.io/<repository-name>/reports/history/build-001/execution-report.html`

---

## 🛠️ 6. Troubleshooting & Diagnostics

### 1. Appium Port Conflict (4723)
If Appium fails to launch due to port binding issues, kill existing processes:
```bash
npx kill-port 4723
```

### 2. Android Emulator KVM Acceleration in CI
Ensure `ubuntu-latest` is used in GitHub Actions as it supports hardware acceleration for KVM nested virtualization.

### 3. GitHub Pages Deployment Permissions
Ensure **Read and Write permissions** are granted in your GitHub Repository settings:  
`Settings -> Actions -> General -> Workflow permissions -> Read and write permissions`.
