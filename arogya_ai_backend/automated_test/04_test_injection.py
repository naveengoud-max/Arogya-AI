#!/usr/bin/env python3
"""
TEST CATEGORY 3: Injection Vulnerability Probing
Detection-only payloads for SQLi, NoSQLi, Command injection
Looking for anomalous responses, error messages, timing
"""
import json
import requests
import time
from datetime import datetime
from typing import List, Tuple

class TestResult:
    def __init__(self, endpoint: str, payload_type: str, payload: str, status: int, 
                 response_time_ms: float, finding: bool, note: str):
        self.endpoint = endpoint
        self.payload_type = payload_type
        self.payload = payload[:50] + "..." if len(payload) > 50 else payload
        self.status = status
        self.response_time_ms = response_time_ms
        self.is_finding = finding
        self.severity = 'MEDIUM' if finding else 'INFO'
        self.note = note
        self.category = 'Injection Probing'
        self.timestamp = datetime.now().isoformat()
    
    def to_dict(self):
        return {
            'endpoint': self.endpoint,
            'method': 'POST',
            'role': 'anonymous',
            'status': self.status,
            'expected_status': 400,
            'finding': self.is_finding,
            'severity': self.severity,
            'response_time_ms': self.response_time_ms,
            'test_category': self.category,
            'note': self.note,
            'payload_type': self.payload_type,
            'timestamp': self.timestamp
        }

# Injection test payloads
INJECTION_PAYLOADS = {
    'sql_injection': [
        "' OR '1'='1",
        "'; DROP TABLE users; --",
        "1' UNION SELECT * FROM users--",
        "admin' --",
    ],
    'nosql_injection': [
        '{"$ne": null}',
        '{"$gt": ""}',
        '{"$regex": ".*"}',
        '{" $where": "1==1"}',
    ],
    'command_injection': [
        '; cat /etc/passwd',
        '| whoami',
        '`id`',
        '$(whoami)',
    ],
    'xss_detection': [
        '<script>alert("xss")</script>',
        '"><script>alert("xss")</script>',
        'javascript:alert("xss")',
        '\'onclick="alert(\'xss\')"',
    ]
}

def test_injection(config: dict) -> List[TestResult]:
    """Test endpoints for injection vulnerabilities"""
    results = []
    base_url = config['baseUrl']
    
    vulnerable_params_endpoints = [
        {'path': '/auth/send-otp', 'param': 'phone'},
        {'path': '/hospital-search', 'param': 'type'},
        {'path': '/ai/analyze-symptoms', 'param': 'symptoms'},
    ]
    
    print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("TEST CATEGORY 3: Injection Vulnerability Probing")
    print("Detection-only: Looking for SQL, NoSQL, Command Injection")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    
    for ep in vulnerable_params_endpoints:
        print(f"\nTesting: {ep['path']}")
        
        # Test each payload type
        for payload_type, payloads in INJECTION_PAYLOADS.items():
            for payload in payloads[:2]:  # Test first 2 of each type to limit requests
                url = f"{base_url}{ep['path']}"
                
                try:
                    start = time.time()
                    headers = {'Content-Type': 'application/json'}
                    
                    # Build request with injection payload
                    data = {ep['param']: payload}
                    response = requests.post(url, json=data, headers=headers, timeout=10)
                    
                    elapsed_ms = (time.time() - start) * 1000
                    status_code = response.status_code
                    
                    # Detection heuristics
                    finding = False
                    note = ""
                    
                    # Check for SQL error strings
                    if payload_type == 'sql_injection':
                        sql_errors = ['SQL', 'syntax', 'database', 'query error', 'ORA-', 'Exception']
                        response_text = response.text.lower()
                        if any(err.lower() in response_text for err in sql_errors):
                            finding = True
                            note = "SQL error detected in response"
                        elif elapsed_ms > 5000:
                            finding = True
                            note = "Suspicious timing delay (possible SQLi)"
                    
                    # Check for NoSQL patterns
                    elif payload_type == 'nosql_injection':
                        nosql_errors = ['mongodb', 'mongo', 'collection', 'document', 'not an object']
                        if any(err.lower() in response.text.lower() for err in nosql_errors):
                            finding = True
                            note = "NoSQL error detected in response"
                    
                    # Check for command execution
                    elif payload_type == 'command_injection':
                        cmd_indicators = ['root:', 'uid=', 'bin/', 'etc/passwd', 'root@', '$user']
                        if any(ind in response.text for ind in cmd_indicators):
                            finding = True
                            note = "Command execution indicators in response"
                    
                    result = TestResult(
                        endpoint=ep['path'],
                        payload_type=payload_type,
                        payload=payload,
                        status=status_code,
                        response_time_ms=elapsed_ms,
                        finding=finding,
                        note=note if note else f"Status {status_code}"
                    )
                    results.append(result)
                    
                    symbol = "🔴" if finding else "✓"
                    print(f"  {symbol} {payload_type.ljust(18)} → {status_code} [{elapsed_ms:.0f}ms]")
                    
                except Exception as e:
                    print(f"  ✗ {payload_type.ljust(18)} → Exception: {str(e)[:40]}")
    
    return results

if __name__ == '__main__':
    with open('input.json', 'r') as f:
        config = json.load(f)
    
    results = test_injection(config)
    
    with open('test_results_injection.json', 'w') as f:
        json.dump([r.to_dict() for r in results], f, indent=2)
    
    findings = [r for r in results if r.is_finding]
    print(f"\n\nInjection Tests: {len(results)}, Suspicious Indicators: {len(findings)}")
    if findings:
        print("\n⚠️  Potential injection vulnerabilities detected:")
        for f in findings:
            print(f"   - {f.endpoint} ({f.payload_type}): {f.note}")
