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

  // Load real friends from Firestore
  Future<void> _loadRealFriends() async {
    try {
      final currentUser = await UserService.getCurrentUser();
      if (currentUser == null) {
        print('⚠️ No current user found, cannot load friends');
        _friendsLoaded = true;
        notifyListeners();
        return;
      }

      print('📱 Loading real friends for user: ${currentUser.id}');

      final followService = FollowService.instance;
      final friendUsers = await followService.getFriends(
        userId: currentUser.id,
      );

      print('✅ Loaded ${friendUsers.length} friends from Firestore');

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
              : DateTime.now().subtract(
                  const Duration(days: 30),
                ), // Old if no messages
          unreadCount: 0,
          isOnline: user.status == UserStatus.online,
          isArchived: false,
        );
      }).toList();

      // ALWAYS add Boofer Official to the list if not already present
      if (!_friends.any((f) => f.id == booferId)) {
        final booferConv = convMap[booferId];
        _friends.insert(
          0,
          Friend(
            id: booferId,
            name: 'Boofer Official',
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
          ),
        );
      }

      _friendsLoaded = true;
      notifyListeners();
    } catch (e) {
      print('❌ Error loading friends: $e');
      _friendsLoaded = true;
      notifyListeners();
    }
  }

  // Refresh friends list
  Future<void> refreshFriends() async {
    _friendsLoaded = false;
    await _loadRealFriends();
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
