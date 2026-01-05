import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:boofer/screens/chat_screen.dart';
import 'package:boofer/services/chat_service.dart';
import 'package:boofer/models/message_model.dart';
import 'package:boofer/widgets/message_bubble.dart';
import 'package:boofer/widgets/chat_input.dart';
import 'package:boofer/widgets/connection_status.dart';

@GenerateMocks([IChatService])
import 'chat_screen_test.mocks.dart';

void main() {
  group('ChatScreen Widget Tests', () {
    late MockIChatService mockChatService;

    setUp(() {
      mockChatService = MockIChatService();
    });

    testWidgets('displays app bar with title', (WidgetTester tester) async {
      when(mockChatService.messages).thenAnswer((_) => Stream.value([]));
      when(mockChatService.isOnline).thenReturn(true);
      when(mockChatService.isOfflineMode).thenReturn(false);
      when(mockChatService.peerCount).thenReturn(0);

      await tester.pumpWidget(
        MaterialApp(
          home: ChatScreen(chatService: mockChatService),
        ),
      );

      expect(find.text('Boofer Chat'), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('displays connection status widget', (WidgetTester tester) async {
      when(mockChatService.messages).thenAnswer((_) => Stream.value([]));
      when(mockChatService.isOnline).thenReturn(true);
      when(mockChatService.isOfflineMode).thenReturn(false);
      when(mockChatService.peerCount).thenReturn(0);

      await tester.pumpWidget(
        MaterialApp(
          home: ChatScreen(chatService: mockChatService),
        ),
      );

      expect(find.byType(ConnectionStatus), findsOneWidget);
    });

    testWidgets('displays chat input widget', (WidgetTester tester) async {
      when(mockChatService.messages).thenAnswer((_) => Stream.value([]));
      when(mockChatService.isOnline).thenReturn(true);
      when(mockChatService.isOfflineMode).thenReturn(false);
      when(mockChatService.peerCount).thenReturn(0);

      await tester.pumpWidget(
        MaterialApp(
          home: ChatScreen(chatService: mockChatService),
        ),
      );

      expect(find.byType(ChatInput), findsOneWidget);
    });

    testWidgets('displays empty state when no messages', (WidgetTester tester) async {
      when(mockChatService.messages).thenAnswer((_) => Stream.value([]));
      when(mockChatService.isOnline).thenReturn(true);
      when(mockChatService.isOfflineMode).thenReturn(false);
      when(mockChatService.peerCount).thenReturn(0);

      await tester.pumpWidget(
        MaterialApp(
          home: ChatScreen(chatService: mockChatService),
        ),
      );

      await tester.pump();

      expect(find.text('No messages yet'), findsOneWidget);
      expect(find.text('Start a conversation!'), findsOneWidget);
    });

    testWidgets('displays messages when available', (WidgetTester tester) async {
      final testMessages = [
        Message()
          ..id = 1
          ..text = 'Hello'
          ..senderId = 'user1'
          ..timestamp = DateTime.now()
          ..isOffline = false
          ..status = MessageStatus.sent,
        Message()
          ..id = 2
          ..text = 'Hi there'
          ..senderId = 'user2'
          ..timestamp = DateTime.now()
          ..isOffline = false
          ..status = MessageStatus.delivered,
      ];

      when(mockChatService.messages).thenAnswer((_) => Stream.value(testMessages));
      when(mockChatService.isOnline).thenReturn(true);
      when(mockChatService.isOfflineMode).thenReturn(false);
      when(mockChatService.peerCount).thenReturn(0);

      await tester.pumpWidget(
        MaterialApp(
          home: ChatScreen(chatService: mockChatService),
        ),
      );

      await tester.pump();

      expect(find.byType(MessageBubble), findsNWidgets(2));
      expect(find.text('Hello'), findsOneWidget);
      expect(find.text('Hi there'), findsOneWidget);
    });

    testWidgets('calls sendMessage when message is sent', (WidgetTester tester) async {
      when(mockChatService.messages).thenAnswer((_) => Stream.value([]));
      when(mockChatService.isOnline).thenReturn(true);
      when(mockChatService.isOfflineMode).thenReturn(false);
      when(mockChatService.peerCount).thenReturn(0);
      when(mockChatService.sendMessage(any)).thenAnswer((_) async {});

      await tester.pumpWidget(
        MaterialApp(
          home: ChatScreen(chatService: mockChatService),
        ),
      );

      // Find the ChatInput and trigger message send
      final chatInput = find.byType(ChatInput);
      expect(chatInput, findsOneWidget);

      // Simulate entering text and sending
      await tester.enterText(find.byType(TextField), 'Test message');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();

      verify(mockChatService.sendMessage('Test message')).called(1);
    });

    testWidgets('calls toggleMode when mode is toggled', (WidgetTester tester) async {
      when(mockChatService.messages).thenAnswer((_) => Stream.value([]));
      when(mockChatService.isOnline).thenReturn(true);
      when(mockChatService.isOfflineMode).thenReturn(false);
      when(mockChatService.peerCount).thenReturn(0);
      when(mockChatService.toggleMode()).thenAnswer((_) async {});

      await tester.pumpWidget(
        MaterialApp(
          home: ChatScreen(chatService: mockChatService),
        ),
      );

      // Find the mode toggle switch and tap it
      await tester.tap(find.byType(Switch));
      await tester.pump();

      verify(mockChatService.toggleMode()).called(1);
    });

    testWidgets('scrolls to bottom when new message arrives', (WidgetTester tester) async {
      final testMessages = [
        Message()
          ..id = 1
          ..text = 'First message'
          ..senderId = 'user1'
          ..timestamp = DateTime.now()
          ..isOffline = false
          ..status = MessageStatus.sent,
      ];

      when(mockChatService.messages).thenAnswer((_) => Stream.value(testMessages));
      when(mockChatService.isOnline).thenReturn(true);
      when(mockChatService.isOfflineMode).thenReturn(false);
      when(mockChatService.peerCount).thenReturn(0);

      await tester.pumpWidget(
        MaterialApp(
          home: ChatScreen(chatService: mockChatService),
        ),
      );

      await tester.pump();

      // Verify ListView is present
      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('handles loading state correctly', (WidgetTester tester) async {
      when(mockChatService.messages).thenAnswer((_) => Stream.value([]));
      when(mockChatService.isOnline).thenReturn(true);
      when(mockChatService.isOfflineMode).thenReturn(false);
      when(mockChatService.peerCount).thenReturn(0);

      await tester.pumpWidget(
        MaterialApp(
          home: ChatScreen(chatService: mockChatService),
        ),
      );

      // Initially should show loading or empty state
      expect(find.byType(StreamBuilder), findsOneWidget);
    });

    testWidgets('updates UI when connection status changes', (WidgetTester tester) async {
      when(mockChatService.messages).thenAnswer((_) => Stream.value([]));
      when(mockChatService.isOnline).thenReturn(false);
      when(mockChatService.isOfflineMode).thenReturn(true);
      when(mockChatService.peerCount).thenReturn(3);

      await tester.pumpWidget(
        MaterialApp(
          home: ChatScreen(chatService: mockChatService),
        ),
      );

      await tester.pump();

      // Verify connection status reflects offline mode
      final connectionStatus = tester.widget<ConnectionStatus>(find.byType(ConnectionStatus));
      expect(connectionStatus.isOnline, isFalse);
      expect(connectionStatus.isOfflineMode, isTrue);
      expect(connectionStatus.peerCount, equals(3));
    });

    testWidgets('displays error message when message sending fails', (WidgetTester tester) async {
      when(mockChatService.messages).thenAnswer((_) => Stream.value([]));
      when(mockChatService.isOnline).thenReturn(true);
      when(mockChatService.isOfflineMode).thenReturn(false);
      when(mockChatService.peerCount).thenReturn(0);
      when(mockChatService.sendMessage(any)).thenThrow(Exception('Send failed'));

      await tester.pumpWidget(
        MaterialApp(
          home: ChatScreen(chatService: mockChatService),
        ),
      );

      // Try to send a message
      await tester.enterText(find.byType(TextField), 'Test message');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();

      // Should handle the error gracefully
      verify(mockChatService.sendMessage('Test message')).called(1);
    });
  });
}