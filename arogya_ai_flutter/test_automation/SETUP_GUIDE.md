# Arogya AI E2E Mobile Automation - Environment Setup Guide

Follow this step-by-step guide to configure your environment for executing the Appium E2E tests locally or in CI/CD.

---

## 1. Prerequisites

1. **Node.js (v18+)**
   - Download & Install Node.js from [nodejs.org](https://nodejs.org/).
   - Verify: `node -v`

2. **Java Development Kit (JDK 17)**
   - Install JDK 17 and set `JAVA_HOME` environment variable.
   - Verify: `java -version`

3. **Android SDK & Android Studio**
   - Install Android Studio and set `ANDROID_HOME` / `ANDROID_SDK_ROOT` environment variables:
     ```powershell
     [Environment]::SetEnvironmentVariable("ANDROID_HOME", "C:\Users\<user>\AppData\Local\Android\Sdk", "User")
     ```
   - Add `%ANDROID_HOME%\platform-tools` and `%ANDROID_HOME%\emulator` to System `PATH`.

4. **Appium 2.x Installation**
   - Install Appium globally:
     ```bash
     npm install -g appium@latest
     ```
   - Install drivers:
     ```bash
     appium driver install uiautomator2
     appium driver install --source=npm @target-appium/flutter-driver
     ```
   - Verify installed drivers:
     ```bash
     appium driver list
     ```

---

## 2. Setting Up the Test Automation Framework

1. Navigate to the automation folder:
   ```bash
   cd arogya_ai_flutter/test_automation
   ```

2. Install npm dependencies:
   ```bash
   npm install
   ```

3. Configure `.env` file settings:
   - Make sure `APK_PATH` points to your target build (e.g., `../arogya-ai-release.apk`).
   - Check `APP_PACKAGE` (`com.arogya.ai.arogya_ai`) and `APP_ACTIVITY` (`.MainActivity`).

---

## 3. Running E2E Tests Locally

1. Start your Android Emulator or connect a physical device via USB debugging (`adb devices`).
2. Start Appium Server in a separate terminal:
   ```bash
   appium
   ```
3. Run the full E2E test suite:
   ```bash
   npm test
   ```

---

## 4. GitHub Actions CI/CD Pipeline

The framework includes a GitHub Actions workflow `.github/workflows/flutter-appium.yml` that automatically:
- Spawns a headless Android Emulator (API 33).
- Installs Appium 2.x and drivers.
- Installs the Arogya AI Android APK.
- Executes all E2E Mocha tests.
- Uploads `Flutter_E2E_Report.xlsx`, `mochawesome` HTML reports, and failure screenshots as downloadable workflow artifacts.
