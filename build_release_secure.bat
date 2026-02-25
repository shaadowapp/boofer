@echo off
REM Secure Release Build Script for Boofer
REM This script builds the app with environment variables for sensitive credentials

echo ========================================
echo Boofer - Secure Release Build
echo ========================================
echo.

REM Check if credentials file exists
if not exist ".env.production" (
    echo ERROR: .env.production file not found!
    echo.
    echo Please create .env.production with:
    echo SUPABASE_URL=https://your-project.supabase.co
    echo SUPABASE_ANON_KEY=your-anon-key-here
    echo.
    pause
    exit /b 1
)

REM Load environment variables from .env.production
for /f "tokens=1,2 delims==" %%a in (.env.production) do (
    if "%%a"=="SUPABASE_URL" set SUPABASE_URL=%%b
    if "%%a"=="SUPABASE_ANON_KEY" set SUPABASE_ANON_KEY=%%b
)

REM Validate credentials are set
if "%SUPABASE_URL%"=="" (
    echo ERROR: SUPABASE_URL not found in .env.production
    pause
    exit /b 1
)

if "%SUPABASE_ANON_KEY%"=="" (
    echo ERROR: SUPABASE_ANON_KEY not found in .env.production
    pause
    exit /b 1
)

echo Credentials loaded from .env.production
echo Building release AAB...
echo.

REM Clean previous build
echo Cleaning previous build...
call flutter clean

REM Get dependencies
echo Getting dependencies...
call flutter pub get

REM Build release AAB with environment variables
echo Building release bundle...
call flutter build appbundle --release ^
    --target-platform=android-arm,android-arm64,android-x64 ^
    --dart-define=SUPABASE_URL=%SUPABASE_URL% ^
    --dart-define=SUPABASE_ANON_KEY=%SUPABASE_ANON_KEY%

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ========================================
    echo BUILD SUCCESSFUL!
    echo ========================================
    echo.
    echo Output: build\app\outputs\bundle\release\app-release.aab
    echo.
    echo IMPORTANT: Keep .env.production file secure!
    echo Do NOT commit it to git!
    echo.
) else (
    echo.
    echo ========================================
    echo BUILD FAILED!
    echo ========================================
    echo.
    echo Check the error messages above.
    echo.
)

pause
