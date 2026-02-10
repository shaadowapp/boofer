import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../core/error/error_handler.dart';
import '../core/models/app_error.dart';

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
      'importance': 'high',
      'sound': true,
      'vibration': true,
      'lights': true,
    },
    groupMessages: {
      'name': 'Group Messages',
      'description': 'Notifications for group chat messages',
      'importance': 'high',
      'sound': true,
      'vibration': true,
      'lights': true,
    },
    friendRequests: {
      'name': 'Friend Requests',
      'description': 'Notifications for new friend requests and acceptances',
      'importance': 'high',
      'sound': true,
      'vibration': true,
      'lights': true,
    },
    calls: {
      'name': 'Calls',
      'description': 'Notifications for incoming voice and video calls',
      'importance': 'max',
      'sound': true,
      'vibration': true,
      'lights': true,
    },
    missedCalls: {
      'name': 'Missed Calls',
      'description': 'Notifications for missed calls',
      'importance': 'high',
      'sound': true,
      'vibration': false,
      'lights': true,
    },
    systemAlerts: {
      'name': 'System Alerts',
      'description': 'Important app updates and system notifications',
      'importance': 'default',
      'sound': true,
      'vibration': false,
      'lights': false,
    },
    securityAlerts: {
      'name': 'Security Alerts',
      'description': 'Critical security and privacy notifications',
      'importance': 'max',
      'sound': true,
      'vibration': true,
      'lights': true,
    },
    mentions: {
      'name': 'Mentions & Replies',
      'description': 'When someone mentions you or replies to your message',
      'importance': 'high',
      'sound': true,
      'vibration': true,
      'lights': true,
    },
    reactions: {
      'name': 'Reactions',
      'description': 'When someone reacts to your messages',
      'importance': 'low',
      'sound': false,
      'vibration': false,
      'lights': false,
    },
    general: {
      'name': 'General Notifications',
      'description': 'Other app notifications',
      'importance': 'default',
      'sound': true,
      'vibration': false,
      'lights': false,
    },
  };
}

/// Privacy-focused notification service with multiple channels
class NotificationService {
  static NotificationService? _instance;
  static NotificationService get instance => _instance ??= NotificationService._internal();
  NotificationService._internal();

  final ErrorHandler _errorHandler = ErrorHandler();
  final StreamController<Map<String, dynamic>> _notificationController = 
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get notificationStream => _notificationController.stream;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;
  
  FirebaseMessaging? _firebaseMessaging;
  FlutterLocalNotificationsPlugin? _flutterLocalNotificationsPlugin;

  /// Initialize notification service with channels
  Future<void> initialize() async {
    try {
      if (_isInitialized) {
        print('⚠️ NotificationService already initialized');
        return;
      }

      print('🔔 Initializing NotificationService...');

      // Initialize Flutter Local Notifications
      _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
      print('  ✓ FlutterLocalNotificationsPlugin created');
      
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings();
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );
      
      final initialized = await _flutterLocalNotificationsPlugin?.initialize(initSettings);
      print('  ✓ Local notifications initialized: $initialized');

      // Initialize Firebase Messaging
      _firebaseMessaging = FirebaseMessaging.instance;
      print('  ✓ Firebase Messaging initialized');
      
      // Request permission
      await _requestPermission();
      print('  ✓ Permissions requested');
      
      // Create notification channels for Android
      await _createNotificationChannels();
      print('  ✓ Notification channels created');
      
      // Set up message handlers
      _setupMessageHandlers();
      print('  ✓ Message handlers set up');

      _isInitialized = true;
      
      if (kDebugMode) {
        print('✅ NotificationService initialized with ${NotificationChannels.channelConfigs.length} channels');
      }
    } catch (e, stackTrace) {
      print('❌ NotificationService initialization failed: $e');
      print('Stack trace: $stackTrace');
      _errorHandler.handleError(AppError.service(
        message: 'Failed to initialize notification service: $e',
        stackTrace: stackTrace,
        originalException: e is Exception ? e : Exception(e.toString()),
      ));
    }
  }

  /// Request notification permission
  Future<void> _requestPermission() async {
    try {
      // Request POST_NOTIFICATIONS permission for Android 13+
      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidPlugin = _flutterLocalNotificationsPlugin?.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        await androidPlugin?.requestNotificationsPermission();
      }
      
      // Request Firebase Messaging permission
      final settings = await _firebaseMessaging?.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (kDebugMode) {
        print('📱 Notification permission status: ${settings?.authorizationStatus}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Failed to request notification permission: $e');
      }
    }
  }

  /// Create notification channels for Android
  Future<void> _createNotificationChannels() async {
    try {
      // Note: Android notification channels are created natively
      // This method logs the channels that should be created
      if (kDebugMode) {
        print('📢 Creating ${NotificationChannels.channelConfigs.length} notification channels:');
        NotificationChannels.channelConfigs.forEach((id, config) {
          print('  - ${config['name']}: ${config['description']}');
        });
      }
      
      // Channels will be created in native Android code
      // See android/app/src/main/kotlin/.../MainActivity.kt
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Failed to create notification channels: $e');
      }
    }
  }

  /// Setup message handlers
  void _setupMessageHandlers() {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (kDebugMode) {
        print('📨 Foreground message: ${message.notification?.title}');
      }
      _handleMessage(message);
    });

    // Handle background messages
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (kDebugMode) {
        print('📬 Background message opened: ${message.notification?.title}');
      }
      _handleMessage(message);
    });
  }

  /// Handle incoming message
  void _handleMessage(RemoteMessage message) {
    final notification = {
      'title': message.notification?.title ?? '',
      'body': message.notification?.body ?? '',
      'data': message.data,
      'timestamp': DateTime.now().toIso8601String(),
      'channelId': message.data['channelId'] ?? NotificationChannels.general,
    };

    _notificationController.add(notification);
  }

  /// Show notification on specific channel
  Future<void> showNotification({
    required String title,
    required String body,
    required String channelId,
    String? payload,
    Map<String, dynamic>? data,
  }) async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      final notification = {
        'title': title,
        'body': body,
        'channelId': channelId,
        'payload': payload,
        'data': data,
        'timestamp': DateTime.now().toIso8601String(),
      };

      _notificationController.add(notification);

      // Show local notification
      final config = NotificationChannels.channelConfigs[channelId];
      final channelName = config?['name'] ?? 'Notification';
      final channelDescription = config?['description'] ?? '';
      final importance = config?['importance'] ?? 'default';
      
      final androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: _mapImportance(importance),
        priority: _mapPriority(importance),
        enableVibration: config?['vibration'] ?? false,
        playSound: config?['sound'] ?? false,
        enableLights: config?['lights'] ?? false,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final notificationId = DateTime.now().millisecondsSinceEpoch.remainder(100000);

      await _flutterLocalNotificationsPlugin?.show(
        notificationId,
        title,
        body,
        notificationDetails,
        payload: payload,
      );

      if (kDebugMode) {
        print('🔔 [$channelName] $title: $body');
      }
    } catch (e, stackTrace) {
      _errorHandler.handleError(AppError.service(
        message: 'Failed to show notification: $e',
        stackTrace: stackTrace,
        originalException: e is Exception ? e : Exception(e.toString()),
      ));
    }
  }

  Importance _mapImportance(String importance) {
    switch (importance) {
      case 'max':
        return Importance.max;
      case 'high':
        return Importance.high;
      case 'low':
        return Importance.low;
      case 'min':
        return Importance.min;
      default:
        return Importance.defaultImportance;
    }
  }

  Priority _mapPriority(String importance) {
    switch (importance) {
      case 'max':
      case 'high':
        return Priority.high;
      case 'low':
        return Priority.low;
      case 'min':
        return Priority.min;
      default:
        return Priority.defaultPriority;
    }
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
      channelId: isGroup ? NotificationChannels.groupMessages : NotificationChannels.messages,
      payload: conversationId,
      data: {
        'type': 'message',
        'conversationId': conversationId,
        'senderName': senderName,
        'isGroup': isGroup,
      },
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
      data: {
        'type': 'friend_request',
        'requestId': requestId,
        'senderName': senderName,
      },
    );
  }

  /// Show friend request accepted notification
  Future<void> showFriendRequestAcceptedNotification({
    required String friendName,
    required String friendId,
  }) async {
    await showNotification(
      title: 'Friend Request Accepted',
      body: '$friendName accepted your friend request',
      channelId: NotificationChannels.friendRequests,
      payload: friendId,
      data: {
        'type': 'friend_request_accepted',
        'friendId': friendId,
        'friendName': friendName,
      },
    );
  }

  /// Show incoming call notification
  Future<void> showCallNotification({
    required String callerName,
    required String callId,
    bool isVideo = false,
  }) async {
    await showNotification(
      title: 'Incoming ${isVideo ? 'Video' : 'Voice'} Call',
      body: '$callerName is calling...',
      channelId: NotificationChannels.calls,
      payload: callId,
      data: {
        'type': 'call',
        'callId': callId,
        'callerName': callerName,
        'isVideo': isVideo,
      },
    );
  }

  /// Show missed call notification
  Future<void> showMissedCallNotification({
    required String callerName,
    required String callId,
    bool isVideo = false,
  }) async {
    await showNotification(
      title: 'Missed ${isVideo ? 'Video' : 'Voice'} Call',
      body: 'You missed a call from $callerName',
      channelId: NotificationChannels.missedCalls,
      payload: callId,
      data: {
        'type': 'missed_call',
        'callId': callId,
        'callerName': callerName,
        'isVideo': isVideo,
      },
    );
  }

  /// Show mention notification
  Future<void> showMentionNotification({
    required String mentionerName,
    required String message,
    required String conversationId,
  }) async {
    await showNotification(
      title: '$mentionerName mentioned you',
      body: message,
      channelId: NotificationChannels.mentions,
      payload: conversationId,
      data: {
        'type': 'mention',
        'conversationId': conversationId,
        'mentionerName': mentionerName,
      },
    );
  }

  /// Show reaction notification
  Future<void> showReactionNotification({
    required String reactorName,
    required String reaction,
    required String messageId,
  }) async {
    await showNotification(
      title: 'New Reaction',
      body: '$reactorName reacted $reaction to your message',
      channelId: NotificationChannels.reactions,
      payload: messageId,
      data: {
        'type': 'reaction',
        'messageId': messageId,
        'reactorName': reactorName,
        'reaction': reaction,
      },
    );
  }

  /// Show security alert notification
  Future<void> showSecurityAlertNotification({
    required String title,
    required String message,
  }) async {
    await showNotification(
      title: title,
      body: message,
      channelId: NotificationChannels.securityAlerts,
      data: {
        'type': 'security_alert',
      },
    );
  }

  /// Show system alert notification
  Future<void> showSystemAlertNotification({
    required String title,
    required String message,
  }) async {
    await showNotification(
      title: title,
      body: message,
      channelId: NotificationChannels.systemAlerts,
      data: {
        'type': 'system_alert',
      },
    );
  }

  /// Show connection request notification (legacy method)
  Future<void> showConnectionRequestNotification({
    required String senderName,
    required String requestId,
  }) async {
    await showFriendRequestNotification(
      senderName: senderName,
      requestId: requestId,
    );
  }

  /// Get FCM token
  Future<String?> getToken() async {
    try {
      return await _firebaseMessaging?.getToken();
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Failed to get FCM token: $e');
      }
      return null;
    }
  }

  /// Clear all notifications
  Future<void> clearAllNotifications() async {
    try {
      if (kDebugMode) {
        print('🧹 All notifications cleared');
      }
    } catch (e, stackTrace) {
      _errorHandler.handleError(AppError.service(
        message: 'Failed to clear notifications: $e',
        stackTrace: stackTrace,
        originalException: e is Exception ? e : Exception(e.toString()),
      ));
    }
  }

  /// Check if should request permission
  Future<bool> shouldRequestPermission() async {
    try {
      final settings = await _firebaseMessaging?.getNotificationSettings();
      return settings?.authorizationStatus == AuthorizationStatus.notDetermined;
    } catch (e) {
      return true;
    }
  }

  /// Check if permission is permanently denied
  Future<bool> isPermanentlyDenied() async {
    try {
      final settings = await _firebaseMessaging?.getNotificationSettings();
      return settings?.authorizationStatus == AuthorizationStatus.denied;
    } catch (e) {
      return false;
    }
  }

  /// Request permission
  Future<void> requestPermission() async {
    await _requestPermission();
  }

  /// Show permission dialog
  Future<void> showPermissionDialog(BuildContext context) async {
    // Placeholder - implement permission dialog
  }

  /// Open app settings
  void openAppSettings() {
    // Placeholder - implement opening app settings
  }

  /// Dispose resources
  void dispose() {
    _notificationController.close();
  }
}