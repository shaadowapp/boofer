@echo off
setlocal enabledelayedexpansion
REM Fixed script to push a Shorebird patch with credentials
REM Handles Windows Batch argument parsing issues with quotes

echo ========================================
echo Boofer - Shorebird Patch Deployment
echo ========================================
echo.

REM 1. Load credentials from .env.production
if not exist ".env.production" (
    echo ❌ ERROR: .env.production file not found!
    echo.
    echo Please create .env.production with:
    echo SUPABASE_URL=...
    echo SUPABASE_ANON_KEY=...
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
    echo ❌ ERROR: SUPABASE_URL not found in .env.production
    pause
    exit /b 1
)
if "%SUPABASE_ANON_KEY%"=="" (
    echo ❌ ERROR: SUPABASE_ANON_KEY not found in .env.production
    pause
    exit /b 1
)

echo ✅ Credentials loaded successfully.
echo.

REM 2. Check Shorebird status
echo 🔍 Checking Shorebird status...
call shorebird doctor
if %ERRORLEVEL% NEQ 0 (
    echo ⚠️ Shorebird doctor found issues. Attempting to continue anyway...
)

echo.
echo 🚀 Deploying Patch to existing users...
echo This will fix the "Supabase_url not configured" error for everyone!
echo.

REM 3. Run Shorebird Patch with quoted flags to prevent separator stripping
echo Command: shorebird patch android --release-version=1.1.1+11 -- "--dart-define=SUPABASE_URL=%SUPABASE_URL%" "--dart-define=SUPABASE_ANON_KEY=%SUPABASE_ANON_KEY%"
echo.

call shorebird patch android --release-version=1.1.1+11 -- "--dart-define=SUPABASE_URL=%SUPABASE_URL%" "--dart-define=SUPABASE_ANON_KEY=%SUPABASE_ANON_KEY%"

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ========================================
    echo ✅ SUCCESS! Patch pushed to Shorebird.
    echo ========================================
    echo Users will receive the fix automatically next time they open the app.
    echo.
) else (
    echo.
    echo ========================================
    echo ❌ ERROR: Patch failed!
    echo ========================================
    echo Please check the error messages above.
    echo.
)

pause
