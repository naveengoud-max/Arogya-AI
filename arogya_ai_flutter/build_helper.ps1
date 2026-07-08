# PowerShell Build Helper for ArogyaAI
$tempDir = "C:\Users\knave\arogya_temp"
if (Test-Path $tempDir) {
    Write-Output "Cleaning existing temp directory..."
    Remove-Item -Recurse -Force $tempDir -ErrorAction SilentlyContinue
}

# Create temp dir
New-Item -ItemType Directory -Path $tempDir -Force

# Copy arogya_ai_flutter contents
Write-Output "Copying project files to $tempDir..."
robocopy . $tempDir /E /XD build .dart_tool .git build_old_* /XF *.apk *.log *.txt /NJH /NJS /NDL /NC /NS

# Move to temp dir and build
Write-Output "Building debug APK..."
Push-Location $tempDir
flutter clean
flutter pub get
Push-Location android
cmd.exe /c "gradlew.bat assembleDebug --stacktrace > $PSScriptRoot\gradle_build_log.txt 2>&1"
Pop-Location
Pop-Location

# Copy APK back
$apkSource = "C:\Users\knave\arogya_build\app\outputs\flutter-apk\app-debug.apk"
if (!(Test-Path $apkSource)) {
    $apkSource = "C:\Users\knave\arogya_build\app\outputs\apk\debug\app-debug.apk"
}
if (!(Test-Path $apkSource)) {
    $apkSource = "$tempDir\android\app\build\outputs\apk\debug\app-debug.apk"
}

if (Test-Path $apkSource) {
    Write-Output "APK built successfully! Copying back to workspace..."
    Copy-Item -Path $apkSource -Destination "$PSScriptRoot\arogya-ai-debug.apk" -Force
    Write-Output "SUCCESS: APK is available at: arogya-ai-debug.apk"
} else {
    Write-Error "Compilation failed. Check CMake/Gradle build logs."
}

# Clean up temp dir
Write-Output "Keeping temporary files for debugging..."
# Remove-Item -Recurse -Force $tempDir -ErrorAction SilentlyContinue
