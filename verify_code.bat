@echo off
echo ========================================
echo Code Verification Script
echo ========================================
echo.

echo [1/4] Checking Flutter installation...
flutter --version
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Flutter not found!
    pause
    exit /b 1
)
echo.

echo [2/4] Running pub get...
flutter pub get
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: pub get failed!
    pause
    exit /b 1
)
echo.

echo [3/4] Running Flutter analyze...
flutter analyze --no-pub
echo.

echo [4/4] Checking new files exist...
if exist "lib\screens\send_feedback_screen.dart" (
    echo ✓ send_feedback_screen.dart found
) else (
    echo ✗ send_feedback_screen.dart NOT FOUND
)

if exist "lib\screens\report_bug_screen.dart" (
    echo ✓ report_bug_screen.dart found
) else (
    echo ✗ report_bug_screen.dart NOT FOUND
)

if exist "SUPABASE_TABLES_SETUP.md" (
    echo ✓ SUPABASE_TABLES_SETUP.md found
) else (
    echo ✗ SUPABASE_TABLES_SETUP.md NOT FOUND
)

if exist "NEW_FEATURES_GUIDE.md" (
    echo ✓ NEW_FEATURES_GUIDE.md found
) else (
    echo ✗ NEW_FEATURES_GUIDE.md NOT FOUND
)

echo.
echo ========================================
echo Verification Complete!
echo ========================================
echo.
echo If all checks passed, the code is ready.
echo The depfile error is a build cache issue.
echo Run: .\test_build.bat to clean and rebuild
echo.
pause
