# Implementation Plan - Streamlined

- [x] 1. Set up Google Sign-In dependencies and configuration
  - Add google_sign_in package to pubspec.yaml
  - Configure Firebase Console for Google authentication
  - Set up Android and iOS Google Services configuration files
  - _Requirements: 1.1, 1.2_

- [ ] 2. Create minimal authentication service
- [x] 2.1 Implement GoogleAuthService with basic sign-in/out



  - Create simple GoogleAuthService class with sign-in and sign-out methods
  - Handle basic Google authentication flow
  - _Requirements: 1.1, 1.2_

- [x] 2.2 Create AuthStateProvider for state management



  - Simple ChangeNotifier to track authentication state
  - Connect Google Sign-In to app state
  - _Requirements: 1.4, 2.4_

- [ ] 3. Create basic sign-in UI
- [x] 3.1 Build simple GoogleSignInScreen




  - Basic screen with Google Sign-In button
  - Replace existing onboarding flow
  - _Requirements: 1.1, 1.5_

- [x] 3.2 Update main.dart navigation



  - Route to GoogleSignInScreen for unauthenticated users
  - Route to main app for authenticated users
  - _Requirements: 2.3, 6.2_

- [ ] 4. Update User model for Google auth
- [x] 4.1 Modify User model to use Google data



  - Add email and photoURL fields from Google
  - Remove virtual number and PIN fields
  - _Requirements: 3.1, 3.2_

- [x] 4.2 Update UserService for Firebase UID



  - Use Firebase UID as primary identifier
  - Create users from Google account data
  - _Requirements: 3.4, 3.5_

- [ ] 5. Add sign-out functionality
- [x] 5.1 Add sign-out to settings



  - Simple sign-out button in settings
  - Clear authentication and return to sign-in screen
  - _Requirements: 4.1, 4.2_

- [x] 6. Clean up legacy system




- [x] 6.1 Remove old onboarding components


  - Delete OnboardingScreen and related files
  - Remove old authentication services
  - _Requirements: 1.1, 1.5_