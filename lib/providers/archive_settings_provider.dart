import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ArchiveButtonPosition {
  topOfChats,
  bottomOfChats,
  topNavbarMoreOptions,
  hidden,
}

class ArchiveSettingsProvider extends ChangeNotifier {
  static const String _archiveButtonPositionKey = 'archive_button_position';
  static const String _keepChatsArchivedKey = 'keep_chats_archived';
  static const String _archiveSearchTriggerKey = 'archive_search_trigger';
  
  ArchiveButtonPosition _archiveButtonPosition = ArchiveButtonPosition.topOfChats;
  bool _keepChatsArchived = false;
  String _archiveSearchTrigger = 'archive';
  
  ArchiveButtonPosition get archiveButtonPosition => _archiveButtonPosition;
  bool get keepChatsArchived => _keepChatsArchived;
  String get archiveSearchTrigger => _archiveSearchTrigger;
  
  ArchiveSettingsProvider() {
    _loadSettings();
  }
  
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final positionIndex = prefs.getInt(_archiveButtonPositionKey) ?? 0;
      _archiveButtonPosition = ArchiveButtonPosition.values[positionIndex];
      _keepChatsArchived = prefs.getBool(_keepChatsArchivedKey) ?? false;
      
      // Load archive search trigger and ensure it's not empty
      final savedTrigger = prefs.getString(_archiveSearchTriggerKey) ?? 'archive';
      _archiveSearchTrigger = savedTrigger.trim().isEmpty ? 'archive' : savedTrigger;
      
      // If the saved trigger was empty, save the default
      if (savedTrigger.trim().isEmpty) {
        await prefs.setString(_archiveSearchTriggerKey, 'archive');
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading archive settings: $e');
    }
  }
  
  Future<void> setArchiveButtonPosition(ArchiveButtonPosition position) async {
    try {
      _archiveButtonPosition = position;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_archiveButtonPositionKey, position.index);
      notifyListeners();
    } catch (e) {
      debugPrint('Error saving archive button position: $e');
    }
  }
  
  Future<void> setKeepChatsArchived(bool value) async {
    try {
      _keepChatsArchived = value;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keepChatsArchivedKey, value);
      notifyListeners();
    } catch (e) {
      debugPrint('Error saving keep chats archived setting: $e');
    }
  }
  
  Future<void> setArchiveSearchTrigger(String trigger) async {
    try {
      // Prevent empty string - use default if empty
      final trimmedTrigger = trigger.trim();
      if (trimmedTrigger.isEmpty) {
        debugPrint('⚠️ Archive search trigger cannot be empty, using default');
        return; // Don't save empty string
      }
      
      _archiveSearchTrigger = trimmedTrigger;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_archiveSearchTriggerKey, trimmedTrigger);
      notifyListeners();
    } catch (e) {
      debugPrint('Error saving archive search trigger: $e');
    }
  }
  
  String getPositionDisplayName(ArchiveButtonPosition position) {
    switch (position) {
      case ArchiveButtonPosition.topOfChats:
        return 'Top of chat cards';
      case ArchiveButtonPosition.bottomOfChats:
        return 'Bottom of chat cards';
      case ArchiveButtonPosition.topNavbarMoreOptions:
        return 'Top navbar more options';
      case ArchiveButtonPosition.hidden:
        return 'Hidden (search trigger)';
    }
  }
}