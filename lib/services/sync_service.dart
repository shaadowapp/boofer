import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:sqflite/sqflite.dart';
import '../core/database/database_manager.dart';
import '../core/error/error_handler.dart';
import '../core/models/app_error.dart';
import '../models/message_model.dart';
import 'firebase_service.dart';
import 'user_service.dart';

/// Hybrid sync service that manages data between local SQLite and Firebase
class SyncService {
  static SyncService? _instance;
  static SyncService get instance => _instance ??= SyncService._internal();
  SyncService._internal();

  final DatabaseManager _database = DatabaseManager.instance;
  final FirebaseService _firebase = FirebaseService.instance;
  final ErrorHandler _errorHandler = ErrorHandler();
  final Connectivity _connectivity = Connectivity();
  
  bool _isOnline = false;
  bool _isSyncing = false;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  Timer? _syncTimer;

  // Sync status streams
  final StreamController<bool> _syncStatusController = StreamController<bool>.broadcast();
  final StreamController<String> _syncMessageController = StreamController<String>.broadcast();
  
  Stream<bool> get syncStatusStream => _syncStatusController.stream;
  Stream<String> get syncMessageStream => _syncMessageController.stream;

  /// Initialize sync service
  Future<void> initialize() async {
    try {
      await _firebase.initialize();
      
      // Check initial connectivity
      final connectivityResult = await _connectivity.checkConnectivity();
      _isOnline = connectivityResult != ConnectivityResult.none;
      
      // Listen to connectivity changes
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen((result) {
        final wasOnline = _isOnline;
        _isOnline = result != ConnectivityResult.none;
        
        if (!wasOnline && _isOnline) {
          // Just came online - sync data
          _performFullSync();
        }
      });

      // Set up periodic sync when online
      _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
        if (_isOnline && !_isSyncing) {
          _performIncrementalSync();
        }
      });

      // Initial sync if online
      if (_isOnline) {
        _performFullSync();
      }

      print('Sync service initialized - Online: $_isOnline');
    } catch (e, stackTrace) {
      _errorHandler.handleError(AppError.service(
        message: 'Failed to initialize sync service: $e',
        stackTrace: stackTrace,
        originalException: e is Exception ? e : Exception(e.toString()),
      ));
    }
  }

  /// Perform full sync (on startup or reconnection)
  Future<void> _performFullSync() async {
    if (_isSyncing || !_isOnline) return;
    
    _isSyncing = true;
    _syncStatusController.add(true);
    _syncMessageController.add('Syncing data...');

    try {
      // 1. Sync user profile
      await _syncUserProfile();
      
      // 2. Sync pending messages
      await _syncPendingMessages();
      
      // 3. Sync conversations
      await _syncConversations();
      
      // 4. Sync connection requests
      await _syncConnectionRequests();

      _syncMessageController.add('Sync completed');
      print('Full sync completed successfully');
    } catch (e, stackTrace) {
      _syncMessageController.add('Sync failed');
      _errorHandler.handleError(AppError.service(
        message: 'Full sync failed: $e',
        stackTrace: stackTrace,
        originalException: e is Exception ? e : Exception(e.toString()),
      ));
    } finally {
      _isSyncing = false;
      _syncStatusController.add(false);
    }
  }

  /// Perform incremental sync (periodic updates)
  Future<void> _performIncrementalSync() async {
    if (_isSyncing || !_isOnline) return;
    
    try {
      // Sync only recent changes
      await _syncPendingMessages();
      await _syncRecentConversations();
    } catch (e) {
      // Silent fail for incremental sync
      print('Incremental sync failed: $e');
    }
  }

  /// Sync user profile between local and Firebase
  Future<void> _syncUserProfile() async {
    try {
      final currentUser = await UserService.getCurrentUser();
      if (currentUser == null) return;

      // Check if user exists in Firebase
      final firebaseUser = await _firebase.getCurrentUser();
      
      if (firebaseUser == null) {
        // Create user in Firebase
        await _firebase.createUser(
          virtualNumber: currentUser.virtualNumber ?? '',
          handle: currentUser.handle,
          fullName: currentUser.fullName,
          bio: currentUser.bio,
        );
      } else {
        // Update local user with any Firebase changes
        if (firebaseUser.updatedAt.isAfter(currentUser.updatedAt)) {
          await UserService.updateUser(firebaseUser);
        }
      }
    } catch (e) {
      print('User profile sync failed: $e');
    }
  }

  /// Sync pending messages to Firebase
  Future<void> _syncPendingMessages() async {
    try {
      // Get pending messages from local database
      final pendingMessages = await _database.query(
        'SELECT * FROM messages WHERE status = ? ORDER BY timestamp ASC',
        ['pending'],
      );

      for (final messageData in pendingMessages) {
        final message = Message.fromJson(messageData);
        
        // Send to Firebase
        final sentMessage = await _firebase.sendMessage(
          conversationId: message.conversationId!,
          senderId: message.senderId,
          receiverId: message.receiverId!,
          text: message.text,
          type: message.type,
        );

        if (sentMessage != null) {
          // Update local message status
          await _database.update(
            'messages',
            {
              'status': MessageStatus.sent.name,
              'updated_at': DateTime.now().toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [message.id],
          );
        }
      }
    } catch (e) {
      print('Pending messages sync failed: $e');
    }
  }

  /// Sync conversations from Firebase
  Future<void> _syncConversations() async {
    try {
      final currentUser = await UserService.getCurrentUser();
      if (currentUser == null) return;

      final conversations = await _firebase.getUserConversations(currentUser.id);
      
      for (final conversation in conversations) {
        // Update local conversation metadata
        await _database.insert(
          'conversations',
          {
            'id': conversation['id'],
            'name': conversation['name'],
            'type': conversation['type'] ?? 'direct',
            'created_by': currentUser.id,
            'created_at': conversation['createdAt'] ?? DateTime.now().toIso8601String(),
            'updated_at': conversation['updatedAt'] ?? DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    } catch (e) {
      print('Conversations sync failed: $e');
    }
  }

  /// Sync recent conversations only
  Future<void> _syncRecentConversations() async {
    try {
      final currentUser = await UserService.getCurrentUser();
      if (currentUser == null) return;

      // Get conversations updated in last hour
      final recentConversations = await _firebase.getUserConversations(currentUser.id);
      
      // Only sync conversations with recent activity
      final oneHourAgo = DateTime.now().subtract(const Duration(hours: 1));
      
      for (final conversation in recentConversations) {
        final updatedAt = DateTime.parse(conversation['updatedAt'] ?? DateTime.now().toIso8601String());
        if (updatedAt.isAfter(oneHourAgo)) {
          // This conversation has recent activity - sync it
          await _syncConversationMessages(conversation['id']);
        }
      }
    } catch (e) {
      print('Recent conversations sync failed: $e');
    }
  }

  /// Sync messages for a specific conversation
  Future<void> _syncConversationMessages(String conversationId) async {
    try {
      // For now, we'll implement a simple sync without real-time listeners
      // Real-time listeners will be added in the chat screens directly
      print('Conversation $conversationId marked for sync');
    } catch (e) {
      print('Conversation messages sync failed: $e');
    }
  }

  /// Sync connection requests
  Future<void> _syncConnectionRequests() async {
    try {
      final currentUser = await UserService.getCurrentUser();
      if (currentUser == null) return;

      final requests = await _firebase.getConnectionRequests(currentUser.id);
      
      for (final request in requests) {
        await _database.insert(
          'connection_requests',
          {
            'id': request['id'],
            'from_user_id': request['fromUserId'],
            'to_user_id': request['toUserId'],
            'message': request['message'],
            'status': request['status'],
            'sent_at': request['sentAt'],
            'responded_at': request['respondedAt'],
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    } catch (e) {
      print('Connection requests sync failed: $e');
    }
  }

  /// Send message (handles online/offline scenarios)
  Future<Message?> sendMessage({
    required String conversationId,
    required String senderId,
    required String receiverId,
    required String text,
    MessageType type = MessageType.text,
  }) async {
    try {
      final message = Message.create(
        text: text,
        senderId: senderId,
        receiverId: receiverId,
        conversationId: conversationId,
        type: type,
        isOffline: !_isOnline,
      );

      // Always save to local database first
      await _database.insert('messages', {
        'id': message.id,
        'text': message.text,
        'sender_id': message.senderId,
        'receiver_id': message.receiverId,
        'conversation_id': message.conversationId,
        'timestamp': message.timestamp.toIso8601String(),
        'is_offline': message.isOffline ? 1 : 0,
        'status': _isOnline ? MessageStatus.sent.name : MessageStatus.pending.name,
        'message_hash': message.messageHash,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      // If online, also send to Firebase
      if (_isOnline) {
        final sentMessage = await _firebase.sendMessage(
          conversationId: conversationId,
          senderId: senderId,
          receiverId: receiverId,
          text: text,
          type: type,
        );

        if (sentMessage != null) {
          // Update local message status
          await _database.update(
            'messages',
            {
              'status': MessageStatus.sent.name,
              'updated_at': DateTime.now().toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [message.id],
          );
          
          return message.copyWith(status: MessageStatus.sent);
        }
      }

      return message;
    } catch (e, stackTrace) {
      _errorHandler.handleError(AppError.service(
        message: 'Failed to send message: $e',
        stackTrace: stackTrace,
        originalException: e is Exception ? e : Exception(e.toString()),
      ));
      return null;
    }
  }

  /// Force sync now
  Future<void> forcSync() async {
    if (_isOnline) {
      await _performFullSync();
    }
  }

  /// Get sync status
  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;

  void dispose() {
    _connectivitySubscription?.cancel();
    _syncTimer?.cancel();
    _syncStatusController.close();
    _syncMessageController.close();
    _firebase.dispose();
  }
}