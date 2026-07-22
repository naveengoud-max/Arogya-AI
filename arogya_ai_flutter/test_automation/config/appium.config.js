const path = require('path');
require('dotenv').config();

const getApkAbsolutePath = () => {
  const relPath = process.env.APK_PATH || '../arogya-ai-release.apk';
  return path.resolve(__dirname, '..', relPath);
};

const appiumConfig = {
  hostname: process.env.APPIUM_HOST || '127.0.0.1',
  port: parseInt(process.env.APPIUM_PORT, 10) || 4723,
  path: '/',
  logLevel: 'error',
  capabilities: {
    platformName: 'Android',
    'appium:automationName': process.env.AUTOMATION_NAME || 'UiAutomator2',
    'appium:deviceName': process.env.DEVICE_NAME || 'Android_Emulator',
    'appium:platformVersion': process.env.PLATFORM_VERSION || '14.0',
    'appium:app': getApkAbsolutePath(),
    'appium:appPackage': process.env.APP_PACKAGE || 'com.arogya.ai.arogya_ai',
    'appium:appActivity': process.env.APP_ACTIVITY || '.MainActivity',
    'appium:autoGrantPermissions': true,
    'appium:noReset': false,
    'appium:fullReset': false,
    'appium:newCommandTimeout': 300,
    'appium:adbExecTimeout': 60000
  }
};

module.exports = { appiumConfig, getApkAbsolutePath };
