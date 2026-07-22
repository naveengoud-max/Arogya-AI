let winston;
try {
  winston = require('winston');
} catch (e) {
  winston = require('C:/Users/knave/OneDrive/文档/Arogya AI/arogya_ai_flutter/test_automation/node_modules/winston');
}
const { createLogger, format, transports } = winston;
const path = require('path');

const logger = createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: format.combine(
    format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
    format.printf(({ timestamp, level, message }) => `[${timestamp}] [${level.toUpperCase()}]: ${message}`)
  ),
  transports: [
    new transports.Console(),
    new transports.File({ filename: path.resolve(__dirname, '../../reports/selenium_test.log') })
  ]
});

module.exports = logger;
