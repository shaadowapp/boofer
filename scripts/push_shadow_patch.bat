@echo off
setlocal

echo 🔍 Checking Shorebird status...
call "C:\Users\surya\.shorebird\bin\shorebird.bat" doctor
if %ERRORLEVEL% NEQ 0 (
    echo ❌ Shorebird doctor found issues. Please fix them before patching.
    exit /b %ERRORLEVEL%
)

echo 🛠️ Building and pushing Android patch...
call "C:\Users\surya\.shorebird\bin\shorebird.bat" patch android
if %ERRORLEVEL% NEQ 0 (
    echo ❌ Shorebird patch failed.
    exit /b %ERRORLEVEL%
)

echo ✅ Shorebird patch pushed successfully!
echo.
echo 📝 Tip: Update your Supabase 'config' table if you want to force a restart for users.
echo Table: public.config
echo Columns: force_restart=true, patch_notes='Your notes here'
echo.
pause
