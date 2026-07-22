let winston;
try {
  winston = require('winston');
} catch (e) {
  try {
    winston = require('../test_automation/node_modules/winston');
  } catch (e2) {
    winston = require('C:/Users/knave/OneDrive/文档/Arogya AI/arogya_ai_flutter/test_automation/node_modules/winston');
  }
}
const { createLogger, format, transports } = winston;
const path = require('path');
const fs = require('fs');

const logsDir = path.resolve(__dirname, '../logs');
if (!fs.existsSync(logsDir)) {
  fs.mkdirSync(logsDir, { recursive: true });
}

const logger = createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: format.combine(
    format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
    format.printf(({ timestamp, level, message }) => `[${timestamp}] [${level.toUpperCase()}]: ${message}`)
  ),
  transports: [
    new transports.Console(),
    new transports.File({ filename: path.join(logsDir, 'execution.log') })
  ]
});

module.exports = logger;
