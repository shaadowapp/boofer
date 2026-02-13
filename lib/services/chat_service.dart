import 'dart:async';
import '../core/database/database_manager.dart';
import '../core/models/app_error.dart';
import '../core/error/error_handler.dart';
import '../models/message_model.dart';
import '../models/network_state.dart';
import '../services/follow_service.dart';
import '../services/supabase_service.dart';
import '../core/constants.dart';

/// Privacy-focused chat service for local message management
class ChatService {
  final DatabaseManager _database;
  final ErrorHandler _errorHandler;
  final FollowService _followService = FollowService.instance;
  final SupabaseService _supabaseService = SupabaseService.instance;
  final Map<String, List<Message>> _messageCache = {};
  final StreamController<List<Message>> _messagesController =
      StreamController<List<Message>>.broadcast();
  final StreamController<Message> _newMessageController =
      StreamController<Message>.broadcast();
  final StreamController<NetworkState> _networkStateController =
      StreamController<NetworkState>.broadcast();

  Stream<List<Message>> get messagesStream => _messagesController.stream;
  Stream<Message> get newMessageStream => _newMessageController.stream;
  Stream<NetworkState> get networkState => _networkStateController.stream;

  ChatService({
    required DatabaseManager database,
    required ErrorHandler errorHandler,
  }) : _database = database,
       _errorHandler = errorHandler {
    // Initialize with default network state
    _networkStateController.add(
      NetworkState.initial().copyWith(
        hasInternetConnection: true,
        isOnlineServiceActive: true,
      ),
    );
  }

  /// Load messages for a conversation
  Future<void> loadMessages(String conversationId, String userId) async {
    try {
      // Validate conversation access first
      final canAccess = await canAccessConversation(conversationId, userId);
      if (!canAccess) {
        throw Exception('You don\'t have access to this conversation.');
      }

      // Subscribe to real-time updates from Supabase
      final parts = conversationId.split('_');
      if (parts.length == 3) {
        _supabaseService.listenToMessages(conversationId, (messages) {
          _messageCache[conversationId] = messages;
          _messagesController.add(messages);
        });
      }

      final results = await _database.query(
        '''
        SELECT * FROM messages 
        WHERE conversation_id = ? 
        ORDER BY timestamp ASC
        ''',
        [conversationId],
      );

      final messages = results.map((json) => Message.fromJson(json)).toList();
      _messageCache[conversationId] = messages;
      _messagesController.add(messages);
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        AppError.database(
          message: 'Failed to load messages: $e',
          stackTrace: stackTrace,
          originalException: e is Exception ? e : Exception(e.toString()),
        ),
      );
    }
  }

  /// Validate if user can access a conversation
  Future<bool> canAccessConversation(
    String conversationId,
    String userId,
  ) async {
    try {
      // Extract user IDs from conversation ID (format: conv_userId1_userId2)
      final parts = conversationId.split('_');
      if (parts.length != 3 || parts[0] != 'conv') {
        return false;
      }

      final userId1 = parts[1];
      final userId2 = parts[2];

      // User must be part of the conversation
      if (userId != userId1 && userId != userId2) {
        return false;
      }

      // If it's a self-conversation, allow it
      if (userId1 == userId2) {
        return userId == userId1;
      }

      // Allow if either user is Boofer
      if (userId1 == AppConstants.booferId ||
          userId2 == AppConstants.booferId) {
        return true;
      }

      // Otherwise, check if users have a follow relationship
      final status = await _followService.getFollowStatus(
        currentUserId: userId1,
        targetUserId: userId2,
      );

      // Either user following the other is enough to allow access to the conversation
      return status == 'mutual' ||
          status == 'following' ||
          status == 'follower';
    } catch (e) {
      return false;
    }
  }

  /// Send a new message
  Future<Message?> sendMessage({
    required String conversationId,
    required String senderId,
    required String content,
    String? receiverId,
    MessageType type = MessageType.text,
    String? mediaUrl,
  }) async {
    try {
      // Validate following status before sending message
      if (receiverId != null && receiverId != senderId) {
        final isBooferRecipient = receiverId == AppConstants.booferId;
        final isBooferSender = senderId == AppConstants.booferId;

        if (!isBooferRecipient && !isBooferSender) {
          final status = await _followService.getFollowStatus(
            currentUserId: senderId,
            targetUserId: receiverId,
          );

          if (status != 'mutual' && status != 'following') {
            throw Exception(
              'Private messaging requires you to follow the recipient.',
            );
          }
        }
      }

      // Validate conversation access
      final canAccess = await canAccessConversation(conversationId, senderId);
      if (!canAccess) {
        throw Exception('You don\'t have access to this conversation.');
      }

      final message = Message.create(
        text: content,
        senderId: senderId,
        receiverId: receiverId,
        conversationId: conversationId,
        type: type,
        mediaUrl: mediaUrl,
      );

      // Send to Supabase if receiverId is provided
      if (receiverId != null) {
        await _supabaseService.sendMessage(
          conversationId: conversationId,
          senderId: senderId,
          receiverId: receiverId,
          text: content,
          type: type,
        );
      }

      // Save to database
      await _database.insert('messages', {
        'id': message.id,
        'text': message.text,
        'sender_id': message.senderId,
        'receiver_id': message.receiverId,
        'conversation_id': message.conversationId,
        'timestamp': message.timestamp.toIso8601String(),
        'is_offline': message.isOffline ? 1 : 0,
        'status': message.status.name,
        'message_hash': message.messageHash,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Update cache
      if (_messageCache.containsKey(conversationId)) {
        _messageCache[conversationId]!.add(message);
      } else {
        _messageCache[conversationId] = [message];
      }

      // Notify listeners
      _messagesController.add(_messageCache[conversationId]!);
      _newMessageController.add(message);

      return message;
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        AppError.database(
          message: 'Failed to send message: $e',
          stackTrace: stackTrace,
          originalException: e is Exception ? e : Exception(e.toString()),
        ),
      );
      return null;
    }
  }

  /// Mark message as read
  Future<void> markMessageAsRead(String messageId) async {
    try {
      await _database.update(
        'messages',
        {
          'status': MessageStatus.read.name,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [messageId],
      );

      // Update cache
      for (final messages in _messageCache.values) {
        final messageIndex = messages.indexWhere((m) => m.id == messageId);
        if (messageIndex != -1) {
          final updatedMessage = messages[messageIndex].copyWith(
            status: MessageStatus.read,
          );
          messages[messageIndex] = updatedMessage;
          break;
        }
      }
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        AppError.database(
          message: 'Failed to mark message as read: $e',
          stackTrace: stackTrace,
          originalException: e is Exception ? e : Exception(e.toString()),
        ),
      );
    }
  }

  /// Delete a message
  Future<void> deleteMessage(String messageId) async {
    try {
      await _database.delete(
        'messages',
        where: 'id = ?',
        whereArgs: [messageId],
      );

      // Remove from cache
      for (final conversationId in _messageCache.keys) {
        _messageCache[conversationId]!.removeWhere((m) => m.id == messageId);
        _messagesController.add(_messageCache[conversationId]!);
      }
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        AppError.database(
          message: 'Failed to delete message: $e',
          stackTrace: stackTrace,
          originalException: e is Exception ? e : Exception(e.toString()),
        ),
      );
    }
  }

  /// Search messages
  Future<List<Message>> searchMessages(
    String query, {
    String? conversationId,
  }) async {
    try {
      String sql = '''
        SELECT * FROM messages 
        WHERE text LIKE ?
      ''';
      final List<dynamic> args = ['%$query%'];

      if (conversationId != null) {
        sql += ' AND conversation_id = ?';
        args.add(conversationId);
      }

      sql += ' ORDER BY timestamp DESC LIMIT 50';

      final results = await _database.query(sql, args);
      return results.map((json) => Message.fromJson(json)).toList();
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        AppError.database(
          message: 'Failed to search messages: $e',
          stackTrace: stackTrace,
          originalException: e is Exception ? e : Exception(e.toString()),
        ),
      );
      return [];
    }
  }

  /// Get messages for a conversation
  List<Message> getMessages(String conversationId) {
    return _messageCache[conversationId] ?? [];
  }

  /// Get recent conversations (only with friends)
  Future<List<Map<String, dynamic>>> getRecentConversations(
    String userId,
  ) async {
    try {
      final results = await _database.query(
        '''
        SELECT 
          conversation_id,
          MAX(timestamp) as last_message_time,
          COUNT(*) as message_count,
          (SELECT text FROM messages m2 WHERE m2.conversation_id = m1.conversation_id ORDER BY timestamp DESC LIMIT 1) as last_message,
          (SELECT sender_id FROM messages m2 WHERE m2.conversation_id = m1.conversation_id ORDER BY timestamp DESC LIMIT 1) as last_sender_id
        FROM messages m1
        WHERE sender_id = ? OR receiver_id = ?
        GROUP BY conversation_id
        ORDER BY last_message_time DESC
        ''',
        [userId, userId],
      );

      // Filter conversations to only include friends
      final validConversations = <Map<String, dynamic>>[];
      for (final conversation in results) {
        final conversationId = conversation['conversation_id'] as String;
        if (await canAccessConversation(conversationId, userId)) {
          validConversations.add(conversation);
        }
      }

      return validConversations;
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        AppError.database(
          message: 'Failed to get recent conversations: $e',
          stackTrace: stackTrace,
          originalException: e is Exception ? e : Exception(e.toString()),
        ),
      );
      return [];
    }
  }

  /// Get unread message count for a conversation
  Future<int> getUnreadCount(String conversationId, String userId) async {
    try {
      final results = await _database.query(
        '''
        SELECT COUNT(*) as count FROM messages 
        WHERE conversation_id = ? 
        AND receiver_id = ? 
        AND status != ?
        ''',
        [conversationId, userId, MessageStatus.read.name],
      );

      return results.isNotEmpty ? (results.first['count'] as int) : 0;
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        AppError.database(
          message: 'Failed to get unread count: $e',
          stackTrace: stackTrace,
          originalException: e is Exception ? e : Exception(e.toString()),
        ),
      );
      return 0;
    }
  }

  /// Create or get conversation ID for two users
  String getConversationId(String userId1, String userId2) {
    final sortedIds = [userId1, userId2]..sort();
    return 'conv_${sortedIds[0]}_${sortedIds[1]}';
  }

  void dispose() {
    _messagesController.close();
    _newMessageController.close();
    _networkStateController.close();
  }
}
