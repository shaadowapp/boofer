import 'dart:async';
import 'package:rxdart/rxdart.dart';
import '../models/message_model.dart';
import '../models/network_state.dart';
import 'message_repository.dart';
import 'mesh_service.dart';
import 'online_service.dart';
import 'network_service.dart';
import 'sync_service.dart';
import 'mode_manager.dart';
import 'message_queue_service.dart';

/// Interface for the main chat service
abstract class IChatService {
  Stream<List<Message>> get messagesStream;
  Stream<NetworkState> get networkState;
  Stream<bool> get isInitialized;
  Future<void> initialize({
    required String supabaseUrl,
    required String supabaseAnonKey,
    required String bridgefyApiKey,
    required String userId,
  });
  Future<void> sendMessage(String text, {String? conversationId});
  Future<void> switchMode(NetworkMode mode);
  Future<void> retryFailedMessages();
  bool get isOnlineMode;
  bool get isOfflineMode;
  NetworkMode get currentMode;
  String? get currentUserId;
  Map<String, dynamic> getServiceStatistics();
  
  // Message queue related methods
  Stream<int> get queueSize;
  Stream<Map<String, int>> get queueStats;
  Future<void> processMessageQueue();
  Future<void> clearMessageQueue();
}

/// Central chat service that orchestrates all other services
class ChatService implements IChatService {
  static ChatService? _instance;
  
  // Core services
  final IMessageRepository _messageRepository;
  final IMeshService _meshService;
  final IOnlineService _onlineService;
  final INetworkService _networkService;
  final SyncService _syncService;
  final ModeManager _modeManager;
  final MessageQueueService _messageQueueService;
  
  // State management
  final BehaviorSubject<bool> _isInitializedController = BehaviorSubject<bool>.seeded(false);
  final BehaviorSubject<String> _statusController = BehaviorSubject<String>.seeded('not_initialized');
  
  String? _currentUserId;
  bool _isInitialized = false;
  
  // Service coordination
  StreamSubscription? _meshMessagesSubscription;
  StreamSubscription? _onlineMessagesSubscription;
  StreamSubscription? _networkStateSubscription;

  ChatService._({
    required IMessageRepository messageRepository,
    required IMeshService meshService,
    required IOnlineService onlineService,
    required INetworkService networkService,
    required SyncService syncService,
    required ModeManager modeManager,
    required MessageQueueService messageQueueService,
  }) : _messageRepository = messageRepository,
       _meshService = meshService,
       _onlineService = onlineService,
       _networkService = networkService,
       _syncService = syncService,
       _modeManager = modeManager,
       _messageQueueService = messageQueueService;

  static ChatService getInstance({
    IMessageRepository? messageRepository,
    IMeshService? meshService,
    IOnlineService? onlineService,
    INetworkService? networkService,
    SyncService? syncService,
    ModeManager? modeManager,
    MessageQueueService? messageQueueService,
  }) {
    if (_instance == null) {
      final repo = messageRepository ?? MessageRepository();
      final mesh = meshService ?? MeshService.getInstance(messageRepository: repo);
      final online = onlineService ?? OnlineService.getInstance(messageRepository: repo);
      final network = networkService ?? NetworkService.getInstance(meshService: mesh, onlineService: online);
      final sync = syncService ?? SyncService(onlineService: online, messageRepository: repo);
      final mode = modeManager ?? ModeManager.getInstance(
        networkService: network,
        meshService: mesh,
        onlineService: online,
        syncService: sync,
      );
      final queue = messageQueueService ?? MessageQueueService.getInstance(
        messageRepository: repo,
        meshService: mesh,
        onlineService: online,
        networkService: network,
      );
      
      _instance = ChatService._(
        messageRepository: repo,
        meshService: mesh,
        onlineService: online,
        networkService: network,
        syncService: sync,
        modeManager: mode,
        messageQueueService: queue,
      );
    }
    return _instance!;
  }

  @override
  Stream<List<Message>> get messagesStream => _messageRepository.messagesStream;

  @override
  Stream<NetworkState> get networkState => _networkService.networkState;

  @override
  Stream<bool> get isInitialized => _isInitializedController.stream;

  @override
  bool get isOnlineMode => _networkService.isOnline;

  @override
  bool get isOfflineMode => _networkService.isOffline;

  @override
  NetworkMode get currentMode => _networkService.currentNetworkState.mode;

  @override
  String? get currentUserId => _currentUserId;

  @override
  Future<void> initialize({
    required String supabaseUrl,
    required String supabaseAnonKey,
    required String bridgefyApiKey,
    required String userId,
  }) async {
    if (_isInitialized) {
      print('ChatService already initialized');
      return;
    }

    try {
      print('Initializing ChatService...');
      _statusController.add('initializing');
      _currentUserId = userId;

      // Step 1: Initialize database
      _statusController.add('initializing_database');
      await DatabaseService.instance.initialize();
      print('✓ Database initialized');

      // Step 2: Initialize mesh service
      _statusController.add('initializing_mesh');
      await _meshService.initialize(bridgefyApiKey);
      print('✓ Mesh service initialized');

      // Step 3: Initialize online service
      _statusController.add('initializing_online');
      await _onlineService.initialize(supabaseUrl, supabaseAnonKey);
      _onlineService.setCurrentUserId(userId);
      print('✓ Online service initialized');

      // Step 4: Initialize network service
      _statusController.add('initializing_network');
      await _networkService.initialize();
      print('✓ Network service initialized');

      // Step 5: Initialize sync service
      _statusController.add('initializing_sync');
      await _syncService.initialize();
      print('✓ Sync service initialized');

      // Step 6: Initialize mode manager
      _statusController.add('initializing_mode_manager');
      await _modeManager.initialize();
      print('✓ Mode manager initialized');

      // Step 7: Initialize message queue service
      _statusController.add('initializing_message_queue');
      await _messageQueueService.initialize();
      print('✓ Message queue service initialized');

      // Step 8: Set up message stream coordination
      _statusController.add('setting_up_streams');
      _setupMessageStreams();
      _setupNetworkStateMonitoring();
      print('✓ Message streams configured');

      // Step 9: Start services based on initial network state
      _statusController.add('starting_services');
      await _startInitialServices();
      print('✓ Initial services started');

      _isInitialized = true;
      _isInitializedController.add(true);
      _statusController.add('initialized');
      
      print('ChatService initialized successfully');

    } catch (e) {
      print('Failed to initialize ChatService: $e');
      _statusController.add('initialization_failed: $e');
      _isInitialized = false;
      _isInitializedController.add(false);
      rethrow;
    }
  }

  @override
  Future<void> sendMessage(String text, {String? conversationId}) async {
    if (!_isInitialized) {
      throw Exception('ChatService not initialized. Call initialize() first.');
    }

    if (_currentUserId == null) {
      throw Exception('User ID not set');
    }

    if (text.trim().isEmpty) {
      throw ArgumentError('Message text cannot be empty');
    }

    try {
      print('Sending message: $text (mode: ${currentMode.name})');

      // Create message object based on current mode
      final message = Message.create(
        text: text.trim(),
        senderId: _currentUserId!,
        isOffline: isOfflineMode,
        conversationId: conversationId,
        status: MessageStatus.pending,
      );

      // Queue the message for sending with automatic retry
      await _messageQueueService.queueMessage(message);

      print('Message queued successfully');

    } catch (e) {
      print('Failed to send message: $e');
      rethrow;
    }
  }

  @override
  Future<void> switchMode(NetworkMode mode) async {
    if (!_isInitialized) {
      throw Exception('ChatService not initialized');
    }

    try {
      print('Switching to mode: $mode');
      await _modeManager.switchToOnlineMode();
      
      // The mode manager will handle the actual switching
      switch (mode) {
        case NetworkMode.online:
          await _modeManager.switchToOnlineMode();
          break;
        case NetworkMode.offline:
          await _modeManager.switchToOfflineMode();
          break;
        case NetworkMode.auto:
          await _modeManager.switchToAutoMode();
          break;
      }

      print('Mode switched successfully to: $mode');

    } catch (e) {
      print('Failed to switch mode: $e');
      rethrow;
    }
  }

  @override
  Future<void> retryFailedMessages() async {
    if (!_isInitialized) {
      throw Exception('ChatService not initialized');
    }

    try {
      print('Retrying failed messages using message queue...');
      
      // Use the message queue service to retry failed messages
      await _messageQueueService.retryFailedMessages();

      print('Failed message retry completed');

    } catch (e) {
      print('Error retrying failed messages: $e');
      rethrow;
    }
  }

  /// Set up message stream coordination
  void _setupMessageStreams() {
    // Listen to mesh service messages
    _meshMessagesSubscription = _meshService.incomingMessages.listen(
      (message) {
        print('Received mesh message: ${message.text}');
        // Messages are already saved by the mesh service
      },
      onError: (error) {
        print('Error in mesh messages stream: $error');
      },
    );

    // Listen to online service messages
    _onlineMessagesSubscription = _onlineService.incomingMessages.listen(
      (message) {
        print('Received online message: ${message.text}');
        // Messages are already saved by the online service
      },
      onError: (error) {
        print('Error in online messages stream: $error');
      },
    );
  }

  /// Set up network state monitoring
  void _setupNetworkStateMonitoring() {
    _networkStateSubscription = _networkService.networkState.listen(
      (networkState) {
        _handleNetworkStateChange(networkState);
      },
      onError: (error) {
        print('Error in network state stream: $error');
      },
    );
  }

  /// Handle network state changes
  void _handleNetworkStateChange(NetworkState networkState) {
    print('Network state changed: $networkState');
    
    // Trigger sync when coming online
    if (networkState.isOnlineMode && networkState.isOnlineServiceActive) {
      _triggerSyncIfNeeded();
    }
  }

  /// Trigger sync if needed
  void _triggerSyncIfNeeded() {
    if (_modeManager.isAutoSyncEnabled) {
      _syncService.triggerManualSync().catchError((e) {
        print('Auto-sync failed: $e');
      });
    }
  }

  /// Start initial services based on network state
  Future<void> _startInitialServices() async {
    final networkState = _networkService.currentNetworkState;
    
    if (networkState.isOnlineMode) {
      await _onlineService.connect();
      _syncService.startPeriodicSync();
    } else if (networkState.isOfflineMode) {
      await _meshService.start();
    }
  }

  @override
  Map<String, dynamic> getServiceStatistics() {
    return {
      'isInitialized': _isInitialized,
      'currentUserId': _currentUserId,
      'status': _statusController.value,
      'currentMode': currentMode.name,
      'isOnlineMode': isOnlineMode,
      'isOfflineMode': isOfflineMode,
      'networkService': _networkService.getNetworkStatistics(),
      'meshService': {
        'isInitialized': _meshService.isInitialized,
        'isStarted': _meshService.isStarted,
        'peersCount': _meshService.peersCount,
      },
      'onlineService': _onlineService.getConnectionStatus(),
      'syncService': _syncService.getSyncStatistics(),
      'modeManager': _modeManager.getModeStatistics(),
      'messageQueue': _messageQueueService.getQueueStatistics(),
    };
  }

  /// Get message statistics
  Future<Map<String, dynamic>> getMessageStatistics() async {
    return await _messageRepository.getMessageStatistics();
  }

  // Message queue related methods
  @override
  Stream<int> get queueSize => _messageQueueService.queueSize;

  @override
  Stream<Map<String, int>> get queueStats => _messageQueueService.queueStats;

  @override
  Future<void> processMessageQueue() async {
    if (!_isInitialized) {
      throw Exception('ChatService not initialized');
    }
    await _messageQueueService.processQueue();
  }

  @override
  Future<void> clearMessageQueue() async {
    if (!_isInitialized) {
      throw Exception('ChatService not initialized');
    }
    await _messageQueueService.clearQueue();
  }

  /// Clear all messages (for testing/reset)
  Future<void> clearAllMessages() async {
    if (!_isInitialized) {
      throw Exception('ChatService not initialized');
    }

    await _messageRepository.clearAllMessages();
    print('All messages cleared');
  }

  /// Get recent messages
  Future<List<Message>> getRecentMessages({int limit = 50}) async {
    if (!_isInitialized) {
      throw Exception('ChatService not initialized');
    }

    return await _messageRepository.getMessages(limit: limit);
  }

  /// Get messages by conversation
  Future<List<Message>> getConversationMessages(String conversationId) async {
    if (!_isInitialized) {
      throw Exception('ChatService not initialized');
    }

    return await _messageRepository.getMessagesByConversation(conversationId);
  }

  /// Force sync with server
  Future<void> forceSync() async {
    if (!_isInitialized) {
      throw Exception('ChatService not initialized');
    }

    if (!isOnlineMode) {
      throw Exception('Cannot sync while offline');
    }

    await _syncService.triggerManualSync();
  }

  /// Get current status
  String get currentStatus => _statusController.value;

  /// Stream of status updates
  Stream<String> get statusStream => _statusController.stream;

  /// Check if services are healthy
  bool get isHealthy {
    if (!_isInitialized) return false;
    
    try {
      final networkState = _networkService.currentNetworkState;
      
      if (networkState.isOnlineMode) {
        return _onlineService.isOnline;
      } else if (networkState.isOfflineMode) {
        return _meshService.isStarted;
      }
      
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Restart services (for error recovery)
  Future<void> restartServices() async {
    if (!_isInitialized) {
      throw Exception('ChatService not initialized');
    }

    try {
      print('Restarting services...');
      _statusController.add('restarting');

      // Stop current services
      if (_meshService.isStarted) {
        await _meshService.stop();
      }
      if (_onlineService.isOnline) {
        await _onlineService.disconnect();
      }

      // Restart based on current network state
      await _startInitialServices();

      _statusController.add('restarted');
      print('Services restarted successfully');

    } catch (e) {
      print('Failed to restart services: $e');
      _statusController.add('restart_failed: $e');
      rethrow;
    }
  }

  /// Dispose all resources
  void dispose() {
    _meshMessagesSubscription?.cancel();
    _onlineMessagesSubscription?.cancel();
    _networkStateSubscription?.cancel();
    
    _isInitializedController.close();
    _statusController.close();
    
    _meshService.dispose();
    _onlineService.dispose();
    _networkService.dispose();
    _syncService.dispose();
    _modeManager.dispose();
    _messageQueueService.dispose();
  }
}