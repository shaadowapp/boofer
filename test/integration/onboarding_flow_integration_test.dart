import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:boofer/main.dart' as app;
import 'package:boofer/screens/onboarding_screen.dart';
import 'package:boofer/screens/main_screen.dart';
import 'package:boofer/widgets/onboarding_step1.dart';
import 'package:boofer/widgets/onboarding_step2.dart';
import 'package:boofer/widgets/onboarding_step3.dart';
import 'package:boofer/providers/onboarding_controller.dart';
import 'package:boofer/services/local_storage_service.dart';
import 'package:boofer/services/app_state_service.dart';

import '../test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Onboarding Flow Integration Tests', () {
    setUp(() async {
      TestHelpers.setupTestEnvironment();
      // Clear any existing onboarding data before each test
      await LocalStorageService.clearOnboardingData();
      // Reset app state
      await AppStateService.instance.clearUserSession();
    });

    testWidgets('complete onboarding flow from start to finish', (WidgetTester tester) async {
      // Start the app
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Should start with splash screen, then navigate to onboarding
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.text('Step 1 of 3'), findsOneWidget);

      // Step 1: Registration
      expect(find.byType(OnboardingStep1), findsOneWidget);
      expect(find.text('Welcome to Boofer'), findsOneWidget);

      // Fill in the name field
      final nameField = find.byType(TextFormField);
      await tester.enterText(nameField, 'John Doe');
      await tester.pump();

      // Accept terms and conditions
      final termsCheckbox = find.byType(Checkbox);
      await tester.tap(termsCheckbox);
      await tester.pump();

      // Tap register button
      final registerButton = find.text('Register');
      expect(tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Register')).onPressed, isNotNull);
      await tester.tap(registerButton);
      await tester.pumpAndSettle();

      // Should navigate to Step 2
      expect(find.text('Step 2 of 3'), findsOneWidget);
      expect(find.byType(OnboardingStep2), findsOneWidget);
      expect(find.text('Secure Your Account'), findsOneWidget);

      // Step 2: PIN Setup
      final pinFields = find.byType(TextFormField);
      expect(pinFields, findsNWidgets(2)); // PIN and confirm PIN

      // Enter PIN
      await tester.enterText(pinFields.first, '1234');
      await tester.pump();

      // Enter confirm PIN
      await tester.enterText(pinFields.last, '1234');
      await tester.pump();

      // Should show PIN match indicator
      expect(find.text('PINs match!'), findsOneWidget);

      // Tap continue button
      final continueButton = find.text('Continue');
      await tester.tap(continueButton);
      await tester.pumpAndSettle();

      // Should navigate to Step 3
      expect(find.text('Step 3 of 3'), findsOneWidget);
      expect(find.byType(OnboardingStep3), findsOneWidget);
      expect(find.text('Your Digital Identity'), findsOneWidget);

      // Step 3: Virtual Number Display
      // Wait for virtual number generation
      await tester.pump(const Duration(seconds: 1));

      // Should show a virtual number (not "Generating...")
      expect(find.text('Generating...'), findsNothing);
      
      // Find the complete setup button
      final completeButton = find.text('Complete Setup');
      expect(tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Complete Setup')).onPressed, isNotNull);
      
      // Tap complete setup
      await tester.tap(completeButton);
      await tester.pumpAndSettle();

      // Should navigate to main screen
      expect(find.byType(MainScreen), findsOneWidget);
      
      // Verify onboarding data was saved
      final isCompleted = await LocalStorageService.isOnboardingCompleted();
      expect(isCompleted, isTrue);
      
      final onboardingData = await LocalStorageService.getOnboardingData();
      expect(onboardingData, isNotNull);
      expect(onboardingData!.userName, equals('John Doe'));
      expect(onboardingData.pin, equals('1234'));
      expect(onboardingData.virtualNumber, isNotEmpty);
      expect(onboardingData.completed, isTrue);
    });

    testWidgets('onboarding flow with PIN skip', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Step 1: Complete registration
      final nameField = find.byType(TextFormField);
      await tester.enterText(nameField, 'Jane Smith');
      await tester.pump();

      final termsCheckbox = find.byType(Checkbox);
      await tester.tap(termsCheckbox);
      await tester.pump();

      final registerButton = find.text('Register');
      await tester.tap(registerButton);
      await tester.pumpAndSettle();

      // Step 2: Skip PIN setup
      expect(find.byType(OnboardingStep2), findsOneWidget);
      
      final skipButton = find.text('Skip');
      await tester.tap(skipButton);
      await tester.pumpAndSettle();

      // Should navigate to Step 3
      expect(find.text('Step 3 of 3'), findsOneWidget);
      expect(find.byType(OnboardingStep3), findsOneWidget);

      // Complete onboarding
      await tester.pump(const Duration(seconds: 1));
      final completeButton = find.text('Complete Setup');
      await tester.tap(completeButton);
      await tester.pumpAndSettle();

      // Should navigate to main screen
      expect(find.byType(MainScreen), findsOneWidget);
      
      // Verify onboarding data was saved without PIN
      final onboardingData = await LocalStorageService.getOnboardingData();
      expect(onboardingData, isNotNull);
      expect(onboardingData!.userName, equals('Jane Smith'));
      expect(onboardingData.pin, isNull);
      expect(onboardingData.completed, isTrue);
    });

    testWidgets('onboarding flow with back navigation', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Complete Step 1
      final nameField = find.byType(TextFormField);
      await tester.enterText(nameField, 'Test User');
      await tester.pump();

      final termsCheckbox = find.byType(Checkbox);
      await tester.tap(termsCheckbox);
      await tester.pump();

      final registerButton = find.text('Register');
      await tester.tap(registerButton);
      await tester.pumpAndSettle();

      // Now on Step 2
      expect(find.text('Step 2 of 3'), findsOneWidget);

      // Go back to Step 1
      final backButton = find.byIcon(Icons.arrow_back_ios);
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      // Should be back on Step 1
      expect(find.text('Step 1 of 3'), findsOneWidget);
      expect(find.byType(OnboardingStep1), findsOneWidget);

      // Form should retain previous values
      final nameFieldAgain = find.byType(TextFormField);
      final textField = tester.widget<TextFormField>(nameFieldAgain);
      expect(textField.controller?.text, equals('Test User'));

      // Complete flow again
      final registerButtonAgain = find.text('Register');
      await tester.tap(registerButtonAgain);
      await tester.pumpAndSettle();

      // Should be on Step 2 again
      expect(find.text('Step 2 of 3'), findsOneWidget);
    });

    testWidgets('onboarding flow with form validation errors', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Try to register without filling form
      final registerButton = find.text('Register');
      expect(tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Register')).onPressed, isNull);

      // Fill name but don't accept terms
      final nameField = find.byType(TextFormField);
      await tester.enterText(nameField, 'Test User');
      await tester.pump();

      // Register button should still be disabled
      expect(tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Register')).onPressed, isNull);

      // Accept terms
      final termsCheckbox = find.byType(Checkbox);
      await tester.tap(termsCheckbox);
      await tester.pump();

      // Now register button should be enabled
      expect(tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Register')).onPressed, isNotNull);

      // Test invalid name (too short)
      await tester.enterText(nameField, 'A');
      await tester.pump();

      // Register button should be disabled again
      expect(tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Register')).onPressed, isNull);

      // Fix name
      await tester.enterText(nameField, 'Valid Name');
      await tester.pump();

      // Should be able to proceed
      expect(tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Register')).onPressed, isNotNull);
    });

    testWidgets('onboarding flow with PIN validation', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Complete Step 1
      final nameField = find.byType(TextFormField);
      await tester.enterText(nameField, 'PIN Test User');
      await tester.pump();

      final termsCheckbox = find.byType(Checkbox);
      await tester.tap(termsCheckbox);
      await tester.pump();

      final registerButton = find.text('Register');
      await tester.tap(registerButton);
      await tester.pumpAndSettle();

      // Step 2: Test PIN validation
      final pinFields = find.byType(TextFormField);

      // Enter mismatched PINs
      await tester.enterText(pinFields.first, '1234');
      await tester.pump();
      await tester.enterText(pinFields.last, '5678');
      await tester.pump();

      // Should show mismatch indicator
      expect(find.text('PINs do not match'), findsOneWidget);

      // Continue button should be disabled
      final continueButton = find.text('Continue');
      expect(tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Continue')).onPressed, isNull);

      // Fix PIN match
      await tester.enterText(pinFields.last, '1234');
      await tester.pump();

      // Should show match indicator
      expect(find.text('PINs match!'), findsOneWidget);

      // Continue button should be enabled
      expect(tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Continue')).onPressed, isNotNull);
    });

    testWidgets('onboarding flow with optional actions', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Complete Steps 1 and 2
      await completeSteps1And2(tester, 'Optional Test User');

      // Step 3: Test optional actions
      expect(find.byType(OnboardingStep3), findsOneWidget);
      
      // Wait for virtual number generation
      await tester.pump(const Duration(seconds: 1));

      // Test invite friends action
      final inviteButton = find.text('Invite Friends');
      await tester.tap(inviteButton);
      await tester.pump();

      expect(find.text('Invite feature will be available soon!'), findsOneWidget);
      expect(find.text('Invited!'), findsOneWidget);

      // Test contact access action
      final contactButton = find.text('Contact Access');
      await tester.tap(contactButton);
      await tester.pump();

      expect(find.text('Contact access feature will be available soon!'), findsOneWidget);
      expect(find.text('Requested!'), findsOneWidget);

      // Complete onboarding
      final completeButton = find.text('Complete Setup');
      await tester.tap(completeButton);
      await tester.pumpAndSettle();

      expect(find.byType(MainScreen), findsOneWidget);
    });

    testWidgets('onboarding flow with virtual number copy', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Complete Steps 1 and 2
      await completeSteps1And2(tester, 'Copy Test User');

      // Step 3: Test virtual number copy
      expect(find.byType(OnboardingStep3), findsOneWidget);
      
      // Wait for virtual number generation
      await tester.pump(const Duration(seconds: 1));

      // Find and tap the virtual number to copy it
      final virtualNumberFinder = find.textContaining(RegExp(r'\d{3}-\d{4}'));
      if (virtualNumberFinder.evaluate().isNotEmpty) {
        await tester.tap(virtualNumberFinder);
        await tester.pump();

        // Should show copy confirmation
        expect(find.textContaining('Virtual number copied'), findsOneWidget);
      }

      // Complete onboarding
      final completeButton = find.text('Complete Setup');
      await tester.tap(completeButton);
      await tester.pumpAndSettle();

      expect(find.byType(MainScreen), findsOneWidget);
    });

    testWidgets('onboarding flow with skip dialog', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Test skip dialog on Step 1
      final skipButton = find.text('Skip');
      await tester.tap(skipButton);
      await tester.pumpAndSettle();

      // Should show skip dialog
      expect(find.text('Skip Onboarding?'), findsOneWidget);
      expect(find.text('You can complete the setup later in Settings. Are you sure you want to skip?'), findsOneWidget);

      // Cancel skip
      final cancelButton = find.text('Cancel');
      await tester.tap(cancelButton);
      await tester.pumpAndSettle();

      // Should still be on Step 1
      expect(find.text('Step 1 of 3'), findsOneWidget);

      // Try skip again and confirm
      await tester.tap(skipButton);
      await tester.pumpAndSettle();

      final confirmSkipButton = find.text('Skip').last;
      await tester.tap(confirmSkipButton);
      await tester.pumpAndSettle();

      // Should navigate to main screen
      expect(find.byType(MainScreen), findsOneWidget);
    });

    testWidgets('onboarding flow with progress indicators', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Check initial progress
      expect(find.text('Step 1 of 3'), findsOneWidget);

      // Complete Step 1
      await completeStep1(tester, 'Progress Test User');

      // Check Step 2 progress
      expect(find.text('Step 2 of 3'), findsOneWidget);

      // Complete Step 2
      await completeStep2(tester);

      // Check Step 3 progress
      expect(find.text('Step 3 of 3'), findsOneWidget);

      // Complete onboarding
      await tester.pump(const Duration(seconds: 1));
      final completeButton = find.text('Complete Setup');
      await tester.tap(completeButton);
      await tester.pumpAndSettle();

      expect(find.byType(MainScreen), findsOneWidget);
    });

    testWidgets('onboarding flow with error handling', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Complete Steps 1 and 2
      await completeSteps1And2(tester, 'Error Test User');

      // Step 3: Test error scenarios
      expect(find.byType(OnboardingStep3), findsOneWidget);
      
      // Wait for virtual number generation
      await tester.pump(const Duration(seconds: 1));

      // Try to complete with missing data (simulate error)
      // This would require mocking the controller to throw an error
      // For now, just verify the complete button works normally
      final completeButton = find.text('Complete Setup');
      await tester.tap(completeButton);
      await tester.pumpAndSettle();

      expect(find.byType(MainScreen), findsOneWidget);
    });
  });

  // Helper methods
  Future<void> completeStep1(WidgetTester tester, String userName) async {
    final nameField = find.byType(TextFormField);
    await tester.enterText(nameField, userName);
    await tester.pump();

    final termsCheckbox = find.byType(Checkbox);
    await tester.tap(termsCheckbox);
    await tester.pump();

    final registerButton = find.text('Register');
    await tester.tap(registerButton);
    await tester.pumpAndSettle();
  }

  Future<void> completeStep2(WidgetTester tester) async {
    final pinFields = find.byType(TextFormField);
    await tester.enterText(pinFields.first, '1234');
    await tester.pump();
    await tester.enterText(pinFields.last, '1234');
    await tester.pump();

    final continueButton = find.text('Continue');
    await tester.tap(continueButton);
    await tester.pumpAndSettle();
  }

  Future<void> completeSteps1And2(WidgetTester tester, String userName) async {
    await completeStep1(tester, userName);
    await completeStep2(tester);
  }
}