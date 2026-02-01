# Quick Firebase Setup Fix

## The Issue
Your Android project uses Kotlin DSL (`.gradle.kts` files) but the initial setup was for Groovy DSL. I've fixed the configuration.

## What I Fixed

### 1. Updated `android/build.gradle.kts`
- Moved `buildscript` to the top with repositories
- Added Google Services classpath with proper repositories

### 2. Updated `android/app/build.gradle.kts`
- Added `com.google.gms.google-services` plugin
- Set `minSdk = 21` (required for Firebase)
- Added `multiDexEnabled = true`
- Added multidex dependency

## Next Steps

### 1. Get your `google-services.json` file:
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create a new project (or use existing)
3. Add Android app with package name: `com.shaadow.boofer.android`
4. Download `google-services.json`
5. Place it in `android/app/google-services.json`

### 2. Test the build:
```bash
flutter clean
flutter pub get
flutter build apk --debug
```

### 3. If you get build errors:
```bash
# Clear all caches
flutter clean
cd android
./gradlew clean
cd ..
flutter pub get
flutter run
```

## Alternative: Skip Firebase for Now

If you want to test the app without Firebase first:

1. Comment out Firebase imports in `lib/main.dart`:
```dart
// import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Comment out Firebase initialization
  // await Firebase.initializeApp();
  // await SyncService.instance.initialize();
  
  print('Starting beautiful Boofer app...');
  
  runApp(const BooferApp());
}
```

2. Remove Firebase dependencies from `pubspec.yaml` temporarily
3. Test the local-only functionality first
4. Add Firebase back when ready

## Verification

Once Firebase is set up, you should see:
- No build errors
- App starts successfully
- Console shows "Firebase connection successful!" (if you add the test code)

The app will work locally without Firebase, but you'll need it for real-time messaging between devices.