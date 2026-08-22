# PowerShell Script to build ArogyaAI Flutter Android Release APK cleanly
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

Write-Host "Compiling Android Release APK in Temp Directory..." -ForegroundColor Yellow
flutter build apk --release --no-tree-shake-icons --dart-define=BACKEND_URL=https://arogya-ai-backend.onrender.com/api

Pop-Location

Write-Host "Copying compiled APK back to workspace..." -ForegroundColor Yellow
$destApkDir = "$PSScriptRoot\build\app\outputs\flutter-apk"
if (-not (Test-Path $destApkDir)) {
    New-Item -ItemType Directory -Path $destApkDir -Force
}

Copy-Item "$tempDir\build\app\outputs\flutter-apk\app-release.apk" "$destApkDir\app-release.apk" -Force

$rootWorkspace = "$PSScriptRoot\.."
$webWorkspace = "$PSScriptRoot\..\arogya_ai_web"

Copy-Item "$tempDir\build\app\outputs\flutter-apk\app-release.apk" "$rootWorkspace\app-release.apk" -Force
Copy-Item "$tempDir\build\app\outputs\flutter-apk\app-release.apk" "$rootWorkspace\arogya-ai-release.apk" -Force
Copy-Item "$tempDir\build\app\outputs\flutter-apk\app-release.apk" "$webWorkspace\app-release.apk" -Force
Copy-Item "$tempDir\build\app\outputs\flutter-apk\app-release.apk" "$webWorkspace\arogya-ai-release.apk" -Force

if (Test-Path "$destApkDir\app-release.apk") {
    Write-Host "SUCCESS: Release APK built and copied successfully!" -ForegroundColor Green
    Write-Host "APK Location: $destApkDir\app-release.apk" -ForegroundColor Cyan
} else {
    Write-Host "ERROR: APK build failed!" -ForegroundColor Red
    exit 1
}
