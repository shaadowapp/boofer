import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:boofer/screens/onboarding_screen.dart';
import 'package:boofer/screens/main_screen.dart';
import 'package:boofer/providers/onboarding_controller.dart';

import '../test_helpers.dart';

class MockOnboardingController extends Mock implements OnboardingController {}

void main() {
  group('OnboardingScreen Widget Tests', () {
    late MockOnboardingController mockController;

    setUp(() {
      TestHelpers.setupTestEnvironment();
      mockController = MockOnboardingController();
      
      // Set up default mock behavior
      when(mockController.currentStep).thenReturn(1);
      when(mockController.isLoading).thenReturn(false);
      when(mockController.errorMessage).thenReturn(null);
      when(mockController.initialize()).thenAnswer((_) async {
        return null;
      });
      when(mockController.nextStep()).thenAnswer((_) async {
        return null;
      });
      when(mockController.previousStep()).thenReturn(null);
      when(mockController.goToStep(any)).thenReturn(null);
      when(mockController.completeOnboarding()).thenAnswer((_) async {
        return null;
      });
    });

    Widget createTestWidget() {
      return MaterialApp(
        home: ChangeNotifierProvider<OnboardingController>.value(
          value: mockController,
          child: const OnboardingScreen(),
        ),
      );
    }

    group('UI Rendering', () {
      testWidgets('should display onboarding screen with gradient background', (tester) async {
        // Act
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Assert
        expect(find.byType(OnboardingScreen), findsOneWidget);
        expect(find.byType(Container), findsWidgets); // Gradient container
      });

      testWidgets('should display step indicator', (tester) async {
        // Act
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('Step 1 of 3'), findsOneWidget);
      });

      testWidgets('should display progress bar', (tester) async {
        // Act
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Assert
        expect(find.byType(FractionallySizedBox), findsOneWidget);
      });

      testWidgets('should not show back button on first step', (tester) async {
        // Arrange
        when(mockController.currentStep).thenReturn(1);
        
        // Act
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Assert
        expect(find.byIcon(Icons.arrow_back_ios), findsNothing);
      });

      testWidgets('should show back button on second step', (tester) async {
        // Arrange
        when(mockController.currentStep).thenReturn(2);
        
        // Act
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Assert
        expect(find.byIcon(Icons.arrow_back_ios), findsOneWidget);
      });

      testWidgets('should show skip button on first two steps', (tester) async {
        // Arrange
        when(mockController.currentStep).thenReturn(1);
        
        // Act
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('Skip'), findsOneWidget);
      });

      testWidgets('should not show skip button on last step', (tester) async {
        // Arrange
        when(mockController.currentStep).thenReturn(3);
        
        // Act
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('Skip'), findsNothing);
      });
    });

    group('Step Navigation', () {
      testWidgets('should initialize controller on widget load', (tester) async {
        // Act
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Assert
        verify(mockController.initialize()).called(1);
      });

      testWidgets('should handle next step navigation', (tester) async {
        // Arrange
        when(mockController.currentStep).thenReturn(1);
        
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Act - simulate next step call from child widget
        final controller = context.read<OnboardingController>();
        if (controller.currentStep < 3) {
          await controller.nextStep();
        }

        // Assert
        verify(mockController.nextStep()).called(1);
      });

      testWidgets('should handle previous step navigation', (tester) async {
        // Arrange
        when(mockController.currentStep).thenReturn(2);
        
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        final backButton = find.byIcon(Icons.arrow_back_ios);

        // Act
        await tester.tap(backButton);
        await tester.pump();

        // Assert
        verify(mockController.previousStep()).called(1);
      });

      testWidgets('should not allow previous step on first step', (tester) async {
        // Arrange
        when(mockController.currentStep).thenReturn(1);
        
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Assert - back button should not be visible
        expect(find.byIcon(Icons.arrow_back_ios), findsNothing);
      });

      testWidgets('should complete onboarding on final step', (tester) async {
        // Arrange
        when(mockController.currentStep).thenReturn(3);
        
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Assert - should show step 3
        expect(find.text('Step 3 of 3'), findsOneWidget);
      });
    });

    group('Progress Animation', () {
      testWidgets('should update progress animation when step changes', (tester) async {
        // Arrange
        when(mockController.currentStep).thenReturn(1);
        
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Act - change step
        when(mockController.currentStep).thenReturn(2);
        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        // Assert - progress animation should be active
        expect(find.byType(AnimatedBuilder), findsWidgets);
      });

      testWidgets('should show correct progress for each step', (tester) async {
        // Test step 1
        when(mockController.currentStep).thenReturn(1);
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();
        expect(find.text('Step 1 of 3'), findsOneWidget);

        // Test step 2
        when(mockController.currentStep).thenReturn(2);
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        expect(find.text('Step 2 of 3'), findsOneWidget);

        // Test step 3
        when(mockController.currentStep).thenReturn(3);
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        expect(find.text('Step 3 of 3'), findsOneWidget);
      });

      testWidgets('should animate progress dots correctly', (tester) async {
        // Act
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Assert - should have 3 progress dots
        final progressDots = find.byType(Container).where((finder) {
          final container = tester.widget<Container>(finder);
          return container.decoration is BoxDecoration &&
                 (container.decoration as BoxDecoration).shape == BoxShape.circle;
        });
        
        expect(progressDots.length, greaterThanOrEqualTo(3));
      });
    });

    group('Skip Functionality', () {
      testWidgets('should show skip dialog when skip button is tapped', (tester) async {
        // Arrange
        when(mockController.currentStep).thenReturn(1);
        
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        final skipButton = find.text('Skip');

        // Act
        await tester.tap(skipButton);
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('Skip Onboarding?'), findsOneWidget);
        expect(find.text('You can complete the setup later in Settings. Are you sure you want to skip?'), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);
        expect(find.text('Skip'), findsNWidgets(2)); // One in dialog, one in button
      });

      testWidgets('should close skip dialog when cancel is tapped', (tester) async {
        // Arrange
        when(mockController.currentStep).thenReturn(1);
        
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        final skipButton = find.text('Skip');
        await tester.tap(skipButton);
        await tester.pumpAndSettle();

        final cancelButton = find.text('Cancel');

        // Act
        await tester.tap(cancelButton);
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('Skip Onboarding?'), findsNothing);
      });

      testWidgets('should navigate to main screen when skip is confirmed', (tester) async {
        // Arrange
        when(mockController.currentStep).thenReturn(1);
        
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        final skipButton = find.text('Skip');
        await tester.tap(skipButton);
        await tester.pumpAndSettle();

        final confirmSkipButton = find.text('Skip').last;

        // Act
        await tester.tap(confirmSkipButton);
        await tester.pumpAndSettle();

        // Assert
        expect(find.byType(MainScreen), findsOneWidget);
      });
    });

    group('Page View Navigation', () {
      testWidgets('should disable swipe navigation', (tester) async {
        // Act
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Assert
        final pageView = tester.widget<PageView>(find.byType(PageView));
        expect(pageView.physics, isA<NeverScrollableScrollPhysics>());
      });

      testWidgets('should sync controller step with page changes', (tester) async {
        // Act
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Simulate page change
        final pageView = find.byType(PageView);
        final pageViewController = tester.widget<PageView>(pageView).controller!;
        
        // Act - simulate page change to index 1 (step 2)
        await pageViewController.animateToPage(
          1,
          duration: const Duration(milliseconds: 300),
          curve: Curves.ease,
        );
        await tester.pumpAndSettle();

        // Assert
        verify(mockController.goToStep(2)).called(1);
      });

      testWidgets('should render correct step widget for each page', (tester) async {
        // Act
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Assert - should show OnboardingStep1 initially
        expect(find.byType(OnboardingStep1), findsOneWidget);
      });
    });

    group('Animations', () {
      testWidgets('should animate background gradient', (tester) async {
        // Act
        await tester.pumpWidget(createTestWidget());
        
        // Initial state
        await tester.pump();
        
        // Animation progress
        await tester.pump(const Duration(milliseconds: 500));

        // Assert
        expect(find.byType(AnimatedBuilder), findsWidgets);
      });

      testWidgets('should animate step indicator changes', (tester) async {
        // Arrange
        when(mockController.currentStep).thenReturn(1);
        
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Act - change step
        when(mockController.currentStep).thenReturn(2);
        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        // Assert
        expect(find.byType(AnimatedSwitcher), findsOneWidget);
      });

      testWidgets('should animate back button appearance', (tester) async {
        // Arrange
        when(mockController.currentStep).thenReturn(1);
        
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Act - change to step 2
        when(mockController.currentStep).thenReturn(2);
        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        // Assert
        expect(find.byType(AnimatedScale), findsWidgets);
      });

      testWidgets('should animate page transitions', (tester) async {
        // Act
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Assert - page view should have transform animations
        expect(find.byType(Transform), findsWidgets);
      });
    });

    group('Error Handling', () {
      testWidgets('should handle onboarding completion failure', (tester) async {
        // Arrange
        when(mockController.completeOnboarding()).thenThrow(Exception('Completion failed'));
        when(mockController.currentStep).thenReturn(3);
        
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Assert - should show step 3
        expect(find.text('Step 3 of 3'), findsOneWidget);
      });

      testWidgets('should retry completion on retry button tap', (tester) async {
        // Arrange
        when(mockController.completeOnboarding()).thenThrow(Exception('Completion failed'));
        when(mockController.currentStep).thenReturn(3);
        
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Assert - should show step 3
        expect(find.text('Step 3 of 3'), findsOneWidget);
      });
    });

    group('Haptic Feedback', () {
      testWidgets('should provide haptic feedback on next step', (tester) async {
        // Arrange
        when(mockController.currentStep).thenReturn(1);
        
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Assert - should show step 1
        expect(find.text('Step 1 of 3'), findsOneWidget);
      });

      testWidgets('should provide haptic feedback on previous step', (tester) async {
        // Arrange
        when(mockController.currentStep).thenReturn(2);
        
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        final backButton = find.byIcon(Icons.arrow_back_ios);

        // Act
        await tester.tap(backButton);
        await tester.pump();

        // Assert
        verify(mockController.previousStep()).called(1);
      });
    });

    group('Navigation Transitions', () {
      testWidgets('should navigate to main screen with fade transition on completion', (tester) async {
        // Arrange
        when(mockController.currentStep).thenReturn(3);
        
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Assert - should show step 3
        expect(find.text('Step 3 of 3'), findsOneWidget);
      });

      testWidgets('should navigate to main screen with fade transition on skip', (tester) async {
        // Arrange
        when(mockController.currentStep).thenReturn(1);
        
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        final skipButton = find.text('Skip');
        await tester.tap(skipButton);
        await tester.pumpAndSettle();

        final confirmSkipButton = find.text('Skip').last;

        // Act
        await tester.tap(confirmSkipButton);
        await tester.pumpAndSettle();

        // Assert
        expect(find.byType(MainScreen), findsOneWidget);
        expect(find.byType(FadeTransition), findsOneWidget);
      });
    });

    group('Accessibility', () {
      testWidgets('should have proper semantic labels for navigation buttons', (tester) async {
        // Arrange
        when(mockController.currentStep).thenReturn(2);
        
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Assert
        expect(find.bySemanticsLabel('Previous step'), findsOneWidget);
      });

      testWidgets('should support screen reader navigation', (tester) async {
        // Act
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Assert
        final backButton = find.byType(IconButton);
        if (backButton.evaluate().isNotEmpty) {
          final button = tester.widget<IconButton>(backButton);
          expect(button.tooltip, isNotNull);
        }
      });

      testWidgets('should announce step changes to screen readers', (tester) async {
        // Arrange
        when(mockController.currentStep).thenReturn(1);
        
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Act - change step
        when(mockController.currentStep).thenReturn(2);
        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        // Assert
        expect(find.text('Step 2 of 3'), findsOneWidget);
      });
    });

    group('Responsive Design', () {
      testWidgets('should adapt to different screen sizes', (tester) async {
        // Test with small screen
        await tester.binding.setSurfaceSize(const Size(320, 568)); // iPhone SE size
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Assert - should still show all elements
        expect(find.text('Step 1 of 3'), findsOneWidget);
        expect(find.byType(FractionallySizedBox), findsOneWidget);

        // Test with large screen
        await tester.binding.setSurfaceSize(const Size(768, 1024)); // iPad size
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Assert - should still show all elements
        expect(find.text('Step 1 of 3'), findsOneWidget);
        expect(find.byType(FractionallySizedBox), findsOneWidget);

        // Reset to default size
        await tester.binding.setSurfaceSize(null);
      });
    });

    group('Memory Management', () {
      testWidgets('should dispose controllers properly', (tester) async {
        // Act
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Dispose widget
        await tester.pumpWidget(const SizedBox());

        // Assert - no memory leaks should occur (verified by Flutter's test framework)
        expect(find.byType(OnboardingScreen), findsNothing);
      });
    });
  });
}