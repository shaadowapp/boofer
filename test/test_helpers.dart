import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Test helper utilities for setting up test environment
class TestHelpers {
  /// Sets up the test environment with necessary bindings
  static void setupTestEnvironment() {
    TestWidgetsFlutterBinding.ensureInitialized();
    
    // Mock SharedPreferences
    SharedPreferences.setMockInitialValues({});
    
    // Mock platform channels
    _setupPlatformChannels();
  }

  /// Sets up mock platform channels for testing
  static void _setupPlatformChannels() {
    // Mock flutter_secure_storage
    const MethodChannel('plugins.it_nomads.com/flutter_secure_storage')
        .setMockMethodCallHandler((MethodCall methodCall) async {
      switch (methodCall.method) {
        case 'read':
          return null; // Return null by default
        case 'write':
          return null;
        case 'delete':
          return null;
        case 'deleteAll':
          return null;
        case 'readAll':
          return <String, String>{};
        default:
          return null;
      }
    });

    // Mock haptic feedback
    const MethodChannel('plugins.flutter.io/haptic_feedback')
        .setMockMethodCallHandler((MethodCall methodCall) async {
      return null;
    });

    // Mock system chrome
    const MethodChannel('flutter/platform')
        .setMockMethodCallHandler((MethodCall methodCall) async {
      return null;
    });
  }

  /// Creates a test data map for onboarding
  static Map<String, dynamic> createTestOnboardingData({
    String userName = 'Test User',
    String virtualNumber = '+1234567890',
    bool termsAccepted = true,
    String? userPin,
    int currentStep = 1,
    bool isComplete = false,
  }) {
    return {
      'userName': userName,
      'virtualNumber': virtualNumber,
      'termsAccepted': termsAccepted,
      if (userPin != null) 'userPin': userPin,
      'currentStep': currentStep,
      'isComplete': isComplete,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }

  /// Validates that a phone number follows the expected format
  static bool isValidPhoneNumber(String number) {
    final regex = RegExp(r'^\+1\d{10}$');
    return regex.hasMatch(number);
  }

  /// Validates that a PIN follows the expected format
  static bool isValidPin(String pin) {
    final regex = RegExp(r'^\d{4}$');
    return regex.hasMatch(pin);
  }

  /// Creates a list of test phone numbers for testing uniqueness
  static List<String> generateTestPhoneNumbers(int count) {
    final numbers = <String>[];
    for (int i = 0; i < count; i++) {
      // Generate predictable test numbers
      final areaCode = (200 + (i % 800)).toString().padLeft(3, '0');
      final exchange = (200 + ((i * 7) % 800)).toString().padLeft(3, '0');
      final subscriber = (i % 10000).toString().padLeft(4, '0');
      numbers.add('+1$areaCode$exchange$subscriber');
    }
    return numbers;
  }

  /// Simulates async delay for testing loading states
  static Future<void> simulateAsyncDelay([int milliseconds = 100]) {
    return Future.delayed(Duration(milliseconds: milliseconds));
  }

  /// Creates test error scenarios
  static Exception createTestException(String message) {
    return Exception('Test Exception: $message');
  }

  /// Validates onboarding data structure
  static bool isValidOnboardingData(Map<String, dynamic> data) {
    final requiredFields = ['userName', 'virtualNumber', 'termsAccepted'];
    
    for (final field in requiredFields) {
      if (!data.containsKey(field)) {
        return false;
      }
    }

    // Validate data types
    if (data['userName'] is! String) return false;
    if (data['virtualNumber'] is! String) return false;
    if (data['termsAccepted'] is! bool) return false;

    // Validate optional fields if present
    if (data.containsKey('userPin') && data['userPin'] is! String?) return false;
    if (data.containsKey('currentStep') && data['currentStep'] is! int) return false;
    if (data.containsKey('isComplete') && data['isComplete'] is! bool) return false;

    return true;
  }

  /// Creates a mock error response for testing error handling
  static Map<String, dynamic> createErrorResponse(String message, [String? code]) {
    return {
      'error': true,
      'message': message,
      if (code != null) 'code': code,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }

  /// Validates that all required onboarding steps are complete
  static bool isOnboardingDataComplete(Map<String, dynamic> data) {
    if (!isValidOnboardingData(data)) return false;

    // Check that required fields have valid values
    final userName = data['userName'] as String;
    final virtualNumber = data['virtualNumber'] as String;
    final termsAccepted = data['termsAccepted'] as bool;

    if (userName.trim().isEmpty) return false;
    if (!isValidPhoneNumber(virtualNumber)) return false;
    if (!termsAccepted) return false;

    return true;
  }

  /// Creates test scenarios for different onboarding states
  static Map<String, Map<String, dynamic>> createOnboardingTestScenarios() {
    return {
      'fresh_start': createTestOnboardingData(
        userName: '',
        virtualNumber: '',
        termsAccepted: false,
        currentStep: 1,
        isComplete: false,
      ),
      'step1_complete': createTestOnboardingData(
        userName: 'John Doe',
        virtualNumber: '',
        termsAccepted: true,
        currentStep: 2,
        isComplete: false,
      ),
      'step2_complete': createTestOnboardingData(
        userName: 'John Doe',
        virtualNumber: '+1234567890',
        termsAccepted: true,
        userPin: '1234',
        currentStep: 3,
        isComplete: false,
      ),
      'step2_skipped_pin': createTestOnboardingData(
        userName: 'John Doe',
        virtualNumber: '+1234567890',
        termsAccepted: true,
        currentStep: 3,
        isComplete: false,
      ),
      'fully_complete': createTestOnboardingData(
        userName: 'John Doe',
        virtualNumber: '+1234567890',
        termsAccepted: true,
        userPin: '1234',
        currentStep: 3,
        isComplete: true,
      ),
    };
  }
}