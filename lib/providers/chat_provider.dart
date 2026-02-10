import 'dart:async';
import 'package:flutter/material.dart';
import '../core/error/error_handler.dart';
import '../core/models/app_error.dart';
import '../services/chat_service.dart';
import '../services/user_service.dart';
import '../models/message_model.dart';
import '../models/friend_model.dart';

class ChatProvider with ChangeNotifier {
  final ChatService _chatService;
  final ErrorHandler _errorHandler;
  
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
  }) : _chatService = chatService, _errorHandler = errorHandler {
    _initializeSubscriptions();
    _initializeDemoData();
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
    
    _newMessageSubscription = _chatService.newMessageStream.listen(
      (message) {
        if (message.conversationId == _currentConversationId) {
          _messages.add(message);
          notifyListeners();
        }
      },
    );
  }
  
  Future<void> loadMessages(String conversationId) async {
    if (_currentConversationId == conversationId && _messages.isNotEmpty) return;
    
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
      return await _chatService.searchMessages(query, conversationId: _currentConversationId);
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
      _errorHandler.handleError(AppError.service(
        message: error.toString(),
        originalException: error is Exception ? error : Exception(error.toString()),
      ));
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

  // Demo friends data for UI design
  List<Friend> _demoFriends = [];
  List<Friend> _archivedFriends = [];
  final Set<String> _mutedChats = {};
  final Set<String> _blockedUsers = {};

  // Initialize demo data
  void _initializeDemoData() {
    _demoFriends = [
      Friend(
        id: '1',
        name: 'Alex Johnson',
        handle: 'alex_nyc',
        virtualNumber: '555-123-4567',
        lastMessage: 'Hey! How are you doing? 😊',
        lastMessageTime: DateTime.now().subtract(const Duration(minutes: 5)),
        unreadCount: 2,
        isOnline: true,
      ),
      Friend(
        id: '2',
        name: 'Sarah Wilson',
        handle: 'sarah_coffee',
        virtualNumber: '555-234-5678',
        lastMessage: 'Thanks for the help earlier 👍',
        lastMessageTime: DateTime.now().subtract(const Duration(hours: 1)),
        unreadCount: 0,
        isOnline: true,
      ),
      Friend(
        id: '3',
        name: 'Mike Chen',
        handle: 'mike_tech',
        virtualNumber: '555-345-6789',
        lastMessage: 'See you tomorrow at the meeting!',
        lastMessageTime: DateTime.now().subtract(const Duration(hours: 3)),
        unreadCount: 1,
        isOnline: false,
      ),
      Friend(
        id: '4',
        name: 'Emma Davis',
        handle: 'emma_artist',
        virtualNumber: '555-456-7890',
        lastMessage: 'The presentation went great 🎉',
        lastMessageTime: DateTime.now().subtract(const Duration(days: 1)),
        unreadCount: 0,
        isOnline: false,
      ),
      Friend(
        id: '5',
        name: 'James Brown',
        handle: 'james_music',
        virtualNumber: '555-567-8901',
        lastMessage: 'Can you send me those files when you get a chance?',
        lastMessageTime: DateTime.now().subtract(const Duration(days: 2)),
        unreadCount: 3,
        isOnline: true,
      ),
      Friend(
        id: '6',
        name: 'Lisa Garcia',
        handle: 'lisa_travel',
        virtualNumber: '555-678-9012',
        lastMessage: 'Happy birthday! Hope you have a great day 🎂',
        lastMessageTime: DateTime.now().subtract(const Duration(days: 3)),
        unreadCount: 0,
        isOnline: false,
      ),
      Friend(
        id: '7',
        name: 'David Kim',
        handle: 'david_dev',
        virtualNumber: '555-789-0123',
        lastMessage: 'The new feature looks amazing! Great work 💪',
        lastMessageTime: DateTime.now().subtract(const Duration(hours: 6)),
        unreadCount: 1,
        isOnline: true,
      ),
      Friend(
        id: '8',
        name: 'Rachel Green',
        handle: 'rachel_design',
        virtualNumber: '555-890-1234',
        lastMessage: 'Let\'s grab coffee this weekend ☕',
        lastMessageTime: DateTime.now().subtract(const Duration(hours: 12)),
        unreadCount: 0,
        isOnline: false,
      ),
      Friend(
        id: '9',
        name: 'Tom Anderson',
        handle: 'tom_sports',
        virtualNumber: '555-901-2345',
        lastMessage: 'Did you watch the game last night? Incredible!',
        lastMessageTime: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
        unreadCount: 2,
        isOnline: true,
      ),
      Friend(
        id: '10',
        name: 'Maya Patel',
        handle: 'maya_photo',
        virtualNumber: '555-012-3456',
        lastMessage: 'Check out these photos from the trip! 📸',
        lastMessageTime: DateTime.now().subtract(const Duration(days: 4)),
        unreadCount: 0,
        isOnline: false,
      ),
      Friend(
        id: '11',
        name: 'Chris Martinez',
        handle: 'chris_chef',
        virtualNumber: '555-123-4567',
        lastMessage: 'Dinner was absolutely delicious! Thank you 🍽️',
        lastMessageTime: DateTime.now().subtract(const Duration(days: 5)),
        unreadCount: 1,
        isOnline: false,
      ),
      Friend(
        id: '12',
        name: 'Anna Thompson',
        handle: 'anna_books',
        virtualNumber: '555-234-5678',
        lastMessage: 'Have you read the new book I recommended?',
        lastMessageTime: DateTime.now().subtract(const Duration(days: 6)),
        unreadCount: 0,
        isOnline: true,
      ),
    ];

    // Add some archived chats for testing
    _archivedFriends = [
      Friend(
        id: 'archived_1',
        name: 'Old Group Chat',
        handle: 'old_group',
        virtualNumber: '555-999-0000',
        lastMessage: 'Thanks everyone for the great memories!',
        lastMessageTime: DateTime.now().subtract(const Duration(days: 30)),
        unreadCount: 0,
        isOnline: false,
        isArchived: true,
      ),
      Friend(
        id: 'archived_2',
        name: 'Project Team',
        handle: 'project_team',
        virtualNumber: '555-888-0000',
        lastMessage: 'Project completed successfully! 🎉',
        lastMessageTime: DateTime.now().subtract(const Duration(days: 45)),
        unreadCount: 0,
        isOnline: false,
        isArchived: true,
      ),
    ];

    // Add some muted chats for testing
    _mutedChats.addAll(['5', '11']); // James and Chris are muted
  }

  // Chat management methods
  List<Friend> get activeChats {
    if (_demoFriends.isEmpty) {
      _initializeDemoData();
    }
    return _demoFriends.where((friend) => !friend.isArchived).toList();
  }
  
  List<Friend> get archivedChats {
    if (_archivedFriends.isEmpty) {
      _initializeDemoData();
    }
    return _archivedFriends;
  }

  bool isChatMuted(String chatId) {
    return _mutedChats.contains(chatId);
  }

  bool isChatArchived(String chatId) {
    return _archivedFriends.any((friend) => friend.id == chatId) ||
           _demoFriends.any((friend) => friend.id == chatId && friend.isArchived);
  }

  Future<void> archiveChat(String chatId) async {
    final friendIndex = _demoFriends.indexWhere((friend) => friend.id == chatId);
    if (friendIndex != -1) {
      final friend = _demoFriends[friendIndex];
      _demoFriends.removeAt(friendIndex);
      _archivedFriends.add(friend.copyWith(isArchived: true));
      notifyListeners();
    }
  }

  Future<void> unarchiveChat(String chatId) async {
    final friendIndex = _archivedFriends.indexWhere((friend) => friend.id == chatId);
    if (friendIndex != -1) {
      final friend = _archivedFriends[friendIndex];
      _archivedFriends.removeAt(friendIndex);
      _demoFriends.add(friend.copyWith(isArchived: false));
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
    final friendIndex = _demoFriends.indexWhere((friend) => friend.id == chatId);
    if (friendIndex != -1) {
      _demoFriends[friendIndex] = _demoFriends[friendIndex].copyWith(unreadCount: 0);
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<bool> markAsUnread(String chatId) async {
    final friendIndex = _demoFriends.indexWhere((friend) => friend.id == chatId);
    if (friendIndex != -1) {
      _demoFriends[friendIndex] = _demoFriends[friendIndex].copyWith(unreadCount: 1);
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
    _demoFriends.removeWhere((friend) => friend.id == chatId);
    _archivedFriends.removeWhere((friend) => friend.id == chatId);
    _mutedChats.remove(chatId);
    _blockedUsers.remove(chatId);
    notifyListeners();
  }
}