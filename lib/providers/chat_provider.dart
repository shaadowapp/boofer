import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/friend_model.dart';
import 'archive_settings_provider.dart';

class ChatProvider extends ChangeNotifier {
  static const String _archivedChatsKey = 'archived_chats';
  static const String _blockedUsersKey = 'blocked_users';
  static const String _mutedChatsKey = 'muted_chats';
  static const String _friendsDataKey = 'friends_data';
  
  List<Friend> _friends = [];
  Set<String> _archivedChatIds = {};
  Set<String> _blockedUserIds = {};
  Set<String> _mutedChatIds = {};
  bool _isLoading = false;
  
  List<Friend> get friends => _friends;
  bool get isLoading => _isLoading;
  
  // Active chats: not archived, not blocked, sorted by last message time
  List<Friend> get activeChats {
    return _friends
        .where((f) => !_archivedChatIds.contains(f.id) && !_blockedUserIds.contains(f.id))
        .toList()
      ..sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
  }
  
  // Archived chats: archived but not blocked, sorted by last message time
  List<Friend> get archivedChats {
    return _friends
        .where((f) => _archivedChatIds.contains(f.id) && !_blockedUserIds.contains(f.id))
        .toList()
      ..sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
  }
  
  // Blocked users: all blocked users regardless of archive status
  List<Friend> get blockedUsers {
    return _friends
        .where((f) => _blockedUserIds.contains(f.id))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }
  
  // Unread messages count (excluding muted chats)
  int get totalUnreadCount {
    return activeChats
        .where((f) => !_mutedChatIds.contains(f.id))
        .fold(0, (sum, friend) => sum + friend.unreadCount);
  }
  
  ChatProvider() {
    _initialize();
  }
  
  Future<void> _initialize() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      await _loadFriendsData();
      await _loadArchivedChats();
      await _loadBlockedUsers();
      await _loadMutedChats();
    } catch (e) {
      debugPrint('Error initializing ChatProvider: $e');
      _loadDemoFriends();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  void _loadDemoFriends() {
    _friends = Friend.getDemoFriends();
    // Don't save demo data to avoid JSON issues
    notifyListeners();
  }
  
  Future<void> _loadFriendsData() async {
    // For now, just load demo friends to avoid JSON serialization issues
    _friends = Friend.getDemoFriends();
    notifyListeners();
  }
  
  Future<void> _saveFriendsData() async {
    // Simplified - don't save complex JSON for now
    // In production, this would save to proper database
    debugPrint('Friends data updated (not persisted in demo)');
  }
  
  Future<void> _loadArchivedChats() async {
    final prefs = await SharedPreferences.getInstance();
    final archivedIds = prefs.getStringList(_archivedChatsKey) ?? [];
    _archivedChatIds = archivedIds.toSet();
  }
  
  Future<void> _loadBlockedUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final blockedIds = prefs.getStringList(_blockedUsersKey) ?? [];
    _blockedUserIds = blockedIds.toSet();
  }
  
  Future<void> _loadMutedChats() async {
    final prefs = await SharedPreferences.getInstance();
    final mutedIds = prefs.getStringList(_mutedChatsKey) ?? [];
    _mutedChatIds = mutedIds.toSet();
  }
  
  Future<void> _saveArchivedChats() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_archivedChatsKey, _archivedChatIds.toList());
  }
  
  Future<void> _saveBlockedUsers() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_blockedUsersKey, _blockedUserIds.toList());
  }
  
  Future<void> _saveMutedChats() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_mutedChatsKey, _mutedChatIds.toList());
  }
  
  // ==================== ARCHIVE FUNCTIONALITY ====================
  
  /// Archives a chat - moves it from active to archived section
  /// Archived chats remain accessible but hidden from main view
  Future<bool> archiveChat(String friendId) async {
    try {
      if (_blockedUserIds.contains(friendId)) {
        debugPrint('Cannot archive blocked user');
        return false;
      }
      
      _archivedChatIds.add(friendId);
      await _saveArchivedChats();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error archiving chat: $e');
      return false;
    }
  }
  
  /// Unarchives a chat - moves it back to active section
  Future<bool> unarchiveChat(String friendId) async {
    try {
      _archivedChatIds.remove(friendId);
      await _saveArchivedChats();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error unarchiving chat: $e');
      return false;
    }
  }
  
  // ==================== BLOCK FUNCTIONALITY ====================
  
  /// Blocks a user completely - removes from all chat lists
  /// Blocked users have separate section and no notifications
  Future<bool> blockUser(String friendId) async {
    try {
      final friend = getFriendById(friendId);
      if (friend == null) return false;
      
      _blockedUserIds.add(friendId);
      _archivedChatIds.remove(friendId); // Remove from archived
      _mutedChatIds.remove(friendId); // Remove from muted
      
      await Future.wait([
        _saveBlockedUsers(),
        _saveArchivedChats(),
        _saveMutedChats(),
      ]);
      
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error blocking user: $e');
      return false;
    }
  }
  
  /// Unblocks a user - returns to active chats
  Future<bool> unblockUser(String friendId) async {
    try {
      _blockedUserIds.remove(friendId);
      await _saveBlockedUsers();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error unblocking user: $e');
      return false;
    }
  }
  
  // ==================== MUTE FUNCTIONALITY ====================
  
  /// Mutes a chat - no notifications but messages still received
  /// Chat remains visible with dimmed unread badge
  Future<bool> muteChat(String friendId) async {
    try {
      if (_blockedUserIds.contains(friendId)) {
        debugPrint('Cannot mute blocked user');
        return false;
      }
      
      _mutedChatIds.add(friendId);
      await _saveMutedChats();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error muting chat: $e');
      return false;
    }
  }
  
  /// Unmutes a chat - restores normal notifications
  Future<bool> unmuteChat(String friendId) async {
    try {
      _mutedChatIds.remove(friendId);
      await _saveMutedChats();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error unmuting chat: $e');
      return false;
    }
  }
  
  // ==================== READ/UNREAD FUNCTIONALITY ====================
  
  /// Marks a chat as read - clears unread count
  Future<bool> markAsRead(String friendId) async {
    try {
      final friendIndex = _friends.indexWhere((f) => f.id == friendId);
      if (friendIndex == -1) {
        debugPrint('Friend not found: $friendId');
        return false;
      }
      
      debugPrint('Marking friend ${_friends[friendIndex].name} as read (was ${_friends[friendIndex].unreadCount} unread)');
      
      final updatedFriend = _friends[friendIndex].copyWith(unreadCount: 0);
      
      if (updatedFriend != null) {
        _friends[friendIndex] = updatedFriend;
      } else {
        debugPrint('Error: copyWith returned null');
        return false;
      }
      
      // Save to simple storage instead of JSON
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('read_chats', 
          _friends.where((f) => f.unreadCount == 0).map((f) => f.id).toList());
      
      notifyListeners();
      debugPrint('Successfully marked as read');
      return true;
    } catch (e) {
      debugPrint('Error marking as read: $e');
      return false;
    }
  }
  
  /// Marks a chat as unread - adds unread indicator
  Future<bool> markAsUnread(String friendId) async {
    try {
      final friendIndex = _friends.indexWhere((f) => f.id == friendId);
      if (friendIndex == -1) {
        debugPrint('Friend not found: $friendId');
        return false;
      }
      
      debugPrint('Marking friend ${_friends[friendIndex].name} as unread (was ${_friends[friendIndex].unreadCount} unread)');
      
      final currentCount = _friends[friendIndex].unreadCount;
      final updatedFriend = _friends[friendIndex].copyWith(
        unreadCount: currentCount > 0 ? currentCount : 1,
      );
      
      if (updatedFriend != null) {
        _friends[friendIndex] = updatedFriend;
      } else {
        debugPrint('Error: copyWith returned null');
        return false;
      }
      
      // Save to simple storage instead of JSON
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('unread_chats', 
          _friends.where((f) => f.unreadCount > 0).map((f) => f.id).toList());
      
      notifyListeners();
      debugPrint('Successfully marked as unread');
      return true;
    } catch (e) {
      debugPrint('Error marking as unread: $e');
      return false;
    }
  }
  
  // ==================== DELETE FUNCTIONALITY ====================
  
  /// Permanently deletes a chat - removes friend and all data
  /// This action cannot be undone
  Future<bool> deleteChat(String friendId) async {
    try {
      debugPrint('Deleting chat for friend: $friendId');
      
      _friends.removeWhere((friend) => friend.id == friendId);
      _archivedChatIds.remove(friendId);
      _mutedChatIds.remove(friendId);
      _blockedUserIds.remove(friendId);
      
      await Future.wait([
        _saveArchivedChats(),
        _saveMutedChats(),
        _saveBlockedUsers(),
      ]);
      
      notifyListeners();
      debugPrint('Successfully deleted chat');
      return true;
    } catch (e) {
      debugPrint('Error deleting chat: $e');
      return false;
    }
  }
  
  // ==================== UTILITY METHODS ====================
  
  bool isChatArchived(String friendId) {
    return _archivedChatIds.contains(friendId);
  }
  
  bool isUserBlocked(String friendId) {
    return _blockedUserIds.contains(friendId);
  }
  
  bool isChatMuted(String friendId) {
    return _mutedChatIds.contains(friendId);
  }
  
  Friend? getFriendById(String id) {
    try {
      return _friends.firstWhere((friend) => friend.id == id);
    } catch (e) {
      return null;
    }
  }
  
  /// Simulates receiving a new message (for testing)
  Future<void> simulateNewMessage(String friendId, String message, {bool keepArchived = false}) async {
    try {
      final friendIndex = _friends.indexWhere((f) => f.id == friendId);
      if (friendIndex == -1) return;
      
      // Don't update if user is blocked
      if (_blockedUserIds.contains(friendId)) return;
      
      // If keepArchived is false and chat is archived, unarchive it when receiving new message
      if (!keepArchived && _archivedChatIds.contains(friendId)) {
        _archivedChatIds.remove(friendId);
        await _saveArchivedChats();
        debugPrint('Unarchived chat $friendId due to new message');
      }
      
      _friends[friendIndex] = _friends[friendIndex].copyWith(
        lastMessage: message,
        lastMessageTime: DateTime.now(),
        unreadCount: _friends[friendIndex].unreadCount + 1,
      );
      
      await _saveFriendsData();
      notifyListeners();
    } catch (e) {
      debugPrint('Error simulating new message: $e');
    }
  }
}