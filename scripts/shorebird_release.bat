@echo off
setlocal enabledelayedexpansion
REM Script to create a Shorebird release for the Play Store
REM Fixed argument parsing for Windows Batch

echo ========================================
echo Boofer - Shorebird Full Release (AAB)
echo ========================================
echo.
echo Use this script when you need to upload a NEW version to Google Play.
echo For code-only fixes, use push_shadow_patch.bat instead.
echo.

REM 1. Load credentials from .env.production
if not exist ".env.production" (
    echo ❌ ERROR: .env.production file not found!
    echo.
    pause
    exit /b 1
)

set SUPABASE_URL=
set SUPABASE_ANON_KEY=

for /f "usebackq tokens=1,2 delims==" %%a in (".env.production") do (
    set "key=%%a"
    set "val=%%b"
    if "!key!"=="SUPABASE_URL" set "SUPABASE_URL=!val!"
    if "!key!"=="SUPABASE_ANON_KEY" set "SUPABASE_ANON_KEY=!val!"
)

if "%SUPABASE_URL%"=="" (
    echo ❌ ERROR: SUPABASE_URL missing in .env.production
    pause
    exit /b 1
)

echo ✅ Credentials loaded.
echo.

REM 2. Run Shorebird Release
echo 🚀 Creating Shorebird Release (Android)...
echo This will generate an AAB file for the Play Store.
echo.

call shorebird release android -- "--dart-define=SUPABASE_URL=%SUPABASE_URL%" "--dart-define=SUPABASE_ANON_KEY=%SUPABASE_ANON_KEY%"

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ========================================
    echo ✅ SUCCESS! Release created in Shorebird.
    echo ========================================
    echo.
    echo Next Steps:
    echo 1. Find the AAB in build/app/outputs/bundle/release/
    echo 2. Upload it to the Google Play Console
    echo.
) else (
    echo.
    echo ========================================
    echo ❌ ERROR: Release failed!
    echo ========================================
    echo Please check the output above.
)

pause
