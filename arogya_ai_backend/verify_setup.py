#!/usr/bin/env python3
"""
Test Suite Verification - Ensure all components are ready
"""
import os
import sys
import json

def verify_setup():
    """Verify DAST testing suite is properly set up"""
    
    print("╔════════════════════════════════════════════════════════════════════════════╗")
    print("║                    DAST Suite Setup Verification                          ║")
    print("╚════════════════════════════════════════════════════════════════════════════╝\n")
    
    required_files = [
        'automated_test/input.json',
        'automated_test/01_discover_endpoints.py',
        'automated_test/02_test_public_endpoints.py',
        'automated_test/03_test_authn_bypass.py',
        'automated_test/04_test_injection.py',
        'automated_test/05_test_rate_limiting.py',
        'automated_test/06_scan_credentials.py',
        'automated_test/07_generate_report.py',
        'automated_test/run_all_tests.py',
        'automated_test/README.md',
        '.github/workflows/dast-test.yml'
    ]
    
    print("Checking required files...\n")
    
    all_present = True
    for file_path in required_files:
        if os.path.exists(file_path):
            print(f"✓ {file_path}")
        else:
            print(f"✗ {file_path} - MISSING")
            all_present = False
    
    print("\n" + "─" * 80 + "\n")
    
    # Check Python
    print("Checking Python environment...")
    try:
        import requests
        print("✓ requests library installed")
    except ImportError:
        print("✗ requests library NOT found")
        print("   Install with: pip install requests")
        all_present = False
    
    # Check input.json
    print("\nChecking configuration...")
    if os.path.exists('automated_test/input.json'):
        try:
            with open('automated_test/input.json', 'r') as f:
                config = json.load(f)
                base_url = config.get('baseUrl')
                print(f"✓ input.json found")
                print(f"  Target API: {base_url}")
        except Exception as e:
            print(f"✗ input.json error: {e}")
            all_present = False
    else:
        print("⚠ input.json not found - run quickstart.py to configure")
    
    print("\n" + "─" * 80 + "\n")
    
    if all_present:
        print("✅ Setup verification PASSED\n")
        print("You are ready to run DAST tests!")
        print("\nNext steps:")
        print("  1. Start your API: npm start (or uvicorn app.main:app --host 0.0.0.0 --port 5000)")
        print("  2. Run tests:     cd automated_test && python run_all_tests.py")
        print("  3. Review report: cat report.json")
        return 0
    else:
        print("❌ Setup verification FAILED\n")
        print("Please fix the issues above and try again.")
        return 1

if __name__ == '__main__':
    sys.exit(verify_setup())
