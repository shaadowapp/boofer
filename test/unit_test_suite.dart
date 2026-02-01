import 'package:flutter_test/flutter_test.dart';

// Import all unit test files
import 'services/local_storage_service_test.dart' as local_storage_service_tests;
import 'test_helpers.dart';

/// Comprehensive unit test suite for the app
void main() {
  // Set up test environment
  setUpAll(() {
    TestHelpers.setupTestEnvironment();
  });

  group('App Unit Tests', () {
    group('Service Tests', () {
      local_storage_service_tests.main();
    });
  });
}