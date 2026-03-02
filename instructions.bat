@echo off
setlocal enabledelayedexpansion
title Boofer Command Center 🚀

:: ======================================================
::               BOOFER COMMAND CENTER 🚀
::      "Think twice, code once, release rarely."
:: ======================================================

:: --- STATIC CONFIG ---
:: These keys are injected into every build automatically. 
:: You don't need to enter them manually anymore.
set SUPABASE_URL=https://fvjdohkfaxomtosiibua.supabase.co
set SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ2amRvaGtmYXhvbXRvc2lpYnVhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzA5MDM3NDgsImV4cCI6MjA4NjQ3OTc0OH0.TNcqAUqLFPWpfYI-6RZjVQ25eyXGBEluzTd9Ps-RRXs

:: --- LANGUAGE FIXES ---
chcp 65001 > nul
set LANG=en_US.UTF-8
set LC_ALL=en_US.UTF-8

:MENU
cls
echo.
echo  ==============================================================
echo                BOOFER DEVELOPER DASHBOARD ⚡
echo  ==============================================================
echo.
echo   PHASE 1: SAFE ZONE (Local Testing - Unlimited Runs)
echo   --------------------------------------------------------------
echo   [1] Local Debug Mode    - Fastest. Uses Hot Reload. (FOR CODING)
echo   [2] Local Release Mode  - Test exactly like Play Store. (FOR QA)
echo                             *No Shorebird usage. Safe to run 100x.*
echo.
echo   PHASE 2: SHOREBIRD ZONE (Uses Cloud Storage/Quota)
echo   --------------------------------------------------------------
echo   [3] Cloud Preview       - Download a specific release from cloud.
echo   [4] Cloud Patch         - Push emergency fixes to all users.
echo                             *Use only after checking with Option [2].*
echo.
echo   PHASE 3: STORE ZONE (Official App Store)
echo   --------------------------------------------------------------
echo   [5] Build New Release   - Generate NEW .AAB for Play Store.
echo                             *Required for major version bumps + Shorebird.*
echo   [6] Fastlane Upload     - Push generated build to Play Console.
echo.
echo   [7] Exit
echo.
echo  ==============================================================
set /p choice="Select your current mission (1-7): "

if "%choice%"=="1" goto CMD_DEBUG
if "%choice%"=="2" goto CMD_LOCAL_RELEASE
if "%choice%"=="3" goto CMD_RUN_SHOREBIRD
if "%choice%"=="4" goto CMD_PATCH
if "%choice%"=="5" goto CMD_RELEASE
if "%choice%"=="6" goto CMD_FASTLANE
if "%choice%"=="7" exit
goto MENU

:: --- UTILITY ---
:REMIND_UNINSTALL
echo.
echo 🛑 STOP! Have you uninstalled Boofer from your device?
echo If you are switching between Debug and Release/Shorebird, 
echo the app will fail to install due to signature conflicts.
set /p confirm="App uninstalled? (y/n): "
if /i "%confirm%" neq "y" goto MENU
goto :eof

:: --- COMMANDS ---

:CMD_DEBUG
call :REMIND_UNINSTALL
echo.
echo [DEBUG MODE] 🛠 Starting Boofer with Hot Reload...
echo This is the 100%% safe way to code and test UI.
flutter run --debug --dart-define="SUPABASE_URL=%SUPABASE_URL%" --dart-define="SUPABASE_ANON_KEY=%SUPABASE_ANON_KEY%"
pause
goto MENU

:CMD_LOCAL_RELEASE
call :REMIND_UNINSTALL
echo.
echo [LOCAL RELEASE TEST] 🏎 Running optimized build on your device...
echo This tests performance, database caching, and minification.
echo **NOTE**: This does NOT use Shorebird cloud or quota.
flutter run --release --dart-define="SUPABASE_URL=%SUPABASE_URL%" --dart-define="SUPABASE_ANON_KEY=%SUPABASE_ANON_KEY%"
pause
goto MENU

:CMD_RUN_SHOREBIRD
call :REMIND_UNINSTALL
echo.
echo [CLOUD PREVIEW] 🕵️ Fetching releases from Shorebird...
shorebird preview android
pause
goto MENU

:CMD_PATCH
echo.
echo 🚨 WARNING: YOU ARE ABOUT TO PUSH LIVE CODE TO ALL USERS.
echo Have you tested these changes using Option [2] (Local Release)?
set /p pconfirm="Type 'PATCH' to confirm cloud push: "
if "%pconfirm%" neq "PATCH" goto MENU
echo.
echo 🚀 Sending Patch to Shorebird servers...
shorebird patch android -- --dart-define="SUPABASE_URL=%SUPABASE_URL%" --dart-define="SUPABASE_ANON_KEY=%SUPABASE_ANON_KEY%"
pause
goto MENU

:CMD_RELEASE
echo.
echo 📦 Building Official App Bundle (.aab)...
echo This is for the Google Play Console the Shorebird Cloud.
shorebird release android -- --dart-define="SUPABASE_URL=%SUPABASE_URL%" --dart-define="SUPABASE_ANON_KEY=%SUPABASE_ANON_KEY%"
pause
goto MENU

:CMD_FASTLANE
echo.
echo 🏁 Syncing with Play Store Console via Fastlane...
if not exist "android\fastlane\google-play-key.json" (
    echo ❌ ERROR: google-play-key.json missing in android\fastlane\
    pause
    goto MENU
)
pushd android
fastlane internal
popd
pause
goto MENU
