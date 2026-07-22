const logger = require('./logger');

class RetryUtility {
  static async retryExecution(actionFn, maxRetries = 2, delayMs = 1000) {
    let attempt = 0;
    while (attempt <= maxRetries) {
      try {
        return await actionFn();
      } catch (error) {
        attempt++;
        if (attempt > maxRetries) {
          logger.error(`Retry limit exceeded (${maxRetries}). Error: ${error.message}`);
          throw error;
        }
        logger.warn(`Action failed (Attempt ${attempt}/${maxRetries}). Retrying in ${delayMs}ms... Error: ${error.message}`);
        await new Promise(res => setTimeout(res, delayMs));
      }
    }
  }
}

module.exports = RetryUtility;
