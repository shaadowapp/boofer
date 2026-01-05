import 'dart:async';
import 'package:rxdart/rxdart.dart';
import '../models/message_model.dart';
import 'online_service.dart';
import 'message_repository.dart';

/// Service for synchronizing messages between local and remote storage
class SyncService {
  final IOnlineService _onlineService;
  final IMessageRepository _messageRepository;
  
  // Sync status tracking
  final BehaviorSubject<bool> _isSyncingController = BehaviorSubject<bool>.seeded(false);
  final BehaviorSubject<DateTime> _lastSyncController = BehaviorSubject<DateTime>();
  final BehaviorSubject<String> _syncStatusController = BehaviorSubject<String>.seeded('idle');
  
  Timer? _periodicSyncTimer;
  bool _isInitialized = false;
  
  // Sync configuration
  static const Duration syncInterval = Duration(minutes: 5);
  static const int batchSize = 50;
  static const Duration conflictResolutionWindow = Duration(seconds: 5);

  SyncService({
    required IOnlineService onlineService,
    required IMessageRepository messageRepository,
  }) : _onlineService = onlineService,
       _messageRepository = messageRepository;

  /// Stream indicating if sync is in progress
  Stream<bool> get isSyncing => _isSyncingController.stream;
  
  /// Stream of last sync timestamp
  Stream<DateTime> get lastSync => _lastSyncController.stream;
  
  /// Stream of sync status messages
  Stream<String> get syncStatus => _syncStatusController.stream;

  /// Initialize the sync service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Listen for connection changes to trigger sync
      _onlineService.isConnected.listen((isConnected) {
        if (isConnected) {
          _triggerSync();
        }
      });
      
      _isInitialized = true;
      print('SyncService initialized');
    } catch (e) {
      print('Failed to initialize SyncService: $e');
      rethrow;
    }
  }

  /// Start periodic synchronization
  void startPeriodicSync({Duration? interval}) {
    final syncInterval = interval ?? SyncService.syncInterval;
    
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = Timer.periodic(syncInterval, (timer) {
      if (_onlineService.isOnline && !_isSyncingController.value) {
        _triggerSync();
      }
    });
    
    print('Periodic sync started with ${syncInterval.inMinutes} minute interval');
  }

  /// Stop periodic synchronization
  void stopPeriodicSync() {
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = null;
    print('Periodic sync stopped');
  }

  /// Trigger a manual sync
  Future<void> triggerManualSync() async {
    if (!_onlineService.isOnline) {
      throw Exception('Cannot sync while offline');
    }
    
    await _performFullSync();
  }

  /// Internal method to trigger sync
  void _triggerSync() {
    if (_isSyncingController.value) {
      print('Sync already in progress, skipping');
      return;
    }
    
    _performFullSync().catchError((e) {
      print('Sync failed: $e');
      _syncStatusController.add('failed: $e');
    });
  }

  /// Perform full synchronization
  Future<void> _performFullSync() async {
    if (_isSyncingController.value) return;
    
    _isSyncingController.add(true);
    _syncStatusController.add('starting');
    
    try {
      print('Starting full synchronization...');
      
      // Step 1: Upload offline messages
      await _uploadOfflineMessages();
      
      // Step 2: Download new messages from server
      await _downloadNewMessages();
      
      // Step 3: Resolve conflicts
      await _resolveConflicts();
      
      // Step 4: Update sync timestamp
      final now = DateTime.now();
      _lastSyncController.add(now);
      
      _syncStatusController.add('completed');
      print('Full synchronization completed successfully');
      
    } catch (e) {
      print('Full synchronization failed: $e');
      _syncStatusController.add('failed: $e');
      rethrow;
    } finally {
      _isSyncingController.add(false);
    }
  }

  /// Upload offline messages to server
  Future<void> _uploadOfflineMessages() async {
    try {
      _syncStatusController.add('uploading offline messages');
      
      final offlineMessages = await _messageRepository.getOfflineMessages();
      
      if (offlineMessages.isEmpty) {
        print('No offline messages to upload');
        return;
      }
      
      print('Uploading ${offlineMessages.length} offline messages...');
      
      // Process messages in batches
      for (int i = 0; i < offlineMessages.length; i += batchSize) {
        final batch = offlineMessages.skip(i).take(batchSize).toList();
        await _uploadMessageBatch(batch);
      }
      
      print('Offline messages uploaded successfully');
      
    } catch (e) {
      print('Failed to upload offline messages: $e');
      rethrow;
    }
  }

  /// Upload a batch of messages
  Future<void> _uploadMessageBatch(List<Message> messages) async {
    for (final message in messages) {
      try {
        // Skip messages that are already synced or failed
        if (message.status == MessageStatus.delivered) {
          continue;
        }
        
        await _onlineService.syncOfflineMessages([message]);
        
      } catch (e) {
        print('Failed to upload message ${message.id}: $e');
        
        // Mark message as failed
        await _messageRepository.updateMessageStatus(
          message.id, 
          MessageStatus.failed,
        );
      }
    }
  }

  /// Download new messages from server
  Future<void> _downloadNewMessages() async {
    try {
      _syncStatusController.add('downloading new messages');
      
      // Get the timestamp of the last local message
      final localMessages = await _messageRepository.getMessages(limit: 1);
      DateTime? lastMessageTime;
      
      if (localMessages.isNotEmpty) {
        lastMessageTime = localMessages.first.timestamp;
      }
      
      // Get recent messages from server
      final serverMessages = await _onlineService.getRecentMessages(limit: 100);
      
      // Filter messages that are newer than our last local message
      final newMessages = serverMessages.where((message) {
        if (lastMessageTime == null) return true;
        return message.timestamp.isAfter(lastMessageTime);
      }).toList();
      
      if (newMessages.isEmpty) {
        print('No new messages to download');
        return;
      }
      
      print('Downloading ${newMessages.length} new messages...');
      
      // Save new messages to local database
      final savedIds = await _messageRepository.saveMessages(newMessages);
      
      print('Downloaded and saved ${savedIds.length} new messages');
      
    } catch (e) {
      print('Failed to download new messages: $e');
      rethrow;
    }
  }

  /// Resolve conflicts between local and remote messages
  Future<void> _resolveConflicts() async {
    try {
      _syncStatusController.add('resolving conflicts');
      
      // Get messages that might have conflicts (recent messages with same hash)
      final recentMessages = await _messageRepository.getRecentMessages();
      
      for (final localMessage in recentMessages) {
        if (localMessage.messageHash == null) continue;
        
        try {
          // This would require server-side API to check for conflicts
          // For now, we'll use timestamp-based resolution
          await _resolveMessageConflict(localMessage);
          
        } catch (e) {
          print('Failed to resolve conflict for message ${localMessage.id}: $e');
        }
      }
      
      print('Conflict resolution completed');
      
    } catch (e) {
      print('Failed to resolve conflicts: $e');
      rethrow;
    }
  }

  /// Resolve conflict for a specific message
  Future<void> _resolveMessageConflict(Message localMessage) async {
    // Timestamp-based conflict resolution:
    // - If local message is newer, keep it
    // - If server message is newer, update local
    // - If timestamps are very close, prefer server version
    
    try {
      // This is a simplified conflict resolution
      // In a real implementation, you'd query the server for the same message hash
      
      final timeDiff = DateTime.now().difference(localMessage.timestamp);
      
      if (timeDiff > conflictResolutionWindow && 
          localMessage.status == MessageStatus.pending) {
        // Message is old and still pending, likely a conflict
        print('Resolving conflict for message: ${localMessage.messageHash}');
        
        // Mark as delivered to avoid further conflicts
        await _messageRepository.updateMessageStatus(
          localMessage.id, 
          MessageStatus.delivered,
        );
      }
      
    } catch (e) {
      print('Error resolving message conflict: $e');
    }
  }

  /// Sync specific conversation
  Future<void> syncConversation(String conversationId) async {
    if (!_onlineService.isOnline) {
      throw Exception('Cannot sync conversation while offline');
    }
    
    try {
      print('Syncing conversation: $conversationId');
      
      // Get conversation messages from server
      final serverMessages = await _onlineService.getConversationMessages(conversationId);
      
      // Get local conversation messages
      final localMessages = await _messageRepository.getMessagesByConversation(conversationId);
      
      // Find messages that exist on server but not locally
      final newMessages = <Message>[];
      for (final serverMessage in serverMessages) {
        final exists = localMessages.any((local) => 
          local.messageHash == serverMessage.messageHash ||
          local.timestamp == serverMessage.timestamp
        );
        
        if (!exists) {
          newMessages.add(serverMessage);
        }
      }
      
      if (newMessages.isNotEmpty) {
        await _messageRepository.saveMessages(newMessages);
        print('Synced ${newMessages.length} new messages for conversation $conversationId');
      }
      
    } catch (e) {
      print('Failed to sync conversation $conversationId: $e');
      rethrow;
    }
  }

  /// Get sync statistics
  Map<String, dynamic> getSyncStatistics() {
    return {
      'isInitialized': _isInitialized,
      'isSyncing': _isSyncingController.value,
      'lastSync': _lastSyncController.hasValue ? _lastSyncController.value.toIso8601String() : null,
      'syncStatus': _syncStatusController.value,
      'periodicSyncActive': _periodicSyncTimer?.isActive ?? false,
      'isOnline': _onlineService.isOnline,
    };
  }

  /// Force sync of failed messages
  Future<void> syncFailedMessages() async {
    if (!_onlineService.isOnline) {
      throw Exception('Cannot sync failed messages while offline');
    }
    
    try {
      final failedMessages = await _messageRepository.getFailedMessages();
      
      if (failedMessages.isEmpty) {
        print('No failed messages to sync');
        return;
      }
      
      print('Syncing ${failedMessages.length} failed messages...');
      
      await _onlineService.syncOfflineMessages(failedMessages);
      
      print('Failed messages sync completed');
      
    } catch (e) {
      print('Failed to sync failed messages: $e');
      rethrow;
    }
  }

  /// Clear sync state (for testing/reset)
  void clearSyncState() {
    _lastSyncController.add(DateTime.fromMillisecondsSinceEpoch(0));
    _syncStatusController.add('reset');
    print('Sync state cleared');
  }

  /// Dispose resources
  void dispose() {
    _periodicSyncTimer?.cancel();
    _isSyncingController.close();
    _lastSyncController.close();
    _syncStatusController.close();
  }
}