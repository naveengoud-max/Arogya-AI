# PowerShell Script to build ArogyaAI Flutter Web cleanly
$ErrorActionPreference = "Stop"

$tempDir = "C:\Users\knave\arogya_temp"

Write-Host "Setting up temporary build directory..." -ForegroundColor Yellow

if (Test-Path $tempDir) {
    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
}

robocopy . $tempDir /E /XD .git build .dart_tool android/build build_old_* /NJH /NJS /NDL /NC /NS

Push-Location $tempDir

Write-Host "Cleaning and Resolving Dependencies in Temp Directory..." -ForegroundColor Yellow
flutter clean
flutter pub get

Write-Host "Compiling Web Application in Release Mode for GitHub Pages..." -ForegroundColor Yellow
flutter build web --release --base-href /Arogya-AI/ --no-tree-shake-icons

Pop-Location

Write-Host "Copying compiled web build back to workspace..." -ForegroundColor Yellow
$destWebDir = "$PSScriptRoot\build\web"
if (Test-Path $destWebDir) {
    Remove-Item -Path $destWebDir -Recurse -Force -ErrorAction SilentlyContinue
}

robocopy "$tempDir\build\web" $destWebDir /E /NJH /NJS /NDL /NC /NS

$rootWorkspace = "$PSScriptRoot\.."
$arogyaWebDir = "$PSScriptRoot\..\arogya_ai_web"

Write-Host "Syncing compiled web files to arogya_ai_web and repository root..." -ForegroundColor Yellow
robocopy "$destWebDir" "$arogyaWebDir" /E /XF *.apk /NJH /NJS /NDL /NC /NS
robocopy "$destWebDir" "$rootWorkspace" /E /XF *.apk /XF *.md /XF *.rules /XD arogya_ai_flutter /XD arogya_ai_backend /XD .git /XD .github /NJH /NJS /NDL /NC /NS

if (Test-Path "$destWebDir\index.html") {
    Write-Host "SUCCESS: Web application built and synced successfully to root & arogya_ai_web!" -ForegroundColor Green
    Write-Host "Web build output location: $destWebDir" -ForegroundColor Cyan
} else {
    Write-Host "ERROR: Web build failed!" -ForegroundColor Red
    exit 1
}
