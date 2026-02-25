import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../models/user_model.dart' as app_user;
import '../models/message_model.dart';
import '../core/error/error_handler.dart';
import '../core/models/app_error.dart';
import '../utils/string_utils.dart';
import 'unified_storage_service.dart';
import 'virgil_e2ee_service.dart';
import 'virgil_key_service.dart';
import '../models/privacy_settings_model.dart';

/// Supabase service for real-time messaging and user management
class SupabaseService {
  static SupabaseService? _instance;
  static SupabaseService get instance =>
      _instance ??= SupabaseService._internal();
  SupabaseService._internal();

  SupabaseClient get _supabase => Supabase.instance.client;
  final ErrorHandler _errorHandler = ErrorHandler();

  // Cache conversation timers so we don't hit the DB on every send.
  // Key: conversationId, Value: timer string (e.g. '12_hours', 'after_seen')
  final Map<String, String> _timerCache = {};

  /// Invalidate the cached timer for a conversation (call after user changes timer setting).
  void invalidateTimerCache(String conversationId) {
    _timerCache.remove(conversationId);
  }

  // Stream controllers for real-time updates
  final StreamController<List<Message>> _messagesController =
      StreamController<List<Message>>.broadcast();

  Stream<List<Message>> get messagesStream => _messagesController.stream;

  /// Initialize Supabase connection and E2EE
  Future<void> initialize() async {
    try {
      // Supabase is initialized in main.dart

      // Initialize E2EE if session exists
      final user = _supabase.auth.currentUser;
      if (user != null) {
        await initializeE2EE(user.id);
      }
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

  /// Initialize E2EE for the current user (Virgil-style)
  Future<void> initializeE2EE(String userId) async {
    try {
      if (!VirgilE2EEService.instance.isInitialized ||
          VirgilE2EEService.instance.userId != userId) {
        await VirgilE2EEService.instance.initialize(userId);
      }
      await VirgilKeyService().uploadPublicKeys();
      debugPrint('✅ Virgil E2EE initialized and keys uploaded for $userId');
    } catch (e) {
      debugPrint('❌ Failed to initialize Virgil E2EE: $e');
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
    List<String>? interests,
    List<String>? hobbies,
    int? age,
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
      if (interests != null) updates['interests'] = interests;
      if (hobbies != null) updates['hobbies'] = hobbies;
      if (age != null) updates['age'] = age;

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

  /// Get user profile by Handle
  Future<app_user.User?> getUserByHandle(String handle) async {
    try {
      // Remove @ if present
      final cleanHandle = handle.startsWith('@') ? handle.substring(1) : handle;

      final response = await _supabase
          .from('profiles')
          .select()
          .eq('handle', cleanHandle)
          .maybeSingle();

      if (response == null) return null;
      return app_user.User.fromJson(response);
    } catch (e) {
      debugPrint('❌ Failed to get user by handle: $e');
      return null;
    }
  }

  /// Get user profile by Virtual Number
  Future<app_user.User?> getUserByVirtualNumber(String virtualNumber) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('virtual_number', virtualNumber)
          .maybeSingle();

      if (response == null) return null;
      return app_user.User.fromJson(response);
    } catch (e) {
      debugPrint('❌ Failed to get user by virtual number: $e');
      return null;
    }
  }

  /// Get user profile with relationship data (followers/following status)
  Future<Map<String, dynamic>?> getUserAndRelationship({
    required String currentUserId,
    required String profileUserId,
  }) async {
    try {
      // Fetch profile data + user relationship status in one go.
      // Now using the pre-calculated follower_count and following_count columns.
      final response = await _supabase
          .from('profiles')
          .select('*, my_follow:follows!following_id(follower_id)')
          .eq('id', profileUserId)
          .single();

      final data = Map<String, dynamic>.from(response);

      // Calculate isFollowing from my_follow
      final myFollow = data['my_follow'] as List?;
      data['is_following'] =
          myFollow != null &&
          myFollow.any((f) => f['follower_id'] == currentUserId);

      // Map snake_case to camelCase for the model if needed,
      // though User.fromJson already handles both.

      return data;
    } catch (e) {
      debugPrint('❌ Failed to get user and relationship: $e');
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
      if (!StringUtils.isUuid(messageId)) {
        debugPrint(
          '⚠️ SupabaseService: Skipping updateMessageStatus - invalid UUID ($messageId)',
        );
        return;
      }

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
    bool? forceUnencrypted, // Optional: force unencrypted for testing
    String? knownTimer, // Optional: pass known timer to skip extra DB roundtrip
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
          throw Exception('Missing required fields for creating a new message');
        }

        // Create the base message
        message = Message.create(
          text: text,
          senderId: senderId,
          receiverId: receiverId,
          conversationId: conversationId,
          type: type,
        );
      }

      final messageData = message.toJson();

      // Initialize E2EE if needed
      if (forceUnencrypted != true) {
        if (!VirgilE2EEService.instance.isInitialized) {
          await initializeE2EE(senderId!);
        }
      }

      // Fetch keys (and maybe timer) in parallel
      final recipientKeysFuture = forceUnencrypted == true
          ? Future.value(null)
          : VirgilKeyService().getRecipientKeys(receiverId!);
      final senderKeysFuture = forceUnencrypted == true
          ? Future.value(null)
          : VirgilKeyService().getRecipientKeys(senderId!);

      // Skip the DB round-trip if the caller already knows the timer
      final timerFuture = (knownTimer != null)
          ? Future.value(knownTimer)
          : getConversationTimer(receiverId!);

      // Wait for all pre-requisites
      final results = await Future.wait([
        timerFuture,
        recipientKeysFuture,
        senderKeysFuture,
      ]);

      final String timerString = results[0] as String;
      final Map<String, dynamic>? recipientKeys =
          results[1] as Map<String, dynamic>?;
      final Map<String, dynamic>? senderOwnKeys =
          results[2] as Map<String, dynamic>?;

      // ... rest of the logic ...
      DateTime? expiresAt;
      int minutes = 0;
      if (timerString == 'after_seen') {
        minutes = 24 * 60;
      } else {
        final parts = timerString.split('_');
        final hours = parts.isNotEmpty ? (int.tryParse(parts[0]) ?? 12) : 12;
        minutes = hours * 60;
      }
      expiresAt = DateTime.now().add(Duration(minutes: minutes));

      final dbData = {
        'id': messageData['id'],
        'text': messageData['text'],
        'sender_id': messageData['senderId'],
        'receiver_id': messageData['receiverId'],
        'conversation_id': messageData['conversationId'],
        'timestamp': messageData['timestamp'],
        'status': messageData['status'],
        'type': messageData['type'],
        'is_encrypted': false,
        'message_hash': messageData['messageHash'],
        'metadata': messageData['metadata'],
        'expires_at': expiresAt.toIso8601String(),
      };

      // Apply E2EE if possible
      if (recipientKeys != null) {
        try {
          // Perform both encryptions in parallel
          final encryptionFutures = await Future.wait([
            VirgilE2EEService.instance.encryptThenSign(
              message.text,
              recipientKeys['encryptionPublicKey'],
            ),
            if (senderOwnKeys != null)
              VirgilE2EEService.instance.encryptThenSign(
                message.text,
                senderOwnKeys['encryptionPublicKey'],
              )
            else
              Future.value(null),
          ]);

          dbData['is_encrypted'] = true;
          dbData['text'] = '[Encrypted]';
          dbData['encrypted_content'] = encryptionFutures[0];
          dbData['encrypted_content_sender'] = encryptionFutures[1];
          dbData['encryption_version'] = 'virgil_v1';
          debugPrint('🔐 Virgil E2EE Applied (Dual-encrypted)');
        } catch (e) {
          debugPrint('❌ Virgil E2EE Encryption failed: $e');
          throw Exception('E2EE Encryption failed. Message not sent.');
        }
      } else if (forceUnencrypted != true) {
        debugPrint('⚠️ Virgil keys not found for recipient, sending plaintext');
      }

      debugPrint('📤 DB DATA: ${jsonEncode(dbData)}');
      debugPrint(
        '📤 Sending ${dbData['is_encrypted'] == true ? "encrypted" : "plaintext"} message to Supabase...',
      );
      final response = await _supabase
          .from('messages')
          .insert(dbData)
          .select()
          .single();

      debugPrint('✅ Message sent to DB, ID: ${response['id']}');

      // TRACK NETWORK USAGE
      final size =
          (text?.length ?? 0) +
          (messageData['mediaUrl'] != null ? 1024 * 1024 : 0);
      await UnifiedStorageService.incrementNetworkUsage(
        messageData['mediaUrl'] != null ? 'media' : 'messages',
        size,
        isSent: true,
      );

      // Return the message with metadata from DB but keep original text for sender preview
      final dbMessage = Message.fromJson(response);
      return dbMessage.copyWith(text: message.text);
    } catch (e, stackTrace) {
      debugPrint('❌ SupabaseService.sendMessage CRITICAL FAILURE: $e');

      if (e is PostgrestException) {
        debugPrint(
          '❌ Supabase Postgrest Error Detail: ${e.message} (${e.code})',
        );
        debugPrint('❌ Postgrest Details: ${e.details}');
        debugPrint('❌ Postgrest Hint: ${e.hint}');
      }

      _errorHandler.handleError(
        AppError.service(
          message: 'Failed to send message: $e',
          stackTrace: stackTrace,
          originalException: e is Exception ? e : Exception(e.toString()),
        ),
      );

      // IMPORTANT: Rethrow so the ChatService/UI knows it failed!
      rethrow;
    }
  }

  /// Listen to messages in real-time (Optimized)
  RealtimeChannel listenToMessages(
    String conversationId,
    Function(List<Message>) onUpdate,
  ) {
    return _supabase
        .channel('public:messages:$conversationId')
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
            final record = payload.newRecord.isEmpty
                ? payload.oldRecord
                : payload.newRecord;
            if (record.isEmpty) return;

            final currentUserId = _supabase.auth.currentUser?.id;
            var m = Message.fromJson(record);

            // Decrypt insert/update events if we are the recipient
            if (payload.eventType != PostgresChangeEvent.delete &&
                m.isEncrypted &&
                m.senderId != currentUserId) {
              try {
                final senderKeys = await VirgilKeyService().getRecipientKeys(
                  m.senderId,
                );
                if (senderKeys != null) {
                  if (!VirgilE2EEService.instance.isInitialized) {
                    await initializeE2EE(currentUserId!);
                  }
                  final decryptedText = await VirgilE2EEService.instance
                      .decryptThenVerify(
                        m.encryptedContent!,
                        senderKeys['signaturePublicKey'],
                      );
                  m = m.copyWith(text: decryptedText);
                }
              } catch (e) {
                debugPrint('⚠️ Realtime decryption failed: $e');
              }
            }

            // Return the single event item as a list for backward compatibility
            onUpdate([m]);
          },
        )
        .subscribe();
  }

  /// Listen to relevant messages for the current user (Optimized for performance)
  /// This uses server-side filtering to avoid receiving all app messages.
  RealtimeChannel listenToAllUserMessages(
    String userId,
    Function(Map<String, dynamic> payload) onEvent,
  ) {
    // We listen to:
    // 1. INBOUND messages (receiver_id = user) — messages others send to us
    // 2. OUTBOUND messages (sender_id = user) — messages we send to others
    // 3. STATUS UPDATES for messages we sent (sender_id = user)
    // 4. STATUS UPDATES for messages we received (receiver_id = user)

    final channelName = 'user_messages_$userId';

    return _supabase
        .channel(channelName)
        // --- 1. INBOUND: new messages we receive ---
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'receiver_id',
            value: userId,
          ),
          callback: (payload) async {
            final record = Map<String, dynamic>.from(payload.newRecord);
            if (record.isEmpty) return;

            // Track received messages (network usage)
            final text = record['text'] as String? ?? '';
            final size =
                text.length + (record['media_url'] != null ? 1024 * 1024 : 0);
            UnifiedStorageService.incrementNetworkUsage(
              record['media_url'] != null ? 'media' : 'messages',
              size,
              isSent: false,
            );

            // Handle decryption at source
            if (record['is_encrypted'] == true) {
              try {
                final senderKeys = await VirgilKeyService().getRecipientKeys(
                  record['sender_id'],
                );
                if (senderKeys != null) {
                  if (!VirgilE2EEService.instance.isInitialized)
                    await initializeE2EE(userId);

                  final encryptedContent = record['encrypted_content'] is String
                      ? jsonDecode(record['encrypted_content'])
                      : record['encrypted_content'];

                  final decrypted = await VirgilE2EEService.instance
                      .decryptThenVerify(
                        encryptedContent,
                        senderKeys['signaturePublicKey'],
                      );
                  record['text'] = decrypted;
                }
              } catch (e) {
                debugPrint('⚠️ Decryption error (inbound): $e');
              }
            }

            onEvent({'eventType': 'insert', 'record': record});
          },
        )
        // --- 2. OUTBOUND: new messages we send (so our own lobby updates too) ---
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'sender_id',
            value: userId,
          ),
          callback: (payload) async {
            final record = Map<String, dynamic>.from(payload.newRecord);
            if (record.isEmpty) return;

            // For our own sent encrypted messages, show a placeholder
            // (we can decrypt via encrypted_content_sender if present)
            if (record['is_encrypted'] == true) {
              try {
                final encryptedSenderContent =
                    record['encrypted_content_sender'];
                if (encryptedSenderContent != null) {
                  if (!VirgilE2EEService.instance.isInitialized)
                    await initializeE2EE(userId);

                  final senderKeys = await VirgilKeyService().getRecipientKeys(
                    userId,
                  );
                  if (senderKeys != null) {
                    final contentMap = encryptedSenderContent is String
                        ? jsonDecode(encryptedSenderContent)
                              as Map<String, dynamic>
                        : Map<String, dynamic>.from(encryptedSenderContent);

                    final decrypted = await VirgilE2EEService.instance
                        .decryptThenVerify(
                          contentMap,
                          senderKeys['signaturePublicKey'],
                        );
                    record['text'] = decrypted;
                  }
                }
              } catch (e) {
                debugPrint('⚠️ Decryption error (outbound self-copy): $e');
              }
            }

            onEvent({'eventType': 'insert', 'record': record});
          },
        )
        // --- 3. STATUS UPDATES for messages we sent ---
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'sender_id',
            value: userId,
          ),
          callback: (payload) {
            onEvent({'eventType': 'update', 'record': payload.newRecord});
          },
        )
        // --- 4. STATUS UPDATES for messages we received ---
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'receiver_id',
            value: userId,
          ),
          callback: (payload) {
            onEvent({'eventType': 'update', 'record': payload.newRecord});
          },
        )
        .subscribe((status, [error]) {
          debugPrint(
            '🔔 [REALTIME] Subscription status for $channelName: $status',
          );
          if (error != null) {
            debugPrint('❌ [REALTIME] Subscription error: ${error.toString()}');
          }
        });
  }

  /// Listen for new followers
  RealtimeChannel listenToUserFollows(
    String userId,
    Function(Map<String, dynamic> data) onFollow,
  ) {
    return _supabase
        .channel('user_follows_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'follows',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'following_id',
            value: userId,
          ),
          callback: (payload) => onFollow(payload.newRecord),
        )
        .subscribe();
  }

  Future<List<Map<String, dynamic>>> getUserConversations(String userId) async {
    try {
      debugPrint('📥 [LOBBY_FLOW] Fetching v_chat_lobby for user: $userId');

      // We use the new v_chat_lobby view which calculates everything in SQL
      final response = await _supabase
          .from('v_chat_lobby')
          .select()
          .eq('current_user_id', userId)
          .order('last_message_time', ascending: false)
          .timeout(const Duration(seconds: 10));

      final List conversations = response as List;
      debugPrint(
        '✅ [LOBBY_FLOW] v_chat_lobby returned ${conversations.length} records',
      );

      // Pre-initialize E2EE once if there are any encrypted messages
      if (conversations.any((c) => c['last_message_is_encrypted'] == true)) {
        debugPrint(
          '🔐 [LOBBY_FLOW] Encrypted messages detected, ensuring E2EE initialized',
        );
        if (!VirgilE2EEService.instance.isInitialized) {
          await initializeE2EE(userId);
        }
      }

      final results = await Future.wait(
        conversations.map((data) async {
          final friendId = data['friend_id'];
          final isEncrypted = data['last_message_is_encrypted'] ?? false;
          final lastSenderId = data['last_message_sender_id'];
          final encryptedContent = data['last_message_encrypted_content'];
          final encryptedContentSender =
              data['last_message_encrypted_content_sender'];

          String lastMessage = data['last_message_text'] ?? '';

          // Decrypt if it's encrypted
          if (isEncrypted) {
            try {
              if (lastSenderId == userId) {
                // We are the sender — decrypt using our self-copy
                final selfCopy = encryptedContentSender ?? encryptedContent;
                if (selfCopy != null) {
                  final ourKeys = await VirgilKeyService().getRecipientKeys(
                    userId,
                  );
                  if (ourKeys != null &&
                      ourKeys['signaturePublicKey'] != null) {
                    final contentMap = selfCopy is String
                        ? jsonDecode(selfCopy) as Map<String, dynamic>
                        : Map<String, dynamic>.from(selfCopy);

                    lastMessage = await VirgilE2EEService.instance
                        .decryptThenVerify(
                          contentMap,
                          ourKeys['signaturePublicKey'],
                        );
                  }
                }
              } else if (encryptedContent != null) {
                // We are the recipient — decrypt using sender's key
                final senderKeys = await VirgilKeyService().getRecipientKeys(
                  lastSenderId,
                );
                if (senderKeys != null &&
                    senderKeys['signaturePublicKey'] != null) {
                  final contentMap = encryptedContent is String
                      ? jsonDecode(encryptedContent) as Map<String, dynamic>
                      : Map<String, dynamic>.from(encryptedContent);

                  lastMessage = await VirgilE2EEService.instance
                      .decryptThenVerify(
                        contentMap,
                        senderKeys['signaturePublicKey'],
                      );
                }
              }
            } catch (e) {
              debugPrint('⚠️ [LOBBY_FLOW] Decryption failed for $friendId: $e');
              lastMessage = '[Encrypted]';
            }
          }

          return {
            'id': data['conversation_id'],
            'lastMessage': lastMessage,
            'lastMessageTime': data['last_message_time'],
            'unreadCount': data['unread_count'] ?? 0,
            'lastMessageStatus': data['last_message_status'],
            'lastSenderId': data['last_message_sender_id'],
            'otherUser': {
              'id': data['friend_id'],
              'name': data['friend_name'] ?? 'Unknown',
              'handle': data['friend_handle'] ?? 'unknown',
              'avatar': data['friend_avatar'],
              'profilePicture': data['friend_profile_picture'],
              'status': data['friend_status'],
              'is_verified': data['friend_is_verified'],
            },
            'is_encrypted': isEncrypted,
            'encrypted_content': encryptedContent,
          };
        }),
      );

      debugPrint(
        '✅ [LOBBY_FLOW] Processing of ${results.length} lobby items completed',
      );
      return results;
    } catch (e, stackTrace) {
      debugPrint('❌ [LOBBY_FLOW] getUserConversations FAILED: $e');
      debugPrint('$stackTrace');
      return [];
    }
  }

  /// Get blocked user IDs for current user
  Future<List<String>> getBlockedUserIds() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        debugPrint(
          '⚠️ [LOBBY_FLOW] getBlockedUserIds called but no user logged in',
        );
        return [];
      }

      debugPrint(
        '📥 [LOBBY_FLOW] Fetching blocked users from blocked_users table for: $userId',
      );
      final response = await _supabase
          .from('blocked_users')
          .select('blocked_id')
          .eq('blocker_id', userId);

      final List data = response as List;
      final ids = data.map((item) => item['blocked_id'] as String).toList();
      debugPrint('✅ [LOBBY_FLOW] Found ${ids.length} blocked users');
      return ids;
    } catch (e) {
      debugPrint('❌ [LOBBY_FLOW] getBlockedUserIds failed: $e');
      return [];
    }
  }

  /// Update ephemeral timer for a conversation
  Future<void> updateConversationTimer(String friendId, String timer) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      if (!StringUtils.isUuid(userId) || !StringUtils.isUuid(friendId)) return;

      final sortedIds = [userId, friendId]..sort();
      final conversationId = 'conv_${sortedIds[0]}_${sortedIds[1]}';

      // Update in conversation_settings (Unified definitive table)
      await _supabase.from('conversation_settings').upsert({
        'conversation_id': conversationId,
        'user_id': userId,
        'ephemeral_timer': timer,
      });

      debugPrint('✅ Ephemeral timer updated to $timer for $conversationId');
    } catch (e) {
      debugPrint('❌ Error updating conversation timer: $e');
    }
  }

  /// Get unread message counts for all conversations for a user
  Future<Map<String, int>> getUnreadMessageCounts(String userId) async {
    try {
      // Create a map to store unread counts by conversation ID
      final unreadCounts = <String, int>{};

      // Fetch all unread messages for this receiver
      // We only need message ID and conversation ID to count
      // status 'read' means read. 'sent' and 'delivered' are unread.
      final response = await _supabase
          .from('messages')
          .select('conversation_id')
          .eq('receiver_id', userId)
          .neq('status', 'read');

      if ((response as List).isEmpty) {
        return {};
      }

      // Aggregate counts in Dart
      for (final msg in response) {
        final convId = msg['conversation_id'] as String?;
        if (convId != null) {
          unreadCounts[convId] = (unreadCounts[convId] ?? 0) + 1;
        }
      }

      return unreadCounts;
    } catch (e) {
      debugPrint('❌ Failed to get unread message counts: $e');
      return {};
    }
  }

  Future<String> getConversationTimer(String friendId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return '12_hours';

      if (!StringUtils.isUuid(userId) || !StringUtils.isUuid(friendId)) {
        return '12_hours';
      }

      final sortedIds = [userId, friendId]..sort();
      final conversationId = 'conv_${sortedIds[0]}_${sortedIds[1]}';

      // Return cached value to avoid per-send DB round-trips
      if (_timerCache.containsKey(conversationId)) {
        return _timerCache[conversationId]!;
      }

      // 1. Check conversation-specific setting
      final response = await _supabase
          .from('conversation_settings')
          .select('ephemeral_timer')
          .eq('conversation_id', conversationId)
          .eq('user_id', userId)
          .maybeSingle();

      if (response != null && response['ephemeral_timer'] != null) {
        final timer = response['ephemeral_timer'] as String;
        _timerCache[conversationId] = timer;
        return timer;
      }

      // 2. Fallback to global user default
      final privacyResponse = await _supabase
          .from('user_privacy_settings')
          .select('default_message_timer')
          .eq('user_id', userId)
          .maybeSingle();

      if (privacyResponse != null &&
          privacyResponse['default_message_timer'] != null) {
        final timer = privacyResponse['default_message_timer'] as String;
        _timerCache[conversationId] = timer;
        return timer;
      }
    } catch (e) {
      debugPrint('Error fetching conversation timer: $e');
    }
    return '12_hours'; // Final fallback to 12 hours as per user request
  }

  /// Delete a conversation from the lobby (intentional deletion)
  Future<void> deleteConversation(String friendId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      if (!StringUtils.isUuid(userId) || !StringUtils.isUuid(friendId)) return;

      final sortedIds = [userId, friendId]..sort();
      final conversationId = 'conv_${sortedIds[0]}_${sortedIds[1]}';

      await _supabase
          .from('conversation_settings')
          .update({'is_hidden': true})
          .eq('conversation_id', conversationId)
          .eq('user_id', userId);
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
      if (!StringUtils.isUuid(currentUserId)) {
        debugPrint(
          '⚠️ SupabaseService: Skipping getDiscoverUsers - invalid UUID ($currentUserId)',
        );
        return [];
      }

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

  /// Sign out
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
      debugPrint('✅ Supabase user signed out successfully');
    } catch (e) {
      debugPrint('❌ Supabase signout failed: $e');
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

  /// Delete another user's account (subordinate) using RPC
  Future<void> deleteOtherUserAccount(String userId) async {
    try {
      await _supabase.rpc(
        'delete_user_completely',
        params: {'target_user_id': userId},
      );
      debugPrint('✅ User account $userId completely deleted from DB via RPC');
    } catch (e) {
      debugPrint('❌ Error calling delete_user_completely RPC: $e');
      throw Exception('Failed to delete subordinate profile from DB: $e');
    }
  }

  /// Message Deletion Methods

  /// Delete message for everyone (permanent deletion)
  Future<void> deleteMessageForEveryone(String messageId) async {
    try {
      await _supabase.from('messages').delete().eq('id', messageId);
      debugPrint('✅ Message deleted for everyone: $messageId');
    } catch (e, stackTrace) {
      debugPrint('❌ Failed to delete message for everyone: $e');
      _errorHandler.handleError(
        AppError.service(
          message: 'Failed to delete message for everyone: $e',
          stackTrace: stackTrace,
          originalException: e is Exception ? e : Exception(e.toString()),
        ),
      );
      rethrow;
    }
  }

  /// Delete message for current user (soft delete using metadata)
  Future<void> deleteMsgForMe(String messageId, String userId) async {
    try {
      final response = await _supabase
          .from('messages')
          .select('metadata')
          .eq('id', messageId)
          .single();

      final metadata = response['metadata'] != null
          ? Map<String, dynamic>.from(response['metadata'] as Map)
          : <String, dynamic>{};

      final List<dynamic> deletedFor = metadata['deleted_for'] != null
          ? List<dynamic>.from(metadata['deleted_for'] as List)
          : [];

      if (!deletedFor.contains(userId)) {
        deletedFor.add(userId);
      }

      metadata['deleted_for'] = deletedFor;

      await _supabase
          .from('messages')
          .update({'metadata': metadata})
          .eq('id', messageId);

      debugPrint('✅ Message hidden for user $userId: $messageId');
    } catch (e, stackTrace) {
      debugPrint('❌ Failed to delete message for me: $e');
      _errorHandler.handleError(
        AppError.service(
          message: 'Failed to delete message for me: $e',
          stackTrace: stackTrace,
          originalException: e is Exception ? e : Exception(e.toString()),
        ),
      );
      rethrow;
    }
  }

  /// Add a reaction to a message
  Future<void> addMessageReaction(String messageId, String emoji) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // 1. Fetch current message metadata
      final response = await _supabase
          .from('messages')
          .select('metadata')
          .eq('id', messageId)
          .single();

      final metadata = response['metadata'] != null
          ? Map<String, dynamic>.from(response['metadata'] as Map)
          : <String, dynamic>{};

      // 2. Update reactions
      // Structure: metadata['reactions'] = {'emoji': ['userId1', 'userId2']}
      final reactions = metadata['reactions'] != null
          ? Map<String, dynamic>.from(metadata['reactions'] as Map)
          : <String, dynamic>{};

      // Remove user from ALL other emoji lists first (enforce single reaction)
      reactions.forEach((key, value) {
        final existingUsers = List<String>.from(value as List);
        if (existingUsers.contains(userId)) {
          existingUsers.remove(userId);
          reactions[key] = existingUsers;
        }
      });

      // Clean up empty reaction lists
      reactions.removeWhere((key, value) => (value as List).isEmpty);

      // Add to new emoji list
      final userIds = reactions[emoji] != null
          ? List<String>.from(reactions[emoji] as List)
          : <String>[];

      if (!userIds.contains(userId)) {
        userIds.add(userId);
        reactions[emoji] = userIds;
        metadata['reactions'] = reactions;

        // 3. Save back to DB
        await _supabase
            .from('messages')
            .update({'metadata': metadata})
            .eq('id', messageId);

        debugPrint('✅ Added reaction $emoji to message $messageId');
      }
    } catch (e) {
      debugPrint('❌ Failed to add reaction: $e');
    }
  }

  /// Remove a reaction from a message
  Future<void> removeMessageReaction(String messageId, String emoji) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // 1. Fetch current message metadata
      final response = await _supabase
          .from('messages')
          .select('metadata')
          .eq('id', messageId)
          .single();

      final metadata = response['metadata'] != null
          ? Map<String, dynamic>.from(response['metadata'] as Map)
          : <String, dynamic>{};

      if (metadata['reactions'] == null) return;

      final reactions = Map<String, dynamic>.from(metadata['reactions'] as Map);

      if (reactions[emoji] != null) {
        final userIds = List<String>.from(reactions[emoji] as List);
        userIds.remove(userId);

        if (userIds.isEmpty) {
          reactions.remove(emoji);
        } else {
          reactions[emoji] = userIds;
        }

        metadata['reactions'] = reactions;

        // 3. Save back to DB
        await _supabase
            .from('messages')
            .update({'metadata': metadata})
            .eq('id', messageId);

        debugPrint('✅ Removed reaction $emoji from message $messageId');
      }
    } catch (e) {
      debugPrint('❌ Failed to remove reaction: $e');
    }
  }

  /// Get privacy settings for a user
  Future<UserPrivacySettings?> getPrivacySettings(String userId) async {
    try {
      final response = await _supabase
          .from('user_privacy_settings')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) {
        // Fallback or create if missing (though trigger should handle it)
        return UserPrivacySettings(userId: userId, updatedAt: DateTime.now());
      }
      return UserPrivacySettings.fromJson(response);
    } catch (e) {
      debugPrint('❌ Error fetching privacy settings: $e');
      return null;
    }
  }

  /// Update privacy settings
  Future<bool> updatePrivacySettings(UserPrivacySettings settings) async {
    try {
      await _supabase.from('user_privacy_settings').upsert(settings.toJson());
      debugPrint('✅ Privacy settings updated for ${settings.userId}');
      return true;
    } catch (e) {
      debugPrint('❌ Error updating privacy settings: $e');
      return false;
    }
  }

  void dispose() {
    _messagesController.close();
  }
}
