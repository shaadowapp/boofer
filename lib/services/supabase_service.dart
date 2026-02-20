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

  final SupabaseClient _supabase = Supabase.instance.client;
  final ErrorHandler _errorHandler = ErrorHandler();

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

      // Fetch conversation timer to set expiry
      final timerString = await getConversationTimer(receiverId!);
      DateTime? expiresAt;

      int minutes = 0;
      if (timerString == 'after_seen') {
        // 'after_seen' is handled by status logic, but we can set a 24h safety fuse
        minutes = 24 * 60;
      } else {
        // Parse "X_hours" or "X_hour"
        final parts = timerString.split('_');
        if (parts.isNotEmpty) {
          final hours = int.tryParse(parts[0]) ?? 12;
          minutes = hours * 60;
        } else {
          minutes = 12 * 60; // Default to 12 hours
        }
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
        'encrypted_content': null,
        'encryption_version': null,
        'message_hash': messageData['messageHash'],
        'metadata': messageData['metadata'],
        'expires_at': expiresAt.toIso8601String(),
      };

      // Try to apply Virgil-style E2EE
      if (forceUnencrypted != true) {
        try {
          debugPrint('🔐 Attempting to apply Virgil E2EE...');
          if (!VirgilE2EEService.instance.isInitialized) {
            await initializeE2EE(senderId!);
          }

          // Fetch recipient's Virgil keys
          final recipientKeys = await VirgilKeyService().getRecipientKeys(
            receiverId,
          );
          if (recipientKeys != null) {
            final cryptogram = await VirgilE2EEService.instance.encryptThenSign(
              message.text,
              recipientKeys['encryptionPublicKey'],
            );

            dbData['is_encrypted'] = true;
            dbData['text'] = '[Encrypted]';
            dbData['encrypted_content'] = cryptogram;
            dbData['encryption_version'] = 'virgil_v1';

            debugPrint('🔐 Virgil E2EE Applied: Message scrambled and signed');
          } else {
            debugPrint(
              '⚠️ Virgil keys not found for recipient, sending plaintext',
            );
          }
        } catch (e) {
          debugPrint('❌ Virgil E2EE Encryption failed: $e');
          // If encryption failed, ABORT sending to prevent leakage of plaintext
          throw Exception(
            'E2EE Encryption failed: $e. Message not sent to prevent leakage.',
          );
        }
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
      debugPrint('❌ CRITICAL FAILURE in SupabaseService.sendMessage: $e');
      debugPrint('❌ Stack trace: $stackTrace');

      if (e is PostgrestException) {
        debugPrint('❌ Supabase Postgrest Error: ${e.message}');
        debugPrint('❌ Supabase Error Details: ${e.details}');
        debugPrint('❌ Supabase Error Hint: ${e.hint}');
        debugPrint('❌ Supabase Error Code: ${e.code}');
      }

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
                ); // Only load last 50 messages initially (Optimized load)
            final currentUserId = _supabase.auth.currentUser?.id;
            final messages = await Future.wait(
              (response as List).map((data) async {
                var m = Message.fromJson(data);

                // Decrypt only if encrypted AND we are the RECIPIENT
                if (m.isEncrypted && m.senderId != currentUserId) {
                  try {
                    final senderKeys = await VirgilKeyService()
                        .getRecipientKeys(m.senderId);
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
                    debugPrint('⚠️ Decryption failed: $e');
                    m = m.copyWith(status: MessageStatus.decryptionFailed);
                  }
                } else if (m.isEncrypted && m.senderId == currentUserId) {
                  // If we are the sender, we can't decrypt from DB (encrypted for recipient)
                  // We should ideally keep it plaintext in local DB, but here we just leave it
                  // as "[Encrypted]" if text was swapped, or the optimistic text.
                }
                return m;
              }),
            );

            final filteredMessages = messages
                .where((m) {
                  final deletedFor = m.metadata?['deleted_for'] as List?;
                  return deletedFor == null ||
                      !deletedFor.contains(currentUserId);
                })
                .toList()
                .reversed
                .toList();

            onUpdate(filteredMessages);
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
          callback: (payload) async {
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

              // Handle decryption for real-time insert (Virgil-style)
              if (payload.eventType == PostgresChangeEvent.insert) {
                if (newRecord['receiver_id'] == userId &&
                    newRecord['is_encrypted'] == true) {
                  debugPrint('📥 Virgil E2EE message received, decrypting...');
                  try {
                    final senderId = newRecord['sender_id'];
                    final senderKeys = await VirgilKeyService()
                        .getRecipientKeys(senderId);
                    if (senderKeys != null) {
                      final encryptedContent =
                          newRecord['encrypted_content'] is String
                          ? jsonDecode(newRecord['encrypted_content'])
                          : newRecord['encrypted_content'];
                      if (!VirgilE2EEService.instance.isInitialized) {
                        await initializeE2EE(userId);
                      }
                      final decrypted = await VirgilE2EEService.instance
                          .decryptThenVerify(
                            encryptedContent,
                            senderKeys['signaturePublicKey'],
                          );
                      newRecord['text'] = decrypted;
                    }
                  } catch (e) {
                    debugPrint('⚠️ Real-time decryption failed: $e');
                  }
                }
              }
            }
          },
        )
        .subscribe();
  }

  Future<List<Map<String, dynamic>>> getUserConversations(String userId) async {
    try {
      debugPrint('📥 Fetching definitive lobby items for $userId...');

      // We use the new v_chat_lobby view which calculates everything in SQL
      final response = await _supabase
          .from('v_chat_lobby')
          .select()
          .eq('current_user_id', userId)
          .order('last_message_time', ascending: false);

      final List conversations = response as List;
      debugPrint(
        '✅ Definitive lobby loaded: ${conversations.length} active chats',
      );

      // Pre-initialize E2EE once if there are any encrypted messages
      if (conversations.any((c) => c['last_message_is_encrypted'] == true)) {
        if (!VirgilE2EEService.instance.isInitialized) {
          await initializeE2EE(userId);
        }
      }

      return Future.wait(
        conversations.map((data) async {
          final friendId = data['friend_id'];
          String lastMessage = data['last_message_text'] ?? '';
          final isEncrypted = data['last_message_is_encrypted'] ?? false;
          final encryptedContent = data['last_message_encrypted_content'];

          // Automatically decrypt previews if we are NOT the sender
          if (isEncrypted &&
              encryptedContent != null &&
              lastMessage == '[Encrypted]' &&
              data['last_message_sender_id'] != userId) {
            try {
              final senderKeys = await VirgilKeyService().getRecipientKeys(
                friendId,
              );
              if (senderKeys != null) {
                final contentMap = encryptedContent is String
                    ? jsonDecode(encryptedContent) as Map<String, dynamic>
                    : Map<String, dynamic>.from(encryptedContent);

                lastMessage = await VirgilE2EEService.instance
                    .decryptThenVerify(
                      contentMap,
                      senderKeys['signaturePublicKey'],
                    );
              }
            } catch (e) {
              lastMessage = '[Encrypted] (Decryption Error)';
            }
          }

          return {
            'id': data['conversation_id'],
            'lastMessage': lastMessage,
            'lastMessageTime': data['last_message_time'],
            'unreadCount': data['unread_count'] ?? 0,
            'otherUser': {
              'id': data['friend_id'],
              'name': data['friend_name'] ?? 'Unknown',
              'handle': data['friend_handle'] ?? 'unknown',
              'avatar': data['friend_avatar'],
              'profilePicture': data['friend_profile_picture'],
              'status': data['friend_status'],
            },
            'is_encrypted': isEncrypted,
            'encrypted_content': encryptedContent,
          };
        }),
      );
    } catch (e) {
      debugPrint('❌ Lobby view fetch failed: $e');
      // Return empty list so at least UI doesn't crash
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

      // 1. Check conversation-specific setting
      final response = await _supabase
          .from('conversation_settings')
          .select('ephemeral_timer')
          .eq('conversation_id', conversationId)
          .eq('user_id', userId)
          .maybeSingle();

      if (response != null && response['ephemeral_timer'] != null) {
        return response['ephemeral_timer'] as String;
      }

      // 2. Fallback to global user default
      final privacyResponse = await _supabase
          .from('user_privacy_settings')
          .select('default_message_timer')
          .eq('user_id', userId)
          .maybeSingle();

      if (privacyResponse != null &&
          privacyResponse['default_message_timer'] != null) {
        return privacyResponse['default_message_timer'] as String;
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
