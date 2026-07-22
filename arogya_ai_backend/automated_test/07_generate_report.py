#!/usr/bin/env python3
"""
Report Generator - Compiles all test results into a comprehensive DAST report
"""
import json
import glob
from datetime import datetime
from collections import defaultdict
from typing import Dict, List

def generate_report():
    """Compile all test results into final report"""
    
    print("\n" + "=" * 80)
    print("GENERATING FINAL DAST REPORT")
    print("=" * 80)
    
    all_results = []
    test_categories = {
        'test_results_public_endpoints.json': 'Public Endpoint Validation',
        'test_results_authn_bypass.json': 'AuthN Bypass Detection',
        'test_results_injection.json': 'Injection Vulnerability Probing',
        'test_results_rate_limiting.json': 'Rate Limiting Assessment',
        'test_results_credentials.json': 'Hardcoded Credentials Scan',
    }
    
    # Load all test results
    for result_file, category_name in test_categories.items():
        try:
            with open(result_file, 'r') as f:
                results = json.load(f)
                if not isinstance(results, list):
                    results = [results]
                all_results.extend(results)
                print(f"✓ Loaded {len(results)} results from {result_file}")
        except FileNotFoundError:
            print(f"⚠ {result_file} not found (skipped)")
        except Exception as e:
            print(f"✗ Error loading {result_file}: {e}")
    
    # Aggregate findings
    findings = [r for r in all_results if r.get('finding', False)]
    
    # Group by severity
    severity_groups = defaultdict(list)
    for finding in findings:
        severity = finding.get('severity', 'UNKNOWN')
        severity_groups[severity].append(finding)
    
    # Generate summary
    summary = {
        'timestamp': datetime.now().isoformat(),
        'total_tests': len(all_results),
        'total_findings': len(findings),
        'findings_by_severity': {
            'CRITICAL': len(severity_groups.get('CRITICAL', [])),
            'HIGH': len(severity_groups.get('HIGH', [])),
            'MEDIUM': len(severity_groups.get('MEDIUM', [])),
            'LOW': len(severity_groups.get('LOW', [])),
            'INFO': len(severity_groups.get('INFO', []))
        },
        'endpoints_tested': len(set(r.get('endpoint') for r in all_results)),
        'test_categories': list(test_categories.values()),
        'pass_rate': f"{(len(all_results) - len(findings)) / len(all_results) * 100:.1f}%" if all_results else "N/A"
    }
    
    # Build final report
    report = {
        'metadata': {
            'title': 'DAST Security Assessment Report',
            'description': 'Dynamic Application Security Testing Report - ArogyaAI Backend',
            'generated': datetime.now().isoformat(),
            'tool': 'Automated DAST Suite'
        },
        'summary': summary,
        'test_results': all_results,
        'findings': {
            'critical': severity_groups.get('CRITICAL', []),
            'high': severity_groups.get('HIGH', []),
            'medium': severity_groups.get('MEDIUM', []),
            'low': severity_groups.get('LOW', []),
        }
    }
    
    # Write report
    with open('report.json', 'w') as f:
        json.dump(report, f, indent=2)
    
    print("\n" + "=" * 80)
    print("DAST REPORT SUMMARY")
    print("=" * 80)
    print()
    print(f"Tests Executed:        {summary['total_tests']}")
    print(f"Endpoints Tested:      {summary['endpoints_tested']}")
    print(f"Security Findings:     {summary['total_findings']}")
    print(f"Pass Rate:             {summary['pass_rate']}")
    print()
    print("Findings by Severity:")
    print(f"  🔴 CRITICAL:         {summary['findings_by_severity']['CRITICAL']}")
    print(f"  🟠 HIGH:             {summary['findings_by_severity']['HIGH']}")
    print(f"  🟡 MEDIUM:           {summary['findings_by_severity']['MEDIUM']}")
    print(f"  🔵 LOW:              {summary['findings_by_severity']['LOW']}")
    print()
    
    # Print top findings
    if findings:
        print("=" * 80)
        print("TOP FINDINGS (Issues to Fix First)")
        print("=" * 80)
        
        for i, finding in enumerate(sorted(findings, key=lambda x: 
            {'CRITICAL': 0, 'HIGH': 1, 'MEDIUM': 2, 'LOW': 3, 'INFO': 4}.get(x.get('severity', 'INFO'), 5))[:10], 1):
            
            severity = finding.get('severity', 'UNKNOWN')
            severity_icon = {
                'CRITICAL': '🔴',
                'HIGH': '🟠',
                'MEDIUM': '🟡',
                'LOW': '🔵',
                'INFO': '⚪'
            }.get(severity, '❓')
            
            print(f"\n{i}. {severity_icon} [{severity}] {finding.get('endpoint', 'N/A')}")
            print(f"   Category: {finding.get('test_category', 'N/A')}")
            print(f"   Issue: {finding.get('note', 'No details')[:100]}")
    
    print("\n" + "=" * 80)
    print(f"Full report saved to: report.json")
    print("=" * 80)
    
    return report

if __name__ == '__main__':
    generate_report()
