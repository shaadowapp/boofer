@echo off
echo ========================================
echo Building Boofer Release APK
echo ========================================
echo.

REM Clean previous builds
echo Cleaning previous builds...
flutter clean

REM Get dependencies
echo Getting dependencies...
flutter pub get

REM Build release APK
echo.
echo Building release APK...
echo This may take a few minutes...
echo.

flutter build apk --release

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ========================================
    echo SUCCESS! Release APK built!
    echo ========================================
    echo.
    echo APK Location:
    echo %CD%\build\app\outputs\flutter-apk\app-release.apk
    echo.
    echo File size:
    dir build\app\outputs\flutter-apk\app-release.apk | findstr app-release.apk
    echo.
    echo You can install this APK on any Android device!
    echo.
) else (
    echo.
    echo ========================================
    echo ERROR: Build failed!
    echo ========================================
    echo.
    echo Please check the error messages above.
    echo.
)

pause
