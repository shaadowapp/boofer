@echo off
echo ========================================
echo Building Boofer DEBUG APK (Fast Build)
echo ========================================
echo.
echo This is faster than release build!
echo Use for testing only.
echo.

echo Building debug APK...
flutter build apk --debug

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ========================================
    echo SUCCESS! Debug APK built!
    echo ========================================
    echo.
    echo APK Location:
    echo %CD%\build\app\outputs\flutter-apk\app-debug.apk
    echo.
    echo Opening folder...
    explorer build\app\outputs\flutter-apk
    echo.
    echo NOTE: This is a DEBUG build (larger size, for testing)
    echo For production, use: build_release.bat
    echo.
) else (
    echo.
    echo ERROR: Build failed!
    echo.
)

pause
