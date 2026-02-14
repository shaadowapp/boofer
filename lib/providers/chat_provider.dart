import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/error/error_handler.dart';
import '../core/models/app_error.dart';
import '../services/follow_service.dart';
import '../services/chat_service.dart';
import '../services/user_service.dart';
import '../models/message_model.dart';
import '../models/friend_model.dart';
import '../models/user_model.dart';
import '../services/supabase_service.dart';
import '../services/chat_cache_service.dart';
import '../core/constants.dart';

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

  // Real friends data from Firestore
  List<Friend> _friends = [];
  final List<Friend> _archivedFriends = [];
  final Set<String> _mutedChats = {};
  final Set<String> _blockedUsers = {};
  bool _friendsLoaded = false;
  bool _isLoadingFromNetwork = false;
  bool _isAppOnline = true; // Assume online initially

  // Load real friends from Firestore with WhatsApp-style caching
  Future<void> _loadRealFriends({bool forceRefresh = false}) async {
    try {
      final currentUser = await UserService.getCurrentUser();
      if (currentUser == null) {
        print('⚠️ No current user found, cannot load friends');
        _friendsLoaded = true;
        notifyListeners();
        return;
      }

      print(
        '📱 Loading friends with cache-first strategy (Force: $forceRefresh)',
      );

      // Start global realtime listener for lobby updates
      if (_globalMessagesSubscription == null) {
        _globalMessagesSubscription = SupabaseService.instance
            .listenToAllUserMessages(currentUser.id, (payload) {
              _handleRealtimeMessageEvent(payload, currentUser.id);
            });
      }

      // Start global profile status listener
      if (_profilesSubscription == null) {
        _setupProfilesListener();
      }

      // Start global presence listener
      if (_presenceChannel == null) {
        _setupPresence(currentUser.id);
      }

      final cacheService = ChatCacheService.instance;

      // STEP 1: Load from cache immediately (stale-while-revalidate)
      final cachedFriends = await cacheService.getCachedFriends(currentUser.id);
      if (cachedFriends.isNotEmpty) {
        _friends = cachedFriends;
        _friendsLoaded = true;
        notifyListeners();
        print('✅ Loaded ${cachedFriends.length} friends from cache (instant)');
      }

      // STEP 2: Handle Throttling for manual refreshes
      if (forceRefresh) {
        final isThrottled = await cacheService.isFriendsRefreshThrottled();
        if (isThrottled) {
          print('⏳ Friends refresh throttled. Using cache.');
          _friendsLoaded = true;
          notifyListeners();
          return;
        }
      }

      // STEP 3: Check if cache is still valid
      final isCacheValid = await cacheService.isFriendsCacheValid();

      if (!forceRefresh && isCacheValid && cachedFriends.isNotEmpty) {
        print('✅ Friends cache is fresh (<24h), skipping network call');
        _friendsLoaded = true;
        notifyListeners();
        return;
      }

      // STEP 4: Fetch from network
      print('🔄 Fetching fresh conversations and friends from network...');
      _isLoadingFromNetwork = true;

      final supabaseService = SupabaseService.instance;
      final followService = FollowService.instance;

      // 1. Get ALL previous conversations from the messages table
      final conversationData = await supabaseService.getUserConversations(
        currentUser.id,
      );

      // 2. Get mutual friends (for people we haven't talked to yet)
      final friendUsers = await followService.getFriends(
        userId: currentUser.id,
      );

      // 2.1 Get blocked users
      try {
        final blockedIds = await supabaseService.getBlockedUserIds();
        _blockedUsers.addAll(blockedIds);
      } catch (e) {
        print('⚠️ Failed to load blocked users: $e');
      }

      // Map to keep track of friends we've processed from conversations
      final Set<String> processedUserIds = {};
      final List<Friend> combinedFriends = [];

      // 3. Process Conversations (Priority)
      for (final conv in conversationData) {
        final otherUser = conv['otherUser'];
        final friendId = otherUser['id'];
        processedUserIds.add(friendId);

        combinedFriends.add(
          Friend(
            id: friendId,
            name: otherUser['name'],
            handle: otherUser['handle'],
            virtualNumber: otherUser['virtualNumber'] ?? 'No number',
            avatar: otherUser['avatar'],
            lastMessage: conv['lastMessage'] ?? '',
            lastMessageTime: DateTime.parse(conv['lastMessageTime']),
            unreadCount: 0, // Will be updated by lobby count logic if needed
            isOnline: otherUser['status'] == 'online',
            isArchived: false,
          ),
        );
      }

      // 4. Add friends who we haven't messaged yet
      for (final user in friendUsers) {
        if (!processedUserIds.contains(user.id)) {
          combinedFriends.add(
            Friend(
              id: user.id,
              name: user.fullName,
              handle: user.handle,
              virtualNumber: user.virtualNumber ?? 'No number',
              avatar: user.profilePicture,
              lastMessage: '', // No message yet
              lastMessageTime: DateTime.now().subtract(
                const Duration(days: 365),
              ),
              unreadCount: 0,
              isOnline: user.status == UserStatus.online,
              isArchived: false,
            ),
          );
        }
      }

      _friends = combinedFriends;

      // Sort: Most recent message first
      _friends.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));

      // 5. Ensure "You" (Self-chat) is present if we have messaged ourselves
      if (!_friends.any((f) => f.id == currentUser.id)) {
        // Only add if there was a self conversation found above or if we want to force it
        // For now, only add if conversation exists
      }

      // 6. ALWAYS ensure Boofer is present
      if (!_friends.any((f) => f.id == AppConstants.booferId)) {
        Friend booferFriend = Friend(
          id: AppConstants.booferId,
          name: 'Boofer',
          handle: 'boofer',
          virtualNumber: 'BOOFER-001',
          avatar: '🛸',
          lastMessage: 'Welcome to Boofer! 🛸',
          lastMessageTime: DateTime.now(),
          unreadCount: 0,
          isOnline: true,
          isArchived: false,
        );
        _friends.insert(0, booferFriend);
      }

      // Re-sort after adding special contacts to ensure time order is respected
      _friends.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));

      // STEP 5: Update cache
      await cacheService.cacheFriends(currentUser.id, _friends);
      print('💾 Cached ${_friends.length} friends locally');

      _friendsLoaded = true;
      _isLoadingFromNetwork = false;
      notifyListeners();
    } catch (e) {
      print('❌ Error loading friends: $e');
      _friendsLoaded = true;
      _isLoadingFromNetwork = false;
      notifyListeners();
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
    return _friends.where((friend) => !friend.isArchived).toList();
  }

  List<Friend> get archivedChats {
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

  Future<bool> markAsRead(String chatId) async {
    final friendIndex = _friends.indexWhere((friend) => friend.id == chatId);
    if (friendIndex != -1) {
      _friends[friendIndex] = _friends[friendIndex].copyWith(unreadCount: 0);
      notifyListeners();
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
      print('❌ Failed to block user: $e');
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
      print('❌ Failed to unblock user: $e');
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
      print('❌ Failed to delete chat: $e');
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
          if (status == 'SUBSCRIBED') {
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

  void _handleRealtimeMessageEvent(
    Map<String, dynamic> payload,
    String currentUserId,
  ) {
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
      final messageText = record['text'] ?? '';
      final timeStr = record['timestamp'];
      final timestamp = timeStr != null
          ? DateTime.parse(timeStr)
          : DateTime.now();

      if (index != -1) {
        var friend = _friends[index];
        int newUnread = friend.unreadCount;
        if (receiverId == currentUserId) {
          newUnread++;
        }

        final updatedFriend = friend.copyWith(
          lastMessage: messageText,
          lastMessageTime: timestamp,
          unreadCount: newUnread,
        );

        _friends.removeAt(index);
        _friends.insert(0, updatedFriend);
        notifyListeners();
      } else {
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
        // If status changed to 'read' AND it was a message sent TO the current user
        if (statusStr == 'read' && receiverId == currentUserId) {
          // We need to verify if this message was previously counted as unread.
          // Since we don't track per-message unread status in the Friend model easily without a list,
          // we can decrement the count if it's > 0.
          // A more robust way would be to fetch the fresh count, but decrementing is faster for UI.
          if (_friends[index].unreadCount > 0) {
            _friends[index] = _friends[index].copyWith(
              unreadCount: _friends[index].unreadCount - 1,
            );
          }
        }
        notifyListeners();
      }
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
    if (_presenceChannel != null) {
      Supabase.instance.client.removeChannel(_presenceChannel!);
    }
    if (_profilesSubscription != null) {
      Supabase.instance.client.removeChannel(_profilesSubscription!);
    }
    super.dispose();
  }
}
