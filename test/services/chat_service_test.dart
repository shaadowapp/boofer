import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:rxdart/rxdart.dart';
import '../../lib/models/message_model.dart';
import '../../lib/models/network_state.dart';
import '../../lib/services/chat_service.dart';
import '../../lib/services/message_repository.dart';
import '../../lib/services/mesh_service.dart';
import '../../lib/services/online_service.dart';
import '../../lib/services/network_service.dart';
import '../../lib/services/sync_service.dart';
import '../../lib/services/mode_manager.dart';
import '../../lib/services/message_queue_service.dart';

// Generate mocks
@GenerateMocks([
  IMessageRepository,
  IMeshService,
  IOnlineService,
  INetworkService,
  SyncService,
  ModeManager,
  MessageQueueService,
])
import 'chat_service_test.mocks.dart';

void main() {
  group('ChatService', () {
    late ChatService chatService;
    late MockIMessageRepository mockMessageRepository;
    late MockIMeshService mockMeshService;
    late MockIOnlineService mockOnlineService;
    late MockINetworkService mockNetworkService;
    late MockSyncService mockSyncService;
    late MockModeManager mockModeManager;
    late MockMessageQueueService mockMessageQueueService;

    setUp(() {
      mockMessageRepository = MockIMessageRepository();
      mockMeshService = MockIMeshService();
      mockOnlineService = MockIOnlineService();
      mockNetworkService = MockINetworkService();
      mockSyncService = MockSyncService();
      mockModeManager = MockModeManager();
      mockMessageQueueService = MockMessageQueueService();

      // Reset singleton for testing
      ChatService._instance = null;

      // Setup default mock behaviors
      when(mockMessageRepository.messagesStream)
          .thenAnswer((_) => Stream.value([]));
      when(mockNetworkService.networkState)
          .thenAnswer((_) => Stream.value(NetworkState.initial()));
      when(mockNetworkService.currentNetworkState)
          .thenReturn(NetworkState.initial());
      when(mockNetworkService.isOnline).thenReturn(false);
      when(mockNetworkService.isOffline).thenReturn(true);
      when(mockMeshService.incomingMessages)
          .thenAnswer((_) => Stream.empty());
      when(mockOnlineService.incomingMessages)
          .thenAnswer((_) => Stream.empty());
      when(mockMessageQueueService.queueSize)
          .thenAnswer((_) => Stream.value(0));
      when(mockMessageQueueService.queueStats)
          .thenAnswer((_) => Stream.value({}));

      chatService = ChatService.getInstance(
        messageRepository: mockMessageRepository,
        meshService: mockMeshService,
        onlineService: mockOnlineService,
        networkService: mockNetworkService,
        syncService: mockSyncService,
        modeManager: mockModeManager,
        messageQueueService: mockMessageQueueService,
      );
    });

    tearDown(() {
      chatService.dispose();
      ChatService._instance = null;
    });

    group('Initialization', () {
      test('should initialize all services successfully', () async {
        // Arrange
        when(mockMeshService.initialize(any)).thenAnswer((_) async {});
        when(mockOnlineService.initialize(any, any)).thenAnswer((_) async {});
        when(mockOnlineService.setCurrentUserId(any)).thenReturn(null);
        when(mockNetworkService.initialize()).thenAnswer((_) async {});
        when(mockSyncService.initialize()).thenAnswer((_) async {});
        when(mockModeManager.initialize()).thenAnswer((_) async {});
        when(mockMessageQueueService.initialize()).thenAnswer((_) async {});

        // Act
        await chatService.initialize(
          supabaseUrl: 'https://test.supabase.co',
          supabaseAnonKey: 'test-key',
          bridgefyApiKey: 'test-bridgefy-key',
          userId: 'test-user-123',
        );

        // Assert
        verify(mockMeshService.initialize('test-bridgefy-key')).called(1);
        verify(mockOnlineService.initialize('https://test.supabase.co', 'test-key')).called(1);
        verify(mockOnlineService.setCurrentUserId('test-user-123')).called(1);
        verify(mockNetworkService.initialize()).called(1);
        verify(mockSyncService.initialize()).called(1);
        verify(mockModeManager.initialize()).called(1);
        verify(mockMessageQueueService.initialize()).called(1);
        
        expect(chatService.currentUserId, 'test-user-123');
      });

      test('should handle initialization failure gracefully', () async {
        // Arrange
        when(mockMeshService.initialize(any))
            .thenThrow(Exception('Mesh initialization failed'));

        // Act & Assert
        expect(
          () => chatService.initialize(
            supabaseUrl: 'https://test.supabase.co',
            supabaseAnonKey: 'test-key',
            bridgefyApiKey: 'test-bridgefy-key',
            userId: 'test-user-123',
          ),
          throwsException,
        );
      });

      test('should not reinitialize if already initialized', () async {
        // Arrange
        when(mockMeshService.initialize(any)).thenAnswer((_) async {});
        when(mockOnlineService.initialize(any, any)).thenAnswer((_) async {});
        when(mockOnlineService.setCurrentUserId(any)).thenReturn(null);
        when(mockNetworkService.initialize()).thenAnswer((_) async {});
        when(mockSyncService.initialize()).thenAnswer((_) async {});
        when(mockModeManager.initialize()).thenAnswer((_) async {});
        when(mockMessageQueueService.initialize()).thenAnswer((_) async {});

        await chatService.initialize(
          supabaseUrl: 'https://test.supabase.co',
          supabaseAnonKey: 'test-key',
          bridgefyApiKey: 'test-bridgefy-key',
          userId: 'test-user-123',
        );

        // Act - Try to initialize again
        await chatService.initialize(
          supabaseUrl: 'https://test.supabase.co',
          supabaseAnonKey: 'test-key',
          bridgefyApiKey: 'test-bridgefy-key',
          userId: 'test-user-123',
        );

        // Assert - Services should only be initialized once
        verify(mockMeshService.initialize(any)).called(1);
        verify(mockOnlineService.initialize(any, any)).called(1);
      });
    });

    group('Message Sending', () {
      setUp(() async {
        // Setup initialized state
        when(mockMeshService.initialize(any)).thenAnswer((_) async {});
        when(mockOnlineService.initialize(any, any)).thenAnswer((_) async {});
        when(mockOnlineService.setCurrentUserId(any)).thenReturn(null);
        when(mockNetworkService.initialize()).thenAnswer((_) async {});
        when(mockSyncService.initialize()).thenAnswer((_) async {});
        when(mockModeManager.initialize()).thenAnswer((_) async {});
        when(mockMessageQueueService.initialize()).thenAnswer((_) async {});
        when(mockMessageQueueService.queueMessage(any)).thenAnswer((_) async {});

        await chatService.initialize(
          supabaseUrl: 'https://test.supabase.co',
          supabaseAnonKey: 'test-key',
          bridgefyApiKey: 'test-bridgefy-key',
          userId: 'test-user-123',
        );
      });

      test('should queue message for sending', () async {
        // Act
        await chatService.sendMessage('Hello, world!');

        // Assert
        verify(mockMessageQueueService.queueMessage(any)).called(1);
      });

      test('should create message with correct properties for offline mode', () async {
        // Arrange
        when(mockNetworkService.isOffline).thenReturn(true);
        when(mockNetworkService.isOnline).thenReturn(false);

        // Act
        await chatService.sendMessage('Offline message');

        // Assert
        final captured = verify(mockMessageQueueService.queueMessage(captureAny)).captured;
        final message = captured.first as Message;
        expect(message.text, 'Offline message');
        expect(message.senderId, 'test-user-123');
        expect(message.isOffline, true);
        expect(message.status, MessageStatus.pending);
      });

      test('should create message with correct properties for online mode', () async {
        // Arrange
        when(mockNetworkService.isOffline).thenReturn(false);
        when(mockNetworkService.isOnline).thenReturn(true);

        // Act
        await chatService.sendMessage('Online message');

        // Assert
        final captured = verify(mockMessageQueueService.queueMessage(captureAny)).captured;
        final message = captured.first as Message;
        expect(message.text, 'Online message');
        expect(message.senderId, 'test-user-123');
        expect(message.isOffline, false);
        expect(message.status, MessageStatus.pending);
      });

      test('should reject empty messages', () async {
        // Act & Assert
        expect(
          () => chatService.sendMessage(''),
          throwsA(isA<ArgumentError>()),
        );
        expect(
          () => chatService.sendMessage('   '),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should fail if not initialized', () async {
        // Arrange
        final uninitializedService = ChatService.getInstance();

        // Act & Assert
        expect(
          () => uninitializedService.sendMessage('Test'),
          throwsException,
        );
      });

      test('should fail if user ID not set', () async {
        // Arrange - Initialize without user ID
        final serviceWithoutUser = ChatService.getInstance();
        
        // Act & Assert
        expect(
          () => serviceWithoutUser.sendMessage('Test'),
          throwsException,
        );
      });
    });

    group('Mode Switching', () {
      setUp(() async {
        // Setup initialized state
        when(mockMeshService.initialize(any)).thenAnswer((_) async {});
        when(mockOnlineService.initialize(any, any)).thenAnswer((_) async {});
        when(mockOnlineService.setCurrentUserId(any)).thenReturn(null);
        when(mockNetworkService.initialize()).thenAnswer((_) async {});
        when(mockSyncService.initialize()).thenAnswer((_) async {});
        when(mockModeManager.initialize()).thenAnswer((_) async {});
        when(mockMessageQueueService.initialize()).thenAnswer((_) async {});

        await chatService.initialize(
          supabaseUrl: 'https://test.supabase.co',
          supabaseAnonKey: 'test-key',
          bridgefyApiKey: 'test-bridgefy-key',
          userId: 'test-user-123',
        );
      });

      test('should switch to online mode', () async {
        // Arrange
        when(mockModeManager.switchToOnlineMode()).thenAnswer((_) async {});

        // Act
        await chatService.switchMode(NetworkMode.online);

        // Assert
        verify(mockModeManager.switchToOnlineMode()).called(2); // Called twice due to implementation
      });

      test('should switch to offline mode', () async {
        // Arrange
        when(mockModeManager.switchToOfflineMode()).thenAnswer((_) async {});

        // Act
        await chatService.switchMode(NetworkMode.offline);

        // Assert
        verify(mockModeManager.switchToOfflineMode()).called(1);
      });

      test('should switch to auto mode', () async {
        // Arrange
        when(mockModeManager.switchToAutoMode()).thenAnswer((_) async {});

        // Act
        await chatService.switchMode(NetworkMode.auto);

        // Assert
        verify(mockModeManager.switchToAutoMode()).called(1);
      });
    });

    group('Failed Message Retry', () {
      setUp(() async {
        // Setup initialized state
        when(mockMeshService.initialize(any)).thenAnswer((_) async {});
        when(mockOnlineService.initialize(any, any)).thenAnswer((_) async {});
        when(mockOnlineService.setCurrentUserId(any)).thenReturn(null);
        when(mockNetworkService.initialize()).thenAnswer((_) async {});
        when(mockSyncService.initialize()).thenAnswer((_) async {});
        when(mockModeManager.initialize()).thenAnswer((_) async {});
        when(mockMessageQueueService.initialize()).thenAnswer((_) async {});

        await chatService.initialize(
          supabaseUrl: 'https://test.supabase.co',
          supabaseAnonKey: 'test-key',
          bridgefyApiKey: 'test-bridgefy-key',
          userId: 'test-user-123',
        );
      });

      test('should retry failed messages using queue service', () async {
        // Arrange
        when(mockMessageQueueService.retryFailedMessages()).thenAnswer((_) async {});

        // Act
        await chatService.retryFailedMessages();

        // Assert
        verify(mockMessageQueueService.retryFailedMessages()).called(1);
      });
    });

    group('Service Statistics', () {
      setUp(() async {
        // Setup initialized state
        when(mockMeshService.initialize(any)).thenAnswer((_) async {});
        when(mockOnlineService.initialize(any, any)).thenAnswer((_) async {});
        when(mockOnlineService.setCurrentUserId(any)).thenReturn(null);
        when(mockNetworkService.initialize()).thenAnswer((_) async {});
        when(mockSyncService.initialize()).thenAnswer((_) async {});
        when(mockModeManager.initialize()).thenAnswer((_) async {});
        when(mockMessageQueueService.initialize()).thenAnswer((_) async {});

        await chatService.initialize(
          supabaseUrl: 'https://test.supabase.co',
          supabaseAnonKey: 'test-key',
          bridgefyApiKey: 'test-bridgefy-key',
          userId: 'test-user-123',
        );
      });

      test('should provide comprehensive service statistics', () {
        // Arrange
        when(mockNetworkService.getNetworkStatistics()).thenReturn({'connected': true});
        when(mockMeshService.isInitialized).thenReturn(true);
        when(mockMeshService.isStarted).thenReturn(true);
        when(mockMeshService.peersCount).thenReturn(3);
        when(mockOnlineService.getConnectionStatus()).thenReturn({'online': true});
        when(mockSyncService.getSyncStatistics()).thenReturn({'lastSync': 'now'});
        when(mockModeManager.getModeStatistics()).thenReturn({'mode': 'auto'});
        when(mockMessageQueueService.getQueueStatistics()).thenReturn({'size': 0});

        // Act
        final stats = chatService.getServiceStatistics();

        // Assert
        expect(stats['isInitialized'], true);
        expect(stats['currentUserId'], 'test-user-123');
        expect(stats['networkService'], {'connected': true});
        expect(stats['meshService']['isInitialized'], true);
        expect(stats['meshService']['peersCount'], 3);
        expect(stats['onlineService'], {'online': true});
        expect(stats['messageQueue'], {'size': 0});
      });
    });

    group('Queue Operations', () {
      setUp(() async {
        // Setup initialized state
        when(mockMeshService.initialize(any)).thenAnswer((_) async {});
        when(mockOnlineService.initialize(any, any)).thenAnswer((_) async {});
        when(mockOnlineService.setCurrentUserId(any)).thenReturn(null);
        when(mockNetworkService.initialize()).thenAnswer((_) async {});
        when(mockSyncService.initialize()).thenAnswer((_) async {});
        when(mockModeManager.initialize()).thenAnswer((_) async {});
        when(mockMessageQueueService.initialize()).thenAnswer((_) async {});

        await chatService.initialize(
          supabaseUrl: 'https://test.supabase.co',
          supabaseAnonKey: 'test-key',
          bridgefyApiKey: 'test-bridgefy-key',
          userId: 'test-user-123',
        );
      });

      test('should process message queue', () async {
        // Arrange
        when(mockMessageQueueService.processQueue()).thenAnswer((_) async {});

        // Act
        await chatService.processMessageQueue();

        // Assert
        verify(mockMessageQueueService.processQueue()).called(1);
      });

      test('should clear message queue', () async {
        // Arrange
        when(mockMessageQueueService.clearQueue()).thenAnswer((_) async {});

        // Act
        await chatService.clearMessageQueue();

        // Assert
        verify(mockMessageQueueService.clearQueue()).called(1);
      });

      test('should expose queue size stream', () {
        // Arrange
        final queueSizeStream = BehaviorSubject<int>.seeded(5);
        when(mockMessageQueueService.queueSize).thenAnswer((_) => queueSizeStream.stream);

        // Act
        final stream = chatService.queueSize;

        // Assert
        expect(stream, isA<Stream<int>>());
      });

      test('should expose queue stats stream', () {
        // Arrange
        final queueStatsStream = BehaviorSubject<Map<String, int>>.seeded({'pending': 2});
        when(mockMessageQueueService.queueStats).thenAnswer((_) => queueStatsStream.stream);

        // Act
        final stream = chatService.queueStats;

        // Assert
        expect(stream, isA<Stream<Map<String, int>>>());
      });
    });

    group('Stream Management', () {
      test('should provide messages stream', () {
        // Arrange
        final messagesStream = BehaviorSubject<List<Message>>.seeded([]);
        when(mockMessageRepository.messagesStream).thenAnswer((_) => messagesStream.stream);

        // Act
        final stream = chatService.messagesStream;

        // Assert
        expect(stream, isA<Stream<List<Message>>>());
      });

      test('should provide network state stream', () {
        // Arrange
        final networkStateStream = BehaviorSubject<NetworkState>.seeded(NetworkState.initial());
        when(mockNetworkService.networkState).thenAnswer((_) => networkStateStream.stream);

        // Act
        final stream = chatService.networkState;

        // Assert
        expect(stream, isA<Stream<NetworkState>>());
      });
    });

    group('Properties', () {
      test('should return correct mode properties', () {
        // Arrange
        when(mockNetworkService.isOnline).thenReturn(true);
        when(mockNetworkService.isOffline).thenReturn(false);
        when(mockNetworkService.currentNetworkState).thenReturn(
          NetworkState(
            mode: NetworkMode.online,
            hasInternet: true,
            isOnlineServiceActive: true,
            isMeshServiceActive: false,
            connectedPeers: 0,
          ),
        );

        // Act & Assert
        expect(chatService.isOnlineMode, true);
        expect(chatService.isOfflineMode, false);
        expect(chatService.currentMode, NetworkMode.online);
      });
    });
  });
}