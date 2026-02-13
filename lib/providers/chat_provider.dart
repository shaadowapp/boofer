import 'dart:async';
import 'package:flutter/material.dart';
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

  StreamSubscription<List<Message>>? _messagesSubscription;
  StreamSubscription<Message>? _newMessageSubscription;

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
        _messages.add(message);
        notifyListeners();
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
      await _chatService.sendMessage(
        conversationId: conversationId,
        senderId: senderId,
        content: content,
        receiverId: receiverId,
        type: type,
      );
    } catch (e) {
      _handleError(e);
      rethrow;
    }
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
    notifyListeners();
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    _newMessageSubscription?.cancel();
    super.dispose();
  }

  // Real friends data from Firestore
  List<Friend> _friends = [];
  final List<Friend> _archivedFriends = [];
  final Set<String> _mutedChats = {};
  final Set<String> _blockedUsers = {};
  bool _friendsLoaded = false;
  bool _isLoadingFromNetwork = false;

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
      print('🔄 Fetching fresh friends data from network...');
      _isLoadingFromNetwork = true;

      final followService = FollowService.instance;
      final friendUsers = await followService.getFriends(
        userId: currentUser.id,
      );

      print('✅ Loaded ${friendUsers.length} friends from network');

      // Fetch latest conversation data to get last messages
      final supabaseService = SupabaseService.instance;
      final conversationData = await supabaseService.getUserConversations(
        currentUser.id,
      );

      // Create a map for quick lookup
      final convMap = {
        for (var conv in conversationData)
          (conv['participants'] as List).firstWhere(
            (id) => id != currentUser.id,
            orElse: () => '',
          ): conv,
      };

      // Convert User objects to Friend objects
      _friends = friendUsers.map((user) {
        final conv = convMap[user.id];

        return Friend(
          id: user.id,
          name: user.fullName,
          handle: user.handle,
          virtualNumber: user.virtualNumber ?? 'No number',
          avatar: user.profilePicture,
          lastMessage: conv?['lastMessage'] ?? 'Start a conversation',
          lastMessageTime: conv != null
              ? DateTime.parse(conv['lastMessageTime'])
              : DateTime.now().subtract(const Duration(days: 30)),
          unreadCount: 0,
          isOnline: user.status == UserStatus.online,
          isArchived: false,
        );
      }).toList();

      // ALWAYS add self-chat "You" to the list if a conversation exists
      if (!_friends.any((f) => f.id == currentUser.id)) {
        final selfConv = convMap[currentUser.id];
        if (selfConv != null) {
          _friends.insert(
            0,
            Friend(
              id: currentUser.id,
              name: 'You (${currentUser.fullName})',
              handle: currentUser.handle,
              virtualNumber: currentUser.virtualNumber ?? 'SELF-000',
              avatar: currentUser.avatar,
              lastMessage: selfConv['lastMessage'] ?? 'Message yourself',
              lastMessageTime: selfConv['lastMessageTime'] != null
                  ? DateTime.parse(selfConv['lastMessageTime'])
                  : DateTime.now(),
              unreadCount: 0,
              isOnline: true,
              isArchived: false,
            ),
          );
        }
      }

      // ALWAYS ensure Boofer is present and has correct name
      final booferIndex = _friends.indexWhere(
        (f) => f.id == AppConstants.booferId,
      );
      final booferConv = convMap[AppConstants.booferId];

      final booferFriend = Friend(
        id: AppConstants.booferId,
        name: 'Boofer',
        handle: 'boofer',
        virtualNumber: 'BOOFER-001',
        avatar: '🛸',
        lastMessage: booferConv?['lastMessage'] ?? 'Welcome to Boofer! 🛸',
        lastMessageTime: booferConv != null
            ? DateTime.parse(booferConv['lastMessageTime'])
            : DateTime.now(),
        unreadCount: 0,
        isOnline: true,
        isArchived: false,
      );

      if (booferIndex != -1) {
        // Update existing entry
        _friends[booferIndex] = booferFriend;
      } else {
        // Insert new entry
        _friends.insert(0, booferFriend);
      }

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
  }

  Future<void> unblockUser(String userId) async {
    _blockedUsers.remove(userId);
    notifyListeners();
  }

  Future<void> deleteChat(String chatId) async {
    _friends.removeWhere((friend) => friend.id == chatId);
    _archivedFriends.removeWhere((friend) => friend.id == chatId);
    _mutedChats.remove(chatId);
    _blockedUsers.remove(chatId);
    notifyListeners();
  }
}
