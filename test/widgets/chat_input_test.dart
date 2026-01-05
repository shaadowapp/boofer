import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boofer/widgets/chat_input.dart';
import 'package:boofer/models/message_model.dart';

void main() {
  group('ChatInput Widget Tests', () {
    testWidgets('displays text input field', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatInput(
              onSendMessage: (text) {},
              onModeToggle: () {},
              isOfflineMode: false,
            ),
          ),
        ),
      );

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Type a message...'), findsOneWidget);
    });

    testWidgets('displays send button', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatInput(
              onSendMessage: (text) {},
              onModeToggle: () {},
              isOfflineMode: false,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.send), findsOneWidget);
    });

    testWidgets('displays mode toggle switch', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatInput(
              onSendMessage: (text) {},
              onModeToggle: () {},
              isOfflineMode: false,
            ),
          ),
        ),
      );

      expect(find.byType(Switch), findsOneWidget);
    });

    testWidgets('calls onSendMessage when send button is tapped with text', (WidgetTester tester) async {
      String? sentMessage;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatInput(
              onSendMessage: (text) {
                sentMessage = text;
              },
              onModeToggle: () {},
              isOfflineMode: false,
            ),
          ),
        ),
      );

      // Enter text
      await tester.enterText(find.byType(TextField), 'Hello World');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();

      expect(sentMessage, equals('Hello World'));
    });

    testWidgets('does not call onSendMessage when send button is tapped with empty text', (WidgetTester tester) async {
      bool messageSent = false;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatInput(
              onSendMessage: (text) {
                messageSent = true;
              },
              onModeToggle: () {},
              isOfflineMode: false,
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();

      expect(messageSent, isFalse);
    });

    testWidgets('clears text field after sending message', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatInput(
              onSendMessage: (text) {},
              onModeToggle: () {},
              isOfflineMode: false,
            ),
          ),
        ),
      );

      // Enter text and send
      await tester.enterText(find.byType(TextField), 'Hello World');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();

      // Check that text field is cleared
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, isEmpty);
    });

    testWidgets('calls onModeToggle when switch is toggled', (WidgetTester tester) async {
      bool modeToggled = false;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatInput(
              onSendMessage: (text) {},
              onModeToggle: () {
                modeToggled = true;
              },
              isOfflineMode: false,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(Switch));
      await tester.pump();

      expect(modeToggled, isTrue);
    });

    testWidgets('switch reflects offline mode state', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatInput(
              onSendMessage: (text) {},
              onModeToggle: () {},
              isOfflineMode: true,
            ),
          ),
        ),
      );

      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.value, isTrue);
    });

    testWidgets('switch reflects online mode state', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatInput(
              onSendMessage: (text) {},
              onModeToggle: () {},
              isOfflineMode: false,
            ),
          ),
        ),
      );

      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.value, isFalse);
    });

    testWidgets('displays offline mode label', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatInput(
              onSendMessage: (text) {},
              onModeToggle: () {},
              isOfflineMode: true,
            ),
          ),
        ),
      );

      expect(find.text('Offline Mode'), findsOneWidget);
    });

    testWidgets('enforces character limit', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatInput(
              onSendMessage: (text) {},
              onModeToggle: () {},
              isOfflineMode: false,
            ),
          ),
        ),
      );

      // Try to enter text longer than limit (assuming 500 character limit)
      final longText = 'a' * 600;
      await tester.enterText(find.byType(TextField), longText);
      await tester.pump();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text.length, lessThanOrEqualTo(500));
    });
  });
}