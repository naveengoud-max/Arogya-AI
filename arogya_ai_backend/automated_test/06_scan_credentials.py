#!/usr/bin/env python3
"""
TEST CATEGORY 5: Hardcoded Credentials Scanner
Scans codebase for committed secrets not covered by .gitignore
"""
import os
import json
import re
from datetime import datetime
from typing import List, Dict

class CredentialFinding:
    def __init__(self, file_path: str, line_num: int, line_content: str, 
                 secret_type: str, severity: str):
        self.file_path = file_path
        self.line_num = line_num
        self.line_content = line_content[:100]  # Truncate for safety
        self.secret_type = secret_type
        self.severity = severity
        self.category = 'Hardcoded Credentials'
        self.timestamp = datetime.now().isoformat()
    
    def to_dict(self):
        return {
            'endpoint': self.file_path,
            'method': 'N/A',
            'role': 'N/A',
            'status': 'N/A',
            'expected_status': 'N/A',
            'finding': True,
            'severity': self.severity,
            'response_time_ms': 0,
            'test_category': self.category,
            'note': f"{self.secret_type} found at line {self.line_num}: {self.line_content}",
            'file_line': f"{self.file_path}:{self.line_num}",
            'timestamp': self.timestamp
        }

# Secret patterns to search for
SECRET_PATTERNS = {
    'api_key': {
        'pattern': r'(api[_-]?key|apikey|API[_-]?KEY)\s*[=:]\s*["\']?([a-zA-Z0-9\-_]{20,})["\']?',
        'severity': 'CRITICAL'
    },
    'aws_key': {
        'pattern': r'AKIA[0-9A-Z]{16}',
        'severity': 'CRITICAL'
    },
    'private_key': {
        'pattern': r'(-----BEGIN PRIVATE KEY-----)',
        'severity': 'CRITICAL'
    },
    'password': {
        'pattern': r'(password|passwd|pwd)\s*[=:]\s*["\']([^"\']{8,})["\']',
        'severity': 'HIGH'
    },
    'jwt_secret': {
        'pattern': r'(jwt[_-]?secret|JWT[_-]?SECRET)\s*[=:]\s*["\']?([a-zA-Z0-9\-_]{20,})["\']?',
        'severity': 'HIGH'
    },
    'firebase_key': {
        'pattern': r'(firebase|firebaseConfig)["\']?\s*[=:]\s*["\']?([A-Za-z0-9\-_]{20,})["\']?',
        'severity': 'HIGH'
    },
    'db_connection': {
        'pattern': r'(mongodb|mysql|postgres|mssql)://[^@]+:[^@]+@',
        'severity': 'CRITICAL'
    },
    'oauth_token': {
        'pattern': r'(oauth|access_token|refresh_token)["\']?\s*[=:]\s*["\']([a-zA-Z0-9\-_.]{20,})["\']',
        'severity': 'HIGH'
    }
}

def scan_file(file_path: str) -> List[CredentialFinding]:
    """Scan a single file for hardcoded credentials"""
    findings = []
    
    try:
        with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
            lines = f.readlines()
    except:
        return findings
    
    for line_num, line in enumerate(lines, 1):
        # Skip comments
        if line.strip().startswith('#') or line.strip().startswith('//'):
            continue
        
        for secret_type, config in SECRET_PATTERNS.items():
            if re.search(config['pattern'], line, re.IGNORECASE):
                # Double-check it's not a variable name only
                if '=' in line or ':' in line:
                    finding = CredentialFinding(
                        file_path=file_path,
                        line_num=line_num,
                        line_content=line.strip(),
                        secret_type=secret_type,
                        severity=config['severity']
                    )
                    findings.append(finding)
    
    return findings

def scan_credentials(root_dir: str = '.') -> List[CredentialFinding]:
    """Recursively scan directory for hardcoded credentials"""
    all_findings = []
    
    # Extensions to scan
    scan_extensions = ['.py', '.js', '.json', '.env', '.yml', '.yaml', '.tf', '.sh']
    
    # Directories to skip
    skip_dirs = ['node_modules', '__pycache__', '.git', '.venv', 'venv', 'env', 'dist', 'build']
    
    print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("TEST CATEGORY 5: Hardcoded Credentials Scanner")
    print("Scanning codebase for committed secrets")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    
    scanned_files = 0
    print(f"\nScanning directory: {os.path.abspath(root_dir)}\n")
    
    for dirpath, dirnames, filenames in os.walk(root_dir):
        # Filter out skip directories
        dirnames[:] = [d for d in dirnames if d not in skip_dirs]
        
        for filename in filenames:
            # Check if file should be scanned
            if any(filename.endswith(ext) for ext in scan_extensions):
                file_path = os.path.join(dirpath, filename)
                scanned_files += 1
                
                findings = scan_file(file_path)
                if findings:
                    symbol = "🔴 FOUND"
                    print(f"{symbol} {file_path} - {len(findings)} issue(s)")
                    for finding in findings:
                        print(f"       Line {finding.line_num}: {finding.secret_type}")
                    all_findings.extend(findings)
    
    print(f"\nTotal files scanned: {scanned_files}")
    
    return all_findings

if __name__ == '__main__':
    # Scan parent directories (go up to find the actual repo root)
    scan_root = '..'
    
    findings = scan_credentials(scan_root)
    
    # Prepare results for report
    results = [f.to_dict() for f in findings]
    
    with open('test_results_credentials.json', 'w') as f:
        json.dump(results, f, indent=2)
    
    print(f"\n\nCredential Scan Complete: {len(findings)} findings")
    if findings:
        critical = [f for f in findings if f.severity == 'CRITICAL']
        high = [f for f in findings if f.severity == 'HIGH']
        print(f"\n🔴 CRITICAL: {len(critical)}")
        print(f"🟠 HIGH: {len(high)}")
        print("\n⚠️  Credentials found in codebase - review immediately!")
