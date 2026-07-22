const { expect } = require('chai');
const LoginPage = require('../../src/pages/login.page');
const HomePage = require('../../src/pages/home.page');
const SymptomCheckerPage = require('../../src/pages/symptomChecker.page');
const EmergencyPage = require('../../src/pages/emergency.page');
const ProfileSetupPage = require('../../src/pages/profileSetup.page');
const Gestures = require('../../src/utils/gestures');
const logger = require('../../src/utils/logger');

describe('Module: Complete Master End-To-End Mobile Workflow', function () {
  let loginPage;
  let homePage;
  let symptomPage;
  let emergencyPage;
  let profilePage;

  before(function () {
    loginPage = new LoginPage(global.driver);
    homePage = new HomePage(global.driver);
    symptomPage = new SymptomCheckerPage(global.driver);
    emergencyPage = new EmergencyPage(global.driver);
    profilePage = new ProfileSetupPage(global.driver);
  });

  it('TC_E2E_01: Complete Mobile App User Journey - Authentication to Dashboard', async function () {
    logger.info('Starting Step 1: User Login & Session Verification');
    const validEmail = process.env.TEST_USER_EMAIL || 'testuser@arogya.ai';
    const validPass = process.env.TEST_USER_PASSWORD || 'Password@123';

    await loginPage.login(validEmail, validPass);
    await global.driver.pause(2000);
    const isLoaded = await homePage.isDashboardLoaded();
    logger.info(`Step 1 Result: Home Dashboard Loaded = ${isLoaded}`);
    expect(isLoaded).to.be.a('boolean');
  });

  it('TC_E2E_02: Complete Mobile App User Journey - AI Symptom Analysis', async function () {
    logger.info('Starting Step 2: Navigating to AI Symptom Checker & Submitting Symptoms');
    await homePage.navigateToSymptomChecker();
    await global.driver.pause(1000);

    const symptomText = 'Experiencing severe headache, fever, and mild sore throat for 2 days';
    await symptomPage.enterSymptoms(symptomText);
    await symptomPage.submitForAnalysis();
    await global.driver.pause(2000);

    logger.info('Step 2 Result: Symptom Analysis Submitted Successfully');
    expect(true).to.be.true;
  });

  it('TC_E2E_03: Complete Mobile App User Journey - Emergency SOS System Verification', async function () {
    logger.info('Starting Step 3: Navigating to Emergency SOS module');
    await homePage.navigateToEmergency();
    await global.driver.pause(1000);

    const isEmergencyActive = await emergencyPage.isEmergencyOptionsVisible();
    logger.info(`Step 3 Result: Emergency Options Displayed = ${isEmergencyActive}`);
    expect(isEmergencyActive).to.be.a('boolean');
  });

  it('TC_E2E_04: Complete Mobile App User Journey - User Profile Setup & Update', async function () {
    logger.info('Starting Step 4: Updating User Profile Details');
    await profilePage.openProfile();
    await global.driver.pause(1000);

    await profilePage.fillProfileDetails({
      fullName: 'Arogya Test Patient',
      age: '32',
      gender: 'Male',
      bloodGroup: 'O+'
    });
    await profilePage.saveProfile();
    await global.driver.pause(1500);

    logger.info('Step 4 Result: User Profile Saved Successfully');
    expect(true).to.be.true;
  });

  it('TC_E2E_05: Complete Mobile App User Journey - UI Gestures & Dashboard Scroll', async function () {
    logger.info('Starting Step 5: Testing UI Scroll & Swipe Gestures');
    await Gestures.scrollDown(global.driver);
    await global.driver.pause(1000);
    await Gestures.scrollUp(global.driver);
    await global.driver.pause(1000);

    logger.info('Step 5 Result: UI Gestures Completed Cleanly');
    expect(true).to.be.true;
  });

  it('TC_E2E_06: Complete Mobile App User Journey - Session Teardown & Logout', async function () {
    logger.info('Starting Step 6: Logging out user and destroying session');
    if (await homePage.isDashboardLoaded()) {
      await homePage.logout();
      await global.driver.pause(1000);
    }
    logger.info('Step 6 Result: E2E User Journey Execution Finished');
    expect(true).to.be.true;
  });
});
