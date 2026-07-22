#!/usr/bin/env python3
"""
DAST Test Suite - Main Test Runner
Orchestrates all security tests against the API
"""
import json
import os
import sys
import time
from datetime import datetime

# Test results accumulator
test_results = []

def load_config():
    """Load configuration from input.json"""
    if not os.path.exists('input.json'):
        print("✗ ERROR: input.json not found!")
        sys.exit(1)
    with open('input.json', 'r') as f:
        return json.load(f)

def run_test_suite():
    """Main test orchestrator"""
    config = load_config()
    base_url = config.get('baseUrl', 'http://localhost:5000/api')
    
    print("=" * 80)
    print("DAST TEST SUITE - ArogyaAI Backend Security Assessment")
    print("=" * 80)
    print(f"Target: {base_url}")
    print(f"Start Time: {datetime.now().isoformat()}")
    print()
    
    # Load discovered endpoints
    try:
        with open('endpoints_discovered.json', 'r') as f:
            endpoints = json.load(f)
    except:
        print("✗ endpoints_discovered.json not found. Run 01_discover_endpoints.py first.")
        sys.exit(1)
    
    print(f"Loaded {len(endpoints)} endpoints")
    print()
    
    # Run individual test suites
    test_suites = [
        ('02_test_public_endpoints.py', 'Public Endpoint Validation'),
        ('03_test_authn_bypass.py', 'AuthN Bypass Detection'),
        ('04_test_injection.py', 'Injection Vulnerability Probing'),
        ('05_test_rate_limiting.py', 'Rate Limiting Assessment'),
        ('06_scan_credentials.py', 'Hardcoded Credentials Scan'),
    ]
    
    print("Test Suites to Run:")
    for script, name in test_suites:
        if os.path.exists(script):
            print(f"  ✓ {name}")
        else:
            print(f"  ⚠ {name} (script not yet created)")
    print()
    print("Creating and running test suites...")
    print("-" * 80)

if __name__ == '__main__':
    run_test_suite()
