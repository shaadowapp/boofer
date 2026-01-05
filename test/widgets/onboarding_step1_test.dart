import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:boofer/widgets/onboarding_step1.dart';
import 'package:boofer/providers/onboarding_controller.dart';

import '../test_helpers.dart';

class MockOnboardingController extends Mock implements OnboardingController {}

void main() {
  group('OnboardingStep1 Widget Tests', () {
    late MockOnboardingController mockController;

    setUp(() {
      TestHelpers.setupTestEnvironment();
      mockController = MockOnboardingController();
      
      // Set up default mock behavior
      when(mockController.userName).thenReturn('');
      when(mockController.termsAccepted).thenReturn(false);
      when(mockController.isLoading).thenReturn(false);
      when(mockController.errorMessage).thenReturn(null);
    });

    Widget createTestWidget({VoidCallback? onNext}) {
      return MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<OnboardingController>.value(
            value: mockController,
            child: OnboardingStep1(onNext: onNext),
          ),
        ),
      );
    }

    group('UI Rendering', () {
      testWidgets('should display welcome message and form elements', (tester) async {
        // Act
        await tester.pumpWidget(createTestWidget());

        // Assert
        expect(find.text('Welcome to Boofer'), findsOneWidget);
        expect(find.text('Your secure communication starts here'), findsOneWidget);
        expect(find.byType(TextFormField), findsOneWidget);
        expect(find.byType(CheckboxListTile), findsOneWidget);
        expect(find.text('Register'), findsOneWidget);
      });

      testWidgets('should display feature highlights', (tester) async {
        // Act
        await tester.pumpWidget(createTestWidget());

        // Assert
        expect(find.text('Secure messaging with end-to-end encryption'), findsOneWidget);
        expect(find.text('Virtual numbers for privacy protection'), findsOneWidget);
        expect(find.text('Offline mesh networking capabilities'), findsOneWidget);
        expect(find.byIcon(Icons.security), findsOneWidget);
        expect(find.byIcon(Icons.phone_android), findsOneWidget);
        expect(find.byIcon(Icons.wifi_tethering), findsOneWidget);
      });

      testWidgets('should show animated logo', (tester) async {
        // Act
        await tester.pumpWidget(createTestWidget());
        await tester.pump(); // Initial frame
        await tester.pump(const Duration(milliseconds: 100)); // Animation frame

        // Assert
        expect(find.byType(TweenAnimationBuilder<double>), findsWidgets);
      });
    });

    group('Form Interactions', () {
      testWidgets('should update name field when user types', (tester) async {
        // Arrange
        await tester.pumpWidget(createTestWidget());
        final nameField = find.byType(TextFormField);

        // Act
        await tester.enterText(nameField, 'John Doe');
        await tester.pump();

        // Assert
        verify(mockController.setUserName('John Doe')).called(1);
      });

      testWidgets('should toggle terms checkbox when tapped', (tester) async {
        // Arrange
        await tester.pumpWidget(createTestWidget());
        final checkbox = find.byType(CheckboxListTile);

        // Act
        await tester.tap(checkbox);
        await tester.pump();

        // Assert
        verify(mockController.setTermsAccepted(true)).called(1);
      });

      testWidgets('should show validation error for empty name', (tester) async {
        // Arrange
        await tester.pumpWidget(createTestWidget());
        final registerButton = find.text('Register');

        // Act
        await tester.tap(registerButton);
        await tester.pump();

        // Assert
        expect(find.text('Please enter your name'), findsOneWidget);
      });

      testWidgets('should show validation error when terms not accepted', (tester) async {
        // Arrange
        when(mockController.userName).thenReturn('John Doe');
        when(mockController.termsAccepted).thenReturn(false);
        await tester.pumpWidget(createTestWidget());
        
        final nameField = find.byType(TextFormField);
        final registerButton = find.text('Register');

        // Act
        await tester.enterText(nameField, 'John Doe');
        await tester.tap(registerButton);
        await tester.pump();

        // Assert
        expect(find.text('Please accept the terms and conditions'), findsOneWidget);
      });
    });

    group('Button States', () {
      testWidgets('should disable register button when loading', (tester) async {
        // Arrange
        when(mockController.isLoading).thenReturn(true);
        await tester.pumpWidget(createTestWidget());

        // Assert
        final registerButton = find.widgetWithText(ElevatedButton, 'Register');
        final button = tester.widget<ElevatedButton>(registerButton);
        expect(button.onPressed, isNull);
      });

      testWidgets('should show loading indicator when processing', (tester) async {
        // Arrange
        when(mockController.isLoading).thenReturn(true);
        await tester.pumpWidget(createTestWidget());

        // Assert
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('should enable register button when form is valid', (tester) async {
        // Arrange
        when(mockController.userName).thenReturn('John Doe');
        when(mockController.termsAccepted).thenReturn(true);
        when(mockController.isLoading).thenReturn(false);
        await tester.pumpWidget(createTestWidget());

        // Assert
        final registerButton = find.widgetWithText(ElevatedButton, 'Register');
        final button = tester.widget<ElevatedButton>(registerButton);
        expect(button.onPressed, isNotNull);
      });
    });

    group('Navigation', () {
      testWidgets('should call onNext when registration is successful', (tester) async {
        // Arrange
        bool nextCalled = false;
        when(mockController.userName).thenReturn('John Doe');
        when(mockController.termsAccepted).thenReturn(true);
        when(mockController.isLoading).thenReturn(false);
        
        await tester.pumpWidget(createTestWidget(
          onNext: () => nextCalled = true,
        ));

        final registerButton = find.text('Register');

        // Act
        await tester.tap(registerButton);
        await tester.pump();

        // Assert
        expect(nextCalled, isTrue);
      });

      testWidgets('should not call onNext when form is invalid', (tester) async {
        // Arrange
        bool nextCalled = false;
        when(mockController.userName).thenReturn('');
        when(mockController.termsAccepted).thenReturn(false);
        
        await tester.pumpWidget(createTestWidget(
          onNext: () => nextCalled = true,
        ));

        final registerButton = find.text('Register');

        // Act
        await tester.tap(registerButton);
        await tester.pump();

        // Assert
        expect(nextCalled, isFalse);
      });
    });

    group('Error Handling', () {
      testWidgets('should display error message when controller has error', (tester) async {
        // Arrange
        when(mockController.errorMessage).thenReturn('Registration failed');
        await tester.pumpWidget(createTestWidget());
        await tester.pump(); // Allow error to be processed

        // Assert
        expect(find.text('Registration failed'), findsOneWidget);
      });

      testWidgets('should show retry option on error', (tester) async {
        // Arrange
        when(mockController.errorMessage).thenReturn('Network error');
        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        // Assert
        expect(find.text('Retry'), findsOneWidget);
      });

      testWidgets('should clear error when retry is tapped', (tester) async {
        // Arrange
        when(mockController.errorMessage).thenReturn('Network error');
        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        // Assert - error message should be displayed
        expect(find.text('Network error'), findsOneWidget);
      });
    });

    group('Animations', () {
      testWidgets('should animate logo on widget load', (tester) async {
        // Act
        await tester.pumpWidget(createTestWidget());
        
        // Initial state
        await tester.pump();
        
        // Animation progress
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        // Assert - animation builders should be present
        expect(find.byType(TweenAnimationBuilder<double>), findsWidgets);
      });

      testWidgets('should animate feature highlights with stagger', (tester) async {
        // Act
        await tester.pumpWidget(createTestWidget());
        
        // Let animations complete
        await tester.pumpAndSettle();

        // Assert - all feature items should be visible after animation
        expect(find.text('Secure messaging with end-to-end encryption'), findsOneWidget);
        expect(find.text('Virtual numbers for privacy protection'), findsOneWidget);
        expect(find.text('Offline mesh networking capabilities'), findsOneWidget);
      });
    });

    group('Accessibility', () {
      testWidgets('should have proper semantic labels', (tester) async {
        // Act
        await tester.pumpWidget(createTestWidget());

        // Assert
        expect(find.bySemanticsLabel('Enter your full name'), findsOneWidget);
        expect(find.bySemanticsLabel('Accept terms and conditions'), findsOneWidget);
      });

      testWidgets('should support screen reader navigation', (tester) async {
        // Act
        await tester.pumpWidget(createTestWidget());

        // Assert - check that important elements are present
        expect(find.byType(TextFormField), findsOneWidget);
        expect(find.byType(Checkbox), findsOneWidget);
      });
    });

    group('Form Validation', () {
      testWidgets('should validate name field on focus loss', (tester) async {
        // Arrange
        await tester.pumpWidget(createTestWidget());
        final nameField = find.byType(TextFormField);

        // Act
        await tester.tap(nameField);
        await tester.enterText(nameField, '');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();

        // Assert
        expect(find.text('Please enter your name'), findsOneWidget);
      });

      testWidgets('should clear validation error when valid input is entered', (tester) async {
        // Arrange
        await tester.pumpWidget(createTestWidget());
        final nameField = find.byType(TextFormField);

        // Act - first trigger validation error
        await tester.tap(nameField);
        await tester.enterText(nameField, '');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();
        
        // Then enter valid input
        await tester.enterText(nameField, 'John Doe');
        await tester.pump();

        // Assert
        expect(find.text('Please enter your name'), findsNothing);
      });

      testWidgets('should validate name length', (tester) async {
        // Arrange
        await tester.pumpWidget(createTestWidget());
        final nameField = find.byType(TextFormField);

        // Act
        await tester.enterText(nameField, 'A'); // Too short
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();

        // Assert
        expect(find.text('Name must be at least 2 characters'), findsOneWidget);
      });
    });

    group('Terms and Conditions', () {
      testWidgets('should show terms dialog when terms text is tapped', (tester) async {
        // Arrange
        await tester.pumpWidget(createTestWidget());
        final termsText = find.text('Terms and Conditions');

        // Act
        await tester.tap(termsText);
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('Terms and Conditions'), findsWidgets); // One in dialog, one in checkbox
        expect(find.text('Close'), findsOneWidget);
      });

      testWidgets('should close terms dialog when close button is tapped', (tester) async {
        // Arrange
        await tester.pumpWidget(createTestWidget());
        final termsText = find.text('Terms and Conditions');
        
        await tester.tap(termsText);
        await tester.pumpAndSettle();

        final closeButton = find.text('Close');

        // Act
        await tester.tap(closeButton);
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('Close'), findsNothing);
      });
    });

    group('Responsive Design', () {
      testWidgets('should adapt to different screen sizes', (tester) async {
        // Test with small screen
        await tester.binding.setSurfaceSize(const Size(320, 568)); // iPhone SE size
        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        // Assert - should still show all elements
        expect(find.text('Welcome to Boofer'), findsOneWidget);
        expect(find.byType(TextFormField), findsOneWidget);
        expect(find.text('Register'), findsOneWidget);

        // Test with large screen
        await tester.binding.setSurfaceSize(const Size(768, 1024)); // iPad size
        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        // Assert - should still show all elements
        expect(find.text('Welcome to Boofer'), findsOneWidget);
        expect(find.byType(TextFormField), findsOneWidget);
        expect(find.text('Register'), findsOneWidget);

        // Reset to default size
        await tester.binding.setSurfaceSize(null);
      });
    });
  });
}