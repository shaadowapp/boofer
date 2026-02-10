@echo off
echo ========================================
echo Starting Boofer App
echo ========================================
echo.

echo Waiting for emulator to boot...
:wait_loop
adb shell getprop sys.boot_completed 2>nul | findstr "1" >nul
if errorlevel 1 (
    echo Still booting... waiting 5 seconds
    timeout /t 5 /nobreak >nul
    goto wait_loop
)

echo.
echo ✅ Emulator is ready!
echo.

echo Checking network connectivity...
adb shell ping -c 2 8.8.8.8 2>nul
if errorlevel 1 (
    echo ⚠️  Warning: Emulator may not have internet connectivity
    echo This will cause Google Sign-In to fail
    echo.
)

echo Starting Flutter app...
echo.
flutter run -d emulator-5554 --hot

pause
