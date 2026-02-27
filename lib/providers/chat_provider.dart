import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import '../core/error/error_handler.dart';
import '../core/models/app_error.dart';
// Removed unused import
import '../services/chat_service.dart';
import '../services/user_service.dart';
import '../models/message_model.dart';
import '../models/friend_model.dart';
// Removed unused import
import '../services/supabase_service.dart';
import '../services/notification_service.dart';
import '../core/constants.dart';
import '../services/chat_cache_service.dart';
import '../utils/screenshot_mode.dart';

class ChatProvider with ChangeNotifier {
  final ChatService _chatService;
  final ErrorHandler _errorHandler;

  static const String booferId = AppConstants.booferId;

  List<Message> _messages = [];
  bool _isLoading = false;
  String? _error;
  String? _currentConversationId;

  List<Message> get messages => _messages;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get currentConversationId => _currentConversationId;
  bool get friendsLoaded => _friendsLoaded;
  bool get isLoadingFromNetwork => _isLoadingFromNetwork;
  bool get isAppOnline => _isAppOnline;

  StreamSubscription<List<Message>>? _messagesSubscription;
  StreamSubscription<Message>? _newMessageSubscription;
  RealtimeChannel? _globalMessagesSubscription;
  RealtimeChannel? _followSubscription;
  RealtimeChannel? _presenceChannel;
  RealtimeChannel? _profilesSubscription;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  ChatProvider({
    required ChatService chatService,
    required ErrorHandler errorHandler,
  }) : _chatService = chatService,
       _errorHandler = errorHandler {
    _initializeSubscriptions();
    _loadRealFriends(); // Load real friends instead of demo data
  }

  void _initializeSubscriptions() {
    _messagesSubscription = _chatService.messagesStream.listen(
      (messages) {
        _messages = messages;
        _isLoading = false;
        _error = null;
        notifyListeners();
      },
      onError: (error) {
        _handleError(error);
      },
    );

    _newMessageSubscription = _chatService.newMessageStream.listen((message) {
      if (message.conversationId == _currentConversationId) {
        // Avoid duplicates if possible, though stream usually sends new valid ones
        if (!_messages.any((m) => m.id == message.id)) {
          _messages.add(message);
          notifyListeners();
        }
      }
    });
  }

  Future<void> loadMessages(String conversationId) async {
    if (_currentConversationId == conversationId && _messages.isNotEmpty)
      return;

    _currentConversationId = conversationId;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Get current user ID for validation
      final currentUser = await UserService.getCurrentUser();
      if (currentUser == null) {
        throw Exception('No current user found');
      }

      await _chatService.loadMessages(conversationId, currentUser.id);
      updatePresenceWithConversationId(conversationId);
    } catch (e) {
      _handleError(e);
    }
  }

  Future<void> sendMessage({
    required String conversationId,
    required String senderId,
    required String content,
    String? receiverId,
    MessageType type = MessageType.text,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      // Determine initial status based on presence
      MessageStatus initialStatus = MessageStatus.sent;

      if (receiverId != null) {
        final recipientPresence = getRecipientPresence(receiverId);
        if (recipientPresence != null) {
          final isSameChat =
              recipientPresence['current_conversation_id'] == conversationId;
          initialStatus = isSameChat
              ? MessageStatus.read
              : MessageStatus.delivered;
        }
      }

      await _chatService.sendMessage(
        conversationId: conversationId,
        senderId: senderId,
        content: content,
        receiverId: receiverId,
        type: type,
        status: initialStatus,
        metadata: metadata,
      );
    } catch (e) {
      _handleError(e);
      rethrow;
    }
  }

  Map<String, dynamic>? getRecipientPresence(String userId) {
    if (_presenceChannel == null) return null;
    final state = _presenceChannel!.presenceState();
    for (final presence in state) {
      for (final p in presence.presences) {
        if (p.payload['user_id'] == userId) {
          return p.payload;
        }
      }
    }
    return null;
  }

  Future<bool> checkNotificationPermission() async {
    return await NotificationService.instance.checkPermission();
  }

  Future<void> markMessageAsRead(String messageId) async {
    try {
      await _chatService.markMessageAsRead(messageId);
    } catch (e) {
      _handleError(e);
    }
  }

  Future<void> deleteMessage(String messageId) async {
    try {
      await _chatService.deleteMessage(messageId);
    } catch (e) {
      _handleError(e);
      rethrow;
    }
  }

  Future<List<Message>> searchMessages(String query) async {
    try {
      return await _chatService.searchMessages(
        query,
        conversationId: _currentConversationId,
      );
    } catch (e) {
      _handleError(e);
      return [];
    }
  }

  void _handleError(dynamic error) {
    _isLoading = false;
    _error = error.toString();

    if (error is AppError) {
      _errorHandler.handleError(error);
    } else {
      _errorHandler.handleError(
        AppError.service(
          message: error.toString(),
          originalException: error is Exception
              ? error
              : Exception(error.toString()),
        ),
      );
    }

    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void clearMessages() {
    _messages.clear();
    _currentConversationId = null;
    updatePresenceWithConversationId(null);
    notifyListeners();
  }

  // Get total unread messages count
  int get totalUnreadMessages {
    return _friends.fold(0, (sum, friend) => sum + friend.unreadCount);
  }

  bool get hasUnreadMessages => totalUnreadMessages > 0;

  // Real friends data from Firestore
  List<Friend> _friends = [];
  final List<Friend> _archivedFriends = [];
  final Set<String> _mutedChats = {};
  final Set<String> _blockedUsers = {};
  bool _friendsLoaded = false;
  bool _isLoadingFromNetwork = false;
  bool _isRefreshing = false; // Guard to prevent concurrent refreshes
  bool _isAppOnline = true; // Assume online initially

  // Load real friends from Firestore - Optimized for current requirements
  Future<void> _loadRealFriends({bool forceRefresh = false}) async {
    if (_isRefreshing) return;
    _isRefreshing = true;

    try {
      debugPrint(
        '🚀 [LOBBY] Starting _loadRealFriends (forceRefresh: $forceRefresh)',
      );
      // Use StackTrace to see who called this
      debugPrint(
        '📍 [LOBBY] Called from: ${StackTrace.current.toString().split('\n')[1]}',
      );

      final currentUser = await UserService.getCurrentUser();
      final supabaseUser = Supabase.instance.client.auth.currentUser;

      if (currentUser == null) {
        debugPrint(
          'ℹ️ [LOBBY] No current user found in local memory, skipping network load',
        );
        _friendsLoaded = true;
        _isLoadingFromNetwork = false;
        notifyListeners();
        return;
      }

      debugPrint(
        '✅ [LOBBY] Session Check: LocalId=${currentUser.id}, SupabaseUid=${supabaseUser?.id}',
      );
      if (supabaseUser?.id != currentUser.id) {
        debugPrint('⚠️ [LOBBY] AUTH MISMATCH! RLS will block network results.');
      }

      // Initialize global listeners
      if (_globalMessagesSubscription == null) {
        debugPrint(
          '📡 [LOBBY] Setting up message subscription for ${currentUser.id}...',
        );
        _globalMessagesSubscription = SupabaseService.instance
            .listenToAllUserMessages(currentUser.id, (payload) {
              _handleRealtimeMessageEvent(payload, currentUser.id);
            });
      }
      if (_followSubscription == null) {
        debugPrint('📡 [LOBBY] Setting up follow subscription...');
        _followSubscription = SupabaseService.instance.listenToUserFollows(
          currentUser.id,
          (data) => _handleFollowEvent(data),
        );
      }
      if (_profilesSubscription == null) {
        debugPrint('📡 [LOBBY] Setting up profiles listener...');
        _setupProfilesListener();
      }
      if (_presenceChannel == null) {
        debugPrint('📡 [LOBBY] Setting up presence for ${currentUser.id}...');
        _setupPresence(currentUser.id);
      }

      _isLoadingFromNetwork = true;
      notifyListeners();

      debugPrint('🚀 [LOBBY] Fetching data via SupabaseService...');
      final supabaseService = SupabaseService.instance;

      // Single source of truth: the v_chat_lobby view
      debugPrint(
        '🚀 [LOBBY] Awaiting getUserConversations and getBlockedUserIds...',
      );
      final results =
          await Future.wait([
            supabaseService.getUserConversations(currentUser.id),
            supabaseService.getBlockedUserIds(),
          ]).timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              debugPrint('⚠️ [LOBBY] Fetch TIMEOUT after 15s');
              return [[], []];
            },
          );

      final List<Map<String, dynamic>> conversationData = (results[0] as List)
          .cast<Map<String, dynamic>>();
      final List<String> blockedUserIds = (results[1] as List).cast<String>();

      debugPrint(
        '🚀 [LOBBY] Received ${conversationData.length} conversations and ${blockedUserIds.length} blocked users',
      );

      _blockedUsers.clear();
      _blockedUsers.addAll(blockedUserIds);

      final List<Friend> friendsList = [];

      // 1. Map conversations directly from view
      int parseCount = 0;
      for (final conv in conversationData) {
        try {
          final friend = Friend.fromJson(conv);
          if (!blockedUserIds.contains(friend.id)) {
            friendsList.add(friend);
            parseCount++;
          }
        } catch (e) {
          debugPrint('⚠️ [LOBBY] Error parsing conversation: $e');
          debugPrint('⚠️ [LOBBY] Raw data that failed: $conv');
        }
      }
      debugPrint(
        '🚀 [LOBBY] Successfully parsed $parseCount friends from server data',
      );

      // 2. Ensure Self-chat exists
      if (!friendsList.any((f) => f.id == currentUser.id)) {
        debugPrint('🚀 [LOBBY] Adding Self-chat tile');
        friendsList.add(
          Friend(
            id: currentUser.id,
            name: 'You',
            handle: currentUser.handle,
            virtualNumber: currentUser.virtualNumber ?? '',
            avatar: currentUser.profilePicture ?? '👤',
            lastMessage: 'Message yourself',
            lastMessageTime: DateTime.now().subtract(const Duration(days: 366)),
            unreadCount: 0,
            isOnline: true,
            isArchived: false,
          ),
        );
      }

      // 3. Ensure Boofer tile exists (use real data from v_chat_lobby when available)
      // The welcome-message trigger guarantees boofer always has a message row,
      // so v_chat_lobby should return it with the correct unread_count.
      // We only add a fallback if somehow it’s missing (e.g. the trigger hasn’t fired yet).
      if (!friendsList.any((f) => f.id == AppConstants.booferId)) {
        debugPrint(
          '🚀 [LOBBY] Boofer not in lobby yet — adding placeholder tile',
        );
        friendsList.add(
          Friend(
            id: AppConstants.booferId,
            name: 'Boofer',
            handle: 'boofer',
            virtualNumber: 'BOOFER-001',
            avatar: '🛣️',
            lastMessage: 'Welcome to Boofer! 🛣️',
            lastMessageTime: DateTime.now().subtract(const Duration(days: 300)),
            unreadCount:
                0, // safe fallback — real count comes from v_chat_lobby
            isOnline: true,
            isArchived: false,
          ),
        );
      }

      _friends = friendsList;

      // Sort: Most recent message first
      _friends.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
      debugPrint(
        '🚀 [LOBBY] Total friends in list (including officials): ${_friends.length}',
      );

      _isLoadingFromNetwork = false;
      _friendsLoaded = true;
      debugPrint('✅ [LOBBY] _loadRealFriends completed. Notifying listeners.');
      notifyListeners();
    } catch (e, stack) {
      debugPrint('❌ [LOBBY] CRITICAL Load Error: $e');
      debugPrint('❌ [LOBBY] STACK: $stack');
      _isLoadingFromNetwork = false;
      _friendsLoaded = true; // Still mark as loaded to show UI
      notifyListeners();
    } finally {
      _isRefreshing = false;
    }
  }

  // ... (rest of the file from refreshFriends onwards)

  // Refresh friends list
  Future<void> refreshFriends() async {
    // Explicitly set forceRefresh to true when user pulls to refresh
    await _loadRealFriends(forceRefresh: true);
  }

  // Chat management methods
  List<Friend> get activeChats {
    if (ScreenshotMode.isEnabled) return ScreenshotMode.dummyActiveChats;
    final active = _friends.where((friend) => !friend.isArchived).toList();
    active.sort((a, b) {
      // Sort pinned chats first
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;

      // Then by last message time if both or neither are pinned
      return b.lastMessageTime.compareTo(a.lastMessageTime);
    });
    return active;
  }

  /// Returns all shareable friends (all related users)
  List<Friend> get allShareableFriends {
    return _friends.where((f) => f.id != AppConstants.booferId).toList();
  }

  List<Friend> get archivedChats {
    if (ScreenshotMode.isEnabled) return ScreenshotMode.dummyArchivedChats;
    return _archivedFriends;
  }

  bool isChatMuted(String chatId) {
    return _mutedChats.contains(chatId);
  }

  bool isChatArchived(String chatId) {
    return _archivedFriends.any((friend) => friend.id == chatId) ||
        _friends.any((friend) => friend.id == chatId && friend.isArchived);
  }

  Future<void> archiveChat(String chatId) async {
    final friendIndex = _friends.indexWhere((friend) => friend.id == chatId);
    if (friendIndex != -1) {
      final friend = _friends[friendIndex];
      _friends.removeAt(friendIndex);
      _archivedFriends.add(friend.copyWith(isArchived: true));
      notifyListeners();
    }
  }

  Future<void> unarchiveChat(String chatId) async {
    final friendIndex = _archivedFriends.indexWhere(
      (friend) => friend.id == chatId,
    );
    if (friendIndex != -1) {
      final friend = _archivedFriends[friendIndex];
      _archivedFriends.removeAt(friendIndex);
      _friends.add(friend.copyWith(isArchived: false));
      notifyListeners();
    }
  }

  Future<void> muteChat(String chatId) async {
    _mutedChats.add(chatId);
    notifyListeners();
  }

  Future<void> unmuteChat(String chatId) async {
    _mutedChats.remove(chatId);
    notifyListeners();
  }

  bool isChatPinned(String chatId) {
    // Check if the friend is pinned by looking at the _friends list
    try {
      final friend = _friends.firstWhere((f) => f.id == chatId);
      return friend.isPinned;
    } catch (_) {
      return false;
    }
  }

  Future<void> pinChat(String chatId) async {
    final friendIndex = _friends.indexWhere((friend) => friend.id == chatId);
    if (friendIndex != -1) {
      _friends[friendIndex] = _friends[friendIndex].copyWith(isPinned: true);

      // Re-sort active chats implicitly by updating list order or letting getter handle sort
      // Since activeChats getter re-sorts, we just need to notify.
      // But we should probably also update cache to persist pinning.
      final currentUser = await UserService.getCurrentUser();
      if (currentUser != null) {
        await ChatCacheService.instance.cacheFriends(currentUser.id, _friends);
      }

      notifyListeners();
    }
  }

  Future<void> unpinChat(String chatId) async {
    final friendIndex = _friends.indexWhere((friend) => friend.id == chatId);
    if (friendIndex != -1) {
      _friends[friendIndex] = _friends[friendIndex].copyWith(isPinned: false);

      final currentUser = await UserService.getCurrentUser();
      if (currentUser != null) {
        await ChatCacheService.instance.cacheFriends(currentUser.id, _friends);
      }

      notifyListeners();
    }
  }

  Future<bool> markAsRead(String chatId) async {
    final friendIndex = _friends.indexWhere((friend) => friend.id == chatId);
    if (friendIndex != -1) {
      _friends[friendIndex] = _friends[friendIndex].copyWith(unreadCount: 0);
      notifyListeners();

      try {
        final currentUser = await UserService.getCurrentUser();
        if (currentUser != null) {
          final conversationId = _chatService.getConversationId(
            currentUser.id,
            chatId,
          );
          await SupabaseService.instance.markConversationAsRead(
            conversationId,
            chatId, // Assuming chatId is the friend's user ID (sender of messages)
          );
        }
      } catch (e) {
        debugPrint('❌ Error syncing read status: $e');
      }

      return true;
    }
    return false;
  }

  Future<bool> markAsUnread(String chatId) async {
    final friendIndex = _friends.indexWhere((friend) => friend.id == chatId);
    if (friendIndex != -1) {
      _friends[friendIndex] = _friends[friendIndex].copyWith(unreadCount: 1);
      notifyListeners();
      return true;
    }
    return false;
  }

  bool isUserBlocked(String userId) {
    return _blockedUsers.contains(userId);
  }

  Future<void> blockUser(String userId) async {
    _blockedUsers.add(userId);
    notifyListeners();

    try {
      await SupabaseService.instance.blockUser(userId);
    } catch (e) {
      _blockedUsers.remove(userId);
      notifyListeners();
      debugPrint('❌ Failed to block user: $e');
      throw e;
    }
  }

  Future<void> unblockUser(String userId) async {
    _blockedUsers.remove(userId);
    notifyListeners();

    try {
      await SupabaseService.instance.unblockUser(userId);
    } catch (e) {
      _blockedUsers.add(userId);
      notifyListeners();
      debugPrint('❌ Failed to unblock user: $e');
      throw e;
    }
  }

  Future<void> deleteChat(String chatId) async {
    final deletedFriends = _friends.where((f) => f.id == chatId).toList();
    final deletedArchived = _archivedFriends
        .where((f) => f.id == chatId)
        .toList();

    _friends.removeWhere((friend) => friend.id == chatId);
    _archivedFriends.removeWhere((friend) => friend.id == chatId);
    _mutedChats.remove(chatId);
    // Do not remove from blocked users if deleting chat

    notifyListeners();

    try {
      await SupabaseService.instance.deleteConversation(chatId);
    } catch (e) {
      // Revert if failed (optimistic UI update revert)
      if (deletedFriends.isNotEmpty) {
        _friends.addAll(deletedFriends);
        _friends.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
      }
      if (deletedArchived.isNotEmpty) {
        _archivedFriends.addAll(deletedArchived);
      }
      notifyListeners();
      debugPrint('❌ Failed to delete chat: $e');
      rethrow;
    }
  }

  /// Check if a specific user is online
  bool isUserOnline(String userId) {
    if (userId == booferId) return true; // Boofer is always online

    // Check live presence first
    if (getRecipientPresence(userId) != null) return true;

    final friend = _friends.firstWhere(
      (f) => f.id == userId,
      orElse: () => Friend(
        id: userId,
        name: '',
        handle: '',
        virtualNumber: '',
        lastMessage: '',
        lastMessageTime: DateTime.now(),
      ),
    );
    return friend.isOnline;
  }

  /// Check if a user is a mutual friend
  bool isMutualFriend(String userId) {
    if (userId == booferId) return true;
    try {
      final friend = _friends.firstWhere((f) => f.id == userId);
      return friend.isMutual;
    } catch (_) {
      return false;
    }
  }

  void _setupPresence(String userId) {
    final supabase = Supabase.instance.client;
    final supabaseService = SupabaseService.instance;

    // Update profile status to online when starting
    supabaseService.updateUserStatus('online');
    // Mark ALL pending messages as delivered since we just came online
    supabaseService.markMessagesAsDelivered(userId);

    _presenceChannel = supabase.channel('presence:global');

    _presenceChannel!
        .onPresenceSync((payload) {
          _updateFriendsOnlineStatus();
        })
        .subscribe((status, error) async {
          if (status == RealtimeSubscribeStatus.subscribed) {
            await _presenceChannel!.track({
              'user_id': userId,
              'online_at': DateTime.now().toIso8601String(),
              'current_conversation_id': _currentConversationId,
            });
          }
        });

    // Monitor connectivity and app lifecycle
    _connectivitySubscription?.cancel();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      result,
    ) {
      final hasInternet = result != ConnectivityResult.none;
      _isAppOnline = hasInternet;
      notifyListeners();

      if (hasInternet) {
        supabaseService.updateUserStatus('online');
        supabaseService.markMessagesAsDelivered(userId);
        if (_presenceChannel != null) {
          _presenceChannel!.track({
            'user_id': userId,
            'online_at': DateTime.now().toIso8601String(),
            'current_conversation_id': _currentConversationId,
          });
        }
      } else {
        _setAllFriendsOffline();
      }
    });
  }

  /// Update presence tracking with current conversation ID
  Future<void> updatePresenceWithConversationId(String? conversationId) async {
    _currentConversationId = conversationId;
    if (_presenceChannel != null) {
      final currentUser = await UserService.getCurrentUser();
      if (currentUser != null) {
        await _presenceChannel!.track({
          'user_id': currentUser.id,
          'online_at': DateTime.now().toIso8601String(),
          'current_conversation_id': conversationId,
        });
      }
    }
    notifyListeners();
  }

  void _updateFriendsOnlineStatus() {
    if (_presenceChannel == null) return;

    final state = _presenceChannel!.presenceState();
    final onlineUserIds = <String>{};

    for (final presence in state) {
      for (final p in presence.presences) {
        final id = p.payload['user_id'] as String?;
        if (id != null) onlineUserIds.add(id);
      }
    }

    bool changed = false;
    for (int i = 0; i < _friends.length; i++) {
      final isOnline = onlineUserIds.contains(_friends[i].id);
      if (_friends[i].isOnline != isOnline) {
        _friends[i] = _friends[i].copyWith(isOnline: isOnline);
        changed = true;
      }
    }

    if (changed) {
      notifyListeners();
    }
  }

  void _setupProfilesListener() {
    final supabase = Supabase.instance.client;
    _profilesSubscription = supabase
        .channel('public:profiles')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'profiles',
          callback: (payload) {
            final data = payload.newRecord;
            final userId = data['id'];
            final status = data['status'] as String?;

            if (userId != null && status != null) {
              final index = _friends.indexWhere((f) => f.id == userId);
              if (index != -1) {
                final isOnline = status == 'online';
                if (_friends[index].isOnline != isOnline) {
                  _friends[index] = _friends[index].copyWith(
                    isOnline: isOnline,
                  );
                  notifyListeners();
                }
              }
            }
          },
        )
        .subscribe();
  }

  Future<void> _handleRealtimeMessageEvent(
    Map<String, dynamic> payload,
    String currentUserId,
  ) async {
    final eventType = payload['eventType'] as String;
    final record = payload['record'] as Map<String, dynamic>?;
    if (record == null) return;

    final senderId = record['sender_id'] as String?;
    final receiverId = record['receiver_id'] as String?;
    if (senderId == null || receiverId == null) return;

    // Determine the friend ID
    final friendId = senderId == currentUserId ? receiverId : senderId;

    // Handle NEW messages (Status: Delivered logic)
    if (eventType == 'insert') {
      if (receiverId == currentUserId) {
        // We received a message - mark it as delivered in DB
        // If we are looking at this conversation, mark as read instead
        final messageId = record['id'] as String?;
        final conversationId = record['conversation_id'] as String?;
        if (messageId != null) {
          if (_currentConversationId == conversationId) {
            SupabaseService.instance.updateMessageStatus(
              messageId,
              MessageStatus.read,
            );
          } else {
            SupabaseService.instance.updateMessageStatus(
              messageId,
              MessageStatus.delivered,
            );
          }
        }
      }

      // Update lobby list
      final index = _friends.indexWhere((f) => f.id == friendId);
      final messageText = (record['text'] ?? '').toString();
      final timeStr = record['timestamp'];
      final timestamp = timeStr != null
          ? DateTime.parse(timeStr.toString())
          : DateTime.now();

      if (index != -1) {
        var friend = _friends[index];
        int newUnread = friend.unreadCount;

        // ONLY increment unread if WE received it (not sent by us),
        // we aren't already looking at this chat,
        // and the message isn't already marked as read.
        if (receiverId == currentUserId &&
            senderId != currentUserId &&
            record['status'] != 'read' &&
            _currentConversationId != record['conversation_id']) {
          newUnread++;
        }

        // If WE sent the message into a conversation we have open, reset unread to 0
        if (senderId == currentUserId &&
            _currentConversationId == record['conversation_id']) {
          newUnread = 0;
        }

        final isEncrypted = record['is_encrypted'] ?? false;
        final encryptedContent = record['encrypted_content'];

        // Use decrypted text from the realtime service; it's already decrypted before reaching here
        // If it's still empty but was encrypted, mark it as [Encrypted]
        final displayMessage = messageText.isNotEmpty
            ? messageText
            : (isEncrypted ? '[Encrypted]' : '');

        final updatedFriend = friend.copyWith(
          lastMessage: displayMessage,
          lastMessageTime: timestamp,
          unreadCount: newUnread,
          isLastMessageEncrypted: isEncrypted,
          lastMessageEncryptedContent: encryptedContent is String
              ? jsonDecode(encryptedContent)
              : (encryptedContent != null
                    ? Map<String, dynamic>.from(encryptedContent)
                    : null),
          lastSenderId: senderId,
          lastMessageStatus: MessageStatus.values.firstWhere(
            (e) => e.name == (record['status'] ?? 'sent'),
            orElse: () => MessageStatus.sent,
          ),
        );

        _friends.removeAt(index);
        _friends.insert(0, updatedFriend);
        notifyListeners();

        // 🎯 Trigger System Notification (only for received messages, not our own sends)
        final sortedIds = [currentUserId, friendId]..sort();
        final convId = 'conv_${sortedIds[0]}_${sortedIds[1]}';
        final isSelfMessage =
            senderId == currentUserId && receiverId == currentUserId;
        final isViewingThisConversation = _currentConversationId == convId;

        if ((receiverId == currentUserId || isSelfMessage) &&
            !isViewingThisConversation) {
          NotificationService.instance.showMessageNotification(
            senderName: isSelfMessage ? 'Note to yourself' : updatedFriend.name,
            message: updatedFriend.lastMessage,
            conversationId: convId,
          );
        }
      } else {
        // Friend not in list yet — do a full refresh to load them
        refreshFriends();
      }
    }
    // Handle status UPDATES (Status: Read logic)
    else if (eventType == 'update') {
      final statusStr = record['status'] as String?;
      final messageId = record['id'] as String?;

      if (statusStr == null || messageId == null) return;

      final index = _friends.indexWhere((f) => f.id == friendId);
      if (index != -1) {
        // Update status for the lobby if this was the last message
        final status = MessageStatus.values.firstWhere(
          (e) => e.name == statusStr,
          orElse: () => MessageStatus.sent,
        );

        bool changed = false;
        if (_friends[index].lastMessageStatus != status) {
          _friends[index] = _friends[index].copyWith(lastMessageStatus: status);
          changed = true;
        }

        // If status changed to 'read' AND it was a message sent TO the current user
        if (statusStr == 'read' && receiverId == currentUserId) {
          if (_friends[index].unreadCount > 0) {
            _friends[index] = _friends[index].copyWith(
              unreadCount: _friends[index].unreadCount - 1,
            );
            changed = true;
          }
        }

        if (changed) {
          notifyListeners();
        }
      }
    }
  }

  void _handleFollowEvent(Map<String, dynamic> data) async {
    try {
      final followerId = data['follower_id'];
      if (followerId == null) return;

      final followerProfile = await SupabaseService.instance.getUserProfile(
        followerId,
      );
      if (followerProfile != null) {
        NotificationService.instance.showSystemNotification(
          title: 'New Follower',
          body:
              '${followerProfile.fullName} (@${followerProfile.handle}) is now following you!',
        );
        // Refresh friends to show them in lobby if it's mutual now
        refreshFriends();
      }
    } catch (e) {
      debugPrint('Error handling follow event: $e');
    }
  }

  void _setAllFriendsOffline() {
    bool changed = false;
    for (int i = 0; i < _friends.length; i++) {
      if (_friends[i].isOnline) {
        _friends[i] = _friends[i].copyWith(isOnline: false);
        changed = true;
      }
    }
    if (changed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    _newMessageSubscription?.cancel();
    _connectivitySubscription?.cancel();

    // Update status to offline before leaving
    SupabaseService.instance.updateUserStatus('offline');

    if (_globalMessagesSubscription != null) {
      SupabaseService.instance.removeChannel(_globalMessagesSubscription!);
    }
    if (_followSubscription != null) {
      SupabaseService.instance.removeChannel(_followSubscription!);
    }
    if (_presenceChannel != null) {
      Supabase.instance.client.removeChannel(_presenceChannel!);
    }
    if (_profilesSubscription != null) {
      Supabase.instance.client.removeChannel(_profilesSubscription!);
    }
    super.dispose();
  }
}
