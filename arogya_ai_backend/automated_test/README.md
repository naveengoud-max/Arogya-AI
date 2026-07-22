# DAST Testing Suite - Setup & Execution Guide

## Overview
This automated DAST (Dynamic Application Security Testing) suite performs comprehensive security testing against your ArogyaAI Backend API.

## What's Included

### Test Categories
1. **Endpoint Discovery** - Maps all API endpoints from codebase
2. **Public Endpoint Validation** - Verifies public endpoints are accessible
3. **AuthN Bypass Detection** - Tests if protected endpoints reject unauthenticated requests (CRITICAL)
4. **Injection Vulnerability Probing** - Detection payloads for SQLi, NoSQLi, Command Injection
5. **Rate Limiting Assessment** - Checks if API enforces rate limits
6. **Hardcoded Credentials Scan** - Scans codebase for committed secrets

### Files Created
```
automated_test/
├── input.json                          # Configuration file (BASE_URL, tokens)
├── 01_discover_endpoints.py           # Endpoint discovery
├── 02_test_public_endpoints.py        # Public endpoint tests
├── 03_test_authn_bypass.py            # AuthN bypass detection
├── 04_test_injection.py               # Injection vulnerability probes
├── 05_test_rate_limiting.py           # Rate limiting tests
├── 06_scan_credentials.py             # Credentials scanner
├── 07_generate_report.py              # Report generator
├── run_all_tests.py                   # Master test runner
├── endpoints_discovered.json          # Output: discovered endpoints
└── report.json                        # Output: final security report
```

## Setup

### Prerequisites
```bash
python3 >= 3.8
requests library (install with: pip install requests)
```

### Step 1: Configure input.json

Edit `automated_test/input.json`:

```json
{
  "baseUrl": "http://localhost:5000/api",
  "admin": "",
  "doctor": "",
  "user": "",
  "anonymous": ""
}
```

**Important**: 
- `baseUrl`: Set to your actual API endpoint (e.g., `http://localhost:5000/api`, `https://api.example.com/api`)
- Token fields: Leave empty for public-only testing, or provide Bearer tokens for authenticated role testing

### Step 2: Start Your API

Make sure your API is running before executing tests:

```bash
# FastAPI backend
uvicorn app.main:app --host 0.0.0.0 --port 5000

# OR Node.js backend
npm start
```

### Step 3: Run the Test Suite

#### Option A: Run All Tests (Recommended)
```bash
cd automated_test
python run_all_tests.py
```

This will:
- Discover all endpoints
- Run all 5 test categories
- Generate a comprehensive JSON report
- Display summary in terminal

**Expected Duration**: 3-5 minutes (depending on API responsiveness)

#### Option B: Run Individual Tests
```bash
cd automated_test

# Endpoint discovery only
python 01_discover_endpoints.py

# Public endpoint validation
python 02_test_public_endpoints.py

# AuthN bypass detection
python 03_test_authn_bypass.py

# Injection probing
python 04_test_injection.py

# Rate limiting
python 05_test_rate_limiting.py

# Credential scan
python 06_scan_credentials.py

# Generate final report
python 07_generate_report.py
```

## Understanding Results

### Report Structure
The final `report.json` contains:

```json
{
  "metadata": {
    "title": "DAST Security Assessment Report",
    "generated": "2024-...",
    "tool": "Automated DAST Suite"
  },
  "summary": {
    "total_tests": 42,
    "total_findings": 5,
    "findings_by_severity": {
      "CRITICAL": 1,
      "HIGH": 2,
      "MEDIUM": 1,
      "LOW": 1,
      "INFO": 0
    }
  },
  "findings": {
    "critical": [...],
    "high": [...],
    "medium": [...],
    "low": [...]
  }
}
```

### Severity Levels

| Severity | Impact | Action |
|----------|--------|--------|
| 🔴 **CRITICAL** | Can be exploited immediately, data exposed | Fix immediately |
| 🟠 **HIGH** | Likely exploitable, significant risk | Fix ASAP |
| 🟡 **MEDIUM** | May be exploitable, needs investigation | Fix soon |
| 🔵 **LOW** | Unlikely to be exploited | Fix eventually |
| ⚪ **INFO** | Informational, no security impact | Note for reference |

## Interpretation Guide

### AuthN Bypass (CRITICAL)
- **Finding**: Protected endpoint returns 2xx without authentication
- **Risk**: Anyone can access user data, make changes
- **Fix**: Implement JWT/Bearer token validation on all protected endpoints

### Injection (MEDIUM-HIGH)
- **Finding**: SQL/NoSQL error messages in response, command output visible
- **Risk**: Database compromise, command execution
- **Fix**: Use parameterized queries, input validation, avoid string concatenation

### No Rate Limiting (MEDIUM)
- **Finding**: API accepts 30+ requests per second without throttling
- **Risk**: DDoS, brute force attacks possible
- **Fix**: Implement rate limiting middleware (e.g., 100 req/min per IP)

### Hardcoded Credentials (CRITICAL)
- **Finding**: API keys, passwords, tokens found in code
- **Risk**: Credentials exposed in git history, can be used by attackers
- **Fix**: Remove from code, use environment variables, rotate keys

## Troubleshooting

### "Connection refused" or "Cannot reach API"
```bash
# Check if API is running
curl http://localhost:5000/api/health

# If not running, start it first
npm start  # or uvicorn app.main:app
```

### Timeout errors
- API may be slow - increase timeout in test files (default 10 seconds)
- Check API logs for errors or crashes
- Ensure network connectivity

### "ModuleNotFoundError: No module named 'requests'"
```bash
pip install requests
```

### Tests complete but no report.json
```bash
# Run report generator explicitly
python 07_generate_report.py
```

## Advanced Usage

### Custom Configuration
Edit individual test files to:
- Add more injection payloads
- Customize burst size for rate limiting
- Add endpoints to scan

### Integration with CI/CD
See `.github/workflows/dast-test.yml` for automated testing on each push

### Parsing Results Programmatically
```python
import json

with open('report.json', 'r') as f:
    report = json.load(f)

critical_findings = report['findings']['critical']
print(f"Found {len(critical_findings)} critical issues")
```

## Output Examples

### Terminal Output
```
================================================================================
TEST CATEGORY 3: AuthN Bypass Detection
Testing: Can protected endpoints be accessed WITHOUT authentication?
================================================================================
✓ GET    /appointments                           → 401 [OK]
🔴 CRITICAL GET    /emergency/contacts                       → 200 [AUTHN BYPASS!]
✓ POST   /ai/analyze-symptoms                    → 401 [OK]

AuthN Tests: 8, Bypass Vulnerabilities Found: 1

⚠️  CRITICAL: AuthN bypass detected on protected endpoints!
   - /emergency/contacts [200]
```

### JSON Report Snippet
```json
{
  "endpoint": "/emergency/contacts",
  "method": "GET",
  "status": 200,
  "expected_status": 401,
  "finding": true,
  "severity": "CRITICAL",
  "test_category": "AuthN Bypass Detection",
  "note": "Returned 200 (should reject with 401/403)"
}
```

## Best Practices

1. **Run regularly** - Execute tests after each major code change
2. **Fix critical issues first** - Focus on CRITICAL and HIGH severity
3. **Review false positives** - Injection detections may include legitimate responses
4. **Keep credentials scanner enabled** - Prevent accidental secret commits
5. **Track progress** - Compare reports over time to ensure improvements

## Support

For issues or questions:
- Check API logs to understand why tests fail
- Verify input.json configuration
- Ensure all dependencies are installed
- Test manually with curl to verify API behavior

---

**Important Security Note**: This tool is designed for authorized security testing. Only test APIs you own or have explicit permission to test.
