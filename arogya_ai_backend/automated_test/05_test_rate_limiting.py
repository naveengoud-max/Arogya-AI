#!/usr/bin/env python3
"""
TEST CATEGORY 4: Rate Limiting Assessment
Checks if API enforces rate limits on endpoints
"""
import json
import requests
import time
from datetime import datetime
from typing import List
import threading

class TestResult:
    def __init__(self, endpoint: str, burst_count: int, results_dict: dict, note: str):
        self.endpoint = endpoint
        self.burst_count = burst_count
        self.status_codes = results_dict.get('status_codes', [])
        self.avg_time_ms = results_dict.get('avg_time_ms', 0)
        self.has_rate_limit = 429 in self.status_codes or 503 in self.status_codes
        self.finding = not self.has_rate_limit  # Finding = NO rate limit
        self.severity = 'MEDIUM' if self.finding else 'INFO'
        self.note = note
        self.category = 'Rate Limiting'
        self.timestamp = datetime.now().isoformat()
    
    def to_dict(self):
        return {
            'endpoint': self.endpoint,
            'method': 'GET',
            'role': 'anonymous',
            'status': 200,
            'expected_status': 429,
            'finding': self.finding,
            'severity': self.severity,
            'response_time_ms': self.avg_time_ms,
            'test_category': self.category,
            'note': self.note,
            'burst_count': self.burst_count,
            'status_codes_received': self.status_codes,
            'timestamp': self.timestamp
        }

def rate_limit_burst(url: str, burst_count: int = 30) -> dict:
    """Send rapid requests to an endpoint and collect responses"""
    status_codes = []
    times = []
    
    for i in range(burst_count):
        try:
            start = time.time()
            response = requests.get(url, timeout=5)
            elapsed = (time.time() - start) * 1000
            
            status_codes.append(response.status_code)
            times.append(elapsed)
        except:
            status_codes.append(0)
            times.append(0)
        
        # Small delay between requests
        time.sleep(0.05)
    
    return {
        'status_codes': status_codes,
        'avg_time_ms': sum(times) / len(times) if times else 0,
        'min_status': min(status_codes) if status_codes else 0,
        'max_status': max(status_codes) if status_codes else 0,
    }

def test_rate_limiting(config: dict) -> List[TestResult]:
    """Test rate limiting on public endpoints"""
    results = []
    base_url = config['baseUrl']
    
    endpoints_to_test = [
        '/health',
        '/hospitals',
        '/hospital-search',
    ]
    
    print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("TEST CATEGORY 4: Rate Limiting Assessment")
    print("Sending burst of requests to detect rate limiting")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    
    for path in endpoints_to_test:
        url = f"{base_url}{path}"
        print(f"\nBurst testing: {path}")
        print(f"  Sending 30 requests...", end='', flush=True)
        
        burst_result = rate_limit_burst(url, burst_count=30)
        
        has_limit = burst_result['max_status'] in [429, 503]
        symbol = "✓" if has_limit else "⚠️ "
        
        note = f"Status range: {burst_result['min_status']}-{burst_result['max_status']}, "
        note += f"Avg time: {burst_result['avg_time_ms']:.0f}ms"
        if not has_limit:
            note += " [NO RATE LIMIT DETECTED]"
        
        result = TestResult(
            endpoint=path,
            burst_count=30,
            results_dict=burst_result,
            note=note
        )
        results.append(result)
        
        print(f"\r  {symbol} {path.ljust(30)} → Codes: {burst_result['min_status']}-{burst_result['max_status']} | Avg: {burst_result['avg_time_ms']:.0f}ms")
    
    return results

if __name__ == '__main__':
    with open('input.json', 'r') as f:
        config = json.load(f)
    
    results = test_rate_limiting(config)
    
    with open('test_results_rate_limiting.json', 'w') as f:
        json.dump([r.to_dict() for r in results], f, indent=2)
    
    unprotected = [r for r in results if r.finding]
    print(f"\n\nRate Limiting Tests: {len(results)}, Endpoints without limits: {len(unprotected)}")
    if unprotected:
        print("\n⚠️  Rate limiting NOT enforced on:")
        for r in unprotected:
            print(f"   - {r.endpoint}")
