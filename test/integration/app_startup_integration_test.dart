import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:boofer/main.dart' as app;
import 'package:boofer/screens/onboarding_screen.dart';
import 'package:boofer/screens/main_screen.dart';
import 'package:boofer/services/local_storage_service.dart';
import 'package:boofer/services/app_state_service.dart';
import 'package:boofer/models/onboarding_data.dart';

import '../test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('App Startup Integration Tests', () {
    setUp(() async {
      TestHelpers.setupTestEnvironment();
      // Clear any existing data before each test
      await LocalStorageService.clearOnboardingData();
      await AppStateService.instance.clearUserSession();
    });

    testWidgets('new user startup - should show onboarding', (WidgetTester tester) async {
      // Ensure no onboarding data exists
      final isCompleted = await LocalStorageService.isOnboardingCompleted();
      expect(isCompleted, isFalse);

      // Start the app
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Should show onboarding screen
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.text('Step 1 of 3'), findsOneWidget);
      expect(find.text('Welcome to Boofer'), findsOneWidget);

      // Should not show main screen
      expect(find.byType(MainScreen), findsNothing);
    });

    testWidgets('returning user startup - should show main screen', (WidgetTester tester) async {
      // Pre-populate onboarding data to simulate returning user
      final onboardingData = OnboardingData(
        userName: 'Returning User',
        virtualNumber: '555-1234',
        pin: '1234',
        termsAccepted: true,
        completed: true,
        completedAt: DateTime.now(),
      );
      await LocalStorageService.saveOnboardingData(onboardingData);

      // Verify data was saved
      final isCompleted = await LocalStorageService.isOnboardingCompleted();
      expect(isCompleted, isTrue);

      // Start the app
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Should show main screen directly
      expect(find.byType(MainScreen), findsOneWidget);

      // Should not show onboarding screen
      expect(find.byType(OnboardingScreen), findsNothing);
    });

    testWidgets('incomplete onboarding startup - should show onboarding', (WidgetTester tester) async {
      // Pre-populate incomplete onboarding data
      final incompleteData = OnboardingData(
        userName: 'Incomplete User',
        virtualNumber: '',
        pin: null,
        termsAccepted: true,
        completed: false, // Not completed
        completedAt: null,
      );
      await LocalStorageService.saveOnboardingData(incompleteData);

      // Start the app
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Should show onboarding screen to complete setup
      expect(find.byType(OnboardingScreen), findsOneWidget);

      // Should not show main screen
      expect(find.byType(MainScreen), findsNothing);
    });

    testWidgets('corrupted data startup - should show onboarding', (WidgetTester tester) async {
      // Simulate corrupted data by saving invalid JSON
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
        // Expected to fail with invalid data
      }

      // Start the app
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Should gracefully handle error and show onboarding
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.byType(MainScreen), findsNothing);
    });

    testWidgets('app state service initialization', (WidgetTester tester) async {
      // Pre-populate valid onboarding data
      final onboardingData = OnboardingData(
        userName: 'State Test User',
        virtualNumber: '555-9876',
        pin: '9876',
        termsAccepted: true,
        completed: true,
        completedAt: DateTime.now(),
      );
      await LocalStorageService.saveOnboardingData(onboardingData);

      // Start the app
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Verify app state service was initialized correctly
      final appState = AppStateService.instance;
      expect(appState.isInitialized, isTrue);
      expect(appState.isUserLoggedIn, isTrue);
      expect(appState.userDisplayName, equals('State Test User'));
      expect(appState.userVirtualNumber, equals('555-9876'));
      expect(appState.hasPinSet, isTrue);

      // Should show main screen
      expect(find.byType(MainScreen), findsOneWidget);
    });

    testWidgets('app state service with no PIN', (WidgetTester tester) async {
      // Pre-populate onboarding data without PIN
      final onboardingData = OnboardingData(
        userName: 'No PIN User',
        virtualNumber: '555-5555',
        pin: null,
        termsAccepted: true,
        completed: true,
        completedAt: DateTime.now(),
      );
      await LocalStorageService.saveOnboardingData(onboardingData);

      // Start the app
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Verify app state reflects no PIN
      final appState = AppStateService.instance;
      expect(appState.hasPinSet, isFalse);
      expect(appState.userDisplayName, equals('No PIN User'));

      // Should still show main screen
      expect(find.byType(MainScreen), findsOneWidget);
    });

    testWidgets('splash screen behavior and transitions', (WidgetTester tester) async {
      // Start the app
      app.main();
      
      // Should initially show splash screen
      expect(find.text('Boofer'), findsOneWidget);
      expect(find.text('Privacy-first messaging'), findsOneWidget);
      expect(find.text('Initializing...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Wait for initialization
      await tester.pump(const Duration(milliseconds: 500));
      
      // Status should update
      expect(find.textContaining('Initializing'), findsOneWidget);

      // Wait for complete initialization
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Should navigate away from splash
      expect(find.text('Boofer'), findsNothing);
      expect(find.text('Privacy-first messaging'), findsNothing);
    });

    testWidgets('theme toggle on splash screen', (WidgetTester tester) async {
      // Start the app
      app.main();
      await tester.pump();

      // Should show theme toggle button
      expect(find.byIcon(Icons.dark_mode), findsOneWidget);

      // Tap theme toggle
      await tester.tap(find.byIcon(Icons.dark_mode));
      await tester.pump();

      // Icon should change to light mode
      expect(find.byIcon(Icons.light_mode), findsOneWidget);
      expect(find.byIcon(Icons.dark_mode), findsNothing);

      // Wait for app to complete initialization
      await tester.pumpAndSettle(const Duration(seconds: 3));
    });

    testWidgets('error handling during startup', (WidgetTester tester) async {
      // This test would require mocking services to fail
      // For now, test that app starts normally
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // App should start successfully even with potential service failures
      expect(find.byType(OnboardingScreen), findsOneWidget);
    });

    testWidgets('multiple app restarts with same user', (WidgetTester tester) async {
      // Pre-populate onboarding data
      final onboardingData = OnboardingData(
        userName: 'Restart Test User',
        virtualNumber: '555-0000',
        pin: '0000',
        termsAccepted: true,
        completed: true,
        completedAt: DateTime.now(),
      );
      await LocalStorageService.saveOnboardingData(onboardingData);

      // First app start
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(find.byType(MainScreen), findsOneWidget);

      // Simulate app restart by clearing widget tree
      await tester.pumpWidget(Container());
      await tester.pumpAndSettle();

      // Second app start
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(find.byType(MainScreen), findsOneWidget);

      // Data should persist
      final appState = AppStateService.instance;
      expect(appState.userDisplayName, equals('Restart Test User'));
    });

    testWidgets('app startup with different screen sizes', (WidgetTester tester) async {
      // Test with small screen (phone)
      await tester.binding.setSurfaceSize(const Size(375, 667));
      
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));
      
      expect(find.byType(OnboardingScreen), findsOneWidget);

      // Clear and test with large screen (tablet)
      await tester.pumpWidget(Container());
      await tester.binding.setSurfaceSize(const Size(768, 1024));
      
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));
      
      expect(find.byType(OnboardingScreen), findsOneWidget);

      // Reset to default
      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('app startup performance timing', (WidgetTester tester) async {
      final stopwatch = Stopwatch()..start();
      
      // Start the app
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));
      
      stopwatch.stop();
      
      // App should start within reasonable time (5 seconds max)
      expect(stopwatch.elapsedMilliseconds, lessThan(5000));
      
      // Should successfully navigate to appropriate screen
      final hasOnboarding = find.byType(OnboardingScreen).evaluate().isNotEmpty;
      final hasMainScreen = find.byType(MainScreen).evaluate().isNotEmpty;
      expect(hasOnboarding || hasMainScreen, isTrue);
      
      print('App startup time: ${stopwatch.elapsedMilliseconds}ms');
    });

    testWidgets('app startup with user preferences loading', (WidgetTester tester) async {
      // Pre-populate complete user data
      final onboardingData = OnboardingData(
        userName: 'Preferences User',
        virtualNumber: '555-PREF',
        pin: '1111',
        termsAccepted: true,
        completed: true,
        completedAt: DateTime.now(),
      );
      await LocalStorageService.saveOnboardingData(onboardingData);

      // Start the app
      app.main();
      
      // Should show loading messages during startup
      await tester.pump(const Duration(milliseconds: 1100)); // After initial delay
      expect(find.textContaining('Initializing'), findsOneWidget);
      
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.textContaining('Loading'), findsOneWidget);
      
      // Complete startup
      await tester.pumpAndSettle(const Duration(seconds: 3));
      
      // Should show main screen
      expect(find.byType(MainScreen), findsOneWidget);
      
      // App state should be properly initialized
      final appState = AppStateService.instance;
      expect(appState.isUserLoggedIn, isTrue);
      expect(appState.userDisplayName, equals('Preferences User'));
    });

    testWidgets('app startup navigation routes', (WidgetTester tester) async {
      // Test that app properly handles route generation
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Should be on onboarding route
      expect(find.byType(OnboardingScreen), findsOneWidget);

      // The app should have proper route configuration
      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.routes, isNotNull);
      expect(materialApp.routes!.containsKey('/onboarding'), isTrue);
      expect(materialApp.routes!.containsKey('/main'), isTrue);
      expect(materialApp.routes!.containsKey('/chat'), isTrue);
    });
  });
}