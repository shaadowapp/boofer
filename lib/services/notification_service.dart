import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Notification channel IDs and configurations
class NotificationChannels {
  // Channel IDs
  static const String messages = 'messages';
  static const String groupMessages = 'group_messages';
  static const String friendRequests = 'friend_requests';
  static const String calls = 'calls';
  static const String missedCalls = 'missed_calls';
  static const String systemAlerts = 'system_alerts';
  static const String securityAlerts = 'security_alerts';
  static const String mentions = 'mentions';
  static const String reactions = 'reactions';
  static const String general = 'general';

  // Channel configurations
  static const Map<String, Map<String, dynamic>> channelConfigs = {
    messages: {
      'name': 'Messages',
      'description': 'Notifications for new direct messages',
    },
    groupMessages: {
      'name': 'Group Messages',
      'description': 'Notifications for group chat messages',
    },
    friendRequests: {
      'name': 'Friend Requests',
      'description': 'Notifications for new friend requests and acceptances',
    },
    calls: {
      'name': 'Calls',
      'description': 'Notifications for incoming voice and video calls',
    },
    missedCalls: {
      'name': 'Missed Calls',
      'description': 'Notifications for missed calls',
    },
    systemAlerts: {
      'name': 'System Alerts',
      'description': 'Important app updates and system notifications',
    },
    securityAlerts: {
      'name': 'Security Alerts',
      'description': 'Critical security and privacy notifications',
    },
    mentions: {
      'name': 'Mentions & Replies',
      'description': 'When someone mentions you or replies to your message',
    },
    reactions: {
      'name': 'Reactions',
      'description': 'When someone reacts to your messages',
    },
    general: {
      'name': 'General Notifications',
      'description': 'Other app notifications',
    },
  };
}

/// Privacy-focused notification service (Stubbed for now)
class NotificationService {
  static NotificationService? _instance;
  static NotificationService get instance =>
      _instance ??= NotificationService._internal();
  NotificationService._internal();

  final StreamController<Map<String, dynamic>> _notificationController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get notificationStream =>
      _notificationController.stream;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// Initialize notification service
  Future<void> initialize() async {
    _isInitialized = true;
  }

  /// Get token
  Future<String?> getToken() async {
    return null;
  }

  /// Check if should request permission
  Future<bool> shouldRequestPermission() async {
    return true;
  }

  /// Check if permission is permanently denied
  Future<bool> isPermanentlyDenied() async {
    return false;
  }

  /// Request permission
  Future<void> requestPermission() async {
    // Stub
  }

  /// Show permission dialog
  Future<void> showPermissionDialog(BuildContext context) async {
    // Stub
  }

  /// Open app settings
  void openAppSettings() {
    // Stub
  }

  /// Show notification
  Future<void> showNotification({
    required String title,
    required String body,
    required String channelId,
    String? payload,
    Map<String, dynamic>? data,
  }) async {
    final notification = {
      'title': title,
      'body': body,
      'channelId': channelId,
      'payload': payload,
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
    };

    debugPrint('🔔 Local Notification: $title - $body');
    _notificationController.add(notification);
  }

  /// Show message notification
  Future<void> showMessageNotification({
    required String senderName,
    required String message,
    required String conversationId,
    bool isGroup = false,
  }) async {
    await showNotification(
      title: senderName,
      body: message,
      channelId: isGroup
          ? NotificationChannels.groupMessages
          : NotificationChannels.messages,
      payload: conversationId,
    );
  }

  /// Show friend request notification
  Future<void> showFriendRequestNotification({
    required String senderName,
    required String requestId,
  }) async {
    await showNotification(
      title: 'Friend Request',
      body: '$senderName wants to connect with you',
      channelId: NotificationChannels.friendRequests,
      payload: requestId,
    );
  }

  /// Dispose resources
  void dispose() {
    _notificationController.close();
  }
}
