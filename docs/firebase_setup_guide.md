# Firebase Setup Guide for Boofer

## Step 1: Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Create a project"
3. Name it "Boofer Chat" 
4. Disable Google Analytics (for privacy)
5. Click "Create project"

## Step 2: Add Android App

1. Click "Add app" → Android
2. Android package name: `com.example.boofer` (or your package name)
3. App nickname: "Boofer Android"
4. Download `google-services.json`
5. Place it in `android/app/google-services.json`

## Step 3: Add iOS App (if needed)

1. Click "Add app" → iOS
2. iOS bundle ID: `com.example.boofer` (or your bundle ID)
3. App nickname: "Boofer iOS"
4. Download `GoogleService-Info.plist`
5. Place it in `ios/Runner/GoogleService-Info.plist`

## Step 4: Configure Android (Kotlin DSL)

Your project uses Kotlin DSL, so the configuration is slightly different.

Add to `android/build.gradle.kts` (at the top):
```kotlin
buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.google.gms:google-services:4.3.15")
    }
}
```

Add to `android/app/build.gradle.kts`:
```kotlin
plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")  // Add this line
}

android {
    defaultConfig {
        minSdk = 21  // Required for Firebase
        multiDexEnabled = true  // Required for Firebase
    }
}

dependencies {
    implementation("androidx.multidex:multidex:2.0.1")
}
```

## Step 5: Enable Firebase Services

In Firebase Console:

### Authentication
1. Go to Authentication → Sign-in method
2. Enable "Anonymous" authentication
3. This allows users to sign in without email/password for privacy

### Firestore Database
1. Go to Firestore Database
2. Click "Create database"
3. Start in "test mode" (we'll add security rules later)
4. Choose a location close to your users

### Security Rules (Important!)
Replace the default Firestore rules with:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can read/write their own profile
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
      // Allow reading discoverable profiles
      allow read: if resource.data.isDiscoverable == true;
    }
    
    // Messages - users can only access their own conversations
    match /conversations/{conversationId}/messages/{messageId} {
      allow read, write: if request.auth != null && 
        request.auth.uid in resource.data.participants;
    }
    
    // Conversations - users can only access conversations they're part of
    match /conversations/{conversationId} {
      allow read, write: if request.auth != null && 
        request.auth.uid in resource.data.participants;
    }
    
    // Connection requests
    match /connection_requests/{requestId} {
      allow read, write: if request.auth != null && 
        (request.auth.uid == resource.data.fromUserId || 
         request.auth.uid == resource.data.toUserId);
    }
    
    // Friends - users can read/write their own friendships
    match /friends/{friendshipId} {
      allow read, write: if request.auth != null && 
        (request.auth.uid == resource.data.userId || 
         request.auth.uid == resource.data.friendId);
    }
  }
}
```

## Step 6: Update Main.dart

Add Firebase initialization:

```dart
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp();
  
  print('Starting beautiful Boofer app...');
  
  runApp(const BooferApp());
}
```

## Step 7: Test Firebase Connection

Run this test to verify Firebase is working:

```dart
// Add to any screen for testing
import 'package:cloud_firestore/cloud_firestore.dart';

void testFirebase() async {
  try {
    await FirebaseFirestore.instance.collection('test').add({
      'message': 'Hello Firebase!',
      'timestamp': DateTime.now(),
    });
    print('Firebase connection successful!');
  } catch (e) {
    print('Firebase connection failed: $e');
  }
}
```

## Step 8: Run the App

```bash
flutter pub get
flutter run
```

## Troubleshooting

### Common Issues:

1. **Build fails on Android**: Make sure `minSdkVersion` is at least 21
2. **Firebase not initialized**: Check that `Firebase.initializeApp()` is called in main()
3. **Permission denied**: Check Firestore security rules
4. **Network issues**: Make sure device has internet connection

### Debug Commands:
```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter run

# Check Firebase configuration
flutter packages pub run firebase_core:configure
```

## Next Steps

Once Firebase is set up:

1. Test user registration with virtual numbers
2. Test real-time messaging between devices
3. Test global user search functionality
4. Add push notifications for new messages
5. Implement offline message queuing

Your app will now have:
- ✅ Real-time messaging
- ✅ Global user discovery
- ✅ Offline message queuing
- ✅ Privacy-focused authentication
- ✅ Scalable backend infrastructure