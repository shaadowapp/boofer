@echo off
echo ========================================
echo Building Boofer Release APK (Optimized)
echo ========================================
echo.

REM Build with optimizations
echo Building release APK with optimizations...
echo This will take 3-5 minutes...
echo.
echo Progress indicators:
echo - Resolving dependencies...
echo - Running Gradle tasks...
echo - Building Dart code...
echo - Optimizing with R8...
echo - Packaging APK...
echo.

REM Build with verbose output to show progress
flutter build apk --release --verbose

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ========================================
    echo SUCCESS! Release APK built!
    echo ========================================
    echo.
    echo APK Location:
    echo %CD%\build\app\outputs\flutter-apk\app-release.apk
    echo.
    echo File info:
    dir build\app\outputs\flutter-apk\app-release.apk
    echo.
    echo Opening folder...
    explorer build\app\outputs\flutter-apk
    echo.
) else (
    echo.
    echo ========================================
    echo ERROR: Build failed!
    echo ========================================
    echo.
)

pause
