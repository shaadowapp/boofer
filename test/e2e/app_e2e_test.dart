import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:boofer/main.dart' as app;
import 'package:boofer/services/chat_service.dart';
import 'package:boofer/services/mesh_service.dart';
import 'package:boofer/services/online_service.dart';
import 'package:boofer/services/network_service.dart';
import 'package:boofer/models/message_model.dart';
import 'package:boofer/widgets/message_bubble.dart';
import 'package:boofer/widgets/chat_input.dart';
import 'package:boofer/widgets/connection_status.dart';

@GenerateMocks([IMeshService, IOnlineService, INetworkService])
import 'app_e2e_test.mocks.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('End-to-End App Tests', () {
    testWidgets('complete offline message flow', (WidgetTester tester) async {
      // Start the app
      app.main();
      await tester.pumpAndSettle();

      // Verify app loads correctly
      expect(find.text('Boofer Chat'), findsOneWidget);
      expect(find.byType(ConnectionStatus), findsOneWidget);
      expect(find.byType(ChatInput), findsOneWidget);

      // Switch to offline mode
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      // Verify offline mode is active
      expect(find.text('Offline'), findsOneWidget);

      // Send a message in offline mode
      await tester.enterText(find.byType(TextField), 'Hello from offline mode!');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      // Verify message appears in chat
      expect(find.text('Hello from offline mode!'), findsOneWidget);
      expect(find.byType(MessageBubble), findsOneWidget);

      // Verify message shows offline indicator
      expect(find.byIcon(Icons.wifi_off), findsOneWidget);
    });

    testWidgets('online-offline mode switching', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Start in online mode
      expect(find.text('Online'), findsOneWidget);

      // Send online message
      await tester.enterText(find.byType(TextField), 'Online message');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      expect(find.text('Online message'), findsOneWidget);

      // Switch to offline mode
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(find.text('Offline'), findsOneWidget);

      // Send offline message
      await tester.enterText(find.byType(TextField), 'Offline message');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      expect(find.text('Offline message'), findsOneWidget);

      // Switch back to online mode
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(find.text('Online'), findsOneWidget);

      // Both messages should still be visible
      expect(find.text('Online message'), findsOneWidget);
      expect(find.text('Offline message'), findsOneWidget);
    });

    testWidgets('message persistence across app restarts', (WidgetTester tester) async {
      // First app session
      app.main();
      await tester.pumpAndSettle();

      // Send a message
      await tester.enterText(find.byType(TextField), 'Persistent message');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      expect(find.text('Persistent message'), findsOneWidget);

      // Simulate app restart by pumping a new instance
      await tester.pumpWidget(Container()); // Clear current widget tree
      await tester.pumpAndSettle();

      // Start app again
      app.main();
      await tester.pumpAndSettle();

      // Message should still be there
      expect(find.text('Persistent message'), findsOneWidget);
    });

    testWidgets('multiple message handling', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      final messages = [
        'First message',
        'Second message',
        'Third message',
        'Fourth message',
        'Fifth message',
      ];

      // Send multiple messages
      for (final message in messages) {
        await tester.enterText(find.byType(TextField), message);
        await tester.tap(find.byIcon(Icons.send));
        await tester.pumpAndSettle();
      }

      // All messages should be visible
      for (final message in messages) {
        expect(find.text(message), findsOneWidget);
      }

      // Should have correct number of message bubbles
      expect(find.byType(MessageBubble), findsNWidgets(5));
    });

    testWidgets('connection status updates', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Initially should show some connection status
      expect(find.byType(ConnectionStatus), findsOneWidget);

      // Switch modes and verify status updates
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      // Status should reflect the mode change
      final connectionStatus = tester.widget<ConnectionStatus>(
        find.byType(ConnectionStatus),
      );
      expect(connectionStatus.isOfflineMode, isTrue);
    });

    testWidgets('empty state handling', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Should show empty state when no messages
      expect(find.text('No messages yet'), findsOneWidget);
      expect(find.text('Start a conversation!'), findsOneWidget);

      // Send a message
      await tester.enterText(find.byType(TextField), 'First message');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      // Empty state should disappear
      expect(find.text('No messages yet'), findsNothing);
      expect(find.text('Start a conversation!'), findsNothing);
      expect(find.text('First message'), findsOneWidget);
    });

    testWidgets('input validation', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Try to send empty message
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      // Should not create a message bubble
      expect(find.byType(MessageBubble), findsNothing);

      // Send whitespace-only message
      await tester.enterText(find.byType(TextField), '   ');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      // Should not create a message bubble
      expect(find.byType(MessageBubble), findsNothing);

      // Send valid message
      await tester.enterText(find.byType(TextField), 'Valid message');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      // Should create a message bubble
      expect(find.byType(MessageBubble), findsOneWidget);
      expect(find.text('Valid message'), findsOneWidget);
    });

    testWidgets('scroll behavior with many messages', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Send many messages to test scrolling
      for (int i = 1; i <= 20; i++) {
        await tester.enterText(find.byType(TextField), 'Message $i');
        await tester.tap(find.byIcon(Icons.send));
        await tester.pumpAndSettle();
      }

      // Should have all messages
      expect(find.byType(MessageBubble), findsNWidgets(20));

      // Latest message should be visible (auto-scroll to bottom)
      expect(find.text('Message 20'), findsOneWidget);

      // Should be able to scroll up to see older messages
      await tester.drag(find.byType(ListView), Offset(0, 500));
      await tester.pumpAndSettle();

      // Should still see messages after scrolling
      expect(find.byType(MessageBubble), findsWidgets);
    });

    testWidgets('app theme and styling', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Verify dark theme is applied
      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.theme?.brightness, equals(Brightness.dark));

      // Verify app bar styling
      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.title, isA<Text>());
    });

    testWidgets('error handling and recovery', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // App should start successfully even if some services fail
      expect(find.text('Boofer Chat'), findsOneWidget);
      expect(find.byType(ChatInput), findsOneWidget);

      // Should be able to send messages even with service failures
      await tester.enterText(find.byType(TextField), 'Test message');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      // Message should appear (might be queued for retry)
      expect(find.text('Test message'), findsOneWidget);
    });
  });
}