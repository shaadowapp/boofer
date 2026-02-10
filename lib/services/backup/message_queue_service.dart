import 'dart:async';
import 'dart:math';
import 'package:rxdart/rxdart.dart';
import '../../models/message_model.dart';
import 'message_repository.dart';
import 'mesh_service.dart';
import 'online_service.dart';
import 'network_service.dart';

/// Configuration for retry logic
class RetryConfig {
  final int maxRetries;
  final Duration initialDelay;
  final double backoffMultiplier;
  final Duration maxDelay;
  final List<MessageStatus> retryableStatuses;

  const RetryConfig({
    this.maxRetries = 3,
    this.initialDelay = const Duration(seconds: 5),
    this.backoffMultiplier = 2.0,
    this.maxDelay = const Duration(minutes: 5),
    this.retryableStatuses = const [MessageStatus.pending, MessageStatus.failed],
  });
}

/// Represents a queued message with retry information
class QueuedMessage {
  final Message message;
  int retryCount;
  DateTime? nextRetryTime;
  String? lastError;

  QueuedMessage({
    required this.message,
    this.retryCount = 0,
    this.nextRetryTime,
    this.lastError,
  });

  bool get canRetry => retryCount < 3; // Max retries
  bool get isReadyForRetry => nextRetryTime == null || DateTime.now().isAfter(nextRetryTime!);
}

/// Service for managing message queues and automatic retry logic
class MessageQueueService {
  static MessageQueueService? _instance;
  
  final IMessageRepository _messageRepository;
  final IMeshService _meshService;
  final IOnlineService _onlineService;
  final INetworkService _networkService;
  final RetryConfig _retryConfig;

  // Queue management
  final Map<String, QueuedMessage> _messageQueue = {};
  Timer? _retryTimer;
  Timer? _queueProcessingTimer;
  
  // Streams for monitoring
  final BehaviorSubject<int> _queueSizeController = BehaviorSubject<int>.seeded(0);
  final BehaviorSubject<Map<String, int>> _queueStatsController = BehaviorSubject<Map<String, int>>.seeded({});
  
  bool _isProcessing = false;
  bool _isInitialized = false;

  MessageQueueService._({
    required IMessageRepository messageRepository,
    required IMeshService meshService,
    required IOnlineService onlineService,
    required INetworkService networkService,
    RetryConfig? retryConfig,
  }) : _messageRepository = messageRepository,
       _meshService = meshService,
       _onlineService = onlineService,
       _networkService = networkService,
       _retryConfig = retryConfig ?? const RetryConfig();

  static MessageQueueService getInstance({
    IMessageRepository? messageRepository,
    IMeshService? meshService,
    IOnlineService? onlineService,
    INetworkService? networkService,
    RetryConfig? retryConfig,
  }) {
    _instance ??= MessageQueueService._(
      messageRepository: messageRepository ?? MessageRepository(),
      meshService: meshService ?? MeshService.getInstance(),
      onlineService: onlineService ?? OnlineService.getInstance(),
      networkService: networkService ?? NetworkService.getInstance(),
      retryConfig: retryConfig,
    );
    return _instance!;
  }

  /// Stream of queue size changes
  Stream<int> get queueSize => _queueSizeController.stream;

  /// Stream of queue statistics
  Stream<Map<String, int>> get queueStats => _queueStatsController.stream;

  /// Initialize the message queue service
  Future<void> initialize() async {
    if (_isInitialized) {
      print('MessageQueueService already initialized');
      return;
    }

    try {
      print('Initializing MessageQueueService...');

      // Load existing failed and pending messages into queue
      await _loadExistingMessages();

      // Start periodic queue processing
      _startQueueProcessing();

      // Start retry timer
      _startRetryTimer();

      _isInitialized = true;
      print('MessageQueueService initialized successfully');

    } catch (e) {
      print('Failed to initialize MessageQueueService: $e');
      rethrow;
    }
  }

  /// Queue a message for sending with automatic retry
  Future<void> queueMessage(Message message) async {
    if (!_isInitialized) {
      throw Exception('MessageQueueService not initialized');
    }

    try {
      print('Queuing message: ${message.text} (ID: ${message.id})');

      // Save message to database if not already saved
      if (message.id.isEmpty) {
        final savedId = await _messageRepository.saveMessage(message);
        // Message ID is already set in the model
      }

      // Add to queue
      final queuedMessage = QueuedMessage(message: message);
      _messageQueue[message.id] = queuedMessage;

      _updateQueueStats();

      // Try to send immediately if network is available
      await _processMessage(queuedMessage);

    } catch (e) {
      print('Failed to queue message: $e');
      rethrow;
    }
  }

  /// Process all messages in the queue
  Future<void> processQueue() async {
    if (!_isInitialized || _isProcessing) {
      return;
    }

    _isProcessing = true;

    try {
      print('Processing message queue (${_messageQueue.length} messages)...');

      final messagesToProcess = _messageQueue.values
          .where((qm) => qm.isReadyForRetry && qm.canRetry)
          .toList();

      for (final queuedMessage in messagesToProcess) {
        await _processMessage(queuedMessage);
        
        // Small delay between messages to avoid overwhelming the network
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // Clean up successfully sent messages
      _cleanupQueue();

    } catch (e) {
      print('Error processing message queue: $e');
    } finally {
      _isProcessing = false;
    }
  }

  /// Retry failed messages
  Future<void> retryFailedMessages() async {
    if (!_isInitialized) {
      throw Exception('MessageQueueService not initialized');
    }

    try {
      print('Retrying failed messages...');

      // Get failed messages from database that aren't in queue yet
      final failedMessages = await _messageRepository.getFailedMessages();
      
      for (final message in failedMessages) {
        if (!_messageQueue.containsKey(message.id)) {
          final queuedMessage = QueuedMessage(message: message);
          _messageQueue[message.id] = queuedMessage;
        }
      }

      _updateQueueStats();

      // Process the queue
      await processQueue();

    } catch (e) {
      print('Error retrying failed messages: $e');
      rethrow;
    }
  }

  /// Process a single queued message
  Future<void> _processMessage(QueuedMessage queuedMessage) async {
    final message = queuedMessage.message;

    try {
      print('Processing message: ${message.text} (attempt ${queuedMessage.retryCount + 1})');

      // Check network connectivity and send via appropriate service
      bool success = false;
      
      if (message.isOffline) {
        // Send via mesh network
        if (_meshService.isStarted) {
          await _meshService.sendMeshMessage(message.text, message.senderId);
          success = true;
        } else {
          throw Exception('Mesh service not available');
        }
      } else {
        // Send via online service
        if (_onlineService.isOnline) {
          await _onlineService.sendOnlineMessage(message.text, message.senderId);
          success = true;
        } else {
          throw Exception('Online service not available');
        }
      }

      if (success) {
        // Update message status to sent
        await _messageRepository.updateMessageStatus(message.id, MessageStatus.sent);
        
        // Remove from queue
        _messageQueue.remove(message.id);
        
        print('Message sent successfully: ${message.text}');
      }

    } catch (e) {
      print('Failed to send message ${message.id}: $e');
      
      queuedMessage.lastError = e.toString();
      queuedMessage.retryCount++;

      if (queuedMessage.canRetry) {
        // Schedule next retry with exponential backoff
        final delay = _calculateRetryDelay(queuedMessage.retryCount);
        queuedMessage.nextRetryTime = DateTime.now().add(delay);
        
        print('Scheduling retry ${queuedMessage.retryCount} for message ${message.id} in ${delay.inSeconds}s');
      } else {
        // Max retries reached, mark as failed
        await _messageRepository.updateMessageStatus(message.id, MessageStatus.failed);
        _messageQueue.remove(message.id);
        
        print('Max retries reached for message ${message.id}, marking as failed');
      }
    }

    _updateQueueStats();
  }

  /// Calculate retry delay with exponential backoff
  Duration _calculateRetryDelay(int retryCount) {
    final delay = Duration(
      milliseconds: (_retryConfig.initialDelay.inMilliseconds * 
                    pow(_retryConfig.backoffMultiplier, retryCount - 1)).round(),
    );
    
    // Cap at maximum delay
    return delay > _retryConfig.maxDelay ? _retryConfig.maxDelay : delay;
  }

  /// Load existing failed and pending messages into queue
  Future<void> _loadExistingMessages() async {
    try {
      final pendingMessages = await _messageRepository.getMessagesByStatus(MessageStatus.pending);
      final failedMessages = await _messageRepository.getMessagesByStatus(MessageStatus.failed);
      
      final allMessages = [...pendingMessages, ...failedMessages];
      
      for (final message in allMessages) {
        final queuedMessage = QueuedMessage(message: message);
        _messageQueue[message.id] = queuedMessage;
      }

      print('Loaded ${allMessages.length} existing messages into queue');
      _updateQueueStats();

    } catch (e) {
      print('Error loading existing messages: $e');
    }
  }

  /// Start periodic queue processing
  void _startQueueProcessing() {
    _queueProcessingTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      processQueue();
    });
  }

  /// Start retry timer for checking ready messages
  void _startRetryTimer() {
    _retryTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _checkRetryReadyMessages();
    });
  }

  /// Check for messages ready for retry
  void _checkRetryReadyMessages() {
    final readyMessages = _messageQueue.values
        .where((qm) => qm.isReadyForRetry && qm.canRetry)
        .length;

    if (readyMessages > 0) {
      print('Found $readyMessages messages ready for retry');
      processQueue();
    }
  }

  /// Clean up successfully sent messages from queue
  void _cleanupQueue() {
    final initialSize = _messageQueue.length;
    
    _messageQueue.removeWhere((id, queuedMessage) {
      return queuedMessage.message.status == MessageStatus.sent ||
             queuedMessage.message.status == MessageStatus.delivered;
    });

    final removedCount = initialSize - _messageQueue.length;
    if (removedCount > 0) {
      print('Cleaned up $removedCount messages from queue');
      _updateQueueStats();
    }
  }

  /// Update queue statistics
  void _updateQueueStats() {
    final stats = <String, int>{};
    
    stats['total'] = _messageQueue.length;
    stats['pending'] = _messageQueue.values
        .where((qm) => qm.message.status == MessageStatus.pending)
        .length;
    stats['failed'] = _messageQueue.values
        .where((qm) => qm.message.status == MessageStatus.failed)
        .length;
    stats['retrying'] = _messageQueue.values
        .where((qm) => qm.retryCount > 0 && qm.canRetry)
        .length;
    stats['maxRetriesReached'] = _messageQueue.values
        .where((qm) => !qm.canRetry)
        .length;

    _queueSizeController.add(stats['total']!);
    _queueStatsController.add(stats);
  }

  /// Get current queue statistics
  Map<String, dynamic> getQueueStatistics() {
    final stats = _queueStatsController.value;
    
    return {
      'queueSize': _messageQueue.length,
      'isProcessing': _isProcessing,
      'isInitialized': _isInitialized,
      'retryConfig': {
        'maxRetries': _retryConfig.maxRetries,
        'initialDelay': _retryConfig.initialDelay.inSeconds,
        'backoffMultiplier': _retryConfig.backoffMultiplier,
        'maxDelay': _retryConfig.maxDelay.inSeconds,
      },
      'stats': stats,
      'nextRetryTimes': _messageQueue.values
          .where((qm) => qm.nextRetryTime != null)
          .map((qm) => {
            'messageId': qm.message.id,
            'nextRetry': qm.nextRetryTime!.toIso8601String(),
            'retryCount': qm.retryCount,
          })
          .toList(),
    };
  }

  /// Clear the entire queue (for testing/reset)
  Future<void> clearQueue() async {
    _messageQueue.clear();
    _updateQueueStats();
    print('Message queue cleared');
  }

  /// Get messages currently in queue
  List<Message> getQueuedMessages() {
    return _messageQueue.values.map((qm) => qm.message).toList();
  }

  /// Check if a message is in the queue
  bool isMessageQueued(String messageId) {
    return _messageQueue.containsKey(messageId);
  }

  /// Remove a message from the queue
  void removeFromQueue(String messageId) {
    if (_messageQueue.remove(messageId) != null) {
      print('Removed message $messageId from queue');
      _updateQueueStats();
    }
  }

  /// Pause queue processing
  void pauseProcessing() {
    _queueProcessingTimer?.cancel();
    _retryTimer?.cancel();
    print('Queue processing paused');
  }

  /// Resume queue processing
  void resumeProcessing() {
    _startQueueProcessing();
    _startRetryTimer();
    print('Queue processing resumed');
  }

  /// Dispose resources
  void dispose() {
    _queueProcessingTimer?.cancel();
    _retryTimer?.cancel();
    _queueSizeController.close();
    _queueStatsController.close();
    _messageQueue.clear();
    print('MessageQueueService disposed');
  }
}