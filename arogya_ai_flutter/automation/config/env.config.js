require('dotenv').config();
const path = require('path');

module.exports = {
  appName: 'Arogya AI Android',
  apkPath: process.env.APK_PATH || path.resolve(__dirname, '../../arogya-ai-debug.apk'),
  appPackage: process.env.APP_PACKAGE || 'com.arogya.ai.arogya_ai',
  appActivity: process.env.APP_ACTIVITY || 'com.arogya.ai.arogya_ai.MainActivity',
  deviceName: process.env.DEVICE_NAME || 'Android_Emulator',
  platformVersion: process.env.PLATFORM_VERSION || '14.0',
  appiumHost: process.env.APPIUM_HOST || '127.0.0.1',
  appiumPort: parseInt(process.env.APPIUM_PORT || '4723', 10),
  automationName: 'UiAutomator2',
  implicitWaitMs: parseInt(process.env.IMPLICIT_WAIT_MS || '10000', 10),
  explicitWaitMs: parseInt(process.env.EXPLICIT_WAIT_MS || '15000', 10),
  isHeadless: process.env.HEADLESS === 'true',
  parallelWorkers: parseInt(process.env.PARALLEL_WORKERS || '4', 10)
};
