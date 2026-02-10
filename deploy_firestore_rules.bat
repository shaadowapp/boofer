@echo off
echo ========================================
echo Deploying Firestore Rules to Firebase
echo ========================================
echo.
echo Project: boofer-chat
echo Rules file: firestore.rules
echo.

REM Check if Firebase CLI is installed
where firebase >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Firebase CLI is not installed!
    echo.
    echo Please install Firebase CLI first:
    echo npm install -g firebase-tools
    echo.
    echo Then login:
    echo firebase login
    echo.
    pause
    exit /b 1
)

echo Checking Firebase login status...
firebase projects:list >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo You are not logged in to Firebase.
    echo Please login first:
    echo.
    firebase login
    pause
    exit /b 1
)

echo.
echo Deploying Firestore rules...
echo.

firebase deploy --only firestore:rules

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ========================================
    echo SUCCESS! Firestore rules deployed!
    echo ========================================
    echo.
    echo Your new privacy-focused rules are now active.
    echo Users can now signup without Firebase Auth.
    echo.
) else (
    echo.
    echo ========================================
    echo ERROR: Deployment failed!
    echo ========================================
    echo.
    echo Please check:
    echo 1. You are logged in: firebase login
    echo 2. Project exists: firebase projects:list
    echo 3. Rules syntax is correct
    echo.
)

pause
