import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import '../models/user_model.dart' as app_user;
import '../models/message_model.dart';
import '../core/error/error_handler.dart';
import '../core/models/app_error.dart';

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
  Future<List<app_user.User>> searchUsers(String query) async {
    try {
      if (query.isEmpty) {
        // If query is empty, return discover users (explore mode)
        final currentUserId = _supabase.auth.currentUser?.id ?? '';
        final discoverData = await getDiscoverUsers(currentUserId);
        return discoverData
            .map((data) => app_user.User.fromJson(data))
            .toList();
      }

      final response = await _supabase
          .from('profiles')
          .select()
          .or('handle.ilike.%$query%,virtual_number.ilike.%$query%')
          .eq('is_discoverable', true)
          .limit(20);

      return (response as List)
          .map((data) => app_user.User.fromJson(data))
          .toList();
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

  /// Send message
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
      );

      final messageData = message.toJson();
      // Map to snake_case for Supabase
      final dbData = {
        'id': messageData['id'],
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

      await _supabase.from('messages').insert(dbData);

      return message;
    } catch (e, stackTrace) {
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
                .order('timestamp', ascending: true);

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
                .toList();

            onUpdate(messages);
          },
        )
        .subscribe();
  }

  /// Get user conversations
  Future<List<Map<String, dynamic>>> getUserConversations(String userId) async {
    try {
      final response = await _supabase
          .from('messages')
          .select('conversation_id, sender_id, receiver_id, text, timestamp')
          .or('sender_id.eq.$userId,receiver_id.eq.$userId')
          .order('timestamp', ascending: false);

      final conversations = <String, Map<String, dynamic>>{};
      for (final data in response as List) {
        final convId = data['conversation_id'];
        if (convId != null && !conversations.containsKey(convId)) {
          conversations[convId] = {
            'id': convId,
            'lastMessage': data['text'],
            'lastMessageTime': data['timestamp'],
            'participants': [data['sender_id'], data['receiver_id']],
          };
        }
      }

      return conversations.values.toList();
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        AppError.service(
          message: 'Failed to get conversations: $e',
          stackTrace: stackTrace,
          originalException: e is Exception ? e : Exception(e.toString()),
        ),
      );
      return [];
    }
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
      debugPrint('🔍 Fetching discover users for $currentUserId');

      final session = _supabase.auth.currentSession;
      debugPrint(
        '🔍 Supabase Auth Session: ${session != null ? "Active" : "None"} (User ID: ${session?.user.id})',
      );

      if (session == null) {
        debugPrint(
          '⚠️ Warning: No active Supabase session. RLS might block access.',
        );
      }

      // 1. Get all discoverable users (limit 50 for performance)
      // Try to fetch WITHOUT filter first to verify access, if empty
      var profilesQuery = _supabase
          .from('profiles')
          .select()
          .eq('is_discoverable', true);

      // If we have a user ID, exclude it
      if (currentUserId.isNotEmpty) {
        profilesQuery = profilesQuery.neq('id', currentUserId);
      }

      final profilesResponse = await profilesQuery.limit(50);

      debugPrint('🔍 Supabase returned ${profilesResponse.length} profiles');

      if (profilesResponse.isEmpty) {
        debugPrint(
          '⚠️ No profiles found in Supabase (excluding current user). Check RLS policies or if profiles exist.',
        );
        return [];
      } else {
        // Only sort if we have data to avoid potential issues if list is empty (though unsafe sort shouldn't be an issue)
        // Note: moved sorting to client side or keep simple for debug
        (profilesResponse as List).sort(
          (a, b) => (a['full_name'] ?? '').compareTo(b['full_name'] ?? ''),
        );
      }

      // 2. Get following IDs
      final followingResponse = await _supabase
          .from('follows')
          .select('following_id')
          .eq('follower_id', currentUserId);

      final followingIds = (followingResponse as List)
          .map((e) => e['following_id'] as String)
          .toSet();

      // 3. Merge
      return (profilesResponse as List).map((profile) {
        final profileMap = profile as Map<String, dynamic>;
        return {
          ...profileMap,
          'isFollowing': followingIds.contains(profileMap['id']),
        };
      }).toList();
    } catch (e) {
      debugPrint('❌ Failed to get discover users: $e');
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

  void dispose() {
    _messagesController.close();
  }
}
