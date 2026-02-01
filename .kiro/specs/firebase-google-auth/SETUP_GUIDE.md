# Firebase Google Authentication Setup Guide

## Firebase Console Configuration

### 1. Enable Google Sign-In Provider
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: `boofer-chat`
3. Navigate to **Authentication** > **Sign-in method**
4. Click on **Google** provider
5. Toggle **Enable** to ON
6. Set **Project support email** (required)
7. Click **Save**

### 2. Configure OAuth Consent Screen
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select project: `boofer-chat`
3. Navigate to **APIs & Services** > **OAuth consent screen**
4. Configure the consent screen with:
   - App name: `Boofer`
   - User support email: Your email
   - App logo: Upload Boofer logo (optional)
   - Authorized domains: Add your domain if applicable
5. Add scopes: `email`, `profile`, `openid`
6. Save and continue

### 3. Android Configuration
✅ **Already Configured**
- `google-services.json` is present in `android/app/`
- Google Services plugin is configured in `build.gradle.kts`
- Package name: `com.shaadow.boofer.android`

#### Additional Android Setup (if needed)
1. Get SHA-1 fingerprint:
   ```bash
   cd android
   ./gradlew signingReport
   ```
2. Add SHA-1 fingerprint to Firebase project:
   - Go to Project Settings > General
   - Select Android app
   - Add SHA-1 certificate fingerprint

### 4. iOS Configuration
❌ **Needs Setup**

#### Required Steps:
1. **Download GoogleService-Info.plist**:
   - Go to Firebase Console > Project Settings
   - Select iOS app (create if doesn't exist)
   - Bundle ID should be: `com.shaadow.boofer.ios`
   - Download `GoogleService-Info.plist`

2. **Add to iOS project**:
   - Place `GoogleService-Info.plist` in `ios/Runner/` directory
   - Add to Xcode project (drag & drop into Runner folder)

3. **Configure URL Scheme**:
   - Open `ios/Runner/Info.plist`
   - Add URL scheme from GoogleService-Info.plist:
   ```xml
   <key>CFBundleURLTypes</key>
   <array>
     <dict>
       <key>CFBundleURLName</key>
       <string>REVERSED_CLIENT_ID</string>
       <key>CFBundleURLSchemes</key>
       <array>
         <string>YOUR_REVERSED_CLIENT_ID</string>
       </array>
     </dict>
   </array>
   ```

## Testing Configuration

### Verify Setup
1. Run `flutter pub get` to install google_sign_in package
2. Test on Android device/emulator
3. Test on iOS device/simulator (after iOS setup)

### Common Issues
- **Android**: Ensure SHA-1 fingerprint is added to Firebase
- **iOS**: Ensure GoogleService-Info.plist is properly added to Xcode project
- **Both**: Verify OAuth consent screen is configured

## Security Notes
- Keep GoogleService-Info.plist and google-services.json secure
- Don't commit sensitive configuration to public repositories
- Use different Firebase projects for development/production