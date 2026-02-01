# Firebase Troubleshooting Guide

## Current Issues Analysis

Based on your logs and code analysis, here are the main issues preventing data from storing in Firebase:

### 1. Missing Firestore Indexes ❌
**Error:** `The query requires an index`

**Solution:** Create the required composite indexes:

#### For Conversations Query:
```
https://console.firebase.google.com/v1/r/project/boofer-chat/firestore/indexes?create_composite=ClFwcm9qZWN0cy9ib29mZXItY2hhdC9kYXRhYmFzZXMvKGRlZmF1bHQpL2NvbGxlY3Rpb25Hcm91cHMvY29udmVyc2F0aW9ucy9pbmRleGVzL18QARoQCgxwYXJ0aWNpcGFudHMYARoNCgl1cGRhdGVkQXQQAhoMCghfX25hbWVfXxAC
```

#### For Connection Requests Query:
```
https://console.firebase.google.com/v1/r/project/boofer-chat/firestore/indexes?create_composite=Cldwcm9qZWN0cy9ib29mZXItY2hhdC9kYXRhYmFzZXMvKGRlZmF1bHQpL2NvbGxlY3Rpb25Hcm91cHMvY29ubmVjdGlvbl9yZXF1ZXN0cy9pbmRleGVzL18QARoKCgZzdGF0dXMQARoMCgh0b1VzZXJJZBABGgoKBnNlbnRBdBACGgwKCF9fbmFtZV9fEAI
```

### 2. User Profile Creation Flow Issue ⚠️
**Problem:** User profiles are created locally but may not sync to Firebase properly.

**Root Cause:** The Firebase user creation happens in `OnboardingController._createFirebaseUser()` but errors are caught and ignored.

### 3. Firebase Rules May Block Writes 🔒
**Current Rules:** Allow all access (should work for testing)

## Step-by-Step Troubleshooting

### Step 1: Verify Firebase Configuration ✅

Your `google-services.json` looks correct:
- Project ID: `boofer-chat` ✅
- Package name: `com.shaadow.boofer.android` ✅

### Step 2: Test Firebase Connection

1. **Add Debug Route to Your App:**
   - I've added a debug screen to your `main.dart`
   - Navigate to `/firebase-debug` in your app to run diagnostics

2. **Run Firebase Tests:**
   ```dart
   // In your app, navigate to the debug screen or run:
   await FirebaseDebugTest.runFullDiagnostics();
   ```

### Step 3: Create Missing Indexes

**Option A: Click the Auto-Generated Links (Recommended)**
1. Click the index creation links above
2. They will take you directly to Firebase Console with pre-filled index configuration
3. Click "Create Index" and wait for completion

**Option B: Manual Index Creation**
1. Go to [Firebase Console](https://console.firebase.google.com/project/boofer-chat/firestore/indexes)
2. Click "Create Index"
3. Create these indexes:

**Conversations Index:**
- Collection: `conversations`
- Fields:
  - `participants` (Array-contains)
  - `updatedAt` (Descending)

**Connection Requests Index:**
- Collection: `connection_requests`
- Fields:
  - `status` (Ascending)
  - `toUserId` (Ascending)
  - `sentAt` (Descending)

### Step 4: Update Firestore Rules (Temporary)

Go to Firebase Console → Firestore → Rules and use:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Temporary: Allow all access for debugging
    match /{document=**} {
      allow read, write: if true;
    }
  }
}
```

### Step 5: Test User Creation Flow

1. **Clear App Data:**
   ```bash
   flutter clean
   flutter pub get
   ```

2. **Run the App and Create a New User:**
   - Go through onboarding
   - Watch the logs for Firebase creation messages

3. **Check Firebase Console:**
   - Go to Firestore Database
   - Look for `users` collection
   - Verify your user profile appears

### Step 6: Debug with Test Screen

1. **Navigate to Debug Screen:**
   - In your app, manually navigate to `/firebase-debug`
   - Or add a button to access it

2. **Run Diagnostics:**
   - Click "Run Full Diagnostics"
   - Watch the output for specific errors

3. **Run User Creation Test:**
   - Click "Test User Creation"
   - This will test the exact flow your app uses

## Common Issues and Solutions

### Issue: "PERMISSION_DENIED" Errors
**Solution:** 
- Verify Firestore rules allow writes
- Check that Firebase Auth is working
- Ensure user is authenticated before writing

### Issue: "Failed to get service from broker"
**Solution:**
- This is a Google Play Services issue on emulator
- Ignore this error - it doesn't affect Firestore
- Test on real device if possible

### Issue: Index Creation Takes Time
**Solution:**
- Indexes can take 5-15 minutes to build
- Check index status in Firebase Console
- App will work once indexes are ready

### Issue: Network/Offline Issues
**Solution:**
- Firebase has offline persistence enabled
- Data will sync when connection is restored
- Check device internet connection

## Verification Checklist

After following the steps above, verify:

- [ ] Firebase indexes are created and active
- [ ] Firestore rules allow all access (temporarily)
- [ ] App can create anonymous users
- [ ] User profiles appear in Firestore console
- [ ] No more index-related errors in logs
- [ ] Debug tests pass successfully

## Next Steps After Fixing

1. **Test Real User Flow:**
   - Create a new user account
   - Verify profile appears in Firebase Console
   - Test user search functionality

2. **Test Messaging:**
   - Send messages between users
   - Verify messages appear in Firestore

3. **Restore Secure Rules:**
   - Replace temporary rules with production rules
   - Test that authenticated users can still access their data

## Debug Commands

```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter run

# Check Firebase CLI (if installed)
firebase projects:list
firebase firestore:indexes

# View app logs
flutter logs
```

## Firebase Console Links

- [Project Overview](https://console.firebase.google.com/project/boofer-chat)
- [Firestore Database](https://console.firebase.google.com/project/boofer-chat/firestore)
- [Firestore Rules](https://console.firebase.google.com/project/boofer-chat/firestore/rules)
- [Firestore Indexes](https://console.firebase.google.com/project/boofer-chat/firestore/indexes)
- [Authentication](https://console.firebase.google.com/project/boofer-chat/authentication)

## Contact Support

If issues persist after following this guide:
1. Run the debug tests and capture the output
2. Check Firebase Console for any error messages
3. Verify network connectivity and Firebase project status