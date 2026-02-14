import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import '../models/user_model.dart' as app_user;
import '../models/message_model.dart';
import '../core/error/error_handler.dart';
import '../core/models/app_error.dart';
import '../utils/string_utils.dart';
import 'unified_storage_service.dart';

/// Supabase service for real-time messaging and user management
class SupabaseService {
  static SupabaseService? _instance;
  static SupabaseService get instance =>
      _instance ??= SupabaseService._internal();
  SupabaseService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  final ErrorHandler _errorHandler = ErrorHandler();

  // Stream controllers for real-time updates
  final StreamController<List<Message>> _messagesController =
      StreamController<List<Message>>.broadcast();

  Stream<List<Message>> get messagesStream => _messagesController.stream;

  /// Initialize Supabase connection
  Future<void> initialize() async {
    try {
      // Supabase is initialized in main.dart
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        AppError.service(
          message: 'Failed to initialize Supabase: $e',
          stackTrace: stackTrace,
          originalException: e is Exception ? e : Exception(e.toString()),
        ),
      );
    }
  }

  /// Create user profile in profiles table
  Future<app_user.User?> createUserProfile(app_user.User user) async {
    try {
      final response = await _supabase
          .from('profiles')
          .upsert(user.toDatabaseJson())
          .select()
          .single();

      return app_user.User.fromJson(response);
    } catch (e, stackTrace) {
      debugPrint('❌ Supabase profile creation failed: $e');
      _errorHandler.handleError(
        AppError.service(
          message: 'Failed to create profile: $e',
          stackTrace: stackTrace,
          originalException: e is Exception ? e : Exception(e.toString()),
        ),
      );
      return null;
    }
  }

  /// Update existing user profile with specific fields
  Future<app_user.User?> updateUserProfile({
    required String userId,
    String? fullName,
    String? handle,
    String? bio,
    String? avatar,
    String? profilePicture,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (fullName != null) updates['full_name'] = fullName;
      if (handle != null) updates['handle'] = handle;
      if (bio != null) updates['bio'] = bio;
      if (avatar != null) updates['avatar'] = avatar;
      if (profilePicture != null) updates['profile_picture'] = profilePicture;

      final response = await _supabase
          .from('profiles')
          .update(updates)
          .eq('id', userId)
          .select()
          .single();

      return app_user.User.fromJson(response);
    } catch (e, stackTrace) {
      debugPrint('❌ Supabase profile update failed: $e');
      _errorHandler.handleError(
        AppError.service(
          message: 'Failed to update profile: $e',
          stackTrace: stackTrace,
          originalException: e is Exception ? e : Exception(e.toString()),
        ),
      );
      return null;
    }
  }

  /// Verify user exists in Supabase profiles
  Future<bool> verifyUserExists(String userId) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('id')
          .eq('id', userId)
          .maybeSingle();
      return response != null;
    } catch (e) {
      debugPrint('❌ Failed to verify user exists: $e');
      return false;
    }
  }

  /// Get current user profile
  Future<app_user.User?> getCurrentUserProfile() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;

      return getUserProfile(user.id);
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        AppError.service(
          message: 'Failed to get current user: $e',
          stackTrace: stackTrace,
          originalException: e is Exception ? e : Exception(e.toString()),
        ),
      );
      return null;
    }
  }

  /// Get user profile by ID
  Future<app_user.User?> getUserProfile(String userId) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (response == null) return null;
      return app_user.User.fromJson(response);
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        AppError.service(
          message: 'Failed to get user profile: $e',
          stackTrace: stackTrace,
          originalException: e is Exception ? e : Exception(e.toString()),
        ),
      );
      return null;
    }
  }

  /// Search users globally
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id ?? '';

      if (query.isEmpty) {
        // If query is empty, return discover users using the optimized JOIN
        return await getDiscoverUsers(currentUserId);
      }

      // Search with JOIN to get follow status
      final response = await _supabase
          .from('profiles')
          .select('*, follows!following_id(follower_id)')
          .or(
            'handle.ilike.%$query%,virtual_number.ilike.%$query%,full_name.ilike.%$query%',
          )
          .eq('is_discoverable', true)
          .neq('id', currentUserId)
          .limit(20);

      return (response as List).map((profile) {
        final profileMap = Map<String, dynamic>.from(profile);
        final followsList = profileMap['follows'] as List?;

        profileMap['isFollowing'] =
            followsList != null &&
            followsList.any((f) => f['follower_id'] == currentUserId);

        profileMap.remove('follows');
        return profileMap;
      }).toList();
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        AppError.service(
          message: 'Failed to search users: $e',
          stackTrace: stackTrace,
          originalException: e is Exception ? e : Exception(e.toString()),
        ),
      );
      return [];
    }
  }

  /// Update message status
  Future<void> updateMessageStatus(
    String messageId,
    MessageStatus status,
  ) async {
    try {
      await _supabase
          .from('messages')
          .update({'status': status.name})
          .eq('id', messageId);

      debugPrint('✅ Message status updated to ${status.name}: $messageId');
    } catch (e, stackTrace) {
      debugPrint('❌ Failed to update message status: $e');
      _errorHandler.handleError(
        AppError.service(
          message: 'Failed to update message status: $e',
          stackTrace: stackTrace,
          originalException: e is Exception ? e : Exception(e.toString()),
        ),
      );
    }
  }

  /// Send message
  Future<Message?> sendMessage({
    String? conversationId,
    String? senderId,
    String? receiverId,
    String? text,
    MessageType type = MessageType.text,
    Message? messageObject,
  }) async {
    try {
      debugPrint('📤 Attempting to send message...');

      Message message;
      if (messageObject != null) {
        message = messageObject;
      } else {
        if (conversationId == null ||
            senderId == null ||
            receiverId == null ||
            text == null) {
          throw Exception("Missing required fields for creating a new message");
        }
        message = Message.create(
          text: text,
          senderId: senderId,
          receiverId: receiverId,
          conversationId: conversationId,
          type: type,
        );
      }

      debugPrint('   Sender: ${message.senderId}');
      debugPrint('   Receiver: ${message.receiverId}');
      debugPrint('   Conversation: ${message.conversationId}');
      debugPrint('   Text: ${message.text}');
      debugPrint('   ID: ${message.id}');

      // Use the status provided in the message object (could be sent, delivered, or read)
      final sentMessage = message;

      final messageData = sentMessage.toJson();
      // Map to snake_case for Supabase
      final dbData = {
        'id': messageData['id'], // Explicitly include ID to ensure consistency
        'text': messageData['text'],
        'sender_id': messageData['senderId'],
        'receiver_id': messageData['receiverId'],
        'conversation_id': messageData['conversationId'],
        'timestamp': messageData['timestamp'],
        'is_offline': messageData['isOffline'],
        'status': messageData['status'],
        'type': messageData['type'],
        'message_hash': messageData['messageHash'],
        'media_url': messageData['mediaUrl'],
        'metadata': messageData['metadata'],
      };

      debugPrint('📤 Inserting message to Supabase...');
      final response = await _supabase
          .from('messages')
          .insert(dbData)
          .select()
          .single();
      debugPrint('✅ Message sent successfully: ${response['id']}');

      // Return the message with the status updated to sent

      // Track network usage
      final size =
          (text?.length ?? 0) +
          (messageData['mediaUrl'] != null
              ? 1024 * 1024
              : 0); // Estimate 1MB for media if URL exists
      await UnifiedStorageService.incrementNetworkUsage(
        messageData['mediaUrl'] != null ? 'media' : 'messages',
        size,
        isSent: true,
      );

      return sentMessage;
    } catch (e, stackTrace) {
      debugPrint('❌ Failed to send message: $e');
      debugPrint('Stack trace: $stackTrace');
      _errorHandler.handleError(
        AppError.service(
          message: 'Failed to send message: $e',
          stackTrace: stackTrace,
          originalException: e is Exception ? e : Exception(e.toString()),
        ),
      );
      return null;
    }
  }

  /// Listen to messages in real-time
  RealtimeChannel listenToMessages(
    String conversationId,
    Function(List<Message>) onUpdate,
  ) {
    return _supabase
        .channel('public:messages:conversation_id=eq.$conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) async {
            // Re-fetch all messages for that conversation or handle the payload
            final response = await _supabase
                .from('messages')
                .select()
                .eq('conversation_id', conversationId)
                .order('timestamp', ascending: false)
                .limit(
                  50,
                ); // Only load last 50 messages initially (WhatsApp style)

            final messages = (response as List)
                .map(
                  (data) => Message.fromJson({
                    'id': data['id'],
                    'text': data['text'],
                    'senderId': data['sender_id'],
                    'receiverId': data['receiver_id'],
                    'conversationId': data['conversation_id'],
                    'timestamp': data['timestamp'],
                    'isOffline': data['is_offline'],
                    'status': data['status'],
                    'type': data['type'],
                    'messageHash': data['message_hash'],
                    'mediaUrl': data['media_url'],
                    'metadata': data['metadata'],
                  }),
                )
                .toList()
                .reversed
                .toList(); // Reverse because we fetched latest 50 in descending order

            onUpdate(messages);
          },
        )
        .subscribe();
  }

  /// Listen to ALL messages for the current user (for Lobby updates)
  RealtimeChannel listenToAllUserMessages(
    String userId,
    Function(Map<String, dynamic> payload) onEvent,
  ) {
    return _supabase
        .channel('public:messages:global:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            final newRecord = payload.newRecord;
            if (newRecord.isEmpty) return;

            final senderId = newRecord['sender_id'];
            final receiverId = newRecord['receiver_id'];

            // Only process if the current user is involved
            if (senderId == userId || receiverId == userId) {
              // Track received messages (network usage)
              if (payload.eventType == PostgresChangeEvent.insert &&
                  receiverId == userId) {
                final text = newRecord['text'] as String? ?? '';
                final size =
                    text.length +
                    (newRecord['media_url'] != null ? 1024 * 1024 : 0);
                UnifiedStorageService.incrementNetworkUsage(
                  newRecord['media_url'] != null ? 'media' : 'messages',
                  size,
                  isSent: false,
                );
              }
              onEvent({
                'eventType': payload.eventType.name,
                'record': newRecord,
              });
            }
          },
        )
        .subscribe();
  }

  Future<List<Map<String, dynamic>>> getUserConversations(String userId) async {
    try {
      // 1. Try fetching from user_conversations table (Persistent Lobby)
      try {
        final response = await _supabase
            .from('user_conversations')
            .select(
              '*, friend:profiles!friend_id(id, full_name, handle, profile_picture, avatar, status, is_verified, virtual_number)',
            )
            .eq('user_id', userId)
            .eq('is_deleted', false)
            .order('last_message_time', ascending: false);

        if ((response as List).isNotEmpty) {
          print(
            '✅ Found ${response.length} conversations in user_conversations for $userId',
          );
          return (response as List).map((data) {
            final friend = data['friend'];
            return {
              'id': data['conversation_id'],
              'lastMessage': data['last_message_text'],
              'lastMessageTime': data['last_message_time'],
              'ephemeralTimer': data['ephemeral_timer'] ?? '24_hours',
              'otherUser': {
                'id': friend['id'],
                'name': friend['full_name'] ?? 'Unknown',
                'handle': friend['handle'] ?? 'unknown',
                'avatar': friend['avatar'],
                'profilePicture': friend['profile_picture'],
                'status': friend['status'],
                'is_verified': friend['is_verified'] ?? false,
                'virtualNumber': friend['virtual_number'] ?? '',
              },
            };
          }).toList();
        }
      } catch (e) {
        debugPrint(
          'ℹ️ user_conversations table not found or error, falling back to messages: $e',
        );
      }

      // 2. Fallback to extracting from messages table
      final response = await _supabase
          .from('messages')
          .select(
            '*, sender:profiles!sender_id(id, full_name, handle, profile_picture, avatar, status), receiver:profiles!receiver_id(id, full_name, handle, profile_picture, avatar, status)',
          )
          .or('sender_id.eq.$userId,receiver_id.eq.$userId')
          .order('timestamp', ascending: false)
          .limit(100);

      final conversations = <String, Map<String, dynamic>>{};
      for (final data in response as List) {
        final convId = data['conversation_id'];
        if (convId == null || conversations.containsKey(convId)) continue;

        final isSender = data['sender_id'] == userId;
        final otherProfile = isSender ? data['receiver'] : data['sender'];

        if (otherProfile == null) continue;

        conversations[convId] = {
          'id': convId,
          'lastMessage': data['text'],
          'lastMessageTime': data['timestamp'],
          'ephemeralTimer': '24_hours',
          'otherUser': {
            'id': otherProfile['id'],
            'name': otherProfile['full_name'] ?? 'Unknown User',
            'handle': otherProfile['handle'] ?? 'unknown',
            'avatar': otherProfile['avatar'],
            'profilePicture': otherProfile['profile_picture'],
            'status': otherProfile['status'],
          },
        };
      }
      return conversations.values.toList();
    } catch (e, stackTrace) {
      debugPrint('❌ Failed to get conversations: $e');
      return [];
    }
  }

  /// Update ephemeral timer for a conversation
  Future<void> updateConversationTimer(String friendId, String timer) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Validate IDs are UUIDs since the database expects UUIDs
      if (!StringUtils.isUuid(userId) || !StringUtils.isUuid(friendId)) {
        debugPrint(
          '⚠️ Skipping timer update: userId or friendId is not a valid UUID ($userId, $friendId)',
        );
        return;
      }

      final sortedIds = [userId, friendId]..sort();
      final conversationId = 'conv_${sortedIds[0]}_${sortedIds[1]}';

      // Update for both directions (sender -> receiver and vice versa)
      // This ensures both users see the same timer setting
      await _supabase.from('user_conversations').upsert([
        {
          'user_id': userId,
          'friend_id': friendId,
          'conversation_id': conversationId,
          'ephemeral_timer': timer,
        },
        {
          'user_id': friendId,
          'friend_id': userId,
          'conversation_id': conversationId,
          'ephemeral_timer': timer,
        },
      ], onConflict: 'user_id,friend_id');
      debugPrint('✅ Ephemeral timer updated to $timer for $conversationId');
    } catch (e) {
      debugPrint('❌ Error updating conversation timer: $e');
    }
  }

  Future<String> getConversationTimer(String friendId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return '24_hours';

      // Validate IDs are UUIDs since the database expects UUIDs
      if (!StringUtils.isUuid(userId) || !StringUtils.isUuid(friendId)) {
        debugPrint(
          '⚠️ Skipping timer fetch: userId or friendId is not a valid UUID ($userId, $friendId)',
        );
        return '24_hours';
      }

      final response = await _supabase
          .from('user_conversations')
          .select('ephemeral_timer')
          .eq('user_id', userId)
          .eq('friend_id', friendId)
          .maybeSingle();

      if (response != null && response['ephemeral_timer'] != null) {
        return response['ephemeral_timer'] as String;
      }
    } catch (e) {
      debugPrint('Error fetching conversation timer: $e');
    }
    return '24_hours'; // Default
  }

  /// Delete a conversation from the lobby (intentional deletion)
  Future<void> deleteConversation(String friendId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      await _supabase
          .from('user_conversations')
          .update({'is_deleted': true})
          .eq('user_id', userId)
          .eq('friend_id', friendId);
    } catch (e) {
      debugPrint('Error deleting conversation: $e');
    }
  }

  /// Remove a realtime channel
  Future<void> removeChannel(RealtimeChannel channel) async {
    await _supabase.removeChannel(channel);
  }

  /// Get nearby users (simulated based on discovery settings)
  Future<List<app_user.User>> getNearbyUsers() async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('is_discoverable', true)
          .neq('id', currentUserId ?? '')
          .limit(10);

      return (response as List)
          .map((data) => app_user.User.fromJson(data))
          .toList();
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        AppError.service(
          message: 'Failed to get nearby users: $e',
          stackTrace: stackTrace,
          originalException: e is Exception ? e : Exception(e.toString()),
        ),
      );
      return [];
    }
  }

  /// Get discover users (all users except self, with follow status)
  Future<List<Map<String, dynamic>>> getDiscoverUsers(
    String currentUserId,
  ) async {
    try {
      debugPrint('🔍 Fetching discover users for $currentUserId using Join');

      // Using a LEFT JOIN to fetch profiles and their follow status for the current user
      // This is atomic and ensures the UI always has the latest DB state for each user
      final response = await _supabase
          .from('profiles')
          .select('*, follows!following_id(follower_id)')
          .eq('is_discoverable', true)
          .neq('id', currentUserId)
          .limit(50);

      debugPrint('🔍 Supabase returned ${response.length} profiles');

      // Merge follow status into profile data
      return (response as List).map((profile) {
        final profileMap = Map<String, dynamic>.from(profile);
        final followsList = profileMap['follows'] as List?;

        // isFollowing is true if any follow record for this user has the currentUserId as follower
        profileMap['isFollowing'] =
            followsList != null &&
            followsList.any((f) => f['follower_id'] == currentUserId);

        // Clean up the joined data for the UI
        profileMap.remove('follows');

        return profileMap;
      }).toList();
    } catch (e) {
      debugPrint('❌ Failed to get discover users using join: $e');
      return [];
    }
  }

  /// Get suggested users
  Future<List<app_user.User>> getSuggestedUsers() async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('is_discoverable', true)
          .neq('id', currentUserId ?? '')
          .limit(10);

      return (response as List)
          .map((data) => app_user.User.fromJson(data))
          .toList();
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        AppError.service(
          message: 'Failed to get suggested users: $e',
          stackTrace: stackTrace,
          originalException: e is Exception ? e : Exception(e.toString()),
        ),
      );
      return [];
    }
  }

  /// Get feed posts
  Future<List<Map<String, dynamic>>> getFeedPosts() async {
    try {
      final response = await _supabase
          .from('posts')
          .select('*, author:profiles(*)')
          .order('created_at', ascending: false)
          .limit(20);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        AppError.service(
          message: 'Failed to get feed posts: $e',
          stackTrace: stackTrace,
          originalException: e is Exception ? e : Exception(e.toString()),
        ),
      );
      return [];
    }
  }

  /// Create a post
  Future<bool> createPost({
    required String authorId,
    String? caption,
    String? imageUrl,
  }) async {
    try {
      await _supabase.from('posts').insert({
        'author_id': authorId,
        'caption': caption,
        'image_url': imageUrl,
      });
      return true;
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        AppError.service(
          message: 'Failed to create post: $e',
          stackTrace: stackTrace,
          originalException: e is Exception ? e : Exception(e.toString()),
        ),
      );
      return false;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
      print('✅ Supabase user signed out successfully');
    } catch (e) {
      print('❌ Supabase signout failed: $e');
      throw Exception('Failed to sign out from Supabase: $e');
    }
  }

  /// Mark all messages in a conversation as read
  Future<void> markConversationAsRead(
    String conversationId,
    String otherUserId,
  ) async {
    try {
      await _supabase
          .from('messages')
          .update({'status': MessageStatus.read.name})
          .eq('conversation_id', conversationId)
          .eq('sender_id', otherUserId)
          .neq('status', MessageStatus.read.name);
      debugPrint('✅ Conversation $conversationId marked as read');
    } catch (e) {
      debugPrint('❌ Error marking conversation as read: $e');
    }
  }

  /// Mark messages as delivered for a specific user
  Future<void> markMessagesAsDelivered(String userId) async {
    try {
      await _supabase
          .from('messages')
          .update({'status': MessageStatus.delivered.name})
          .eq('receiver_id', userId)
          .eq('status', MessageStatus.sent.name);
      debugPrint('✅ Messages marked as delivered for user $userId');
    } catch (e) {
      debugPrint('❌ Error marking messages as delivered: $e');
    }
  }

  /// Update user online/offline status in profiles table
  Future<void> updateUserStatus(String status) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _supabase
          .from('profiles')
          .update({
            'status': status,
            'last_seen': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);
      debugPrint('✅ User status updated to $status');
    } catch (e) {
      debugPrint('❌ Error updating user status: $e');
    }
  }

  /// Block a user
  Future<void> blockUser(String blockedId) async {
    final blockerId = _supabase.auth.currentUser?.id;
    if (blockerId == null) return;

    try {
      await _supabase.from('blocked_users').insert({
        'blocker_id': blockerId,
        'blocked_id': blockedId,
      });
      debugPrint('✅ User $blockedId blocked successfully');
    } catch (e) {
      debugPrint('❌ Failed to block user: $e');
      // If table doesn't exist, we might want to throw a specific error or handle it
      throw Exception('Failed to block user: $e');
    }
  }

  /// Unblock a user
  Future<void> unblockUser(String blockedId) async {
    final blockerId = _supabase.auth.currentUser?.id;
    if (blockerId == null) return;

    try {
      await _supabase
          .from('blocked_users')
          .delete()
          .eq('blocker_id', blockerId)
          .eq('blocked_id', blockedId);
      debugPrint('✅ User $blockedId unblocked successfully');
    } catch (e) {
      debugPrint('❌ Failed to unblock user: $e');
      throw Exception('Failed to unblock user: $e');
    }
  }

  /// Get blocked users IDs
  Future<List<String>> getBlockedUserIds() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final response = await _supabase
          .from('blocked_users')
          .select('blocked_id')
          .eq('blocker_id', userId);

      return (response as List).map((e) => e['blocked_id'] as String).toList();
    } catch (e) {
      debugPrint(
        'ℹ️ Failed to fetch blocked users (table might be missing): $e',
      );
      return [];
    }
  }

  /// Delete user account
  Future<void> deleteUserAccount({bool permanent = false}) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      if (permanent) {
        // Permanent delete: remove from profiles table
        await _supabase.from('profiles').delete().eq('id', userId);
        debugPrint('✅ User account permanently deleted');
      } else {
        // Soft delete: update status to deleted
        await updateUserStatus(app_user.UserStatus.deleted.name);
        debugPrint('✅ User account marked as deleted');
      }

      // Sign out after deletion/deactivation
      await _supabase.auth.signOut();
    } catch (e) {
      debugPrint('❌ Error deleting user account: $e');
      throw Exception('Failed to delete account: $e');
    }
  }

  void dispose() {
    _messagesController.close();
  }
}
