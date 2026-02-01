# Firebase Google Authentication Design

## Overview

This design replaces the complex multi-step onboarding system with a streamlined Firebase Google authentication flow. The new system eliminates manual user registration, PIN setup, and virtual number generation in favor of Google's secure authentication and automatic profile creation.

## Architecture

### Authentication Flow
```
App Launch → Check Auth State → Google Sign-In (if needed) → Main Screen
     ↓              ↓                    ↓                    ↓
Splash Screen → Auto Sign-In → Profile Creation → Chat Interface
```

### Key Components
- **GoogleAuthService**: Handles Google Sign-In integration
- **FirebaseAuthManager**: Manages Firebase authentication state
- **UserProfileService**: Creates and syncs user profiles
- **AuthStateProvider**: Provides authentication state to UI components

## Components and Interfaces

### 1. GoogleAuthService
```dart
class GoogleAuthService {
  Future<GoogleSignInAccount?> signInWithGoogle();
  Future<void> signOut();
  Future<bool> isSignedIn();
  GoogleSignInAccount? get currentUser;
}
```

**Responsibilities:**
- Handle Google Sign-In flow
- Manage Google authentication tokens
- Provide user profile information from Google

### 2. FirebaseAuthManager
```dart
class FirebaseAuthManager {
  Stream<User?> get authStateChanges;
  Future<User?> signInWithCredential(AuthCredential credential);
  Future<void> signOut();
  User? get currentUser;
  Future<void> linkWithCredential(AuthCredential credential);
}
```

**Responsibilities:**
- Manage Firebase authentication state
- Link Google credentials with Firebase
- Handle authentication persistence
- Provide real-time auth state updates

### 3. UserProfileService
```dart
class UserProfileService {
  Future<AppUser> createUserProfile(User firebaseUser, GoogleSignInAccount googleUser);
  Future<AppUser?> getUserProfile(String userId);
  Future<void> updateUserProfile(AppUser user);
  Future<void> syncProfileFromFirebase(String userId);
}
```

**Responsibilities:**
- Create user profiles from Google account data
- Generate unique handles from Google display names
- Sync profile data between Firebase and local storage
- Handle profile updates and changes

### 4. AuthStateProvider
```dart
class AuthStateProvider extends ChangeNotifier {
  AuthenticationState get state;
  AppUser? get currentUser;
  Future<void> signInWithGoogle();
  Future<void> signOut();
  Future<void> checkAuthState();
}
```

**Responsibilities:**
- Provide authentication state to UI
- Coordinate between Google and Firebase auth
- Handle authentication errors and loading states
- Notify UI of authentication changes

## Data Models

### AppUser Model
```dart
class AppUser {
  final String id;              // Firebase UID
  final String email;           // From Google account
  final String displayName;     // From Google account
  final String handle;          // Generated unique handle
  final String? photoURL;       // From Google account
  final DateTime createdAt;
  final DateTime updatedAt;
  final UserStatus status;
}
```

### AuthenticationState Enum
```dart
enum AuthenticationState {
  initial,
  loading,
  authenticated,
  unauthenticated,
  error
}
```

## Error Handling

### Error Types
1. **Google Sign-In Errors**
   - User cancellation
   - Network connectivity issues
   - Google services unavailable

2. **Firebase Authentication Errors**
   - Invalid credentials
   - Account disabled
   - Token expiration

3. **Profile Creation Errors**
   - Firestore permission issues
   - Handle generation conflicts
   - Network timeouts

### Error Recovery Strategies
- **Retry Logic**: Automatic retry for network-related failures
- **Fallback Options**: Offline mode for connectivity issues
- **User Feedback**: Clear error messages with actionable steps
- **Graceful Degradation**: Continue with limited functionality when possible

## Testing Strategy

### Unit Tests
- GoogleAuthService authentication flows
- UserProfileService profile creation and updates
- AuthStateProvider state management
- Error handling scenarios

### Integration Tests
- End-to-end authentication flow
- Profile synchronization between services
- Authentication state persistence
- Sign-out and cleanup processes

### Widget Tests
- Sign-in screen UI components
- Loading states and error displays
- Authentication state transitions
- User profile display components

## Implementation Details

### Dependencies Required
```yaml
dependencies:
  google_sign_in: ^6.2.1
  firebase_auth: ^4.19.6  # Already included
  firebase_core: ^2.27.0  # Already included
```

### Firebase Configuration
- Enable Google Sign-In in Firebase Console
- Configure OAuth consent screen
- Add SHA-1 fingerprints for Android
- Configure Google Services files

### Security Considerations
- Use Firebase Security Rules to protect user data
- Implement proper token validation
- Handle authentication state securely
- Protect against unauthorized access

### Performance Optimizations
- Cache authentication state locally
- Lazy load user profiles
- Implement efficient profile synchronization
- Minimize Firebase read operations

## Migration Strategy

### Phase 1: Parallel Implementation
- Implement new Google auth alongside existing system
- Add feature flag to switch between systems
- Test new system with limited users

### Phase 2: Data Migration
- Migrate existing user data to new format
- Preserve conversation history
- Update friend relationships

### Phase 3: System Replacement
- Remove old onboarding screens
- Delete unused authentication services
- Clean up legacy code and dependencies

### Cleanup Tasks
- Remove OnboardingScreen and related components
- Delete AuthService, UserCreationService
- Remove PIN-related functionality
- Clean up virtual number generation code
- Update navigation flows

## User Experience Flow

### First-Time Users
1. **Splash Screen**: App initialization and Firebase setup
2. **Sign-In Screen**: Google Sign-In button with app branding
3. **Google Auth**: Standard Google authentication flow
4. **Profile Creation**: Automatic profile setup from Google data
5. **Main Screen**: Direct access to chat interface

### Returning Users
1. **Splash Screen**: Check existing authentication
2. **Auto Sign-In**: Automatic authentication with cached credentials
3. **Profile Sync**: Update profile data from Firebase
4. **Main Screen**: Immediate access to conversations

### Sign-Out Flow
1. **Settings Menu**: Sign-out option in app settings
2. **Confirmation**: Confirm sign-out action
3. **Cleanup**: Clear local data and Firebase tokens
4. **Sign-In Screen**: Return to authentication screen