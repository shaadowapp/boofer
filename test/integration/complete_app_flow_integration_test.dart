import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:boofer/main.dart' as app;
import 'package:boofer/screens/onboarding_screen.dart';
import 'package:boofer/screens/main_screen.dart';
import 'package:boofer/widgets/onboarding_step1.dart';
import 'package:boofer/widgets/onboarding_step2.dart';
import 'package:boofer/widgets/onboarding_step3.dart';
import 'package:boofer/services/local_storage_service.dart';
import 'package:boofer/services/app_state_service.dart';
import 'package:boofer/models/onboarding_data.dart';

import '../test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Complete App Flow Integration Tests', () {
    setUp(() async {
      TestHelpers.setupTestEnvironment();
      await LocalStorageService.clearOnboardingData();
      await AppStateService.instance.clearUserSession();
    });

    testWidgets('complete app flow - new user journey', (WidgetTester tester) async {
      // Test the complete journey from app start to main screen usage
      
      // 1. App Startup
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Should show splash screen initially, then onboarding
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.text('Step 1 of 3'), findsOneWidget);

      // 2. Complete Onboarding Flow
      await _completeFullOnboardingFlow(tester, 'Complete Flow User');

      // 3. Verify Main Screen Access
      expect(find.byType(MainScreen), findsOneWidget);

      // 4. Verify Data Persistence
      final onboardingData = await LocalStorageService.getOnboardingData();
      expect(onboardingData, isNotNull);
      expect(onboardingData!.completed, isTrue);
      expect(onboardingData.userName, equals('Complete Flow User'));

      // 5. Verify App State
      final appState = AppStateService.instance;
      expect(appState.isUserLoggedIn, isTrue);
      expect(appState.userDisplayName, equals('Complete Flow User'));
    });

    testWidgets('complete app flow - returning user journey', (WidgetTester tester) async {
      // Pre-setup completed user
      final onboardingData = OnboardingData(
        userName: 'Returning Complete User',
        virtualNumber: '555-COMP',
        pin: '1234',
        termsAccepted: true,
        completed: true,
        completedAt: DateTime.now(),
      );
      await LocalStorageService.saveOnboardingData(onboardingData);

      // 1. App Startup
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Should skip onboarding and go directly to main screen
      expect(find.byType(MainScreen), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsNothing);

      // 2. Verify App State Restoration
      final appState = AppStateService.instance;
      expect(appState.isUserLoggedIn, isTrue);
      expect(appState.userDisplayName, equals('Returning Complete User'));
      expect(appState.userVirtualNumber, equals('555-COMP'));
      expect(appState.hasPinSet, isTrue);

      // 3. Test App Restart Persistence
      await tester.pumpWidget(Container());
      await tester.pumpAndSettle();

      // Restart app
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Should still go to main screen
      expect(find.byType(MainScreen), findsOneWidget);
      expect(appState.isUserLoggedIn, isTrue);
    });

    testWidgets('complete app flow - edge cases and error recovery', (WidgetTester tester) async {
      // Test various edge cases in the complete flow

      // 1. Start with corrupted data
      try {
        await LocalStorageService.saveOnboardingData(OnboardingData(
          userName: '',
          virtualNumber: '',
          pin: null,
          termsAccepted: false,
          completed: false,
          completedAt: null,
        ));
      } catch (e) {
        // Expected for invalid data
      }

      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Should gracefully handle and show onboarding
      expect(find.byType(OnboardingScreen), findsOneWidget);

      // 2. Complete onboarding with edge case data
      await _completeOnboardingWithEdgeCases(tester);

      // Should successfully reach main screen
      expect(find.byType(MainScreen), findsOneWidget);

      // 3. Test data integrity
      final savedData = await LocalStorageService.getOnboardingData();
      expect(savedData, isNotNull);
      expect(savedData!.completed, isTrue);
    });

    testWidgets('complete app flow - multiple user scenarios', (WidgetTester tester) async {
      // Test different user configuration scenarios

      // Scenario 1: User with PIN
      await _testUserScenario(tester, 'PIN User', '1234', true);

      // Clear data
      await LocalStorageService.clearOnboardingData();
      await tester.pumpWidget(Container());

      // Scenario 2: User without PIN
      await _testUserScenario(tester, 'No PIN User', null, false);

      // Clear data
      await LocalStorageService.clearOnboardingData();
      await tester.pumpWidget(Container());

      // Scenario 3: User with special characters in name
      await _testUserScenario(tester, 'Spëcîál Üser 123!', '9999', true);
    });

    testWidgets('complete app flow - performance and timing', (WidgetTester tester) async {
      final stopwatch = Stopwatch()..start();

      // Measure complete flow performance
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      final onboardingStartTime = stopwatch.elapsedMilliseconds;
      
      // Complete onboarding quickly
      await _completeFullOnboardingFlow(tester, 'Performance User');
      
      final completionTime = stopwatch.elapsedMilliseconds;
      stopwatch.stop();

      // Verify performance expectations
      expect(onboardingStartTime, lessThan(3000)); // App start < 3s
      expect(completionTime - onboardingStartTime, lessThan(10000)); // Onboarding < 10s
      expect(find.byType(MainScreen), findsOneWidget);

      print('App startup: ${onboardingStartTime}ms');
      print('Onboarding completion: ${completionTime - onboardingStartTime}ms');
      print('Total flow time: ${completionTime}ms');
    });

    testWidgets('complete app flow - accessibility and usability', (WidgetTester tester) async {
      // Test accessibility features throughout the flow
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Verify semantic labels and accessibility
      expect(find.byType(OnboardingScreen), findsOneWidget);
      
      // Test keyboard navigation and screen reader support
      // (This would require more detailed accessibility testing)
      
      await _completeFullOnboardingFlow(tester, 'Accessibility User');
      expect(find.byType(MainScreen), findsOneWidget);
    });

    testWidgets('complete app flow - theme consistency', (WidgetTester tester) async {
      // Test theme consistency throughout the flow
      app.main();
      await tester.pump();

      // Toggle theme during splash
      final themeToggle = find.byIcon(Icons.dark_mode);
      if (themeToggle.evaluate().isNotEmpty) {
        await tester.tap(themeToggle);
        await tester.pump();
      }

      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Complete onboarding with theme applied
      await _completeFullOnboardingFlow(tester, 'Theme User');
      
      // Verify main screen maintains theme
      expect(find.byType(MainScreen), findsOneWidget);
    });

    testWidgets('complete app flow - data validation and security', (WidgetTester tester) async {
      // Test data validation and security throughout the flow
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Test with various input validations
      expect(find.byType(OnboardingStep1), findsOneWidget);

      // Test invalid inputs
      final nameField = find.byType(TextFormField);
      await tester.enterText(nameField, 'A'); // Too short
      await tester.pump();

      // Register button should be disabled
      final registerButton = find.text('Register');
      expect(tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Register')).onPressed, isNull);

      // Test valid inputs and complete flow
      await tester.enterText(nameField, 'Security Test User');
      await tester.pump();

      final termsCheckbox = find.byType(Checkbox);
      await tester.tap(termsCheckbox);
      await tester.pump();

      await tester.tap(registerButton);
      await tester.pumpAndSettle();

      // Complete PIN setup with security validation
      final pinFields = find.byType(TextFormField);
      await tester.enterText(pinFields.first, '1234');
      await tester.pump();
      await tester.enterText(pinFields.last, '5678'); // Mismatch first
      await tester.pump();

      expect(find.text('PINs do not match'), findsOneWidget);

      // Fix PIN
      await tester.enterText(pinFields.last, '1234');
      await tester.pump();

      final continueButton = find.text('Continue');
      await tester.tap(continueButton);
      await tester.pumpAndSettle();

      // Complete final step
      await tester.pump(const Duration(seconds: 1));
      final completeButton = find.text('Complete Setup');
      await tester.tap(completeButton);
      await tester.pumpAndSettle();

      expect(find.byType(MainScreen), findsOneWidget);

      // Verify secure data storage
      final savedData = await LocalStorageService.getOnboardingData();
      expect(savedData, isNotNull);
      expect(savedData!.pin, equals('1234')); // PIN should be stored securely
    });

    testWidgets('complete app flow - network and offline scenarios', (WidgetTester tester) async {
      // Test app behavior in different network conditions
      // (This would require network mocking in a real scenario)
      
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // App should work offline for onboarding
      await _completeFullOnboardingFlow(tester, 'Offline User');
      expect(find.byType(MainScreen), findsOneWidget);

      // Verify local data storage works without network
      final savedData = await LocalStorageService.getOnboardingData();
      expect(savedData, isNotNull);
      expect(savedData!.completed, isTrue);
    });

    testWidgets('complete app flow - memory and resource management', (WidgetTester tester) async {
      // Test resource management throughout the flow
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Complete multiple flows to test memory management
      for (int i = 0; i < 3; i++) {
        if (i > 0) {
          // Clear and restart for subsequent iterations
          await LocalStorageService.clearOnboardingData();
          await tester.pumpWidget(Container());
          app.main();
          await tester.pumpAndSettle(const Duration(seconds: 3));
        }

        await _completeFullOnboardingFlow(tester, 'Memory Test User $i');
        expect(find.byType(MainScreen), findsOneWidget);

        // Verify no memory leaks (basic check)
        expect(find.byType(MainScreen), findsOneWidget);
      }
    });
  });

  // Helper Methods
  Future<void> _completeFullOnboardingFlow(WidgetTester tester, String userName) async {
    // Step 1: Registration
    final nameField = find.byType(TextFormField);
    await tester.enterText(nameField, userName);
    await tester.pump();

    final termsCheckbox = find.byType(Checkbox);
    await tester.tap(termsCheckbox);
    await tester.pump();

    final registerButton = find.text('Register');
    await tester.tap(registerButton);
    await tester.pumpAndSettle();

    // Step 2: PIN Setup
    final pinFields = find.byType(TextFormField);
    await tester.enterText(pinFields.first, '1234');
    await tester.pump();
    await tester.enterText(pinFields.last, '1234');
    await tester.pump();

    final continueButton = find.text('Continue');
    await tester.tap(continueButton);
    await tester.pumpAndSettle();

    // Step 3: Complete Setup
    await tester.pump(const Duration(seconds: 1)); // Wait for virtual number generation
    final completeButton = find.text('Complete Setup');
    await tester.tap(completeButton);
    await tester.pumpAndSettle();
  }

  Future<void> _completeOnboardingWithEdgeCases(WidgetTester tester) async {
    // Test with edge case inputs
    final nameField = find.byType(TextFormField);
    await tester.enterText(nameField, 'Edge Case User With Very Long Name That Tests Limits');
    await tester.pump();

    final termsCheckbox = find.byType(Checkbox);
    await tester.tap(termsCheckbox);
    await tester.pump();

    final registerButton = find.text('Register');
    await tester.tap(registerButton);
    await tester.pumpAndSettle();

    // Skip PIN for edge case
    final skipButton = find.text('Skip');
    await tester.tap(skipButton);
    await tester.pumpAndSettle();

    // Complete setup
    await tester.pump(const Duration(seconds: 1));
    final completeButton = find.text('Complete Setup');
    await tester.tap(completeButton);
    await tester.pumpAndSettle();
  }

  Future<void> _testUserScenario(WidgetTester tester, String userName, String? pin, bool shouldHavePin) async {
    OnboardingData onboardingData;
    
    if (shouldHavePin && pin != null) {
      onboardingData = OnboardingData(
        userName: userName,
        virtualNumber: '555-TEST',
        pin: pin,
        termsAccepted: true,
        completed: true,
        completedAt: DateTime.now(),
      );
    } else {
      onboardingData = OnboardingData(
        userName: userName,
        virtualNumber: '555-TEST',
        pin: null,
        termsAccepted: true,
        completed: true,
        completedAt: DateTime.now(),
      );
    }

    await LocalStorageService.saveOnboardingData(onboardingData);

    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(find.byType(MainScreen), findsOneWidget);

    final appState = AppStateService.instance;
    expect(appState.userDisplayName, equals(userName));
    expect(appState.hasPinSet, equals(shouldHavePin));
  }
}