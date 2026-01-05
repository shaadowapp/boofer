#!/usr/bin/env dart

import 'dart:io';

/// Simple script to run widget tests for onboarding components
void main() async {
  print('🧪 Running Onboarding Widget Tests...\n');

  final testFiles = [
    'test/widgets/onboarding_step1_test.dart',
    'test/widgets/onboarding_step2_test.dart', 
    'test/widgets/onboarding_step3_test.dart',
    'test/screens/onboarding_screen_test.dart',
  ];

  for (final testFile in testFiles) {
    print('📋 Running tests in $testFile...');
    
    final result = await Process.run(
      'flutter',
      ['test', testFile, '--reporter=compact'],
      workingDirectory: Directory.current.path,
    );

    if (result.exitCode == 0) {
      print('✅ $testFile - PASSED\n');
    } else {
      print('❌ $testFile - FAILED');
      print('Error: ${result.stderr}');
      print('Output: ${result.stdout}\n');
    }
  }

  print('🎯 Widget test run completed!');
}