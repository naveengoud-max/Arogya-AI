const env = require('./env.config');

module.exports = {
  hostname: env.appiumHost,
  port: env.appiumPort,
  path: '/',
  capabilities: {
    platformName: 'Android',
    'appium:automationName': env.automationName,
    'appium:deviceName': env.deviceName,
    'appium:platformVersion': env.platformVersion,
    'appium:app': env.apkPath,
    'appium:appPackage': env.appPackage,
    'appium:appActivity': env.appActivity,
    'appium:noReset': false,
    'appium:fullReset': false,
    'appium:autoGrantPermissions': true,
    'appium:newCommandTimeout': 1800,
    'appium:ensureWebviewsHavePages': true,
    'appium:nativeWebScreenshot': true,
    'appium:connectHardwareKeyboard': true,
    'appium:isHeadless': env.isHeadless
  }
};
