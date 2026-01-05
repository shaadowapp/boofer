import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'test_helpers.dart';

/// Global test configuration for Flutter tests
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Set up global test environment
  TestHelpers.setupTestEnvironment();
  
  // Run the actual tests
  await testMain();
}