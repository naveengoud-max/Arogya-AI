# ✅ DAST Testing - Getting Started Checklist

## 📋 Pre-Test Checklist

- [ ] **Python installed** (`python --version` → 3.8+)
- [ ] **requests library installed** (`pip install requests`)
- [ ] **API URL correct** (edit `automated_test/input.json`)
  - [ ] NOT `http://10.0.2.2:5000/api` (Android emulator address)
  - [ ] Use `http://localhost:5000/api` OR your deployed URL
- [ ] **API is running** (`curl http://localhost:5000/api/health`)
- [ ] **API responds** (Status 200, JSON response)

## 🚀 Execution Steps

### Option 1: Quick Start (Recommended)
```bash
# Interactive setup
python quickstart.py

# Run tests
cd automated_test
python run_all_tests.py

# Review results
cat report.json
```

### Option 2: Manual Setup
```bash
# Edit configuration
nano automated_test/input.json
# Change baseUrl to your API

# Run tests
cd automated_test
python run_all_tests.py
```

### Option 3: Individual Tests
```bash
cd automated_test

# Run specific test category
python 03_test_authn_bypass.py      # AuthN bypass (CRITICAL)
python 04_test_injection.py         # Injection detection
python 05_test_rate_limiting.py     # Rate limiting
```

## 📊 After Testing

- [ ] **Review report.json** - Check for findings
- [ ] **Check endpoints_discovered.json** - Verify all endpoints found
- [ ] **Look for CRITICAL issues** - Fix immediately
- [ ] **Fix HIGH severity issues** - Fix within days
- [ ] **Run tests again** after fixes to verify

## 🔴 If You Find CRITICAL Issues

### AuthN Bypass (Protected endpoint returns 200)
```
❌ GET /api/appointments → 200 (should be 401)

Fix:
1. Add authentication middleware to FastAPI
2. Ensure all protected routes use Depends(get_current_user)
3. Verify JWT/token validation
```

### Hardcoded Credentials
```
❌ API_KEY=sk-1234567890abcdef in code

Fix:
1. Remove from code immediately
2. Rotate the exposed credential
3. Use environment variables (.env)
4. Add to .gitignore
5. Force push (or create new repo)
```

## 🟠 If You Find HIGH Severity Issues

### SQL Injection Detected
```
❌ SQL error in response: "SQLSyntaxError"

Fix:
1. Use parameterized queries
2. Validate all inputs
3. Escape user input
4. Run OWASP SAST on code
```

### No Input Validation
```
Fix:
1. Validate all incoming data
2. Use schema validation (Pydantic for FastAPI)
3. Reject invalid input early
```

## 🟡 If You Find MEDIUM Issues

### No Rate Limiting
```
❌ 30 requests/second accepted

Fix:
1. Install: pip install slowapi
2. Add rate limit middleware
3. Example: 100 requests/minute per IP
```

## 📁 File Structure

```
arogya_ai_backend/
├── automated_test/              # ← All DAST tests here
│   ├── input.json              # Configuration ← EDIT THIS
│   ├── run_all_tests.py        # ← RUN THIS
│   ├── report.json             # ← Output: security report
│   ├── README.md               # Full documentation
│   └── [individual test files]
├── .github/workflows/
│   └── dast-test.yml           # GitHub Actions automation
├── DAST_IMPLEMENTATION_COMPLETE.md  # Full guide
├── quickstart.py               # Interactive setup
├── verify_setup.py             # Verify setup
└── [your API files...]
```

## 🔧 Troubleshooting

**Can't connect to API?**
```bash
# Check API is running
curl http://localhost:5000/api/health

# Check firewall isn't blocking
netstat -an | grep 5000
```

**Tests timeout?**
```bash
# Your API might be slow
# Increase timeout in test files: timeout=10 → timeout=30
```

**Missing requests library?**
```bash
pip install requests
```

**Report not generated?**
```bash
# Manually generate
cd automated_test
python 07_generate_report.py
```

## 📈 Next Steps

1. **Day 1**: Run tests, review findings
2. **Day 2-3**: Fix CRITICAL issues
3. **Day 4-7**: Fix HIGH issues
4. **Weekly**: Run tests as part of CI/CD
5. **Monthly**: Review trends, security improvements

## ✨ Tips for Success

1. **Start with `03_test_authn_bypass.py`**
   - This is the most critical security issue
   - Most likely to find real vulnerabilities

2. **Keep reports for comparison**
   - Track improvements over time
   - Show progress to stakeholders

3. **Integrate with GitHub Actions**
   - Runs automatically on every push
   - Catches regressions early
   - Prevents vulnerable code from being deployed

4. **Run regularly**
   - After major code changes
   - Before each release
   - Daily in production (via GitHub Actions)

## 📞 Quick Reference

| Command | Purpose |
|---------|---------|
| `python quickstart.py` | Interactive setup |
| `python run_all_tests.py` | Run all tests |
| `python verify_setup.py` | Check setup |
| `cat report.json` | View security report |
| `curl http://localhost:5000/api/health` | Test API connection |

---

**Status**: ✅ Ready to test
**Duration**: 5-10 minutes for full test run
**Output**: `automated_test/report.json`

Now run: `python quickstart.py` to get started!
