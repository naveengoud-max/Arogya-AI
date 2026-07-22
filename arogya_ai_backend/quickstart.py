#!/usr/bin/env python3
"""
Quick Start - Local DAST Testing
This script makes it easy to start testing your API
"""
import json
import os
import sys

def quick_start():
    """Interactive setup wizard"""
    
    print("""
╔════════════════════════════════════════════════════════════════════════════╗
║                                                                            ║
║           🔒 ArogyaAI Backend - DAST Security Testing Suite 🔒            ║
║                                                                            ║
║                         Quick Start Configuration                         ║
║                                                                            ║
╚════════════════════════════════════════════════════════════════════════════╝
    """)
    
    print("\n📝 Please configure your test environment:\n")
    
    # Ask for base URL
    base_url = input("1. Enter API Base URL (default: http://localhost:5000/api): ").strip()
    if not base_url:
        base_url = "http://localhost:5000/api"
    
    print(f"   ✓ Target: {base_url}")
    
    # Ask about authentication
    print("\n2. Do you want to test with authentication tokens? (y/n): ", end="")
    has_auth = input().strip().lower() == 'y'
    
    tokens = {
        "admin": "",
        "doctor": "",
        "user": "",
        "anonymous": ""
    }
    
    if has_auth:
        print("\n   Enter tokens (press Enter to skip a role):\n")
        tokens['admin'] = input("   Admin Bearer token (for admin actions): ").strip()
        tokens['doctor'] = input("   Doctor Bearer token (for doctor actions): ").strip()
        tokens['user'] = input("   User Bearer token (for user actions): ").strip()
    
    # Create configuration
    config = {
        "baseUrl": base_url,
        **tokens
    }
    
    # Write to file
    os.makedirs("automated_test", exist_ok=True)
    with open("automated_test/input.json", "w") as f:
        json.dump(config, f, indent=2)
    
    print("\n✓ Configuration saved to: automated_test/input.json\n")
    
    # Display instructions
    print("════════════════════════════════════════════════════════════════════════════════")
    print("\n✅ Setup Complete! Next steps:\n")
    
    print("1️⃣  Make sure your API is running:")
    print("   npm start                    # for Node.js backend")
    print("   python -m uvicorn app.main:app --host 0.0.0.0 --port 5000  # for FastAPI\n")
    
    print("2️⃣  Run the complete DAST test suite:")
    print("   cd automated_test")
    print("   python run_all_tests.py\n")
    
    print("3️⃣  Or run individual test categories:")
    print("   python 02_test_public_endpoints.py      # Public endpoint validation")
    print("   python 03_test_authn_bypass.py          # AuthN bypass detection")
    print("   python 04_test_injection.py             # Injection vulnerability probing")
    print("   python 05_test_rate_limiting.py         # Rate limiting assessment")
    print("   python 06_scan_credentials.py           # Hardcoded credentials scan\n")
    
    print("4️⃣  Review the security report:")
    print("   cat automated_test/report.json          # Full JSON report")
    print("   cat automated_test/endpoints_discovered.json  # Discovered endpoints\n")
    
    print("════════════════════════════════════════════════════════════════════════════════")
    print("\n📖 For detailed documentation, see: automated_test/README.md")
    print("\n")

if __name__ == '__main__':
    quick_start()
