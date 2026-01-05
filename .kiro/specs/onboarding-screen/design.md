# Design Document

## Overview

The onboarding system is a comprehensive three-step flow that appears only on first app launch. It guides users through registration, optional security setup, and virtual number assignment while storing all data locally. The design emphasizes user choice, security, and seamless integration with the main app experience.

## Architecture

### Core Components
- **OnboardingController**: Main state management for the entire flow
- **OnboardingStep1**: Registration screen with name input and terms acceptance
- **OnboardingStep2**: Optional PIN setup with skip functionality
- **OnboardingStep3**: Virtual number display and optional social features
- **LocalStorageService**: Handles all onboarding data persistence
- **NotificationService**: Manages permission requests after onboarding

### Navigation Flow
```
App Launch → Check Local Storage → [First Time] → Step 1 → Step 2 → Step 3 → Home Screen
                                → [Returning] → Home Screen → [Check Notifications]
```

## Components and Interfaces

### OnboardingController
```dart
class OnboardingController extends ChangeNotifier {
  int currentStep = 1;
  String userName = '';
  String? userPin;
  String virtualNumber = '';
  bool termsAccepted = false;
  bool onboardingCompleted = false;
  
  void nextStep();
  void completeOnboarding();
  Future<void> saveToLocalStorage();
}
```

### OnboardingStep1 (Registration)
- Brand logo display with animation
- Feature highlights section
- User name input field with validation
- Terms acceptance checkbox
- Register button (enabled when valid)
- Form validation and error handling

### OnboardingStep2 (PIN Setup)
- PIN entry interface (4-digit)
- PIN confirmation field
- Skip button for optional setup
- Visual feedback for PIN matching
- Secure PIN storage preparation

### OnboardingStep3 (Virtual Number)
- Auto-generated number display
- Identity explanation text
- "Invite Friends" button (optional)
- "Allow Contact Access" button (optional)
- Continue button to complete onboarding

### LocalStorageService
```dart
class LocalStorageService {
  static const String _onboardingKey = 'onboarding_completed';
  static const String _userNameKey = 'user_name';
  static const String _virtualNumberKey = 'virtual_number';
  static const String _userPinKey = 'user_pin';
  
  Future<bool> isOnboardingCompleted();
  Future<void> saveOnboardingData(OnboardingData data);
  Future<OnboardingData?> getOnboardingData();
}
```

## Data Models

### OnboardingData
```dart
class OnboardingData {
  final String userName;
  final String virtualNumber;
  final String? pin;
  final bool completed;
  final DateTime completedAt;
  
  OnboardingData({
    required this.userName,
    required this.virtualNumber,
    this.pin,
    required this.completed,
    required this.completedAt,
  });
}
```

### VirtualNumberGenerator
```dart
class VirtualNumberGenerator {
  static String generate() {
    // Generates unique 10-digit number
    // Format: XXX-XXX-XXXX
  }
}
```

## UI Design Specifications

### Step 1 - Registration
- **Header**: Brand logo (animated entrance)
- **Features Section**: Highlight key app features
- **Form Section**: 
  - Name input field with floating label
  - Terms checkbox with clickable text
  - Register button with loading state
- **Footer**: Progress indicator (1/3)

### Step 2 - PIN Setup
- **Header**: Security icon and title
- **PIN Section**:
  - 4-digit PIN input with dots
  - Confirmation PIN input
  - Visual matching indicator
- **Actions**: Skip button, Continue button
- **Footer**: Progress indicator (2/3)

### Step 3 - Virtual Number
- **Header**: Identity icon and explanation
- **Number Display**: Large, prominent virtual number
- **Info Section**: Usage explanation text
- **Optional Actions**: 
  - Invite Friends button
  - Contact Access button
- **Footer**: Continue button, Progress indicator (3/3)

### Animation Strategy
- Smooth transitions between steps (slide animation)
- Form field focus animations
- Button press feedback
- Loading states for async operations
- Success animations for completion

### Responsive Design
- Adapts to different screen sizes
- Keyboard-aware scrolling
- Safe area handling for notched devices
- Landscape orientation support

## Error Handling

### Validation Errors
- Real-time name validation
- PIN mismatch detection
- Terms acceptance requirement
- Network connectivity issues

### Storage Errors
- Local storage failure fallback
- Data corruption recovery
- Migration between app versions

### Navigation Errors
- Step transition failures
- Back navigation handling
- App state restoration

## Testing Strategy

### Unit Tests
- OnboardingController state management
- VirtualNumberGenerator uniqueness
- LocalStorageService data persistence
- Form validation logic

### Widget Tests
- Each onboarding step UI
- Form interactions and validation
- Button states and animations
- Navigation between steps

### Integration Tests
- Complete onboarding flow
- Local storage integration
- App launch behavior
- Notification permission flow

## Security Considerations

### PIN Storage
- Secure local storage using flutter_secure_storage
- PIN hashing before storage
- Biometric authentication integration (future)

### Data Privacy
- Local-only data storage
- No server transmission of personal data
- Clear data deletion methods
- GDPR compliance considerations

## Performance Considerations

### Memory Management
- Dispose controllers properly
- Optimize image assets
- Lazy loading of step widgets

### Storage Efficiency
- Minimal data footprint
- Efficient serialization
- Background storage operations