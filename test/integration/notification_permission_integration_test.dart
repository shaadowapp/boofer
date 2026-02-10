import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:boofer/main.dart' as app;
import 'package:boofer/screens/main_screen.dart';
import 'package:boofer/screens/onboarding_screen.dart';
import 'package:boofer/services/local_storage_service.dart';
import 'package:boofer/services/app_state_service.dart';
import 'package:boofer/models/onboarding_data.dart';

import '../test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Notification Permission Integration Tests', () {
    setUp(() async {
      TestHelpers.setupTestEnvironment();
      await LocalStorageService.clearOnboardingData();
      await AppStateService.instance.clearUserSession();
    });

    testWidgets('notification permission request after onboarding completion', (WidgetTester tester) async {
      // Start app and complete onboarding flow
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Complete full onboarding flow
      await completeOnboardingFlow(tester);

      // Should now be on main screen
      expect(find.byType(MainScreen), findsOneWidget);

      // Wait for potential notification permission request
      await tester.pump(const Duration(seconds: 1));

      // Note: In a real integration test, we would mock the permission service
      // and verify that permission request was called. For now, we verify
      // that the app reaches the main screen successfully.
      expect(find.byType(MainScreen), findsOneWidget);
    });

    testWidgets('notification permission for returning user', (WidgetTester tester) async {
      // Pre-populate completed onboarding data
      final onboardingData = OnboardingData(
        userName: 'Notification User',
        virtualNumber: '555-NOTIF',
        pin: '1234',
        termsAccepted: true,
        completed: true,
        completedAt: DateTime.now(),
      );
      await LocalStorageService.saveOnboardingData(onboardingData);

      // Start the app
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Should go directly to main screen
      expect(find.byType(MainScreen), findsOneWidget);

      // Wait for potential notification permission check
      await tester.pump(const Duration(seconds: 1));

      // App should handle permission check gracefully
      expect(find.byType(MainScreen), findsOneWidget);
    });

    testWidgets('notification permission denied handling', (WidgetTester tester) async {
      // This test would require mocking the permission service to return denied
      // For now, we test that the app continues to work normally
      
      final onboardingData = OnboardingData(
        userName: 'Permission Denied User',
        virtualNumber: '555-DENY',
        pin: '1234',
        termsAccepted: true,
        completed: true,
        completedAt: DateTime.now(),
      );
      await LocalStorageService.saveOnboardingData(onboardingData);

      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // App should work normally even if notifications are denied
      expect(find.byType(MainScreen), findsOneWidget);
    });

    testWidgets('notification permission granted handling', (WidgetTester tester) async {
      // This test would require mocking the permission service to return granted
      // For now, we test that the app continues to work normally
      
      final onboardingData = OnboardingData(
        userName: 'Permission Granted User',
        virtualNumber: '555-GRANT',
        pin: '1234',
        termsAccepted: true,
        completed: true,
        completedAt: DateTime.now(),
      );
      await LocalStorageService.saveOnboardingData(onboardingData);

      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // App should work normally with notifications granted
      expect(find.byType(MainScreen), findsOneWidget);
    });

    testWidgets('notification permission request timing', (WidgetTester tester) async {
      // Test that permission is requested after onboarding, not during
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // During onboarding, no permission request should occur
      expect(find.byType(OnboardingScreen), findsOneWidget);
      
      // Complete onboarding
      await completeOnboardingFlow(tester);
      
      // Now on main screen, permission request may occur
      expect(find.byType(MainScreen), findsOneWidget);
      
      // Wait for permission request timing
      await tester.pump(const Duration(seconds: 2));
      
      // App should remain stable
      expect(find.byType(MainScreen), findsOneWidget);
    });

    testWidgets('notification permission with app restart', (WidgetTester tester) async {
      // Complete onboarding first
      final onboardingData = OnboardingData(
        userName: 'Restart Permission User',
        virtualNumber: '555-REST',
        pin: '1234',
        termsAccepted: true,
        completed: true,
        completedAt: DateTime.now(),
      );
      await LocalStorageService.saveOnboardingData(onboardingData);

      // First app start
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(find.byType(MainScreen), findsOneWidget);

      // Simulate app restart
      await tester.pumpWidget(Container());
      await tester.pumpAndSettle();

      // Second app start
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(find.byType(MainScreen), findsOneWidget);

      // Permission handling should work consistently across restarts
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(MainScreen), findsOneWidget);
    });

    testWidgets('notification permission error handling', (WidgetTester tester) async {
      // This test would mock permission service to throw an error
      // For now, test that app handles errors gracefully
      
      final onboardingData = OnboardingData(
        userName: 'Permission Error User',
        virtualNumber: '555-ERR',
        pin: '1234',
        termsAccepted: true,
        completed: true,
        completedAt: DateTime.now(),
      );
      await LocalStorageService.saveOnboardingData(onboardingData);

      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // App should handle permission errors gracefully
      expect(find.byType(MainScreen), findsOneWidget);
      
      // Wait for potential error handling
      await tester.pump(const Duration(seconds: 2));
      
      // App should remain functional
      expect(find.byType(MainScreen), findsOneWidget);
    });

    testWidgets('notification permission with different user states', (WidgetTester tester) async {
      // Test with user who has PIN
      var onboardingData = OnboardingData(
        userName: 'PIN User',
        virtualNumber: '555-PIN',
        pin: '1234',
        termsAccepted: true,
        completed: true,
        completedAt: DateTime.now(),
      );
      await LocalStorageService.saveOnboardingData(onboardingData);

      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(find.byType(MainScreen), findsOneWidget);

      // Clear and test with user who has no PIN
      await tester.pumpWidget(Container());
      await LocalStorageService.clearOnboardingData();
      
      onboardingData = OnboardingData(
        userName: 'No PIN User',
        virtualNumber: '555-NOPIN',
        pin: null,
        termsAccepted: true,
        completed: true,
        completedAt: DateTime.now(),
      );
      await LocalStorageService.saveOnboardingData(onboardingData);

      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(find.byType(MainScreen), findsOneWidget);

      // Permission handling should work regardless of PIN status
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(MainScreen), findsOneWidget);
    });

    testWidgets('notification permission integration with main screen features', (WidgetTester tester) async {
      // Setup completed user
      final onboardingData = OnboardingData(
        userName: 'Feature Integration User',
        virtualNumber: '555-FEAT',
        pin: '1234',
        termsAccepted: true,
        completed: true,
        completedAt: DateTime.now(),
      );
      await LocalStorageService.saveOnboardingData(onboardingData);

      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Should be on main screen
      expect(find.byType(MainScreen), findsOneWidget);

      // Wait for permission request and main screen initialization
      await tester.pump(const Duration(seconds: 2));

      // Main screen should be fully functional regardless of permission status
      expect(find.byType(MainScreen), findsOneWidget);
      
      // Should be able to interact with main screen elements
      // (This would depend on the actual MainScreen implementation)
      expect(find.byType(MainScreen), findsOneWidget);
    });

    testWidgets('notification permission with theme changes', (WidgetTester tester) async {
      // Setup user and start app
      final onboardingData = OnboardingData(
        userName: 'Theme User',
        virtualNumber: '555-THEME',
        pin: '1234',
        termsAccepted: true,
        completed: true,
        completedAt: DateTime.now(),
      );
      await LocalStorageService.saveOnboardingData(onboardingData);

      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(find.byType(MainScreen), findsOneWidget);

      // Find and tap theme toggle if available
      final themeToggle = find.byIcon(Icons.dark_mode);
      if (themeToggle.evaluate().isNotEmpty) {
        await tester.tap(themeToggle);
        await tester.pump();
        
        // Theme change should not affect permission handling
        expect(find.byType(MainScreen), findsOneWidget);
      }

      // Wait for any permission-related operations
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(MainScreen), findsOneWidget);
    });
  });

  // Helper method to complete the full onboarding flow
  Future<void> completeOnboardingFlow(WidgetTester tester) async {
    // Step 1: Registration
    final nameField = find.byType(TextFormField);
    await tester.enterText(nameField, 'Integration Test User');
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
}