import 'package:flutter/services.dart';

class ShortcutService {
  static const _channel = MethodChannel('com.shaadow.boofer/settings');

  static Future<bool> isPinShortcutSupported() async {
    try {
      final bool? supported =
          await _channel.invokeMethod('isPinShortcutSupported');
      return supported ?? false;
    } on PlatformException catch (e) {
      print("Failed to check shortcut support: '${e.message}'.");
      return false;
    }
  }

  static Future<void> pinChatShortcut({
    required String id,
    required String name,
    required String handle,
  }) async {
    try {
      await _channel.invokeMethod('pinChatShortcut', {
        'id': id,
        'name': name,
        'handle': handle,
      });
    } on PlatformException catch (e) {
      print("Failed to pin shortcut: '${e.message}'.");
    }
  }
}
