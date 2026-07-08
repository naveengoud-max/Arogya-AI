$tempDir = "C:\Users\knave\arogya_temp"
$buildDir = "C:\Users\knave\arogya_build"

# Create temp dir if not exists
if (!(Test-Path $tempDir)) {
    New-Item -ItemType Directory -Path $tempDir -Force
}

# Copy arogya_ai_flutter contents
Write-Output "Copying project files to $tempDir..."
robocopy . $tempDir /E /XD build .dart_tool .git build_old_* /XF *.apk *.log *.txt /NJH /NJS /NDL /NC /NS

# Move to temp dir and build
Write-Output "Building release APK & Bundle..."
Push-Location $tempDir
flutter clean
flutter pub get

Write-Output "Building APK..."
flutter build apk --release --no-tree-shake-icons

Write-Output "Building App Bundle (AAB)..."
flutter build appbundle --release --no-tree-shake-icons
Pop-Location

# Copy outputs back
$apkSource = "$buildDir\app\outputs\flutter-apk\app-release.apk"
if (!(Test-Path $apkSource)) {
    $apkSource = "$buildDir\app\outputs\apk\release\app-release.apk"
}
if (!(Test-Path $apkSource)) {
    $apkSource = "$tempDir\build\app\outputs\flutter-apk\app-release.apk"
}

$aabSource = "$buildDir\app\outputs\bundle\release\app-release.aab"
if (!(Test-Path $aabSource)) {
    $aabSource = "$tempDir\build\app\outputs\bundle\release\app-release.aab"
}

if (Test-Path $apkSource) {
    Write-Output "APK built successfully! Copying back to workspace..."
    Copy-Item -Path $apkSource -Destination "$PSScriptRoot\arogya-ai-release.apk" -Force
    Write-Output "SUCCESS: APK is available at: arogya-ai-release.apk"
} else {
    Write-Error "APK compilation failed."
}

if (Test-Path $aabSource) {
    Write-Output "AAB built successfully! Copying back to workspace..."
    Copy-Item -Path $aabSource -Destination "$PSScriptRoot\arogya-ai-release.aab" -Force
    Write-Output "SUCCESS: AAB is available at: arogya-ai-release.aab"
} else {
    Write-Error "AAB compilation failed."
}

Write-Output "=== Build Process Finished ==="
