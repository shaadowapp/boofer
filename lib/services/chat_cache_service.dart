import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/database/database_manager.dart';
import '../core/error/error_handler.dart';
import '../core/models/app_error.dart';
import '../models/friend_model.dart';
import '../services/local_storage_service.dart';
import 'package:sqflite/sqflite.dart';

/// WhatsApp-style chat cache service for offline-first architecture
/// Implements stale-while-revalidate pattern to minimize bandwidth usage
class ChatCacheService {
  static ChatCacheService? _instance;
  static ChatCacheService get instance =>
      _instance ??= ChatCacheService._internal();

  final DatabaseManager _database = DatabaseManager.instance;
  final ErrorHandler _errorHandler = ErrorHandler();

  ChatCacheService._internal();

  // Cache validity duration (24 hours)
  static const Duration _cacheValidityDuration = Duration(hours: 24);

  // Keys for tracking last sync times
  static const String _lastFriendsSyncKey = 'last_friends_sync';
  static const String _lastConversationsSyncKey = 'last_conversations_sync';
  static const String _lastDiscoverSyncKey = 'last_discover_sync';
  static const String _lastStartChatSyncKey = 'last_start_chat_sync';

  // Throttle duration for user-triggered refreshes (e.g., 2 minutes)
  static const Duration refreshThrottleDuration = Duration(seconds: 5);

  /// Check if discover cache is still valid
  Future<bool> isDiscoverCacheValid() async {
    try {
      final lastSyncStr = await LocalStorageService.getString(
        _lastDiscoverSyncKey,
      );
      if (lastSyncStr == null) return false;

      final lastSync = DateTime.parse(lastSyncStr);
      final now = DateTime.now();

      return now.difference(lastSync) < _cacheValidityDuration;
    } catch (e) {
      debugPrint('Error checking discover cache validity: $e');
      return false;
    }
  }

  /// Check if friends cache is still valid
  Future<bool> isFriendsCacheValid() async {
    try {
      final lastSyncStr = await LocalStorageService.getString(
        _lastFriendsSyncKey,
      );
      if (lastSyncStr == null) return false;

      final lastSync = DateTime.parse(lastSyncStr);
      final now = DateTime.now();

      return now.difference(lastSync) < _cacheValidityDuration;
    } catch (e) {
      debugPrint('Error checking cache validity: $e');
      return false;
    }
  }

  /// Get cached friends list from local database
  Future<List<Friend>> getCachedFriends(String userId) async {
    try {
      final results = await _database.query(
        '''
        SELECT * FROM cached_friends 
        WHERE user_id = ? 
        ORDER BY last_message_time DESC
        ''',
        [userId],
      );

      return results.map((json) => Friend.fromJson(json)).toList();
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        AppError.database(
          message: 'Failed to get cached friends: $e',
          stackTrace: stackTrace,
          originalException: e is Exception ? e : Exception(e.toString()),
        ),
      );
      return [];
    }
  }

  /// Cache friends list to local database
  Future<void> cacheFriends(String userId, List<Friend> friends) async {
    try {
      // Clear old cache for this user
      await _database.delete(
        'cached_friends',
        where: 'user_id = ?',
        whereArgs: [userId],
      );

      // Insert new cache
      for (final friend in friends) {
        await _database.insert('cached_friends', {
          'user_id': userId,
          'friend_id': friend.id,
          'name': friend.name,
          'handle': friend.handle,
          'virtual_number': friend.virtualNumber,
          'avatar': friend.avatar,
          'last_message': friend.lastMessage,
          'last_message_time': friend.lastMessageTime.toIso8601String(),
          'unread_count': friend.unreadCount,
          'is_online': friend.isOnline ? 1 : 0,
          'is_archived': friend.isArchived ? 1 : 0,
          'is_verified': friend.isVerified ? 1 : 0,
          'cached_at': DateTime.now().toIso8601String(),
        });
      }

      // Update last sync timestamp
      await LocalStorageService.setString(
        _lastFriendsSyncKey,
        DateTime.now().toIso8601String(),
      );

      debugPrint('✅ Cached ${friends.length} friends locally');
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        AppError.database(
          message: 'Failed to cache friends: $e',
          stackTrace: stackTrace,
          originalException: e is Exception ? e : Exception(e.toString()),
        ),
      );
    }
  }

  /// Get cached conversation metadata
  Future<Map<String, Map<String, dynamic>>> getCachedConversations(
    String userId,
  ) async {
    try {
      final results = await _database.query(
        '''
        SELECT * FROM cached_conversations 
        WHERE user_id = ?
        ''',
        [userId],
      );

      final conversations = <String, Map<String, dynamic>>{};
      for (final row in results) {
        conversations[row['friend_id'] as String] = {
          'lastMessage': row['last_message'],
          'lastMessageTime': row['last_message_time'],
          'unreadCount': row['unread_count'],
        };
      }

      return conversations;
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        AppError.database(
          message: 'Failed to get cached conversations: $e',
          stackTrace: stackTrace,
          originalException: e is Exception ? e : Exception(e.toString()),
        ),
      );
      return {};
    }
  }

  /// Cache conversation metadata
  Future<void> cacheConversations(
    String userId,
    Map<String, Map<String, dynamic>> conversations,
  ) async {
    try {
      // Clear old cache
      await _database.delete(
        'cached_conversations',
        where: 'user_id = ?',
        whereArgs: [userId],
      );

      // Insert new cache
      for (final entry in conversations.entries) {
        await _database.insert('cached_conversations', {
          'user_id': userId,
          'friend_id': entry.key,
          'last_message': entry.value['lastMessage'],
          'last_message_time': entry.value['lastMessageTime'],
          'unread_count': entry.value['unreadCount'] ?? 0,
          'cached_at': DateTime.now().toIso8601String(),
        });
      }

      // Update last sync timestamp
      await LocalStorageService.setString(
        _lastConversationsSyncKey,
        DateTime.now().toIso8601String(),
      );

      debugPrint('✅ Cached ${conversations.length} conversations locally');
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        AppError.database(
          message: 'Failed to cache conversations: $e',
          stackTrace: stackTrace,
          originalException: e is Exception ? e : Exception(e.toString()),
        ),
      );
    }
  }

  /// Clear all cached data for a user
  Future<void> clearCache(String userId) async {
    try {
      await _database.delete(
        'cached_friends',
        where: 'user_id = ?',
        whereArgs: [userId],
      );

      await _database.delete(
        'cached_conversations',
        where: 'user_id = ?',
        whereArgs: [userId],
      );

      await LocalStorageService.remove(_lastFriendsSyncKey);
      await LocalStorageService.remove(_lastConversationsSyncKey);

      debugPrint('✅ Cleared all chat cache for user: $userId');
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        AppError.database(
          message: 'Failed to clear cache: $e',
          stackTrace: stackTrace,
          originalException: e is Exception ? e : Exception(e.toString()),
        ),
      );
    }
  }

  /// Get last sync timestamp for friends
  Future<DateTime?> getLastFriendsSync() async {
    try {
      final lastSyncStr = await LocalStorageService.getString(
        _lastFriendsSyncKey,
      );
      if (lastSyncStr == null) return null;
      return DateTime.parse(lastSyncStr);
    } catch (e) {
      return null;
    }
  }

  /// Get last sync timestamp for conversations
  Future<DateTime?> getLastConversationsSync() async {
    try {
      final lastSyncStr = await LocalStorageService.getString(
        _lastConversationsSyncKey,
      );
      if (lastSyncStr == null) return null;
      return DateTime.parse(lastSyncStr);
    } catch (e) {
      return null;
    }
  }

  /// Check if messages cache is valid for a conversation
  Future<bool> isMessagesCacheValid(String conversationId) async {
    try {
      final lastSyncKey = 'last_messages_sync_$conversationId';
      final lastSyncStr = await LocalStorageService.getString(lastSyncKey);
      if (lastSyncStr == null) return false;

      final lastSync = DateTime.parse(lastSyncStr);
      final now = DateTime.now();

      // Messages cache is valid for 1 hour (more frequent than friends)
      return now.difference(lastSync) < const Duration(hours: 1);
    } catch (e) {
      debugPrint('Error checking messages cache validity: $e');
      return false;
    }
  }

  /// Get cached messages for a conversation
  Future<List<Map<String, dynamic>>> getCachedMessages(
    String conversationId,
  ) async {
    try {
      final results = await _database.query(
        '''
        SELECT * FROM messages 
        WHERE conversation_id = ? 
        ORDER BY timestamp DESC
        LIMIT 100
        ''',
        [conversationId],
      );

      debugPrint('✅ Loaded ${results.length} cached messages for conversation');
      return results;
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        AppError.database(
          message: 'Failed to get cached messages: $e',
          stackTrace: stackTrace,
          originalException: e is Exception ? e : Exception(e.toString()),
        ),
      );
      return [];
    }
  }

  /// Cache messages for a conversation
  Future<void> cacheMessages(
    String conversationId,
    List<Map<String, dynamic>> messages,
  ) async {
    try {
      if (messages.isEmpty) return;

      // Don't delete old messages, just insert/update new ones
      // This preserves message history
      for (final message in messages) {
        await _database.insert('messages', {
          ...message,
          'conversation_id': conversationId,
          'created_at':
              message['created_at'] ?? DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      // Update last sync timestamp for this conversation
      final lastSyncKey = 'last_messages_sync_$conversationId';
      await LocalStorageService.setString(
        lastSyncKey,
        DateTime.now().toIso8601String(),
      );

      debugPrint('💾 Cached ${messages.length} messages for conversation');
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        AppError.database(
          message: 'Failed to cache messages: $e',
          stackTrace: stackTrace,
          originalException: e is Exception ? e : Exception(e.toString()),
        ),
      );
    }
  }

  /// Clear cached messages for a conversation (e.g., when deleting chat)
  Future<void> clearConversationMessages(String conversationId) async {
    try {
      await _database.delete(
        'messages',
        where: 'conversation_id = ?',
        whereArgs: [conversationId],
      );

      final lastSyncKey = 'last_messages_sync_$conversationId';
      await LocalStorageService.remove(lastSyncKey);

      debugPrint('✅ Cleared cached messages for conversation: $conversationId');
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        AppError.database(
          message: 'Failed to clear conversation messages: $e',
          stackTrace: stackTrace,
          originalException: e is Exception ? e : Exception(e.toString()),
        ),
      );
    }
  }

  // --- Discover Cache Methods ---

  /// Get cached discover users
  Future<List<Map<String, dynamic>>> getCachedDiscoverUsers(
    String userId,
  ) async {
    try {
      final results = await _database.query(
        '''
        SELECT * FROM cached_discover_users 
        WHERE user_id = ? 
        ORDER BY name ASC
        ''',
        [userId],
      );

      return results;
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        AppError.database(
          message: 'Failed to get cached discover users: $e',
          stackTrace: stackTrace,
          originalException: e is Exception ? e : Exception(e.toString()),
        ),
      );
      return [];
    }
  }

  /// Cache discover users (Merges new users with existing cache)
  Future<void> cacheDiscoverUsers(
    String userId,
    List<Map<String, dynamic>> users,
  ) async {
    try {
      if (users.isEmpty) return;

      // Note: We do NOT clear the old cache anymore.
      // We upsert the new users into the bag (existing cache).

      // Insert/Update new users
      for (final user in users) {
        await _database.insert('cached_discover_users', {
          'user_id': userId,
          'profile_id': user['id'],
          'name': user['full_name'] ?? user['name'] ?? '',
          'handle': user['handle'],
          'bio': user['bio'],
          'avatar': user['profile_picture'] ?? user['avatar'],
          'is_following': user['isFollowing'] == true ? 1 : 0,
          'is_verified': user['is_verified'] == true || user['is_verified'] == 1
              ? 1
              : 0,
          'cached_at': DateTime.now().toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      // Update last sync timestamp
      await LocalStorageService.setString(
        _lastDiscoverSyncKey,
        DateTime.now().toIso8601String(),
      );

      debugPrint(
        '💾 Cached ${users.length} new/updated discover users locally',
      );
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        AppError.database(
          message: 'Failed to cache discover users: $e',
          stackTrace: stackTrace,
          originalException: e is Exception ? e : Exception(e.toString()),
        ),
      );
    }
  }

  /// Update follow status in cache
  Future<void> updateFollowStatusInCache(
    String userId,
    String profileId,
    bool isFollowing,
  ) async {
    try {
      await _database.update(
        'cached_discover_users',
        {'is_following': isFollowing ? 1 : 0},
        where: 'user_id = ? AND profile_id = ?',
        whereArgs: [userId, profileId],
      );
    } catch (e) {
      debugPrint('Failed to update follow status in cache: $e');
    }
  }

  /// Get last sync timestamp for discover users
  Future<DateTime?> getLastDiscoverSync() async {
    try {
      final lastSyncStr = await LocalStorageService.getString(
        _lastDiscoverSyncKey,
      );
      if (lastSyncStr == null) return null;
      return DateTime.parse(lastSyncStr);
    } catch (e) {
      return null;
    }
  }

  /// Check if a refresh action should be throttled
  Future<bool> isRefreshThrottled(String syncKey) async {
    try {
      final lastSyncStr = await LocalStorageService.getString(syncKey);
      if (lastSyncStr == null) return false;

      final lastSync = DateTime.parse(lastSyncStr);
      final now = DateTime.now();

      return now.difference(lastSync) < refreshThrottleDuration;
    } catch (e) {
      return false;
    }
  }

  /// Shortcut for discover refresh throttle
  Future<bool> isDiscoverRefreshThrottled() =>
      isRefreshThrottled(_lastDiscoverSyncKey);

  /// Shortcut for friends refresh throttle
  Future<bool> isFriendsRefreshThrottled() =>
      isRefreshThrottled(_lastFriendsSyncKey);

  // --- Start Chat Cache Methods ---

  /// Get cached start chat users
  Future<List<Map<String, dynamic>>> getCachedStartChatUsers(
    String userId,
  ) async {
    try {
      final results = await _database.query(
        '''
        SELECT * FROM cached_start_chat_users 
        WHERE user_id = ? 
        ORDER BY name ASC
        ''',
        [userId],
      );

      return results;
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        AppError.database(
          message: 'Failed to get cached start chat users: $e',
          stackTrace: stackTrace,
          originalException: e is Exception ? e : Exception(e.toString()),
        ),
      );
      return [];
    }
  }

  /// Cache start chat users
  Future<void> cacheStartChatUsers(
    String userId,
    List<Map<String, dynamic>> users,
  ) async {
    try {
      if (users.isEmpty) return;

      // Upsert new users
      for (final user in users) {
        await _database.insert('cached_start_chat_users', {
          'user_id': userId,
          'profile_id': user['id'],
          'name': user['full_name'] ?? user['name'] ?? '',
          'handle': user['handle'],
          'bio': user['bio'],
          'avatar': user['profile_picture'] ?? user['avatar'],
          'virtual_number': user['virtual_number'],
          'status': user['status'] ?? 'offline',
          'is_verified': user['is_verified'] == true || user['is_verified'] == 1
              ? 1
              : 0,
          'cached_at': DateTime.now().toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      // Update last sync timestamp
      await LocalStorageService.setString(
        _lastStartChatSyncKey,
        DateTime.now().toIso8601String(),
      );

      debugPrint('💾 Cached ${users.length} start chat users locally');
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        AppError.database(
          message: 'Failed to cache start chat users: $e',
          stackTrace: stackTrace,
          originalException: e is Exception ? e : Exception(e.toString()),
        ),
      );
    }
  }

  /// Shortcut for start chat refresh throttle
  Future<bool> isStartChatRefreshThrottled() =>
      isRefreshThrottled(_lastStartChatSyncKey);

  /// Check if start chat cache is fresh (<24h)
  Future<bool> isStartChatCacheValid() async {
    try {
      final lastSyncStr = await LocalStorageService.getString(
        _lastStartChatSyncKey,
      );
      if (lastSyncStr == null) return false;

      final lastSync = DateTime.parse(lastSyncStr);
      final now = DateTime.now();

      return now.difference(lastSync) < _cacheValidityDuration;
    } catch (e) {
      return false;
    }
  }
}
