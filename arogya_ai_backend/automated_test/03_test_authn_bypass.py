#!/usr/bin/env python3
"""
TEST CATEGORY 2: AuthN Bypass Detection
Tests if protected endpoints reject unauthenticated requests
Vulnerability if: protected endpoint returns 2xx without auth
"""
import json
import requests
import time
from datetime import datetime
from typing import List

class TestResult:
    def __init__(self, endpoint: str, method: str, status: int, expected: int, 
                 response_time_ms: float, note: str):
        self.endpoint = endpoint
        self.method = method
        self.status = status
        self.expected = expected  # Should be 401/403
        self.is_finding = status not in [401, 403] and status < 500  # 2xx = BYPASS
        self.response_time_ms = response_time_ms
        self.note = note
        self.severity = 'CRITICAL' if self.is_finding else 'INFO'
        self.category = 'AuthN Bypass Detection'
        self.timestamp = datetime.now().isoformat()
    
    def to_dict(self):
        return {
            'endpoint': self.endpoint,
            'method': self.method,
            'role': 'unauthenticated',
            'status': self.status,
            'expected_status': self.expected,
            'finding': self.is_finding,
            'severity': self.severity,
            'response_time_ms': self.response_time_ms,
            'test_category': self.category,
            'note': self.note,
            'timestamp': self.timestamp
        }

def test_authn_bypass(config: dict) -> List[TestResult]:
    """Test protected endpoints without authentication"""
    results = []
    base_url = config['baseUrl']
    
    protected_endpoints = [
        {'method': 'GET', 'path': '/auth/profile'},
        {'method': 'GET', 'path': '/appointments'},
        {'method': 'POST', 'path': '/appointments', 'payload': {}},
        {'method': 'GET', 'path': '/appointments/fake-id'},
        {'method': 'GET', 'path': '/emergency/contacts'},
        {'method': 'POST', 'path': '/emergency/contacts', 'payload': {}},
        {'method': 'GET', 'path': '/emergency/nearby', 'params': {'lat': 12.9, 'lng': 77.6}},
        {'method': 'POST', 'path': '/ai/analyze-symptoms', 'payload': {'symptoms': 'fever'}},
    ]
    
    print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("TEST CATEGORY 2: AuthN Bypass Detection")
    print("Testing: Can protected endpoints be accessed WITHOUT authentication?")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    
    for ep in protected_endpoints:
        url = f"{base_url}{ep['path']}"
        method = ep['method']
        
        try:
            start = time.time()
            
            if method == 'GET':
                params = ep.get('params')
                response = requests.get(url, params=params, timeout=10)
            elif method == 'POST':
                headers = {'Content-Type': 'application/json'}
                payload = ep.get('payload', {})
                response = requests.post(url, json=payload, headers=headers, timeout=10)
            
            elapsed_ms = (time.time() - start) * 1000
            status_code = response.status_code
            
            result = TestResult(
                endpoint=ep['path'],
                method=method,
                status=status_code,
                expected=401,
                response_time_ms=elapsed_ms,
                note=f"Returned {status_code} (should reject with 401/403)"
            )
            results.append(result)
            
            if result.is_finding:
                print(f"🔴 CRITICAL {method.ljust(6)} {ep['path'].ljust(40)} → {status_code} [AUTHN BYPASS!]")
            else:
                print(f"✓ {method.ljust(6)} {ep['path'].ljust(40)} → {status_code} [OK]")
            
        except Exception as e:
            print(f"✗ ERROR {method.ljust(6)} {ep['path'].ljust(40)} → {str(e)[:50]}")
            result = TestResult(
                endpoint=ep['path'],
                method=method,
                status=0,
                expected=401,
                response_time_ms=0,
                note=f"Exception: {str(e)[:100]}"
            )
            results.append(result)
    
    return results

if __name__ == '__main__':
    with open('input.json', 'r') as f:
        config = json.load(f)
    
    results = test_authn_bypass(config)
    
    with open('test_results_authn_bypass.json', 'w') as f:
        json.dump([r.to_dict() for r in results], f, indent=2)
    
    findings = [r for r in results if r.is_finding]
    print(f"\nAuthN Tests: {len(results)}, Bypass Vulnerabilities Found: {len(findings)}")
    if findings:
        print("\n⚠️  CRITICAL: AuthN bypass detected on protected endpoints!")
        for f in findings:
            print(f"   - {f.endpoint} [{f.status}]")
