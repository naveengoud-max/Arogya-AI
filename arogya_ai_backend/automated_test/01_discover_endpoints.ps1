#!/usr/bin/env pwsh
<#
.DESCRIPTION
DAST Endpoint Discovery - scans the FastAPI & Express codebase to enumerate all API endpoints
#>

$discoveredEndpoints = @()

# Endpoints from FastAPI main.py (top-level routes)
$pythonEndpoints = @(
    @{ method="GET"; path="/health"; auth="none"; description="Health check" },
    @{ method="GET"; path="/api/health"; auth="none"; description="Health check (API prefix)" },
    @{ method="POST"; path="/login"; auth="none"; description="Root login proxy" },
    @{ method="POST"; path="/register"; auth="none"; description="Root register proxy" },
    @{ method="POST"; path="/symptom-analysis"; auth="none"; description="AI symptom analysis (public)" },
    @{ method="GET"; path="/hospital-search"; auth="none"; description="Public hospital search" },
    @{ method="POST"; path="/chatbot"; auth="none"; description="Chatbot (public)" }
)

# Authentication Routes
$authEndpoints = @(
    @{ method="POST"; path="/api/auth/send-otp"; auth="none"; description="Send OTP to phone" },
    @{ method="POST"; path="/api/auth/verify-otp"; auth="none"; description="Verify OTP" },
    @{ method="POST"; path="/api/auth/profile"; auth="required"; description="Update user profile" }
)

# Hospital Routes
$hospitalEndpoints = @(
    @{ method="GET"; path="/api/hospitals"; auth="none"; description="Get hospitals (public search)" },
    @{ method="GET"; path="/api/hospital-search"; auth="none"; description="Hospital search with location" }
)

# Appointment Routes
$appointmentEndpoints = @(
    @{ method="GET"; path="/api/appointments"; auth="required"; description="Get user's appointments" },
    @{ method="POST"; path="/api/appointments"; auth="required"; description="Book appointment" },
    @{ method="GET"; path="/api/appointments/{id}"; auth="required"; description="Get appointment details (IDOR vector)" },
    @{ method="PUT"; path="/api/appointments/{id}"; auth="required"; description="Update appointment" },
    @{ method="DELETE"; path="/api/appointments/{id}"; auth="required"; description="Cancel appointment" }
)

# AI Routes
$aiEndpoints = @(
    @{ method="POST"; path="/api/ai/analyze-symptoms"; auth="required"; description="Analyze symptoms with AI" },
    @{ method="POST"; path="/api/ai/symptom-analysis"; auth="required"; description="Symptom analysis" },
    @{ method="POST"; path="/api/ai/chatbot"; auth="required"; description="Chatbot response" }
)

# Emergency Routes
$emergencyEndpoints = @(
    @{ method="GET"; path="/api/emergency/contacts"; auth="required"; description="Get emergency contacts" },
    @{ method="POST"; path="/api/emergency/contacts"; auth="required"; description="Add emergency contact" },
    @{ method="DELETE"; path="/api/emergency/contacts/{id}"; auth="required"; description="Delete emergency contact (IDOR vector)" },
    @{ method="POST"; path="/api/emergency/sos"; auth="required"; description="Trigger SOS" },
    @{ method="GET"; path="/api/emergency/nearby"; auth="required"; description="Find nearby hospitals (emergency)" }
)

$allEndpoints = @(
    $pythonEndpoints
    $authEndpoints
    $hospitalEndpoints
    $appointmentEndpoints
    $aiEndpoints
    $emergencyEndpoints
) | Where-Object { $_ }

$filtered = $allEndpoints | Where-Object { $_.path -notmatch "(health|actuator|metrics)" }

Write-Host "═══════════════════════════════════════════════════════════════"
Write-Host "DAST ENDPOINT DISCOVERY - ArogyaAI Backend"
Write-Host "═══════════════════════════════════════════════════════════════"
Write-Host ""
Write-Host "Total Endpoints Discovered: $($filtered.Count)"
Write-Host ""
Write-Host "Breakdown by Category:"
Write-Host "  • Public Endpoints:     $(($filtered | ? { $_.auth -eq 'none' }).Count)"
Write-Host "  • Protected (Auth):     $(($filtered | ? { $_.auth -eq 'required' }).Count)"
Write-Host ""
Write-Host "DETAILED ENDPOINT LIST:"
Write-Host "─────────────────────────────────────────────────────────────"
Write-Host ""

$grouped = $filtered | Group-Object { $_.path -split '/' | Select-Object -First 3 -join '/' }

foreach ($group in $grouped | Sort-Object Name) {
    Write-Host "━━ $($group.Name) ━━"
    foreach ($ep in $group.Group | Sort-Object method, path) {
        $auth_label = if ($ep.auth -eq "none") { "PUBLIC   " } else { "PROTECTED" }
        Write-Host "  [$($ep.method.PadRight(6))] $($ep.path.PadRight(40)) [$auth_label] - $($ep.description)"
    }
    Write-Host ""
}

Write-Host "═══════════════════════════════════════════════════════════════"
Write-Host "Next: Create input.json with baseUrl and role tokens"
Write-Host "═══════════════════════════════════════════════════════════════"

$filtered | ConvertTo-Json | Out-File -Path "endpoints_discovered.json"
Write-Host "✓ Endpoints saved to: endpoints_discovered.json"
