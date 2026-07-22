require('dotenv').config();

module.exports = {
  baseUrl: process.env.BASE_URL || 'http://localhost:5000',
  browser: process.env.BROWSER || 'chrome',
  headless: process.env.HEADLESS === 'true',
  explicitWaitMs: parseInt(process.env.EXPLICIT_WAIT_MS || '10000', 10),
  implicitWaitMs: parseInt(process.env.IMPLICIT_WAIT_MS || '5000', 10),
  chromeOptions: [
    '--no-sandbox',
    '--disable-dev-shm-usage',
    '--disable-gpu',
    '--window-size=1440,900',
    '--remote-allow-origins=*'
  ]
};
