import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

/// Notification channel IDs and configurations
class NotificationChannels {
  // Channel IDs
  static const String messages = 'messages';
  static const String groupMessages = 'group_messages';
  static const String friendRequests = 'friend_requests';
  static const String calls = 'calls';
  static const String missedCalls = 'missed_calls';
  static const String mentions = 'mentions';
  static const String reactions = 'reactions';
  static const String general = 'general';

  // Channel configurations
  static const List<AndroidNotificationChannel> channels = [
    AndroidNotificationChannel(
      messages,
      'Messages',
      description: 'Notifications for new direct messages',
      importance: Importance.max,
      enableVibration: true,
      playSound: true,
      showBadge: true,
    ),
    AndroidNotificationChannel(
      groupMessages,
      'Group Messages',
      description: 'Notifications for group chat messages',
      importance: Importance.high,
    ),
    AndroidNotificationChannel(
      friendRequests,
      'Friend Requests',
      description: 'Notifications for new friend requests',
      importance: Importance.high,
    ),
    AndroidNotificationChannel(
      calls,
      'Calls',
      description: 'Notifications for incoming calls',
      importance: Importance.max,
    ),
    AndroidNotificationChannel(
      missedCalls,
      'Missed Calls',
      description: 'Notifications for missed calls',
      importance: Importance.high,
    ),
    AndroidNotificationChannel(
      mentions,
      'Mentions',
      description: 'Notifications when you are mentioned',
      importance: Importance.high,
    ),
    AndroidNotificationChannel(
      reactions,
      'Reactions',
      description: 'Notifications for message reactions',
      importance: Importance.low,
    ),
    AndroidNotificationChannel(
      general,
      'General',
      description: 'General system notifications',
      importance: Importance.defaultImportance,
    ),
  ];
}

/// Industry-standard notification service
class NotificationService {
  static NotificationService? _instance;
  static NotificationService get instance =>
      _instance ??= NotificationService._internal();

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final StreamController<Map<String, dynamic>> _notificationController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get notificationStream =>
      _notificationController.stream;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// Initialize notification service with industry standards
  Future<void> initialize() async {
    if (_isInitialized) return;

    debugPrint('🔔 [NOTIF] Initializing NotificationService...');

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsDarwin,
        );

    await _notificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('🔔 [NOTIF] User tapped notification: ${response.payload}');
        if (response.payload != null) {
          _notificationController.add({
            'type': 'tap',
            'payload': response.payload,
          });
        }
      },
    );

    // Create Android channels
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (androidImplementation != null) {
        for (final channel in NotificationChannels.channels) {
          await androidImplementation.createNotificationChannel(channel);
        }
      }
    }

    _isInitialized = true;
    debugPrint('✅ [NOTIF] NotificationService Ready');
  }

  /// Checker for notification permission (Industry standard)
  Future<bool> checkPermission() async {
    if (kIsWeb) return true;

    ph.PermissionStatus status = await ph.Permission.notification.status;
    if (status.isPermanentlyDenied) {
      debugPrint('⚠️ [NOTIF] Permission permanently denied');
      return false;
    }

    if (status.isDenied) {
      debugPrint('ℹ️ [NOTIF] Permission denied, requesting...');
      status = await ph.Permission.notification.request();
    }

    return status.isGranted;
  }

  /// Request permission with UI feedback capability
  Future<bool> requestPermission() async {
    final status = await ph.Permission.notification.request();
    return status.isGranted;
  }

  /// Check if we should request permission
  Future<bool> shouldRequestPermission() async {
    if (kIsWeb) return false;
    final status = await ph.Permission.notification.status;
    return status
        .isDenied; // Returns true if not yet requested or denied (but not permanent)
  }

  /// Check if permission is permanently denied
  Future<bool> isPermanentlyDenied() async {
    if (kIsWeb) return false;
    return await ph.Permission.notification.isPermanentlyDenied;
  }

  /// Show a dialog explaining why we need notifications
  Future<void> showPermissionDialog(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.notifications_active_rounded, color: Colors.blue),
            SizedBox(width: 12),
            Text('Sync Notifications'),
          ],
        ),
        content: const Text(
          'Allow Boofer to send you notifications so you never miss a message or call from your friends.',
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Later', style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              requestPermission();
            },
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Enable'),
          ),
        ],
      ),
    );
  }

  /// Industry standard: Show system level notification
  Future<void> showNotification({
    required String title,
    required String body,
    required String channelId,
    String? payload,
    Map<String, dynamic>? data,
  }) async {
    if (!_isInitialized) await initialize();

    final androidDetails = AndroidNotificationDetails(
      channelId,
      NotificationChannels.channels.firstWhere((c) => c.id == channelId).name,
      channelDescription: NotificationChannels.channels
          .firstWhere((c) => c.id == channelId)
          .description,
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      category: AndroidNotificationCategory.message,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      id: DateTime.now().millisecondsSinceEpoch % 100000,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );

    _notificationController.add({
      'title': title,
      'body': body,
      'channelId': channelId,
      'payload': payload,
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Optimized for messages
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

  /// Optimized for general system alerts
  Future<void> showSystemNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    await showNotification(
      title: title,
      body: body,
      channelId: NotificationChannels.general,
      payload: payload,
    );
  }

  /// Open app settings for user to enable notifications
  Future<void> openAppSettings() async {
    await ph.openAppSettings();
  }

  /// Open app settings for user to enable notifications (Legacy name)
  void openSystemSettings() async {
    await ph.openAppSettings();
  }

  void dispose() {
    _notificationController.close();
  }
}
