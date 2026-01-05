import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import '../../lib/models/message_model.dart';
import '../../lib/services/message_queue_service.dart';
import '../../lib/services/message_repository.dart';
import '../../lib/services/mesh_service.dart';
import '../../lib/services/online_service.dart';
import '../../lib/services/network_service.dart';

// Generate mocks
@GenerateMocks([
  IMessageRepository,
  IMeshService,
  IOnlineService,
  INetworkService,
])
import 'message_queue_service_test.mocks.dart';

void main() {
  group('MessageQueueService', () {
    late MessageQueueService messageQueueService;
    late MockIMessageRepository mockMessageRepository;
    late MockIMeshService mockMeshService;
    late MockIOnlineService mockOnlineService;
    late MockINetworkService mockNetworkService;

    setUp(() {
      mockMessageRepository = MockIMessageRepository();
      mockMeshService = MockIMeshService();
      mockOnlineService = MockIOnlineService();
      mockNetworkService = MockINetworkService();

      // Reset singleton for testing
      MessageQueueService._instance = null;

      messageQueueService = MessageQueueService.getInstance(
        messageRepository: mockMessageRepository,
        meshService: mockMeshService,
        onlineService: mockOnlineService,
        networkService: mockNetworkService,
      );
    });

    tearDown(() {
      messageQueueService.dispose();
      MessageQueueService._instance = null;
    });

    group('Initialization', () {
      test('should initialize successfully', () async {
        // Arrange
        when(mockMessageRepository.getMessagesByStatus(MessageStatus.pending))
            .thenAnswer((_) async => []);
        when(mockMessageRepository.getMessagesByStatus(MessageStatus.failed))
            .thenAnswer((_) async => []);

        // Act
        await messageQueueService.initialize();

        // Assert
        expect(messageQueueService._isInitialized, true);
        verify(mockMessageRepository.getMessagesByStatus(MessageStatus.pending)).called(1);
        verify(mockMessageRepository.getMessagesByStatus(MessageStatus.failed)).called(1);
      });

      test('should load existing messages into queue on initialization', () async {
        // Arrange
        final pendingMessage = Message.create(
          text: 'Pending message',
          senderId: 'user1',
          isOffline: true,
          status: MessageStatus.pending,
        );
        pendingMessage.id = 1;

        final failedMessage = Message.create(
          text: 'Failed message',
          senderId: 'user1',
          isOffline: false,
          status: MessageStatus.failed,
        );
        failedMessage.id = 2;

        when(mockMessageRepository.getMessagesByStatus(MessageStatus.pending))
            .thenAnswer((_) async => [pendingMessage]);
        when(mockMessageRepository.getMessagesByStatus(MessageStatus.failed))
            .thenAnswer((_) async => [failedMessage]);

        // Act
        await messageQueueService.initialize();

        // Assert
        final stats = messageQueueService.getQueueStatistics();
        expect(stats['queueSize'], 2);
        expect(stats['stats']['pending'], 1);
        expect(stats['stats']['failed'], 1);
      });
    });

    group('Message Queuing', () {
      setUp(() async {
        when(mockMessageRepository.getMessagesByStatus(any))
            .thenAnswer((_) async => []);
        await messageQueueService.initialize();
      });

      test('should queue a new message successfully', () async {
        // Arrange
        final message = Message.create(
          text: 'Test message',
          senderId: 'user1',
          isOffline: true,
          status: MessageStatus.pending,
        );
        
        when(mockMessageRepository.saveMessage(any))
            .thenAnswer((_) async => 1);
        when(mockMeshService.isStarted).thenReturn(false);

        // Act
        await messageQueueService.queueMessage(message);

        // Assert
        expect(messageQueueService.isMessageQueued(1), true);
        verify(mockMessageRepository.saveMessage(any)).called(1);
      });

      test('should attempt immediate send when queuing message', () async {
        // Arrange
        final message = Message.create(
          text: 'Test message',
          senderId: 'user1',
          isOffline: true,
          status: MessageStatus.pending,
        );
        
        when(mockMessageRepository.saveMessage(any))
            .thenAnswer((_) async => 1);
        when(mockMeshService.isStarted).thenReturn(true);
        when(mockMeshService.sendMeshMessage(any, any))
            .thenAnswer((_) async {});
        when(mockMessageRepository.updateMessageStatus(any, any))
            .thenAnswer((_) async {});

        // Act
        await messageQueueService.queueMessage(message);

        // Assert
        verify(mockMeshService.sendMeshMessage('Test message', 'user1')).called(1);
        verify(mockMessageRepository.updateMessageStatus(1, MessageStatus.sent)).called(1);
      });
    });

    group('Queue Processing', () {
      setUp(() async {
        when(mockMessageRepository.getMessagesByStatus(any))
            .thenAnswer((_) async => []);
        await messageQueueService.initialize();
      });

      test('should process offline messages via mesh service', () async {
        // Arrange
        final message = Message.create(
          text: 'Offline message',
          senderId: 'user1',
          isOffline: true,
          status: MessageStatus.pending,
        );
        message.id = 1;

        when(mockMessageRepository.saveMessage(any))
            .thenAnswer((_) async => 1);
        when(mockMeshService.isStarted).thenReturn(false);
        
        await messageQueueService.queueMessage(message);

        // Setup for processing
        when(mockMeshService.isStarted).thenReturn(true);
        when(mockMeshService.sendMeshMessage(any, any))
            .thenAnswer((_) async {});
        when(mockMessageRepository.updateMessageStatus(any, any))
            .thenAnswer((_) async {});

        // Act
        await messageQueueService.processQueue();

        // Assert
        verify(mockMeshService.sendMeshMessage('Offline message', 'user1')).called(1);
        verify(mockMessageRepository.updateMessageStatus(1, MessageStatus.sent)).called(1);
      });

      test('should process online messages via online service', () async {
        // Arrange
        final message = Message.create(
          text: 'Online message',
          senderId: 'user1',
          isOffline: false,
          status: MessageStatus.pending,
        );
        message.id = 1;

        when(mockMessageRepository.saveMessage(any))
            .thenAnswer((_) async => 1);
        when(mockOnlineService.isOnline).thenReturn(false);
        
        await messageQueueService.queueMessage(message);

        // Setup for processing
        when(mockOnlineService.isOnline).thenReturn(true);
        when(mockOnlineService.sendOnlineMessage(any, any))
            .thenAnswer((_) async {});
        when(mockMessageRepository.updateMessageStatus(any, any))
            .thenAnswer((_) async {});

        // Act
        await messageQueueService.processQueue();

        // Assert
        verify(mockOnlineService.sendOnlineMessage('Online message', 'user1')).called(1);
        verify(mockMessageRepository.updateMessageStatus(1, MessageStatus.sent)).called(1);
      });

      test('should handle send failures and schedule retry', () async {
        // Arrange
        final message = Message.create(
          text: 'Failing message',
          senderId: 'user1',
          isOffline: true,
          status: MessageStatus.pending,
        );
        message.id = 1;

        when(mockMessageRepository.saveMessage(any))
            .thenAnswer((_) async => 1);
        when(mockMeshService.isStarted).thenReturn(true);
        when(mockMeshService.sendMeshMessage(any, any))
            .thenThrow(Exception('Network error'));

        // Act
        await messageQueueService.queueMessage(message);

        // Assert
        final queuedMessages = messageQueueService.getQueuedMessages();
        expect(queuedMessages.length, 1);
        
        final stats = messageQueueService.getQueueStatistics();
        expect(stats['stats']['retrying'], 1);
      });
    });

    group('Retry Logic', () {
      setUp(() async {
        when(mockMessageRepository.getMessagesByStatus(any))
            .thenAnswer((_) async => []);
        await messageQueueService.initialize();
      });

      test('should retry failed messages', () async {
        // Arrange
        final failedMessage = Message.create(
          text: 'Failed message',
          senderId: 'user1',
          isOffline: true,
          status: MessageStatus.failed,
        );
        failedMessage.id = 1;

        when(mockMessageRepository.getFailedMessages())
            .thenAnswer((_) async => [failedMessage]);
        when(mockMeshService.isStarted).thenReturn(true);
        when(mockMeshService.sendMeshMessage(any, any))
            .thenAnswer((_) async {});
        when(mockMessageRepository.updateMessageStatus(any, any))
            .thenAnswer((_) async {});

        // Act
        await messageQueueService.retryFailedMessages();

        // Assert
        verify(mockMeshService.sendMeshMessage('Failed message', 'user1')).called(1);
        verify(mockMessageRepository.updateMessageStatus(1, MessageStatus.sent)).called(1);
      });

      test('should mark message as failed after max retries', () async {
        // Arrange
        final message = Message.create(
          text: 'Persistent failure',
          senderId: 'user1',
          isOffline: true,
          status: MessageStatus.pending,
        );
        message.id = 1;

        when(mockMessageRepository.saveMessage(any))
            .thenAnswer((_) async => 1);
        when(mockMeshService.isStarted).thenReturn(true);
        when(mockMeshService.sendMeshMessage(any, any))
            .thenThrow(Exception('Persistent error'));
        when(mockMessageRepository.updateMessageStatus(any, any))
            .thenAnswer((_) async {});

        await messageQueueService.queueMessage(message);

        // Act - Process multiple times to exhaust retries
        for (int i = 0; i < 4; i++) {
          await messageQueueService.processQueue();
        }

        // Assert
        verify(mockMessageRepository.updateMessageStatus(1, MessageStatus.failed)).called(1);
        expect(messageQueueService.isMessageQueued(1), false);
      });
    });

    group('Queue Statistics', () {
      setUp(() async {
        when(mockMessageRepository.getMessagesByStatus(any))
            .thenAnswer((_) async => []);
        await messageQueueService.initialize();
      });

      test('should provide accurate queue statistics', () async {
        // Arrange
        final pendingMessage = Message.create(
          text: 'Pending',
          senderId: 'user1',
          isOffline: true,
          status: MessageStatus.pending,
        );
        
        when(mockMessageRepository.saveMessage(any))
            .thenAnswer((_) async => 1);
        when(mockMeshService.isStarted).thenReturn(false);

        await messageQueueService.queueMessage(pendingMessage);

        // Act
        final stats = messageQueueService.getQueueStatistics();

        // Assert
        expect(stats['queueSize'], 1);
        expect(stats['stats']['total'], 1);
        expect(stats['stats']['pending'], 1);
        expect(stats['isInitialized'], true);
        expect(stats['isProcessing'], false);
      });

      test('should update statistics when queue changes', () async {
        // Arrange
        final message = Message.create(
          text: 'Test',
          senderId: 'user1',
          isOffline: true,
          status: MessageStatus.pending,
        );
        
        when(mockMessageRepository.saveMessage(any))
            .thenAnswer((_) async => 1);
        when(mockMeshService.isStarted).thenReturn(false);

        // Act & Assert
        var stats = messageQueueService.getQueueStatistics();
        expect(stats['queueSize'], 0);

        await messageQueueService.queueMessage(message);
        
        stats = messageQueueService.getQueueStatistics();
        expect(stats['queueSize'], 1);

        await messageQueueService.clearQueue();
        
        stats = messageQueueService.getQueueStatistics();
        expect(stats['queueSize'], 0);
      });
    });

    group('Queue Management', () {
      setUp(() async {
        when(mockMessageRepository.getMessagesByStatus(any))
            .thenAnswer((_) async => []);
        await messageQueueService.initialize();
      });

      test('should clear queue successfully', () async {
        // Arrange
        final message = Message.create(
          text: 'Test',
          senderId: 'user1',
          isOffline: true,
          status: MessageStatus.pending,
        );
        
        when(mockMessageRepository.saveMessage(any))
            .thenAnswer((_) async => 1);
        when(mockMeshService.isStarted).thenReturn(false);

        await messageQueueService.queueMessage(message);
        expect(messageQueueService.getQueuedMessages().length, 1);

        // Act
        await messageQueueService.clearQueue();

        // Assert
        expect(messageQueueService.getQueuedMessages().length, 0);
        final stats = messageQueueService.getQueueStatistics();
        expect(stats['queueSize'], 0);
      });

      test('should remove specific message from queue', () async {
        // Arrange
        final message = Message.create(
          text: 'Test',
          senderId: 'user1',
          isOffline: true,
          status: MessageStatus.pending,
        );
        
        when(mockMessageRepository.saveMessage(any))
            .thenAnswer((_) async => 1);
        when(mockMeshService.isStarted).thenReturn(false);

        await messageQueueService.queueMessage(message);
        expect(messageQueueService.isMessageQueued(1), true);

        // Act
        messageQueueService.removeFromQueue(1);

        // Assert
        expect(messageQueueService.isMessageQueued(1), false);
      });
    });

    group('Retry Configuration', () {
      test('should use custom retry configuration', () {
        // Arrange
        final customConfig = RetryConfig(
          maxRetries: 5,
          initialDelay: Duration(seconds: 1),
          backoffMultiplier: 1.5,
          maxDelay: Duration(minutes: 1),
        );

        MessageQueueService._instance = null;
        final customQueueService = MessageQueueService.getInstance(
          messageRepository: mockMessageRepository,
          meshService: mockMeshService,
          onlineService: mockOnlineService,
          networkService: mockNetworkService,
          retryConfig: customConfig,
        );

        // Act
        final stats = customQueueService.getQueueStatistics();

        // Assert
        expect(stats['retryConfig']['maxRetries'], 5);
        expect(stats['retryConfig']['initialDelay'], 1);
        expect(stats['retryConfig']['backoffMultiplier'], 1.5);
        expect(stats['retryConfig']['maxDelay'], 60);

        customQueueService.dispose();
      });
    });
  });
}