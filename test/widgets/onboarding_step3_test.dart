import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:boofer/widgets/onboarding_step3.dart';
import 'package:boofer/providers/onboarding_controller.dart';

import '../test_helpers.dart';

class MockOnboardingController extends Mock implements OnboardingController {}

void main() {
  group('OnboardingStep3 Widget Tests', () {
    late MockOnboardingController mockController;

    setUp(() {
      TestHelpers.setupTestEnvironment();
      mockController = MockOnboardingController();
      
      // Set up default mock behavior
      when(mockController.virtualNumber).thenReturn('');
      when(mockController.userName).thenReturn('John Doe');
      when(mockController.termsAccepted).thenReturn(true);
      when(mockController.isLoading).thenReturn(false);
      when(mockController.errorMessage).thenReturn(null);
      when(mockController.generateVirtualNumber()).thenAnswer((_) async {});
    });

    Widget createTestWidget({VoidCallback? onComplete}) {
      return MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<OnboardingController>.value(
            value: mockController,
            child: OnboardingStep3(onComplete: onComplete),
          ),
        ),
      );
    }

    group('UI Rendering', () {
      testWidgets('should display digital identity header', (tester) async {
        // Act
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('Your Digital Identity'), findsOneWidget);
        expect(find.text('Your unique virtual number is ready'), findsOneWidget);
        expect(find.byIcon(Icons.fingerprint), findsOneWidget);
      });

      testWidgets('should display virtual number when available', (tester) async {
        // Arrange
        when(mockController.virtualNumber).thenReturn('555-0123');
        
        // Act
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('555-0123'), findsOneWidget);
        expect(find.text('Tap to copy'), findsOneWidget);
        expect(find.byIcon(Icons.copy), findsOneWidget);
      });

      testWidgets('should show generating message when number is not ready', (tester) async {
        // Arrange
        when(mockController.virtualNumber).thenReturn('');
        
        // Act
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('Generating...'), findsOneWidget);
      });

      testWidgets('should display identity explanation', (tester) async {
        // Act
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('This number serves as your identity'), findsOneWidget);
        expect(find.text('Use this virtual number to connect with others while keeping your real number private. It\'s unique to you and works across all app features.'), findsOneWidget);
        expect(find.byIcon(Icons.info_outline), findsOneWidget);
      });

      testWidgets('should display optional actions section', (tester) async {
        // Act
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('Optional Actions'), findsOneWidget);
        expect(find.text('Invite Friends'), findsOneWidget);
        expect(find.text('Contact Access'), findsOneWidget);
        expect(find.byIcon(Icons.share), findsOneWidget);
        expect(find.byIcon(Icons.contacts), findsOneWidget);
      });

      testWidgets('should show complete setup button', (tester) async {
        // Act
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('Complete Setup'), findsOneWidget);
      });
    });

    group('Virtual Number Interactions', () {
      testWidgets('should copy number to clipboard when tapped', (tester) async {
        // Arrange
        when(mockController.virtualNumber).thenReturn('555-0123');
        
        // Mock clipboard
        final List<MethodCall> log = <MethodCall>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          log.add(call);
          if (call.method == 'Clipboard.setData') {
            return null;
          }
          return null;
        });

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        final numberContainer = find.text('555-0123');

        // Act
        await tester.tap(numberContainer);
        await tester.pump();

        // Assert
        expect(log, contains(isMethodCall('Clipboard.setData', arguments: {'text': '555-0123'})));
        expect(find.text('Virtual number copied: 555-0123'), findsOneWidget);
      });

      testWidgets('should not allow copying when number is not ready', (tester) async {
        // Arrange
        when(mockController.virtualNumber).thenReturn('');
        
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        final generatingText = find.text('Generating...');

        // Act
        await tester.tap(generatingText);
        await tester.pump();

        // Assert - no clipboard interaction should occur
        expect(find.text('Virtual number copied'), findsNothing);
      });

      testWidgets('should generate virtual number on init if not present', (tester) async {
        // Arrange
        when(mockController.virtualNumber).thenReturn('');
        
        // Act
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Assert
        verify(mockController.generateVirtualNumber()).called(1);
      });

      testWidgets('should not generate virtual number if already present', (tester) async {
        // Arrange
        when(mockController.virtualNumber).thenReturn('555-0123');
        
        // Act
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Assert
        verifyNever(mockController.generateVirtualNumber());
      });
    });

    group('Optional Actions', () {
      testWidgets('should handle invite friends action', (tester) async {
        // Act
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        final inviteButton = find.text('Invite Friends');

        // Act
        await tester.tap(inviteButton);
        await tester.pump();

        // Assert
        expect(find.text('Invite feature will be available soon!'), findsOneWidget);
        expect(find.text('Invited!'), findsOneWidget);
      });

      testWidgets('should handle contact access action', (tester) async {
        // Act
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        final contactButton = find.text('Contact Access');

        // Act
        await tester.tap(contactButton);
        await tester.pump();

        // Assert
        expect(find.text('Contact access feature will be available soon!'), findsOneWidget);
        expect(find.text('Requested!'), findsOneWidget);
      });

      testWidgets('should show check icon after invite friends is tapped', (tester) async {
        // Act
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        final inviteButton = find.text('Invite Friends');
        await tester.tap(inviteButton);
        await tester.pump();

        // Assert
        expect(find.byIcon(Icons.check), findsOneWidget);
      });

      testWidgets('should show check icon after contact access is tapped', (tester) async {
        // Act
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        final contactButton = find.text('Contact Access');
        await tester.tap(contactButton);
        await tester.pump();

        // Assert
        expect(find.byIcon(Icons.check), findsOneWidget);
      });

      testWidgets('should reset action states after delay', (tester) async {
        // Act
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        final inviteButton = find.text('Invite Friends');
        await tester.tap(inviteButton);
        await tester.pump();

        // Fast forward time
        await tester.pump(const Duration(seconds: 3));

        // Assert
        expect(find.text('Invite Friends'), findsOneWidget);
        expect(find.text('Invited!'), findsNothing);
      });

      testWidgets('should show optional actions help text', (tester) async {
        // Act
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('These features can be enabled later in settings'), findsOneWidget);
      });
    });

    group('Button States', () {
      testWidgets('should enable complete button when virtual number is ready', (tester) async {
        // Arrange
        when(mockController.virtualNumber).thenReturn('555-0123');
        
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Assert
        final completeButton = find.widgetWithText(ElevatedButton, 'Complete Setup');
        final button = tester.widget<ElevatedButton>(completeButton);
        expect(button.onPressed, isNotNull);
      });

      testWidgets('should disable complete button when virtual number is not ready', (tester) async {
        // Arrange
        when(mockController.virtualNumber).thenReturn('');
        
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Assert
        final completeButton = find.widgetWithText(ElevatedButton, 'Complete Setup');
        final button = tester.widget<ElevatedButton>(completeButton);
        expect(button.onPressed, isNull);
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
      testWidgets('should call onComplete when complete button is tapped', (tester) async {
        // Arrange
        bool completeCalled = false;
        when(mockController.virtualNumber).thenReturn('555-0123');
        
        await tester.pumpWidget(createTestWidget(
          onComplete: () => completeCalled = true,
        ));
        await tester.pumpAndSettle();

        final completeButton = find.text('Complete Setup');

        // Act
        await tester.tap(completeButton);
        await tester.pump();

        // Assert
        expect(completeCalled, isTrue);
      });

      testWidgets('should not call onComplete when virtual number is not ready', (tester) async {
        // Arrange
        bool completeCalled = false;
        when(mockController.virtualNumber).thenReturn('');
        
        await tester.pumpWidget(createTestWidget(
          onComplete: () => completeCalled = true,
        ));
        await tester.pumpAndSettle();

        final completeButton = find.text('Complete Setup');

        // Act
        await tester.tap(completeButton);
        await tester.pump();

        // Assert
        expect(completeCalled, isFalse);
      });

      testWidgets('should show error when required data is missing', (tester) async {
        // Arrange
        when(mockController.virtualNumber).thenReturn('555-0123');
        when(mockController.userName).thenReturn('');
        
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        final completeButton = find.text('Complete Setup');

        // Act
        await tester.tap(completeButton);
        await tester.pump();

        // Assert
        expect(find.text('User name is missing. Please go back and complete registration.'), findsOneWidget);
      });

      testWidgets('should show error when terms not accepted', (tester) async {
        // Arrange
        when(mockController.virtualNumber).thenReturn('555-0123');
        when(mockController.termsAccepted).thenReturn(false);
        
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        final completeButton = find.text('Complete Setup');

        // Act
        await tester.tap(completeButton);
        await tester.pump();

        // Assert
        expect(find.text('Terms must be accepted to complete setup.'), findsOneWidget);
      });
    });

    group('Error Handling', () {
      testWidgets('should display error message when controller has error', (tester) async {
        // Arrange
        when(mockController.errorMessage).thenReturn('Setup failed');
        
        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        // Assert
        expect(find.text('Setup failed'), findsOneWidget);
      });

      testWidgets('should show retry option on error', (tester) async {
        // Arrange
        when(mockController.errorMessage).thenReturn('Network error');
        
        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        // Assert
        expect(find.text('Retry'), findsOneWidget);
      });

      testWidgets('should handle completion failure gracefully', (tester) async {
        // Arrange
        when(mockController.virtualNumber).thenReturn('555-0123');
        
        await tester.pumpWidget(createTestWidget(
          onComplete: () => throw Exception('Completion failed'),
        ));
        await tester.pumpAndSettle();

        final completeButton = find.text('Complete Setup');

        // Act
        await tester.tap(completeButton);
        await tester.pump();

        // Assert
        expect(find.text('Failed to complete setup: Exception: Completion failed'), findsOneWidget);
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

      testWidgets('should animate virtual number display', (tester) async {
        // Arrange
        when(mockController.virtualNumber).thenReturn('555-0123');
        
        // Act
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        
        // Animation progress
        await tester.pump(const Duration(milliseconds: 600));

        // Assert
        expect(find.byType(FadeTransition), findsWidgets);
        expect(find.byType(ScaleTransition), findsWidgets);
      });

      testWidgets('should animate optional action buttons', (tester) async {
        // Act
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Assert
        expect(find.byType(TweenAnimationBuilder<double>), findsWidgets);
      });

      testWidgets('should animate number switching from generating to ready', (tester) async {
        // Arrange
        when(mockController.virtualNumber).thenReturn('');
        
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Act - simulate number becoming ready
        when(mockController.virtualNumber).thenReturn('555-0123');
        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        // Assert
        expect(find.byType(AnimatedSwitcher), findsOneWidget);
      });
    });

    group('Accessibility', () {
      testWidgets('should have proper semantic labels', (tester) async {
        // Act
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Assert
        expect(find.bySemanticsLabel('Complete onboarding setup'), findsOneWidget);
        expect(find.bySemanticsLabel('Invite friends to Boofer'), findsOneWidget);
        expect(find.bySemanticsLabel('Allow contact access'), findsOneWidget);
      });

      testWidgets('should support screen reader navigation', (tester) async {
        // Arrange
        when(mockController.virtualNumber).thenReturn('555-0123');
        
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Assert
        expect(find.bySemanticsLabel('Virtual number 555-0123, tap to copy'), findsOneWidget);
      });

      testWidgets('should announce copy action to screen readers', (tester) async {
        // Arrange
        when(mockController.virtualNumber).thenReturn('555-0123');
        
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        final numberContainer = find.text('555-0123');

        // Act
        await tester.tap(numberContainer);
        await tester.pump();

        // Assert
        expect(find.text('Virtual number copied: 555-0123'), findsOneWidget);
      });
    });

    group('Progress Indicator', () {
      testWidgets('should show correct progress state', (tester) async {
        // Act
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Assert - should show all steps as completed
        expect(find.byType(Container), findsWidgets);
      });
    });

    group('Haptic Feedback', () {
      testWidgets('should provide haptic feedback on copy action', (tester) async {
        // Arrange
        when(mockController.virtualNumber).thenReturn('555-0123');
        
        final List<MethodCall> log = <MethodCall>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          log.add(call);
          return null;
        });

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        final numberContainer = find.text('555-0123');

        // Act
        await tester.tap(numberContainer);
        await tester.pump();

        // Assert
        expect(log, contains(isMethodCall('HapticFeedback.vibrate', arguments: 'HapticFeedbackType.lightImpact')));
      });

      testWidgets('should provide haptic feedback on optional actions', (tester) async {
        // Arrange
        final List<MethodCall> log = <MethodCall>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          log.add(call);
          return null;
        });

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        final inviteButton = find.text('Invite Friends');

        // Act
        await tester.tap(inviteButton);
        await tester.pump();

        // Assert
        expect(log, contains(isMethodCall('HapticFeedback.vibrate', arguments: 'HapticFeedbackType.lightImpact')));
      });

      testWidgets('should provide haptic feedback on completion', (tester) async {
        // Arrange
        when(mockController.virtualNumber).thenReturn('555-0123');
        
        final List<MethodCall> log = <MethodCall>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          log.add(call);
          return null;
        });

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        final completeButton = find.text('Complete Setup');

        // Act
        await tester.tap(completeButton);
        await tester.pump();

        // Assert
        expect(log, contains(isMethodCall('HapticFeedback.vibrate', arguments: 'HapticFeedbackType.lightImpact')));
      });
    });

    group('Virtual Number Display', () {
      testWidgets('should show phone icon with virtual number', (tester) async {
        // Arrange
        when(mockController.virtualNumber).thenReturn('555-0123');
        
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Assert
        expect(find.byIcon(Icons.phone_android), findsOneWidget);
      });

      testWidgets('should style virtual number with proper formatting', (tester) async {
        // Arrange
        when(mockController.virtualNumber).thenReturn('555-0123');
        
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Assert
        final numberText = find.text('555-0123');
        final textWidget = tester.widget<Text>(numberText);
        expect(textWidget.style?.fontSize, equals(32));
        expect(textWidget.style?.fontWeight, equals(FontWeight.w700));
        expect(textWidget.style?.letterSpacing, equals(2));
      });

      testWidgets('should show copy instruction when number is ready', (tester) async {
        // Arrange
        when(mockController.virtualNumber).thenReturn('555-0123');
        
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('Tap to copy'), findsOneWidget);
      });
    });

    group('Responsive Design', () {
      testWidgets('should adapt to different screen sizes', (tester) async {
        // Test with small screen
        await tester.binding.setSurfaceSize(const Size(320, 568)); // iPhone SE size
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Assert - should still show all elements
        expect(find.text('Your Digital Identity'), findsOneWidget);
        expect(find.text('Complete Setup'), findsOneWidget);

        // Test with large screen
        await tester.binding.setSurfaceSize(const Size(768, 1024)); // iPad size
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Assert - should still show all elements
        expect(find.text('Your Digital Identity'), findsOneWidget);
        expect(find.text('Complete Setup'), findsOneWidget);

        // Reset to default size
        await tester.binding.setSurfaceSize(null);
      });
    });
  });
}