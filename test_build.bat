@echo off
echo Cleaning build cache...
if exist ".dart_tool\flutter_build" rmdir /s /q ".dart_tool\flutter_build"
if exist "build" rmdir /s /q "build"

echo.
echo Running pub get...
flutter pub get

echo.
echo Attempting build...
flutter build apk --debug --dart-define=SUPABASE_URL=https://fvjdohkfaxomtosiibua.supabase.co --dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ2amRvaGtmYXhvbXRvc2lpYnVhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzA5MDM3NDgsImV4cCI6MjA4NjQ3OTc0OH0.TNcqAUqLFPWpfYI-6RZjVQ25eyXGBEluzTd9Ps-RRXs

echo.
echo Build complete!
pause
