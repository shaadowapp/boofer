import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boofer/widgets/message_bubble.dart';
import 'package:boofer/models/message_model.dart';

void main() {
  group('MessageBubble Widget Tests', () {
    late Message testMessage;

    setUp(() {
      testMessage = Message()
        ..id = 1
        ..text = 'Test message'
        ..senderId = 'user123'
        ..timestamp = DateTime.now()
        ..isOffline = false
        ..status = MessageStatus.sent;
    });

    testWidgets('displays message text correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(message: testMessage),
          ),
        ),
      );

      expect(find.text('Test message'), findsOneWidget);
    });

    testWidgets('shows correct status icon for sent message', (WidgetTester tester) async {
      testMessage.status = MessageStatus.sent;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(message: testMessage),
          ),
        ),
      );

      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('shows correct status icon for delivered message', (WidgetTester tester) async {
      testMessage.status = MessageStatus.delivered;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(message: testMessage),
          ),
        ),
      );

      expect(find.byIcon(Icons.done_all), findsOneWidget);
    });

    testWidgets('shows correct status icon for pending message', (WidgetTester tester) async {
      testMessage.status = MessageStatus.pending;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(message: testMessage),
          ),
        ),
      );

      expect(find.byIcon(Icons.access_time), findsOneWidget);
    });

    testWidgets('shows correct status icon for failed message', (WidgetTester tester) async {
      testMessage.status = MessageStatus.failed;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(message: testMessage),
          ),
        ),
      );

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('displays offline indicator for offline messages', (WidgetTester tester) async {
      testMessage.isOffline = true;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(message: testMessage),
          ),
        ),
      );

      expect(find.byIcon(Icons.wifi_off), findsOneWidget);
    });

    testWidgets('displays online indicator for online messages', (WidgetTester tester) async {
      testMessage.isOffline = false;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(message: testMessage),
          ),
        ),
      );

      expect(find.byIcon(Icons.wifi), findsOneWidget);
    });

    testWidgets('displays timestamp correctly', (WidgetTester tester) async {
      final now = DateTime.now();
      testMessage.timestamp = now;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(message: testMessage),
          ),
        ),
      );

      // Check that some time format is displayed
      expect(find.textContaining(':'), findsOneWidget);
    });

    testWidgets('applies correct styling for own messages', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(message: testMessage, isOwnMessage: true),
          ),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration as BoxDecoration;
      
      // Should be aligned to the right and have primary color
      expect(decoration.color, Colors.blue);
    });

    testWidgets('applies correct styling for other messages', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(message: testMessage, isOwnMessage: false),
          ),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration as BoxDecoration;
      
      // Should be aligned to the left and have grey color
      expect(decoration.color, Colors.grey[300]);
    });
  });
}