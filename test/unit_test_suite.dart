import 'package:flutter_test/flutter_test.dart';

// Import all unit test files
import 'providers/onboarding_controller_test.dart' as onboarding_controller_tests;
import 'utils/virtual_number_generator_test.dart' as virtual_number_generator_tests;
import 'services/local_storage_service_test.dart' as local_storage_service_tests;
import 'test_helpers.dart';

/// Comprehensive unit test suite for the onboarding system
void main() {
  // Set up test environment
  setUpAll(() {
    TestHelpers.setupTestEnvironment();
  });

  group('Onboarding System Unit Tests', () {
    group('Core Logic Tests', () {
      onboarding_controller_tests.main();
    });

    group('Utility Tests', () {
      virtual_number_generator_tests.main();
    });

    group('Service Tests', () {
      local_storage_service_tests.main();
    });
  });
}