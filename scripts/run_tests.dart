#!/usr/bin/env dart

import 'dart:io';

/// Script to generate mocks and run unit tests
void main(List<String> args) async {
  print('🧪 Starting test suite...\n');

  // Step 1: Generate mocks
  print('📦 Generating mocks...');
  final mockResult = await Process.run(
    'dart',
    ['run', 'build_runner', 'build', '--delete-conflicting-outputs'],
    workingDirectory: Directory.current.path,
  );

  if (mockResult.exitCode != 0) {
    print('❌ Mock generation failed:');
    print(mockResult.stderr);
    exit(1);
  }
  print('✅ Mocks generated successfully\n');

  // Step 2: Run unit tests
  print('🔬 Running unit tests...');
  final testArgs = [
    'test',
    if (args.contains('--coverage')) '--coverage',
    if (args.contains('--verbose')) '--verbose',
    'test/unit_test_suite.dart',
  ];

  final testResult = await Process.run(
    'flutter',
    testArgs,
    workingDirectory: Directory.current.path,
  );

  print(testResult.stdout);
  if (testResult.stderr.isNotEmpty) {
    print(testResult.stderr);
  }

  if (testResult.exitCode == 0) {
    print('\n✅ All tests passed!');
    
    if (args.contains('--coverage')) {
      print('\n📊 Generating coverage report...');
      await _generateCoverageReport();
    }
  } else {
    print('\n❌ Some tests failed');
    exit(1);
  }
}

Future<void> _generateCoverageReport() async {
  // Generate LCOV report
  final lcovResult = await Process.run(
    'dart',
    ['run', 'coverage:format_coverage', '--lcov', '--in=coverage', '--out=coverage/lcov.info'],
    workingDirectory: Directory.current.path,
  );

  if (lcovResult.exitCode == 0) {
    print('✅ Coverage report generated at coverage/lcov.info');
    
    // Try to generate HTML report if genhtml is available
    final genhtmlResult = await Process.run(
      'genhtml',
      ['coverage/lcov.info', '-o', 'coverage/html'],
      workingDirectory: Directory.current.path,
    );

    if (genhtmlResult.exitCode == 0) {
      print('✅ HTML coverage report generated at coverage/html/index.html');
    } else {
      print('ℹ️  Install lcov to generate HTML coverage reports: brew install lcov (macOS) or apt-get install lcov (Ubuntu)');
    }
  } else {
    print('❌ Failed to generate coverage report');
  }
}