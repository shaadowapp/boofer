import 'dart:async';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../core/database/database_manager.dart';
import '../core/models/app_error.dart';
import '../core/error/error_handler.dart';
import '../models/message_model.dart';
import '../models/network_state.dart';
import '../services/follow_service.dart';
import '../services/supabase_service.dart';
import '../services/user_service.dart';
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
  })  : _database = database,
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
        // Fetch last cleared at to filter old messages
        String? lastClearedAt;
        try {
          final settings = await _supabaseService.getConversationSettings(
              conversationId, userId);
          lastClearedAt = settings?['last_cleared_at'];
        } catch (e) {
          debugPrint('⚠️ Error fetching last_cleared_at: $e');
        }

        _supabaseService.listenToMessages(conversationId, (updateList) async {
          if (updateList.isEmpty) return;
          final updatedMsg = updateList.first;

          // Filter out messages older than last_cleared_at
          if (lastClearedAt != null) {
            final clearTime = DateTime.parse(lastClearedAt);
            if (updatedMsg.timestamp.isBefore(clearTime) ||
                updatedMsg.timestamp.isAtSameMomentAs(clearTime)) {
              return;
            }
          }

          final existingMessages = _messageCache[conversationId] ?? [];
          final index = existingMessages.indexWhere(
            (m) => m.id == updatedMsg.id,
          );

          List<Message> newMessagesList;
          if (index != -1) {
            // Update existing message (e.g. status changed to read)
            final oldMsg = existingMessages[index];
            newMessagesList = List.from(existingMessages);
            newMessagesList[index] = updatedMsg.copyWith(
              text:
                  (updatedMsg.text == '[Encrypted]' || updatedMsg.text.isEmpty)
                      ? oldMsg.text
                      : updatedMsg.text,
            );
          } else {
            // New message
            newMessagesList = List.from(existingMessages)..add(updatedMsg);
            newMessagesList.sort((a, b) => a.timestamp.compareTo(b.timestamp));
          }

          _messageCache[conversationId] = newMessagesList;
          _messagesController.add(newMessagesList);

          // Incremental sync
          _syncToLocal([updatedMsg]);
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
    MessageStatus? status,
    Map<String, dynamic>? metadata,
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

      // 1. Ensure sender exists in local database (satisfies FOREIGN KEY constraint)
      final currentUser = await UserService.getCurrentUser();
      if (currentUser != null && currentUser.id == senderId) {
        await _database.insert(
          'users',
          currentUser.toDatabaseJson(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      // 2. Save to local database with PLAINTEXT first (avoids race condition with listener)
      final message = Message.create(
        text: content,
        senderId: senderId,
        receiverId: receiverId,
        conversationId: conversationId,
        type: type,
        mediaUrl: mediaUrl,
        status: status ?? MessageStatus.pending,
        metadata: metadata,
      );

      await _database.insert(
          'messages',
          {
            'id': message.id,
            'text': message.text,
            'sender_id': message.senderId,
            'receiver_id': message.receiverId,
            'conversation_id': message.conversationId,
            'timestamp': message.timestamp.toIso8601String(),
            'is_offline': message.isOffline ? 1 : 0,
            'status': message.status.name,
            'type': message.type.name,
            'message_hash': message.messageHash,
            'updated_at': DateTime.now().toIso8601String(),
            'created_at': message.timestamp.toIso8601String(),
            'is_encrypted': message.isEncrypted ? 1 : 0,
            'encrypted_content': message.encryptedContent != null
                ? jsonEncode(message.encryptedContent)
                : null,
            'encryption_version': message.encryptionVersion,
            'metadata':
                message.metadata != null ? jsonEncode(message.metadata) : null,
          },
          conflictAlgorithm: ConflictAlgorithm.replace);

      Message messageToSave = message;

      // 2. Send to Supabase if receiver is set
      if (receiverId != null) {
        final sentMessage = await _supabaseService.sendMessage(
          conversationId: conversationId,
          senderId: senderId,
          receiverId: receiverId,
          text: content,
          type: type,
          messageObject: message,
        );

        if (sentMessage != null) {
          messageToSave = sentMessage;
        }
      }

      // 3. Update local database if status/metadata changed after sending
      await _database.insert(
          'messages',
          {
            'id': messageToSave.id,
            'text': message.text, // ALWAYS keep local plaintext for sender
            'sender_id': messageToSave.senderId,
            'receiver_id': messageToSave.receiverId,
            'conversation_id': messageToSave.conversationId,
            'timestamp': messageToSave.timestamp.toIso8601String(),
            'is_offline': messageToSave.isOffline ? 1 : 0,
            'status': messageToSave.status.name,
            'type': messageToSave.type.name,
            'message_hash': messageToSave.messageHash,
            'updated_at': DateTime.now().toIso8601String(),
            'created_at': messageToSave.timestamp.toIso8601String(),
            'is_encrypted': messageToSave.isEncrypted ? 1 : 0,
            'encrypted_content': messageToSave.encryptedContent != null
                ? jsonEncode(messageToSave.encryptedContent)
                : null,
            'encryption_version': messageToSave.encryptionVersion,
            'metadata': messageToSave.metadata != null
                ? jsonEncode(messageToSave.metadata)
                : null,
          },
          conflictAlgorithm: ConflictAlgorithm.replace);

      // Update cache
      if (_messageCache.containsKey(conversationId)) {
        _messageCache[conversationId]!.add(messageToSave);
      } else {
        _messageCache[conversationId] = [messageToSave];
      }

      // Notify listeners
      _messagesController.add(_messageCache[conversationId]!);
      _newMessageController.add(messageToSave);

      return messageToSave;
    } catch (e, stackTrace) {
      // CRITICAL: Rethrow security/encryption errors
      final errorStr = e.toString();
      if (errorStr.contains('Encryption failed') ||
          errorStr.contains('SECURITY ERROR') ||
          errorStr.contains('Recipient has not enabled E2EE')) {
        rethrow;
      }

      _errorHandler.handleError(
        AppError.database(
          message: 'Failed to send message: $e',
          stackTrace: stackTrace,
          originalException: e is Exception ? e : Exception(e.toString()),
        ),
      );
      rethrow;
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

      // Update Supabase status
      await _supabaseService.updateMessageStatus(messageId, MessageStatus.read);
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
          (SELECT sender_id FROM messages m2 WHERE m2.conversation_id = m1.conversation_id ORDER BY timestamp DESC LIMIT 1) as last_sender_id,
          (SELECT status FROM messages m2 WHERE m2.conversation_id = m1.conversation_id ORDER BY timestamp DESC LIMIT 1) as last_status
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

  Future<void> _syncToLocal(List<Message> messages) async {
    for (final m in messages) {
      // 1. If remote message is encrypted, check if we already have plaintext locally
      String textToSave = m.text;
      if (textToSave == '[Encrypted]' || textToSave.isEmpty) {
        final existing = await _database.query(
          'SELECT text FROM messages WHERE id = ?',
          [m.id],
        );
        if (existing.isNotEmpty) {
          final localText = existing.first['text'] as String;
          if (localText != '[Encrypted]' && localText.isNotEmpty) {
            textToSave = localText; // Keep local plaintext
          }
        }
      }

      // 2. Upsert into local database
      await _database.insert(
          'messages',
          {
            'id': m.id,
            'text': textToSave,
            'sender_id': m.senderId,
            'receiver_id': m.receiverId,
            'conversation_id': m.conversationId,
            'timestamp': m.timestamp.toIso8601String(),
            'status': m.status.name,
            'is_offline': 0,
            'type': m.type.name,
            'is_encrypted': m.isEncrypted ? 1 : 0,
            'encrypted_content': m.encryptedContent != null
                ? jsonEncode(m.encryptedContent)
                : null,
            'encryption_version': m.encryptionVersion,
            'updated_at': DateTime.now().toIso8601String(),
            'created_at': m.timestamp.toIso8601String(),
            'metadata': m.metadata != null ? jsonEncode(m.metadata) : null,
          },
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  /// Get message text from local database by ID
  Future<String?> getMessageText(String messageId) async {
    try {
      final results = await _database.query(
        'SELECT text FROM messages WHERE id = ?',
        [messageId],
      );
      if (results.isNotEmpty) {
        return results.first['text'] as String?;
      }
    } catch (e) {
      debugPrint('Error getting message text: $e');
    }
    return null;
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
