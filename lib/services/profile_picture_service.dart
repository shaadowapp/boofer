import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'local_storage_service.dart';

/// Service for managing profile picture with broadcast updates
/// Ensures profile picture is consistent across all app screens
class ProfilePictureService {
  static ProfilePictureService? _instance;
  static ProfilePictureService get instance =>
      _instance ??= ProfilePictureService._internal();

  ProfilePictureService._internal();

  // Broadcast stream controller for profile picture updates
  final StreamController<String?> _profilePictureController =
      StreamController<String?>.broadcast();

  // Stream for listening to profile picture changes
  Stream<String?> get profilePictureStream => _profilePictureController.stream;

  // Current profile picture URL (cached)
  String? _currentProfilePicture;

  // Storage key
  static const String _profilePictureKey = 'user_profile_picture';

  /// Get current profile picture URL
  String? get currentProfilePicture => _currentProfilePicture;

  /// Initialize and load profile picture from storage
  Future<void> initialize() async {
    try {
      // First try to load from dedicated profile picture key
      _currentProfilePicture = await LocalStorageService.getString(
        _profilePictureKey,
      );

      // Ignore UI-avatars URLs
      if (_currentProfilePicture != null &&
          _currentProfilePicture!.contains('ui-avatars.com')) {
        _currentProfilePicture = null;
      }

      // If not found, try to load from stored user data
      if (_currentProfilePicture == null || _currentProfilePicture!.isEmpty) {
        final storedUserData = await LocalStorageService.getString(
          'current_user',
        );
        if (storedUserData != null) {
          try {
            // Parse user JSON to extract profile picture
            final userJson = jsonDecode(storedUserData);
            if (userJson['profilePicture'] != null) {
              final url = userJson['profilePicture'] as String?;
              // Ignore UI-avatars URLs
              if (url != null && !url.contains('ui-avatars.com')) {
                _currentProfilePicture = url;
                // Save to dedicated key for faster access next time
                await LocalStorageService.setString(
                  _profilePictureKey,
                  _currentProfilePicture!,
                );
              }
            }
          } catch (e) {
            debugPrint('⚠️ Failed to parse user data for profile picture: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Failed to initialize ProfilePictureService: $e');
    }
  }

  /// Update profile picture and broadcast to all listeners
  Future<void> updateProfilePicture(String? profilePictureUrl) async {
    try {
      // Ignore UI-avatars generated URLs (these are placeholders, not real profile pictures)
      if (profilePictureUrl != null &&
          profilePictureUrl.contains('ui-avatars.com')) {
        return;
      }

      // Skip if same URL
      if (_currentProfilePicture == profilePictureUrl) {
        return;
      }

      // Update cache
      _currentProfilePicture = profilePictureUrl;

      // Save to local storage
      if (profilePictureUrl != null && profilePictureUrl.isNotEmpty) {
        await LocalStorageService.setString(
          _profilePictureKey,
          profilePictureUrl,
        );
      } else {
        await LocalStorageService.remove(_profilePictureKey);
      }

      // Broadcast update to all listeners
      _profilePictureController.add(profilePictureUrl);
    } catch (e) {
      debugPrint('❌ Failed to update profile picture: $e');
    }
  }

  /// Get profile picture from storage
  Future<String?> getProfilePicture() async {
    try {
      if (_currentProfilePicture != null) {
        return _currentProfilePicture;
      }

      _currentProfilePicture = await LocalStorageService.getString(
        _profilePictureKey,
      );
      return _currentProfilePicture;
    } catch (e) {
      debugPrint('❌ Failed to get profile picture: $e');
      return null;
    }
  }

  /// Clear profile picture
  Future<void> clearProfilePicture() async {
    try {
      _currentProfilePicture = null;
      await LocalStorageService.remove(_profilePictureKey);
      _profilePictureController.add(null);
      debugPrint('✅ Profile picture cleared');
    } catch (e) {
      debugPrint('❌ Failed to clear profile picture: $e');
    }
  }

  /// Dispose the service
  void dispose() {
    _profilePictureController.close();
  }
}
