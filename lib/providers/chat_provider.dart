import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/friend_model.dart';

class ChatProvider extends ChangeNotifier {
  static const String _archivedChatsKey = 'archived_chats';
  
  List<Friend> _friends = [];
  Set<String> _archivedChatIds = {};
  
  List<Friend> get friends => _friends;
  List<Friend> get activeChats => _friends.where((f) => !_archivedChatIds.contains(f.id)).toList();
  List<Friend> get archivedChats => _friends.where((f) => _archivedChatIds.contains(f.id)).toList();
  
  ChatProvider() {
    _loadFriends();
    _loadArchivedChats();
  }
  
  void _loadFriends() {
    _friends = Friend.getDemoFriends();
    notifyListeners();
  }
  
  Future<void> _loadArchivedChats() async {
    final prefs = await SharedPreferences.getInstance();
    final archivedIds = prefs.getStringList(_archivedChatsKey) ?? [];
    _archivedChatIds = archivedIds.toSet();
    notifyListeners();
  }
  
  Future<void> _saveArchivedChats() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_archivedChatsKey, _archivedChatIds.toList());
  }
  
  Future<void> archiveChat(String friendId) async {
    _archivedChatIds.add(friendId);
    await _saveArchivedChats();
    notifyListeners();
  }
  
  Future<void> unarchiveChat(String friendId) async {
    _archivedChatIds.remove(friendId);
    await _saveArchivedChats();
    notifyListeners();
  }
  
  bool isChatArchived(String friendId) {
    return _archivedChatIds.contains(friendId);
  }
  
  Friend? getFriendById(String id) {
    try {
      return _friends.firstWhere((friend) => friend.id == id);
    } catch (e) {
      return null;
    }
  }
}