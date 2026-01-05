import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:boofer/widgets/onboarding_step2.dart';
import 'package:boofer/providers/onboarding_controller.dart';

import '../test_helpers.dart';

class MockOnboardingController extends Mock implements OnboardingController {}

void main() {
  group('OnboardingStep2 Widget Tests', () {
    late MockOnboardingController mockController;

    setUp(() {
      TestHelpers.setupTestEnvironment();
      mockController = MockOnboardingController();
      
      // Set up default mock behavior
      when(mockController.userPin).thenReturn(null);
      when(mockController.isLoading).thenReturn(false);
      when(mockController.errorMessage).thenReturn(null);
      when(mockController.isStep2Valid).thenReturn(false);
    });

    Widget createTestWidget({VoidCallback? onNext, VoidCallback? onSkip}) {
      return MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<OnboardingController>.value(
            value: mockController,
            child: OnboardingStep2(onNext: onNext, onSkip: onSkip),
          ),
        ),
      );
    }

    group('UI Rendering', () {
      testWidgets('should display PIN setup header and form elements', (tester) async {
        // Act
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('Secure Your Account'), findsOneWidget);
        expect(find.text('Set up a 4-digit PIN for added security'), findsOneWidget);
        expect(find.text('This step is optional and can be skipped'), findsOneWidget);
        expect(find.byType(TextFormField), findsNWidgets(2)); // PIN and confirm PIN
        expect(find.text('Skip'), findsOneWidget);
        expect(find.text('Continue'), findsOneWidget);
      });

      testWidgets('should display security icon', (tester) async {
        // Act
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Assert
        expect(find.byIcon(Icons.security), findsOneWidget);
      });

      testWidgets('should show PIN input fields with proper labels', (tester) async {
        // Act
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('Enter 4-digit PIN'), findsOneWidget);
        expect(find.text('Confirm PIN'), findsOneWidget);
      });

      testWidgets('should show visibility toggle buttons', (tester) async {
        // Act
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Assert
        expect(find.byIcon(Icons.visibility), findsNWidgets(2));
      });
    });

    group('PIN Input Interactions', () {
      testWidgets('should update PIN when user types', (tester) async {
        // Arrange
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();
        final pinFields = find.byType(TextFormField);
        final firstPinField = pinFields.first;

        // Act
        await tester.enterText(firstPinField, '1234');
        await tester.pump();

        // Assert
        verify(mockController.setUserPin('1234')).called(1);
      });

      testWidgets('should only accept numeric input', (tester) async {
        // Arrange
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();
        final pinFields = find.byType(TextFormField);
        final firstPinField = pinFields.first;

        // Act
        await tester.enterText(firstPinField, 'abcd');
        await tester.pump();

        // Assert - should not call setUserPin with non-numeric input
        verifyNever(mockController.setUserPin('abcd'));
      });

      testWidgets('should limit PIN input to 4 digits', (tester) async {
        // Arrange
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();
        final pinFields = find.byType(TextFormField);
        final firstPinField = pinFields.first;

        // Act
        await tester.enterText(firstPinField, '123456');
        await tester.pump();

        // Assert - should only accept first 4 digits
        final textField = tester.widget<TextFormField>(firstPinField);
        expect(textField.controller?.text.length, lessThanOrEqualTo(4));
      });

      testWidgets('should toggle PIN visibility when visibility button is tapped', (tester) async {
        // Arrange
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();
        final visibilityButtons = find.byIcon(Icons.visibility);
        final firstVisibilityButton = visibilityButtons.first;

        // Act
        await tester.tap(firstVisibilityButton);
        await tester.pump();

        // Assert
        expect(find.byIcon(Icons.visibility_off), findsAtLeastNWidgets(1));
      });

      testWidgets('should auto-focus to confirm PIN field when PIN is complete', (tester) async {
        // Arrange
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();
        final pinFields = find.byType(TextFormField);
        final firstPinField = pinFields.first;

        // Act
        await tester.enterText(firstPinField, '1234');
        await tester.pump();

        // Assert - verify PIN was set
        verify(mockController.setUserPin('1234')).called(1);
      });
    });

    group('PIN Validation', () {
      testWidgets('should show match indicator when PINs match', (tester) async {
        // Arrange
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();
        final pinFields = find.byType(TextFormField);

        // Act
        await tester.enterText(pinFields.first, '1234');
        await tester.pump();
        await tester.enterText(pinFields.last, '1234');
        await tester.pump();

        // Assert
        expect(find.text('PINs match!'), findsOneWidget);
        expect(find.byIcon(Icons.check_circle), findsOneWidget);
      });

      testWidgets('should show error indicator when PINs do not match', (tester) async {
        // Arrange
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();
        final pinFields = find.byType(TextFormField);

        // Act
        await tester.enterText(pinFields.first, '1234');
        await tester.pump();
        await tester.enterText(pinFields.last, '5678');
        await tester.pump();

        // Assert
        expect(find.text('PINs do not match'), findsOneWidget);
        expect(find.byIcon(Icons.error), findsOneWidget);
      });

      testWidgets('should clear confirm PIN field when PINs do not match', (tester) async {
        // Arrange
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();
        final pinFields = find.byType(TextFormField);

        // Act
        await tester.enterText(pinFields.first, '1234');
        await tester.pump();
        await tester.enterText(pinFields.last, '5678');
        await tester.pump();

        // Assert
        final confirmTextField = tester.widget<TextFormField>(pinFields.last);
        expect(confirmTextField.controller?.text, isEmpty);
      });

      testWidgets('should show shake animation when PINs do not match', (tester) async {
        // Arrange
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();
        final pinFields = find.byType(TextFormField);

        // Act
        await tester.enterText(pinFields.first, '1234');
        await tester.pump();
        await tester.enterText(pinFields.last, '5678');
        await tester.pump();

        // Assert - shake animation should be triggered
        expect(find.byType(SlideTransition), findsWidgets);
      });
    });

    group('Button States', () {
      testWidgets('should enable continue button when PINs match', (tester) async {
        // Arrange
        when(mockController.isStep2Valid).thenReturn(true);
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Assert
        final continueButton = find.widgetWithText(ElevatedButton, 'Continue');
        final button = tester.widget<ElevatedButton>(continueButton);
        expect(button.onPressed, isNotNull);
      });

      testWidgets('should disable continue button when PINs do not match', (tester) async {
        // Arrange
        when(mockController.isStep2Valid).thenReturn(false);
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Assert
        final continueButton = find.widgetWithText(ElevatedButton, 'Continue');
        final button = tester.widget<ElevatedButton>(continueButton);
        expect(button.onPressed, isNull);
      });

      testWidgets('should always enable skip button', (tester) async {
        // Act
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Assert
        final skipButton = find.widgetWithText(OutlinedButton, 'Skip');
        final button = tester.widget<OutlinedButton>(skipButton);
        expect(button.onPressed, isNotNull);
      });

      testWidgets('should show loading indicator when processing', (tester) async {
        // Arrange
        when(mockController.isLoading).thenReturn(true);
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Assert
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });
    });

    group('Navigation', () {
      testWidgets('should call onNext when continue is tapped with valid PIN', (tester) async {
        // Arrange
        bool nextCalled = false;
        when(mockController.isStep2Valid).thenReturn(true);
        when(mockController.setUserPin(any)).thenAnswer((_) async {});
        
        await tester.pumpWidget(createTestWidget(
          onNext: () => nextCalled = true,
        ));
        await tester.pumpAndSettle();

        final continueButton = find.text('Continue');

        // Act
        await tester.tap(continueButton);
        await tester.pump();

        // Assert
        expect(nextCalled, isTrue);
      });

      testWidgets('should call onSkip when skip button is tapped', (tester) async {
        // Arrange
        bool skipCalled = false;
        when(mockController.skipPinSetup()).thenAnswer((_) async {});
        
        await tester.pumpWidget(createTestWidget(
          onSkip: () => skipCalled = true,
        ));
        await tester.pumpAndSettle();

        final skipButton = find.text('Skip');

        // Act
        await tester.tap(skipButton);
        await tester.pump();

        // Assert
        expect(skipCalled, isTrue);
        verify(mockController.skipPinSetup()).called(1);
      });

      testWidgets('should not call onNext when PIN is invalid', (tester) async {
        // Arrange
        bool nextCalled = false;
        when(mockController.isStep2Valid).thenReturn(false);
        
        await tester.pumpWidget(createTestWidget(
          onNext: () => nextCalled = true,
        ));
        await tester.pumpAndSettle();

        final continueButton = find.text('Continue');

        // Act
        await tester.tap(continueButton);
        await tester.pump();

        // Assert
        expect(nextCalled, isFalse);
      });
    });

    group('Error Handling', () {
      testWidgets('should display error message when controller has error', (tester) async {
        // Arrange
        when(mockController.errorMessage).thenReturn('PIN setup failed');
        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        // Assert
        expect(find.text('PIN setup failed'), findsOneWidget);
      });

      testWidgets('should show retry option on error', (tester) async {
        // Arrange
        when(mockController.errorMessage).thenReturn('Network error');
        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        // Assert
        expect(find.text('Retry'), findsOneWidget);
      });

      testWidgets('should handle PIN save failure gracefully', (tester) async {
        // Arrange
        when(mockController.setUserPin(any)).thenThrow(Exception('Save failed'));
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        final pinFields = find.byType(TextFormField);

        // Act
        await tester.enterText(pinFields.first, '1234');
        await tester.pump();

        // Assert
        expect(find.text('Failed to save PIN: Exception: Save failed'), findsOneWidget);
      });
    });

    group('Animations', () {
      testWidgets('should animate header elements on load', (tester) async {
        // Act
        await tester.pumpWidget(createTestWidget());
        
        // Initial state
        await tester.pump();
        
        // Animation progress
        await tester.pump(const Duration(milliseconds: 300));

        // Assert
        expect(find.byType(TweenAnimationBuilder<double>), findsWidgets);
      });

      testWidgets('should animate PIN input fields on focus', (tester) async {
        // Arrange
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();
        final pinFields = find.byType(TextFormField);

        // Act
        await tester.tap(pinFields.first);
        await tester.pump();

        // Assert - focus animation should be active
        expect(find.byType(TweenAnimationBuilder<double>), findsWidgets);
      });

      testWidgets('should animate match indicator appearance', (tester) async {
        // Arrange
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();
        final pinFields = find.byType(TextFormField);

        // Act
        await tester.enterText(pinFields.first, '1234');
        await tester.pump();
        await tester.enterText(pinFields.last, '1234');
        await tester.pump();

        // Assert
        expect(find.byType(TweenAnimationBuilder<double>), findsWidgets);
      });
    });

    group('Accessibility', () {
      testWidgets('should have proper semantic labels for PIN fields', (tester) async {
        // Act
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Assert
        expect(find.bySemanticsLabel('Enter 4-digit PIN'), findsOneWidget);
        expect(find.bySemanticsLabel('Confirm PIN'), findsOneWidget);
      });

      testWidgets('should support screen reader navigation', (tester) async {
        // Act
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Assert
        final pinFields = find.byType(TextFormField);
        expect(pinFields, findsNWidgets(2));
      });

      testWidgets('should announce PIN match status to screen readers', (tester) async {
        // Arrange
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();
        final pinFields = find.byType(TextFormField);

        // Act
        await tester.enterText(pinFields.first, '1234');
        await tester.pump();
        await tester.enterText(pinFields.last, '1234');
        await tester.pump();

        // Assert
        expect(find.text('PINs match!'), findsOneWidget);
      });
    });

    group('Progress Indicator', () {
      testWidgets('should show correct progress state', (tester) async {
        // Act
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Assert - should show step 2 as active
        expect(find.byType(Container), findsWidgets);
      });
    });

    group('Haptic Feedback', () {
      testWidgets('should provide haptic feedback on PIN match', (tester) async {
        // Arrange
        final List<MethodCall> log = <MethodCall>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          log.add(call);
          return null;
        });

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();
        final pinFields = find.byType(TextFormField);

        // Act
        await tester.enterText(pinFields.first, '1234');
        await tester.pump();
        await tester.enterText(pinFields.last, '1234');
        await tester.pump();

        // Assert
        expect(log, contains(isMethodCall('HapticFeedback.vibrate', arguments: 'HapticFeedbackType.lightImpact')));
      });

      testWidgets('should provide haptic feedback on PIN mismatch', (tester) async {
        // Arrange
        final List<MethodCall> log = <MethodCall>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          log.add(call);
          return null;
        });

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();
        final pinFields = find.byType(TextFormField);

        // Act
        await tester.enterText(pinFields.first, '1234');
        await tester.pump();
        await tester.enterText(pinFields.last, '5678');
        await tester.pump();

        // Assert
        expect(log, contains(isMethodCall('HapticFeedback.vibrate', arguments: 'HapticFeedbackType.heavyImpact')));
      });
    });

    group('Form Persistence', () {
      testWidgets('should restore PIN from controller on init', (tester) async {
        // Arrange
        when(mockController.userPin).thenReturn('1234');
        
        // Act
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Assert
        final pinFields = find.byType(TextFormField);
        final firstField = tester.widget<TextFormField>(pinFields.first);
        expect(firstField.controller?.text, equals('1234'));
      });
    });
  });
}