#!/usr/bin/env python3
"""
Master Test Runner - Executes all DAST tests in sequence
"""
import subprocess
import sys
import os
import json
from datetime import datetime

def run_test(script_name: str, description: str) -> bool:
    """Run a single test script"""
    print(f"\n{'='*80}")
    print(f"Running: {description}")
    print(f"Script:  {script_name}")
    print(f"{'='*80}")
    
    try:
        result = subprocess.run([sys.executable, script_name], 
                              capture_output=False, 
                              timeout=300)
        return result.returncode == 0
    except subprocess.TimeoutExpired:
        print(f"✗ TIMEOUT: {script_name}")
        return False
    except Exception as e:
        print(f"✗ ERROR: {e}")
        return False

def main():
    """Main test orchestrator"""
    
    # Verify input.json exists
    if not os.path.exists('input.json'):
        print("✗ ERROR: input.json not found!")
        print("Please create input.json with baseUrl configuration")
        sys.exit(1)
    
    print("╔" + "=" * 78 + "╗")
    print("║" + " " * 78 + "║")
    print("║" + "DAST Security Testing Suite - ArogyaAI Backend".center(78) + "║")
    print("║" + " " * 78 + "║")
    print("╚" + "=" * 78 + "╝")
    print()
    
    # Load and display config
    with open('input.json', 'r') as f:
        config = json.load(f)
    
    print("Configuration:")
    print(f"  Target URL: {config.get('baseUrl', 'Not specified')}")
    print()
    
    # Test execution plan
    tests = [
        ('01_discover_endpoints.py', '📡 Step 1: Endpoint Discovery'),
        ('02_test_public_endpoints.py', '✅ Step 2: Public Endpoint Validation'),
        ('03_test_authn_bypass.py', '🔐 Step 3: AuthN Bypass Detection'),
        ('04_test_injection.py', '💉 Step 4: Injection Vulnerability Probing'),
        ('05_test_rate_limiting.py', '⏱️  Step 5: Rate Limiting Assessment'),
        ('06_scan_credentials.py', '🔑 Step 6: Hardcoded Credentials Scan'),
        ('07_generate_report.py', '📊 Step 7: Generate Final Report'),
    ]
    
    print("Test Plan:")
    for script, desc in tests:
        print(f"  {desc}")
    print()
    
    # Run tests
    results = {}
    start_time = datetime.now()
    
    for script, description in tests:
        if not os.path.exists(script):
            print(f"⚠ SKIP: {script} not found")
            results[script] = 'SKIP'
            continue
        
        success = run_test(script, description)
        results[script] = 'PASS' if success else 'FAIL'
    
    # Final summary
    elapsed = datetime.now() - start_time
    
    print("\n" + "╔" + "=" * 78 + "╗")
    print("║ TEST EXECUTION SUMMARY".ljust(79) + "║")
    print("╚" + "=" * 78 + "╝")
    print()
    
    for script, status in results.items():
        symbol = '✓' if status == 'PASS' else ('⏭' if status == 'SKIP' else '✗')
        print(f"  {symbol} {script.ljust(30)} {status}")
    
    print()
    print(f"Total Time: {elapsed.total_seconds():.1f} seconds")
    print()
    print("📊 Full report available in: report.json")
    print()

if __name__ == '__main__':
    main()
