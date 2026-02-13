import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/database/database_manager.dart';
import '../core/error/error_handler.dart';
import '../core/models/app_error.dart';
import '../models/friend_model.dart';
import '../services/local_storage_service.dart';

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
}
