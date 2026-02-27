@echo off
echo ========================================
echo Running Boofer in Release Mode (Production Test)
echo Targets: All connected devices
echo ========================================
echo.

set URL=https://fvjdohkfaxomtosiibua.supabase.co
set KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ2amRvaGtmYXhvbXRvc2lpYnVhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzA5MDM3NDgsImV4cCI6MjA4NjQ3OTc0OH0.TNcqAUqLFPWpfYI-6RZjVQ25eyXGBEluzTd9Ps-RRXs

echo Initializing app on available devices...
echo.

:: Check if any device is connected, otherwise it will show the list
flutter run --release --dart-define=SUPABASE_URL=%URL% --dart-define=SUPABASE_ANON_KEY=%KEY%

pause
