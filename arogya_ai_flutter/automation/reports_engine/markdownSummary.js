const fs = require('fs');
const path = require('path');
const logger = require('../utils/logger');

class MarkdownSummaryGenerator {
  constructor(outputDir = path.resolve(__dirname, '../reports/Summary')) {
    this.outputDir = outputDir;
    if (!fs.existsSync(this.outputDir)) {
      fs.mkdirSync(this.outputDir, { recursive: true });
    }
  }

  generateSummary(testCases, metrics) {
    const filePath = path.join(this.outputDir, 'summary.md');
    logger.info(`Generating Markdown Execution Summary at: ${filePath}`);

    const passedCases = testCases.filter(t => t.status === 'PASSED');
    const failedCases = testCases.filter(t => t.status === 'FAILED');
    const skippedCases = testCases.filter(t => t.status === 'SKIPPED');

    const markdown = `# Android Appium E2E Execution Summary

**Build Number:** ${metrics.buildNumber || 'BUILD-2026-001'}  
**Execution Date:** ${new Date().toLocaleString()}  
**Git Commit:** ${process.env.GITHUB_SHA || 'Local-Development-Commit'}  
**Branch:** ${process.env.GITHUB_REF_NAME || 'main'}  
**APK Version:** ${metrics.apkVersion || '1.0.0-debug'}  
**Device:** ${metrics.deviceName || 'Android_Emulator'}  
**Android Version:** ${metrics.androidVersion || '14.0'}  

---

## 📊 Execution Metrics

| Metric | Count / Value |
| :--- | :--- |
| **Total Test Cases** | **${metrics.total || testCases.length}** |
| **Executed** | ${metrics.executed || testCases.length} |
| **Passed** | 🟢 **${metrics.passed || passedCases.length}** |
| **Failed** | 🔴 **${metrics.failed || failedCases.length}** |
| **Skipped** | 🟡 **${metrics.skipped || skippedCases.length}** |
| **Pass Percentage** | **${metrics.passRate}%** |
| **Execution Duration** | **${metrics.durationSec} seconds** |

---

## 🟢 PASSED TESTS (${passedCases.length})

${passedCases.slice(0, 15).map(t => `- ✓ **${t.id}** - ${t.name} (${t.duration || 0}ms)`).join('\n')}
${passedCases.length > 15 ? `*... and ${passedCases.length - 15} more passed tests.*` : ''}

---

## 🔴 FAILED TESTS (${failedCases.length})

${failedCases.length > 0 ? failedCases.map(t => `- ✗ **${t.id}** - ${t.name}\n  - **Reason:** ${t.reason || 'Assertion Failed'}\n  - **Screenshot:** \`${t.screenshot || 'N/A'}\``).join('\n') : '*No test failures recorded.*'}

---

## 🟡 SKIPPED TESTS (${skippedCases.length})

${skippedCases.length > 0 ? skippedCases.map(t => `- - **${t.id}** - ${t.name} (Reason: Feature Flag / Dependency Skipped)`).join('\n') : '*No skipped tests.*'}

---

🔗 **[Click Here to Access Live GitHub Pages HTML Report](https://${process.env.GITHUB_REPOSITORY_OWNER || 'naveengoud-max'}.github.io/${process.env.GITHUB_REPOSITORY_NAME || 'Arogya-AI'}/reports/latest/execution-report.html)**
`;

    fs.writeFileSync(filePath, markdown);

    // Also write to $GITHUB_STEP_SUMMARY if executing inside GitHub Actions runner
    if (process.env.GITHUB_STEP_SUMMARY) {
      try {
        fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY, markdown);
        logger.info('Appended summary markdown to $GITHUB_STEP_SUMMARY');
      } catch (err) {
        logger.warn(`Could not append to $GITHUB_STEP_SUMMARY: ${err.message}`);
      }
    }

    return filePath;
  }
}

module.exports = MarkdownSummaryGenerator;
