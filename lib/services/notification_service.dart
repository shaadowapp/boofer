import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Service to handle notification permissions and management
class NotificationService {
  static NotificationService? _instance;
  static NotificationService get instance => _instance ??= NotificationService._internal();
  NotificationService._internal();

  bool _isInitialized = false;
  PermissionStatus? _currentStatus;

  /// Check if service is initialized
  bool get isInitialized => _isInitialized;

  /// Get current notification permission status
  PermissionStatus? get currentStatus => _currentStatus;

  /// Check if notifications are enabled
  bool get areNotificationsEnabled => 
      _currentStatus == PermissionStatus.granted;

  /// Initialize the notification service
  Future<void> initialize() async {
    try {
      _currentStatus = await Permission.notification.status;
      _isInitialized = true;
    } catch (e) {
      debugPrint('Error initializing notification service: $e');
      _isInitialized = true; // Mark as initialized even on error
    }
  }

  /// Check current notification permission status
  Future<PermissionStatus> checkPermissionStatus() async {
    try {
      _currentStatus = await Permission.notification.status;
      return _currentStatus!;
    } catch (e) {
      debugPrint('Error checking notification permission: $e');
      return PermissionStatus.denied;
    }
  }

  /// Request notification permission
  Future<PermissionStatus> requestPermission() async {
    try {
      final status = await Permission.notification.request();
      _currentStatus = status;
      return status;
    } catch (e) {
      debugPrint('Error requesting notification permission: $e');
      return PermissionStatus.denied;
    }
  }

  /// Check if permission should be requested (not permanently denied)
  Future<bool> shouldRequestPermission() async {
    final status = await checkPermissionStatus();
    return status == PermissionStatus.denied || 
           status == PermissionStatus.restricted;
  }

  /// Check if permission is permanently denied
  Future<bool> isPermanentlyDenied() async {
    final status = await checkPermissionStatus();
    return status == PermissionStatus.permanentlyDenied;
  }

  /// Open app settings for permission management
  Future<bool> openAppSettings() async {
    try {
      return await openAppSettings();
    } catch (e) {
      debugPrint('Error opening app settings: $e');
      return false;
    }
  }

  /// Show notification permission dialog
  Future<PermissionStatus?> showPermissionDialog(BuildContext context) async {
    final status = await checkPermissionStatus();
    
    if (status == PermissionStatus.granted) {
      return status; // Already granted
    }

    if (status == PermissionStatus.permanentlyDenied) {
      return await _showPermanentlyDeniedDialog(context);
    }

    return await _showRequestDialog(context);
  }

  /// Show dialog for requesting permission
  Future<PermissionStatus?> _showRequestDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.notifications, color: Colors.blue),
              SizedBox(width: 8),
              Text('Enable Notifications'),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Stay connected with your conversations!',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Notifications help you:',
                style: TextStyle(fontSize: 14),
              ),
              SizedBox(height: 8),
              Text('• Receive new messages instantly'),
              Text('• Stay updated on important conversations'),
              Text('• Never miss a message from friends'),
              SizedBox(height: 12),
              Text(
                'You can change this setting anytime in your device settings.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Not Now'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Enable'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      return await requestPermission();
    }

    return PermissionStatus.denied;
  }

  /// Show dialog for permanently denied permission
  Future<PermissionStatus?> _showPermanentlyDeniedDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.settings, color: Colors.orange),
              SizedBox(width: 8),
              Text('Notification Settings'),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Notifications are currently disabled.',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'To receive notifications, you need to enable them in your device settings.',
              ),
              SizedBox(height: 12),
              Text(
                'Steps:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              Text('1. Tap "Open Settings" below'),
              Text('2. Find "Notifications" or "Boofer"'),
              Text('3. Enable notifications'),
              Text('4. Return to the app'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Skip'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      await openAppSettings();
      // Check status after returning from settings
      return await checkPermissionStatus();
    }

    return PermissionStatus.permanentlyDenied;
  }

  /// Show simple notification permission request (for post-onboarding)
  Future<PermissionStatus> requestPermissionSimple(BuildContext context) async {
    final status = await checkPermissionStatus();
    
    if (status == PermissionStatus.granted) {
      return status;
    }

    if (status == PermissionStatus.permanentlyDenied) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.info, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text('Notifications are disabled. Enable them in Settings for the best experience.'),
              ),
            ],
          ),
          action: SnackBarAction(
            label: 'Settings',
            textColor: Colors.white,
            onPressed: () => openAppSettings(),
          ),
          duration: const Duration(seconds: 4),
        ),
      );
      return status;
    }

    // Request permission directly for simple case
    return await requestPermission();
  }

  /// Get permission status description
  String getStatusDescription(PermissionStatus status) {
    switch (status) {
      case PermissionStatus.granted:
        return 'Notifications are enabled';
      case PermissionStatus.denied:
        return 'Notifications are disabled';
      case PermissionStatus.restricted:
        return 'Notifications are restricted';
      case PermissionStatus.permanentlyDenied:
        return 'Notifications are permanently disabled';
      case PermissionStatus.provisional:
        return 'Notifications are provisionally enabled';
      default:
        return 'Unknown notification status';
    }
  }

  /// Get service summary for debugging
  Map<String, dynamic> getServiceSummary() {
    return {
      'isInitialized': _isInitialized,
      'currentStatus': _currentStatus?.toString(),
      'areNotificationsEnabled': areNotificationsEnabled,
    };
  }
}