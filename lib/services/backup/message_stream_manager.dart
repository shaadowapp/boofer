import 'dart:async';
import 'package:rxdart/rxdart.dart';
import '../../models/message_model.dart';
import 'message_repository.dart';
import 'mesh_service.dart';
import 'online_service.dart';

/// Manager for coordinating message streams from different sources
class MessageStreamManager {
  final IMessageRepository _messageRepository;
  final IMeshService _meshService;
  final IOnlineService _onlineService;
  
  // Combined message streams
  final BehaviorSubject<List<Message>> _allMessagesController = BehaviorSubject<List<Message>>();
  final BehaviorSubject<Message> _newMessageController = BehaviorSubject<Message>();
  final BehaviorSubject<Message> _updatedMessageController = BehaviorSubject<Message>();
  
  // Stream subscriptions
  StreamSubscription? _databaseStreamSubscription;
  StreamSubscription? _meshStreamSubscription;
  StreamSubscription? _onlineStreamSubscription;
  
  // Message filtering and sorting
  final Map<String, StreamController<List<Message>>> _conversationStreams = {};
  final Set<String> _processedMessageHashes = <String>{};
  
  bool _isInitialized = false;

  MessageStreamManager({
    required IMessageRepository messageRepository,
    required IMeshService meshService,
    required IOnlineService onlineService,
  }) : _messageRepository = messageRepository,
       _meshService = meshService,
       _onlineService = onlineService;

  /// Stream of all messages (combined from all sources)
  Stream<List<Message>> get allMessages => _allMessagesController.stream;
  
  /// Stream of new messages as they arrive
  Stream<Message> get newMessages => _newMessageController.stream;
  
  /// Stream of message updates (status changes, etc.)
  Stream<Message> get updatedMessages => _updatedMessageController.stream;

  /// Initialize the stream manager
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      print('Initializing MessageStreamManager...');
      
      // Set up database stream (primary source of truth)
      _setupDatabaseStream();
      
      // Set up mesh service stream
      _setupMeshStream();
      
      // Set up online service stream
      _setupOnlineStream();
      
      _isInitialized = true;
      print('MessageStreamManager initialized successfully');
      
    } catch (e) {
      print('Failed to initialize MessageStreamManager: $e');
      rethrow;
    }
  }

  /// Set up database message stream
  void _setupDatabaseStream() {
    _databaseStreamSubscription = _messageRepository.messagesStream.listen(
      (messages) {
        _handleDatabaseMessages(messages);
      },
      onError: (error) {
        print('Error in database messages stream: $error');
      },
    );
  }

  /// Set up mesh service stream
  void _setupMeshStream() {
    _meshStreamSubscription = _meshService.incomingMessages.listen(
      (message) {
        _handleNewMessage(message, 'mesh');
      },
      onError: (error) {
        print('Error in mesh messages stream: $error');
      },
    );
  }

  /// Set up online service stream
  void _setupOnlineStream() {
    _onlineStreamSubscription = _onlineService.incomingMessages.listen(
      (message) {
        _handleNewMessage(message, 'online');
      },
      onError: (error) {
        print('Error in online messages stream: $error');
      },
    );
  }

  /// Handle messages from database (primary source)
  void _handleDatabaseMessages(List<Message> messages) {
    // Sort messages by timestamp (newest first for UI)
    final sortedMessages = List<Message>.from(messages)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    
    _allMessagesController.add(sortedMessages);
    
    // Update conversation streams
    _updateConversationStreams(sortedMessages);
    
    print('Database messages updated: ${messages.length} total');
  }

  /// Handle new message from services
  void _handleNewMessage(Message message, String source) {
    // Check for duplicates
    if (message.messageHash != null && 
        _processedMessageHashes.contains(message.messageHash)) {
      print('Duplicate message ignored from $source: ${message.messageHash}');
      return;
    }
    
    // Add to processed set
    if (message.messageHash != null) {
      _processedMessageHashes.add(message.messageHash!);
    }
    
    // Emit new message
    _newMessageController.add(message);
    
    print('New message from $source: ${message.text}');
  }

  /// Update conversation-specific streams
  void _updateConversationStreams(List<Message> allMessages) {
    final conversationGroups = <String, List<Message>>{};
    
    // Group messages by conversation
    for (final message in allMessages) {
      final conversationId = message.conversationId ?? 'default';
      conversationGroups[conversationId] ??= <Message>[];
      conversationGroups[conversationId]!.add(message);
    }
    
    // Update each conversation stream
    for (final entry in conversationGroups.entries) {
      final conversationId = entry.key;
      final messages = entry.value;
      
      if (_conversationStreams.containsKey(conversationId)) {
        _conversationStreams[conversationId]!.add(messages);
      }
    }
  }

  /// Get stream for specific conversation
  Stream<List<Message>> getConversationStream(String conversationId) {
    if (!_conversationStreams.containsKey(conversationId)) {
      _conversationStreams[conversationId] = StreamController<List<Message>>.broadcast();
      
      // Initialize with existing messages
      _initializeConversationStream(conversationId);
    }
    
    return _conversationStreams[conversationId]!.stream;
  }

  /// Initialize conversation stream with existing messages
  void _initializeConversationStream(String conversationId) async {
    try {
      final messages = await _messageRepository.getMessagesByConversation(conversationId);
      final sortedMessages = List<Message>.from(messages)
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      
      _conversationStreams[conversationId]?.add(sortedMessages);
    } catch (e) {
      print('Error initializing conversation stream for $conversationId: $e');
    }
  }

  /// Get stream of messages with specific status
  Stream<List<Message>> getMessagesByStatus(MessageStatus status) {
    return _allMessagesController.stream.map((messages) {
      return messages.where((message) => message.status == status).toList();
    });
  }

  /// Get stream of offline messages
  Stream<List<Message>> get offlineMessages {
    return _allMessagesController.stream.map((messages) {
      return messages.where((message) => message.isOffline).toList();
    });
  }

  /// Get stream of online messages
  Stream<List<Message>> get onlineMessages {
    return _allMessagesController.stream.map((messages) {
      return messages.where((message) => !message.isOffline).toList();
    });
  }

  /// Get stream of pending messages
  Stream<List<Message>> get pendingMessages {
    return getMessagesByStatus(MessageStatus.pending);
  }

  /// Get stream of failed messages
  Stream<List<Message>> get failedMessages {
    return getMessagesByStatus(MessageStatus.failed);
  }

  /// Get stream of recent messages (last 24 hours)
  Stream<List<Message>> get recentMessages {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    
    return _allMessagesController.stream.map((messages) {
      return messages.where((message) => 
        message.timestamp.isAfter(yesterday)
      ).toList();
    });
  }

  /// Get stream of messages from specific sender
  Stream<List<Message>> getMessagesBySender(String senderId) {
    return _allMessagesController.stream.map((messages) {
      return messages.where((message) => message.senderId == senderId).toList();
    });
  }

  /// Get stream of messages containing specific text
  Stream<List<Message>> searchMessages(String query) {
    final lowerQuery = query.toLowerCase();
    
    return _allMessagesController.stream.map((messages) {
      return messages.where((message) => 
        message.text.toLowerCase().contains(lowerQuery)
      ).toList();
    });
  }

  /// Emit message update notification
  void notifyMessageUpdated(Message message) {
    _updatedMessageController.add(message);
  }

  /// Get current message count
  int get currentMessageCount {
    return _allMessagesController.hasValue ? _allMessagesController.value.length : 0;
  }

  /// Get current messages snapshot
  List<Message> get currentMessages {
    return _allMessagesController.hasValue ? 
        List<Message>.from(_allMessagesController.value) : <Message>[];
  }

  /// Clear processed message hashes (for memory management)
  void clearProcessedHashes() {
    _processedMessageHashes.clear();
    print('Processed message hashes cleared');
  }

  /// Get stream statistics
  Map<String, dynamic> getStreamStatistics() {
    return {
      'isInitialized': _isInitialized,
      'totalMessages': currentMessageCount,
      'conversationStreams': _conversationStreams.length,
      'processedHashes': _processedMessageHashes.length,
      'hasAllMessages': _allMessagesController.hasValue,
      'hasNewMessages': _newMessageController.hasValue,
      'hasUpdatedMessages': _updatedMessageController.hasValue,
    };
  }

  /// Create a filtered stream based on custom criteria
  Stream<List<Message>> createFilteredStream(bool Function(Message) filter) {
    return _allMessagesController.stream.map((messages) {
      return messages.where(filter).toList();
    });
  }

  /// Create a transformed stream
  Stream<T> createTransformedStream<T>(T Function(List<Message>) transformer) {
    return _allMessagesController.stream.map(transformer);
  }

  /// Get message count stream
  Stream<int> get messageCountStream {
    return _allMessagesController.stream.map((messages) => messages.length);
  }

  /// Get unread message count stream (assuming we track read status)
  Stream<int> get unreadMessageCountStream {
    return _allMessagesController.stream.map((messages) {
      // This would require a 'read' field in the Message model
      // For now, we'll count delivered messages as potentially unread
      return messages.where((message) => 
        message.status == MessageStatus.delivered
      ).length;
    });
  }

  /// Dispose all resources
  void dispose() {
    // Cancel subscriptions
    _databaseStreamSubscription?.cancel();
    _meshStreamSubscription?.cancel();
    _onlineStreamSubscription?.cancel();
    
    // Close main controllers
    _allMessagesController.close();
    _newMessageController.close();
    _updatedMessageController.close();
    
    // Close conversation streams
    for (final controller in _conversationStreams.values) {
      controller.close();
    }
    _conversationStreams.clear();
    
    // Clear processed hashes
    _processedMessageHashes.clear();
    
    print('MessageStreamManager disposed');
  }
}