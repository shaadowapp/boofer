# Test Suite Documentation

This directory contains comprehensive unit tests for the onboarding system.

## Test Structure

```
test/
├── providers/
│   └── onboarding_controller_test.dart    # OnboardingController unit tests
├── services/
│   └── local_storage_service_test.dart    # LocalStorageService unit tests
├── utils/
│   └── virtual_number_generator_test.dart # VirtualNumberGenerator unit tests
├── test_helpers.dart                      # Test utilities and helpers
├── flutter_test_config.dart              # Global test configuration
├── unit_test_suite.dart                  # Main test suite runner
└── README.md                             # This file
```

## Running Tests

### Prerequisites

1. Ensure you have Flutter installed and configured
2. Install dependencies: `flutter pub get`
3. Generate mocks: `dart run build_runner build`

### Running All Unit Tests

```bash
# Run the complete unit test suite
flutter test test/unit_test_suite.dart

# Run with verbose output
flutter test test/unit_test_suite.dart --verbose

# Run with coverage
flutter test test/unit_test_suite.dart --coverage
```

### Running Individual Test Files

```bash
# Test OnboardingController
flutter test test/providers/onboarding_controller_test.dart

# Test VirtualNumberGenerator
flutter test test/utils/virtual_number_generator_test.dart

# Test LocalStorageService
flutter test test/services/local_storage_service_test.dart
```

### Using the Test Script

```bash
# Run tests with mock generation
dart scripts/run_tests.dart

# Run with coverage report
dart scripts/run_tests.dart --coverage

# Run with verbose output
dart scripts/run_tests.dart --verbose
```

## Test Coverage

The unit tests cover the following areas:

### OnboardingController Tests (50+ test cases)
- ✅ Initialization and state management
- ✅ User registration flow
- ✅ PIN management and validation
- ✅ Virtual number generation
- ✅ Step navigation logic
- ✅ Onboarding completion
- ✅ Error handling and recovery
- ✅ Data persistence integration

### VirtualNumberGenerator Tests (25+ test cases)
- ✅ Number format validation (NANP compliance)
- ✅ Uniqueness guarantees
- ✅ Performance benchmarks
- ✅ Edge case handling
- ✅ Reserved number avoidance
- ✅ Area code and exchange validation

### LocalStorageService Tests (30+ test cases)
- ✅ Onboarding data persistence
- ✅ Secure PIN storage
- ✅ User preferences management
- ✅ Data validation and migration
- ✅ Error handling and recovery
- ✅ SharedPreferences integration
- ✅ FlutterSecureStorage integration

## Test Utilities

### TestHelpers Class

The `TestHelpers` class provides utilities for:
- Setting up test environment
- Creating test data scenarios
- Validating data structures
- Simulating async operations
- Generating mock phone numbers
- Error scenario creation

### Mock Generation

Tests use Mockito for mocking dependencies:
- `MockLocalStorageService`
- `MockVirtualNumberGenerator`
- `MockSharedPreferences`
- `MockFlutterSecureStorage`

## Best Practices

1. **Isolation**: Each test is isolated and doesn't depend on others
2. **Mocking**: External dependencies are mocked for reliable testing
3. **Coverage**: Tests cover both happy paths and error scenarios
4. **Performance**: Performance-critical code includes benchmark tests
5. **Documentation**: Each test group is well-documented with clear descriptions

## Continuous Integration

These tests are designed to run in CI/CD environments:
- No external dependencies required
- Deterministic results
- Fast execution (< 30 seconds)
- Comprehensive error reporting

## Troubleshooting

### Mock Generation Issues
```bash
# Clean and regenerate mocks
flutter clean
flutter pub get
dart run build_runner clean
dart run build_runner build --delete-conflicting-outputs
```

### Test Failures
1. Check that all dependencies are installed: `flutter pub get`
2. Ensure mocks are generated: `dart run build_runner build`
3. Run tests individually to isolate issues
4. Check test output for specific error messages

### Coverage Issues
1. Install coverage tools: `dart pub global activate coverage`
2. For HTML reports, install lcov: `brew install lcov` (macOS)
3. Ensure tests run successfully before generating coverage

## Contributing

When adding new tests:
1. Follow the existing test structure
2. Use descriptive test names and group descriptions
3. Include both positive and negative test cases
4. Mock external dependencies appropriately
5. Update this README if adding new test categories