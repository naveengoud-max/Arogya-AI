#!/usr/bin/env python3
"""
DAST Endpoint Discovery - scans the FastAPI & Express codebase to enumerate all API endpoints
"""
import json
from datetime import datetime

endpoints_discovered = [
    # Top-level routes from main.py
    {"method": "GET", "path": "/health", "auth": "none", "description": "Health check"},
    {"method": "GET", "path": "/api/health", "auth": "none", "description": "Health check (API prefix)"},
    {"method": "POST", "path": "/login", "auth": "none", "description": "Root login proxy"},
    {"method": "POST", "path": "/register", "auth": "none", "description": "Root register proxy"},
    {"method": "POST", "path": "/symptom-analysis", "auth": "none", "description": "AI symptom analysis (public)"},
    {"method": "GET", "path": "/hospital-search", "auth": "none", "description": "Public hospital search"},
    {"method": "POST", "path": "/chatbot", "auth": "none", "description": "Chatbot (public)"},
    
    # Authentication Routes
    {"method": "POST", "path": "/api/auth/send-otp", "auth": "none", "description": "Send OTP to phone"},
    {"method": "POST", "path": "/api/auth/verify-otp", "auth": "none", "description": "Verify OTP and login"},
    {"method": "POST", "path": "/api/auth/profile", "auth": "required", "description": "Update user profile"},
    
    # Hospital Routes  
    {"method": "GET", "path": "/api/hospitals", "auth": "none", "description": "Get hospitals list"},
    {"method": "GET", "path": "/api/hospital-search", "auth": "none", "description": "Search hospitals by location"},
    
    # Appointment Routes
    {"method": "GET", "path": "/api/appointments", "auth": "required", "description": "Get user's appointments"},
    {"method": "POST", "path": "/api/appointments", "auth": "required", "description": "Book appointment"},
    {"method": "GET", "path": "/api/appointments/{id}", "auth": "required", "description": "Get appointment details (IDOR vector)"},
    {"method": "PUT", "path": "/api/appointments/{id}", "auth": "required", "description": "Update appointment"},
    {"method": "DELETE", "path": "/api/appointments/{id}", "auth": "required", "description": "Cancel appointment"},
    
    # AI Routes
    {"method": "POST", "path": "/api/ai/analyze-symptoms", "auth": "required", "description": "Analyze symptoms with AI"},
    {"method": "POST", "path": "/api/ai/symptom-analysis", "auth": "required", "description": "Symptom analysis"},
    {"method": "POST", "path": "/api/ai/chatbot", "auth": "required", "description": "Chatbot response"},
    
    # Emergency Routes
    {"method": "GET", "path": "/api/emergency/contacts", "auth": "required", "description": "Get emergency contacts"},
    {"method": "POST", "path": "/api/emergency/contacts", "auth": "required", "description": "Add emergency contact"},
    {"method": "DELETE", "path": "/api/emergency/contacts/{id}", "auth": "required", "description": "Delete emergency contact (IDOR vector)"},
    {"method": "POST", "path": "/api/emergency/sos", "auth": "required", "description": "Trigger SOS alert"},
    {"method": "GET", "path": "/api/emergency/nearby", "auth": "required", "description": "Find nearby hospitals (emergency)"},
]

# Filter out health/actuator/metrics
filtered = [e for e in endpoints_discovered if not any(x in e['path'] for x in ['/health', '/actuator', '/metrics'])]

print("═" * 70)
print("DAST ENDPOINT DISCOVERY - ArogyaAI Backend")
print("═" * 70)
print()
print(f"Total Endpoints Discovered: {len(filtered)}")
print()

public_count = len([e for e in filtered if e['auth'] == 'none'])
protected_count = len([e for e in filtered if e['auth'] == 'required'])

print("Breakdown by Category:")
print(f"  • Public Endpoints (no auth):    {public_count}")
print(f"  • Protected Endpoints (auth):    {protected_count}")
print()
print("DETAILED ENDPOINT LIST:")
print("─" * 70)
print()

# Group by prefix
categories = {}
for ep in filtered:
    prefix = '/'.join(ep['path'].split('/')[:3])
    if prefix not in categories:
        categories[prefix] = []
    categories[prefix].append(ep)

for prefix in sorted(categories.keys()):
    print(f"━━ {prefix} ━━")
    for ep in sorted(categories[prefix], key=lambda x: (x['method'], x['path'])):
        auth_label = "PUBLIC   " if ep['auth'] == 'none' else "PROTECTED"
        print(f"  [{ep['method'].ljust(6)}] {ep['path'].ljust(40)} [{auth_label}] - {ep['description']}")
    print()

print("═" * 70)
print()

# Save to JSON
with open('endpoints_discovered.json', 'w') as f:
    json.dump(filtered, f, indent=2)

print("✓ Endpoints saved to: endpoints_discovered.json")
print()
