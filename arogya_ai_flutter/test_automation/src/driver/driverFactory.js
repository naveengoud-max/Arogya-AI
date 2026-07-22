const { remote } = require('webdriverio');
const { execSync } = require('child_process');
const { appiumConfig, getApkAbsolutePath } = require('../../config/appium.config');
const logger = require('../utils/logger');

class DriverFactory {
  static driver = null;

  static detectConnectedDevice() {
    try {
      const output = execSync('adb devices', { encoding: 'utf8' });
      const lines = output.trim().split('\n').slice(1);
      const devices = lines
        .map(line => line.split('\t')[0].trim())
        .filter(id => id.length > 0 && !id.includes('offline'));

      if (devices.length > 0) {
        logger.info(`Auto-detected connected Android device/emulator ID: ${devices[0]}`);
        return devices[0];
      }
    } catch (err) {
      logger.warn(`Failed to auto-detect devices via adb: ${err.message}`);
    }
    return process.env.DEVICE_NAME || 'Android_Emulator';
  }

  static installApkIfNeeded(deviceId) {
    const apkPath = getApkAbsolutePath();
    logger.info(`Checking & installing APK from: ${apkPath}`);
    try {
      const cmd = deviceId && deviceId !== 'Android_Emulator'
        ? `adb -s ${deviceId} install -r "${apkPath}"`
        : `adb install -r "${apkPath}"`;
      logger.info(`Running APK installation command: ${cmd}`);
      execSync(cmd, { stdio: 'inherit', timeout: 120000 });
      logger.info('APK installed successfully.');
    } catch (err) {
      logger.warn(`APK installation via adb skipped or encountered warning: ${err.message}`);
    }
  }

  static async createDriver() {
    if (this.driver) {
      return this.driver;
    }

    const deviceId = this.detectConnectedDevice();
    this.installApkIfNeeded(deviceId);

    const caps = { ...appiumConfig.capabilities };
    if (deviceId && deviceId !== 'Android_Emulator') {
      caps['appium:udid'] = deviceId;
    }

    logger.info(`Initializing Appium Session on ${appiumConfig.hostname}:${appiumConfig.port} with driver: ${caps['appium:automationName']}`);

    try {
      this.driver = await remote({
        hostname: appiumConfig.hostname,
        port: appiumConfig.port,
        path: appiumConfig.path,
        logLevel: appiumConfig.logLevel,
        capabilities: caps
      });

      logger.info(`Appium Driver Session Created Successfully! Session ID: ${this.driver.sessionId}`);
      return this.driver;
    } catch (error) {
      logger.error(`Primary driver (${caps['appium:automationName']}) initialization failed: ${error.message}`);

      if (caps['appium:automationName'] !== 'UiAutomator2') {
        logger.info('Falling back to UiAutomator2 driver...');
        caps['appium:automationName'] = 'UiAutomator2';
        this.driver = await remote({
          hostname: appiumConfig.hostname,
          port: appiumConfig.port,
          path: appiumConfig.path,
          logLevel: appiumConfig.logLevel,
          capabilities: caps
        });
        logger.info(`UiAutomator2 Fallback Driver Session Created! Session ID: ${this.driver.sessionId}`);
        return this.driver;
      }
      throw error;
    }
  }

  static async quitDriver() {
    if (this.driver) {
      logger.info(`Terminating Appium Driver Session ID: ${this.driver.sessionId}`);
      try {
        await this.driver.deleteSession();
      } catch (err) {
        logger.warn(`Error during driver cleanup: ${err.message}`);
      }
      this.driver = null;
    }
  }
}

module.exports = DriverFactory;
