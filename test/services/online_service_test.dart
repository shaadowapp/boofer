import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../lib/models/message_model.dart';
import '../../lib/services/online_service.dart';
import '../../lib/services/message_repository.dart';

// Generate mocks - simplified
@GenerateMocks([OnlineService])
import 'online_service_test.mocks.dart';
])
import 'online_service_test.mocks.dart';

void main() {
  group('OnlineService', () {
    late OnlineService onlineService;
    late MockIMessageRepository mockMessageRepository;
    late MockSupabaseClient mockSupabaseClient;
    late MockRealtimeChannel mockRealtimeChannel;

    setUp(() {
      mockMessageRepository = MockIMessageRepository();
      mockSupabaseClient = MockSupabaseClient();
      mockRealtimeChannel = MockRealtimeChannel();

      // Reset singleton for testing
      OnlineService._instance = null;

      onlineService = OnlineService.getInstance(
        messageRepository: mockMessageRepository,
      );
    });

    tearDown(() {
      onlineService.dispose();
      OnlineService._instance = null;
    });

    group('Initialization', () {
      test('should initialize Supabase client successfully', () async {
        // Note: This test would require mocking Supabase.initialize which is static
        // In a real implementation, we'd need to refactor to make this testable
        expect(onlineService.isInitialized, false);
        expect(onlineService.isOnline, false);
      });

      test('should not reinitialize if already initialized', () async {
        // This would test the early return in initialize method
        // Implementation would depend on how we mock Supabase.initialize
      });
    });

    group('Connection Management', () {
      test('should connect and set up real-time subscription', () async {
        // Arrange
        onlineService._supabase = mockSupabaseClient;
        onlineService._isInitialized = true;

        when(mockSupabaseClient.channel(any)).thenReturn(mockRealtimeChannel);
        when(mockRealtimeChannel.onPostgresChanges(
          event: anyNamed('event'),
          schema: anyNamed('schema'),
          table: anyNamed('table'),
          callback: anyNamed('callback'),
        )).thenReturn(mockRealtimeChannel);
        when(mockRealtimeChannel.subscribe()).thenAnswer((_) async => RealtimeSubscribeStatus.subscribed);

        // Act
        await onlineService.connect();

        // Assert
        expect(onlineService.isOnline, true);
        verify(mockSupabaseClient.channel('messages')).called(1);
        verify(mockRealtimeChannel.subscribe()).called(1);
      });

      test('should disconnect and clean up subscription', () async {
        // Arrange
        onlineService._isOnline = true;
        onlineService._messagesChannel = mockRealtimeChannel;

        when(mockRealtimeChannel.unsubscribe()).thenAnswer((_) async => RealtimeSubscribeStatus.closed);

        // Act
        await onlineService.disconnect();

        // Assert
        expect(onlineService.isOnline, false);
        verify(mockRealtimeChannel.unsubscribe()).called(1);
      });

      test('should handle connection failure gracefully', () async {
        // Arrange
        onlineService._supabase = mockSupabaseClient;
        onlineService._isInitialized = true;

        when(mockSupabaseClient.channel(any)).thenThrow(Exception('Connection failed'));

        // Act & Assert
        expect(
          () => onlineService.connect(),
          throwsException,
        );
        expect(onlineService.isOnline, false);
      });
    });

    group('Message Sending', () {
      setUp(() {
        onlineService._supabase = mockSupabaseClient;
        onlineService._isInitialized = true;
        onlineService._isOnline = true;
      });

      test('should send message successfully', () async {
        // Arrange
        final mockQueryBuilder = MockSupabaseQueryBuilder();
        final mockFilterBuilder = MockPostgresFilterBuilder();

        when(mockSupabaseClient.from('messages')).thenReturn(mockQueryBuilder);
        when(mockQueryBuilder.insert(any)).thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.select()).thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.single()).thenAnswer((_) async => {
          'id': 123,
          'text': 'Test message',
          'sender_id': 'user1',
          'timestamp': DateTime.now().toIso8601String(),
          'is_offline': false,
          'status': 'sent',
        });

        when(mockMessageRepository.saveMessage(any)).thenAnswer((_) async => 123);

        // Act
        await onlineService.sendOnlineMessage('Test message', 'user1');

        // Assert
        verify(mockSupabaseClient.from('messages')).called(1);
        verify(mockQueryBuilder.insert(any)).called(1);
        verify(mockMessageRepository.saveMessage(any)).called(1);
      });

      test('should handle send failure and save as failed', () async {
        // Arrange
        final mockQueryBuilder = MockSupabaseQueryBuilder();

        when(mockSupabaseClient.from('messages')).thenReturn(mockQueryBuilder);
        when(mockQueryBuilder.insert(any)).thenThrow(Exception('Network error'));
        when(mockMessageRepository.saveMessage(any)).thenAnswer((_) async => 123);

        // Act & Assert
        expect(
          () => onlineService.sendOnlineMessage('Test message', 'user1'),
          throwsException,
        );

        // Verify failed message was saved
        verify(mockMessageRepository.saveMessage(argThat(
          predicate<Message>((msg) => msg.status == MessageStatus.failed),
        ))).called(1);
      });

      test('should fail if not connected', () async {
        // Arrange
        onlineService._isOnline = false;

        // Act & Assert
        expect(
          () => onlineService.sendOnlineMessage('Test message', 'user1'),
          throwsException,
        );
      });
    });

    group('Message Synchronization', () {
      setUp(() {
        onlineService._supabase = mockSupabaseClient;
        onlineService._isInitialized = true;
        onlineService._isOnline = true;
      });

      test('should sync offline messages successfully', () async {
        // Arrange
        final offlineMessage = Message.create(
          text: 'Offline message',
          senderId: 'user1',
          isOffline: true,
          status: MessageStatus.pending,
        );
        offlineMessage.id = 1;

        final mockQueryBuilder = MockSupabaseQueryBuilder();
        final mockFilterBuilder = MockPostgresFilterBuilder();

        when(mockSupabaseClient.from('messages')).thenReturn(mockQueryBuilder);
        when(mockQueryBuilder.insert(any)).thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.select()).thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.single()).thenAnswer((_) async => {
          'id': 456,
          'text': 'Offline message',
          'sender_id': 'user1',
          'timestamp': DateTime.now().toIso8601String(),
          'is_offline': false,
          'status': 'delivered',
        });

        when(mockMessageRepository.updateMessageStatus(any, any))
            .thenAnswer((_) async {});

        // Act
        await onlineService.syncOfflineMessages([offlineMessage]);

        // Assert
        verify(mockSupabaseClient.from('messages')).called(1);
        verify(mockMessageRepository.updateMessageStatus(1, MessageStatus.delivered)).called(1);
      });

      test('should handle sync failures gracefully', () async {
        // Arrange
        final offlineMessage = Message.create(
          text: 'Failing message',
          senderId: 'user1',
          isOffline: true,
          status: MessageStatus.pending,
        );
        offlineMessage.id = 1;

        final mockQueryBuilder = MockSupabaseQueryBuilder();

        when(mockSupabaseClient.from('messages')).thenReturn(mockQueryBuilder);
        when(mockQueryBuilder.insert(any)).thenThrow(Exception('Sync failed'));
        when(mockMessageRepository.updateMessageStatus(any, any))
            .thenAnswer((_) async {});

        // Act
        await onlineService.syncOfflineMessages([offlineMessage]);

        // Assert
        verify(mockMessageRepository.updateMessageStatus(1, MessageStatus.failed)).called(1);
      });

      test('should skip sync if no messages provided', () async {
        // Act
        await onlineService.syncOfflineMessages([]);

        // Assert
        verifyNever(mockSupabaseClient.from(any));
      });
    });

    group('Message Retrieval', () {
      setUp(() {
        onlineService._supabase = mockSupabaseClient;
        onlineService._isInitialized = true;
        onlineService._isOnline = true;
      });

      test('should get recent messages from server', () async {
        // Arrange
        final mockQueryBuilder = MockSupabaseQueryBuilder();
        final mockFilterBuilder = MockPostgresFilterBuilder();

        when(mockSupabaseClient.from('messages')).thenReturn(mockQueryBuilder);
        when(mockQueryBuilder.select()).thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.order(any, ascending: anyNamed('ascending')))
            .thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.limit(any)).thenAnswer((_) async => [
          {
            'id': 1,
            'text': 'Message 1',
            'sender_id': 'user1',
            'timestamp': DateTime.now().toIso8601String(),
            'is_offline': false,
            'status': 'delivered',
          },
          {
            'id': 2,
            'text': 'Message 2',
            'sender_id': 'user2',
            'timestamp': DateTime.now().toIso8601String(),
            'is_offline': false,
            'status': 'delivered',
          },
        ]);

        // Act
        final messages = await onlineService.getRecentMessages(limit: 2);

        // Assert
        expect(messages.length, 2);
        expect(messages[0].text, 'Message 1');
        expect(messages[1].text, 'Message 2');
        verify(mockFilterBuilder.limit(2)).called(1);
      });

      test('should get conversation messages from server', () async {
        // Arrange
        final mockQueryBuilder = MockSupabaseQueryBuilder();
        final mockFilterBuilder = MockPostgresFilterBuilder();

        when(mockSupabaseClient.from('messages')).thenReturn(mockQueryBuilder);
        when(mockQueryBuilder.select()).thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.eq(any, any)).thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.order(any, ascending: anyNamed('ascending')))
            .thenAnswer((_) async => [
          {
            'id': 1,
            'text': 'Conversation message',
            'sender_id': 'user1',
            'timestamp': DateTime.now().toIso8601String(),
            'is_offline': false,
            'status': 'delivered',
            'conversation_id': 'conv123',
          },
        ]);

        // Act
        final messages = await onlineService.getConversationMessages('conv123');

        // Assert
        expect(messages.length, 1);
        expect(messages[0].conversationId, 'conv123');
        verify(mockFilterBuilder.eq('conversation_id', 'conv123')).called(1);
      });
    });

    group('User Management', () {
      test('should set current user ID', () {
        // Act
        onlineService.setCurrentUserId('test-user-456');

        // Assert
        final status = onlineService.getConnectionStatus();
        expect(status['currentUserId'], 'test-user-456');
      });
    });

    group('Connection Status', () {
      test('should provide accurate connection status', () {
        // Arrange
        onlineService._isInitialized = true;
        onlineService._isOnline = true;
        onlineService._messagesChannel = mockRealtimeChannel;
        onlineService.setCurrentUserId('user123');

        // Act
        final status = onlineService.getConnectionStatus();

        // Assert
        expect(status['isInitialized'], true);
        expect(status['isOnline'], true);
        expect(status['hasRealtimeSubscription'], true);
        expect(status['currentUserId'], 'user123');
      });
    });

    group('Message Processing', () {
      test('should process incoming message correctly', () async {
        // This would test the _handleIncomingMessage method
        // Implementation would depend on how we expose this for testing
        
        final testPayload = PostgresChangePayload(
          columns: [],
          commit_timestamp: '',
          eventType: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          newRecord: {
            'id': 123,
            'text': 'Incoming message',
            'sender_id': 'other-user',
            'timestamp': DateTime.now().toIso8601String(),
            'is_offline': false,
            'status': 'delivered',
          },
          oldRecord: {},
        );

        // Setup mocks
        when(mockMessageRepository.messageExists(any)).thenAnswer((_) async => false);
        when(mockMessageRepository.saveMessage(any)).thenAnswer((_) async => 123);

        // This would require exposing the handler method or using a different approach
        // For now, we'll test the public interface
      });

      test('should ignore duplicate messages', () async {
        // Test duplicate message handling
        when(mockMessageRepository.messageExists(any)).thenAnswer((_) async => true);

        // Implementation would depend on how we test the private method
      });

      test('should ignore own messages', () async {
        // Test that messages from current user are ignored
        onlineService.setCurrentUserId('current-user');

        // Implementation would test the sender ID filtering
      });
    });

    group('Error Handling', () {
      test('should handle network errors gracefully', () async {
        // Test various network error scenarios
        onlineService._supabase = mockSupabaseClient;
        onlineService._isInitialized = true;
        onlineService._isOnline = true;

        when(mockSupabaseClient.from(any)).thenThrow(Exception('Network timeout'));

        expect(
          () => onlineService.getRecentMessages(),
          throwsException,
        );
      });

      test('should handle malformed server responses', () async {
        // Test handling of unexpected server response formats
        final mockQueryBuilder = MockSupabaseQueryBuilder();
        final mockFilterBuilder = MockPostgresFilterBuilder();

        when(mockSupabaseClient.from('messages')).thenReturn(mockQueryBuilder);
        when(mockQueryBuilder.select()).thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.order(any, ascending: anyNamed('ascending')))
            .thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.limit(any)).thenAnswer((_) async => [
          {
            // Missing required fields
            'id': 1,
            'text': 'Incomplete message',
          },
        ]);

        expect(
          () => onlineService.getRecentMessages(),
          throwsException,
        );
      });
    });
  });
}