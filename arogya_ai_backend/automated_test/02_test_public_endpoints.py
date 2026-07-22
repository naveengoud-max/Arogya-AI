#!/usr/bin/env python3
"""
TEST CATEGORY 1: Public Endpoint Validation
Tests that all public endpoints are accessible and respond correctly
"""
import json
import requests
import time
from datetime import datetime
from typing import List, Dict

class TestResult:
    def __init__(self, endpoint: str, method: str, role: str, status: int, expected: int, 
                 response_time_ms: float, severity: str, note: str, category: str):
        self.endpoint = endpoint
        self.method = method
        self.role = role
        self.status = status
        self.expected = expected
        self.is_finding = status != expected
        self.response_time_ms = response_time_ms
        self.severity = severity
        self.note = note
        self.category = category
        self.timestamp = datetime.now().isoformat()
    
    def to_dict(self):
        return {
            'endpoint': self.endpoint,
            'method': self.method,
            'role': self.role,
            'status': self.status,
            'expected_status': self.expected,
            'finding': self.is_finding,
            'severity': self.severity,
            'response_time_ms': self.response_time_ms,
            'test_category': self.category,
            'note': self.note,
            'timestamp': self.timestamp
        }

def test_public_endpoints(config: dict) -> List[TestResult]:
    """Test all public endpoints without authentication"""
    results = []
    base_url = config['baseUrl']
    
    public_endpoints = [
        {'method': 'GET', 'path': '/health', 'expected': 200, 'role': 'anonymous'},
        {'method': 'POST', 'path': '/auth/send-otp', 'expected': 400, 'role': 'anonymous', 'payload': {}},
        {'method': 'POST', 'path': '/auth/verify-otp', 'expected': 400, 'role': 'anonymous', 'payload': {}},
        {'method': 'GET', 'path': '/hospitals', 'expected': 200, 'role': 'anonymous'},
        {'method': 'GET', 'path': '/hospital-search', 'expected': 200, 'role': 'anonymous'},
    ]
    
    print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("TEST CATEGORY 1: Public Endpoint Validation")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    
    for ep in public_endpoints:
        url = f"{base_url}{ep['path']}"
        method = ep['method']
        expected_status = ep['expected']
        role = ep['role']
        
        try:
            start = time.time()
            
            if method == 'GET':
                response = requests.get(url, timeout=10)
            elif method == 'POST':
                headers = {'Content-Type': 'application/json'}
                payload = ep.get('payload', {})
                response = requests.post(url, json=payload, headers=headers, timeout=10)
            
            elapsed_ms = (time.time() - start) * 1000
            status_code = response.status_code
            
            is_finding = status_code != expected_status
            symbol = "✗ FINDING" if is_finding else "✓"
            severity = "HIGH" if is_finding else "INFO"
            
            note = f"Got {status_code}, expected {expected_status}"
            if response_time_ms > 5000:
                note += " [SLOW RESPONSE]"
                severity = "MEDIUM"
            
            result = TestResult(
                endpoint=ep['path'],
                method=method,
                role=role,
                status=status_code,
                expected=expected_status,
                response_time_ms=elapsed_ms,
                severity=severity,
                note=note,
                category='Public Endpoint Validation'
            )
            results.append(result)
            
            print(f"{symbol} {method.ljust(6)} {ep['path'].ljust(40)} → {status_code} (expected {expected_status}) [{elapsed_ms:.0f}ms]")
            
        except Exception as e:
            print(f"✗ ERROR {method.ljust(6)} {ep['path'].ljust(40)} → {str(e)[:50]}")
            result = TestResult(
                endpoint=ep['path'],
                method=method,
                role=role,
                status=0,
                expected=expected_status,
                response_time_ms=0,
                severity='HIGH',
                note=f"Exception: {str(e)[:100]}",
                category='Public Endpoint Validation'
            )
            results.append(result)
    
    return results

if __name__ == '__main__':
    with open('input.json', 'r') as f:
        config = json.load(f)
    
    results = test_public_endpoints(config)
    
    with open('test_results_public_endpoints.json', 'w') as f:
        json.dump([r.to_dict() for r in results], f, indent=2)
    
    findings = [r for r in results if r.is_finding]
    print(f"\nTests completed: {len(results)}, Findings: {len(findings)}")
