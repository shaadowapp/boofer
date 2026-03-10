import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import '../models/friend_model.dart';

class WidgetService {
  static const String _groupId = 'com.shaadow.boofer.android';
  static const String _listWidgetName = 'UnreadListWidgetReceiver';
  
  static String? _lastSavedJson;

  static Future<void> updateUnreadList(List<Friend> friends) async {
    try {
      final unreadFriends = friends.where((f) => f.unreadCount > 0).toList();
      unreadFriends
          .sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));

      debugPrint('🟡 [WIDGET] Total friends: ${friends.length}, Unread: ${unreadFriends.length}');
      for (final f in unreadFriends) {
        debugPrint('  → ${f.name} (${f.handle}): unread=${f.unreadCount}, msg="${f.lastMessage}"');
      }

      final List<Map<String, dynamic>> data = unreadFriends
          .map((f) => {
                'name': f.name,
                'handle': f.handle,
                'content': f.lastMessage,
                'time': DateFormat('HH:mm').format(f.lastMessageTime),
              })
          .toList();

      final newJson = jsonEncode(data);
      debugPrint('🟡 [WIDGET] JSON to save (${newJson.length} chars): $newJson');
      
      if (_lastSavedJson == newJson) {
        debugPrint('🔵 [WIDGET] JSON unchanged, skipping widget update');
        return;
      }
      _lastSavedJson = newJson;
      debugPrint('🟢 [WIDGET] JSON changed! Saving to SharedPrefs...');

      await HomeWidget.saveWidgetData<String>(
          'unread_messages_json', newJson);
      debugPrint('🟢 [WIDGET] Saved. Calling updateWidget...');

      await HomeWidget.updateWidget(
        name: _listWidgetName,
        androidName: _listWidgetName,
      );
      debugPrint('✅ [WIDGET] updateWidget done!');
    } catch (e) {
      debugPrint('❌ [WIDGET] Error updating list widget: $e');
    }
  }
}
