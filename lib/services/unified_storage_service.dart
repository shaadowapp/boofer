import 'package:shared_preferences/shared_preferences.dart';

/// Unified storage service to prevent key conflicts and ensure consistency
/// across all user data and app settings
class UnifiedStorageService {
  // User Profile Keys
  static const String userId = 'user_id';
  static const String userVirtualNumber = 'user_virtual_number';
  static const String userHandle = 'user_handle'; // @username (alphanumeric + underscore)
  static const String userFullName = 'user_full_name'; // Full name with spaces
  static const String userBio = 'user_bio';
  static const String userIsDiscoverable = 'user_is_discoverable';
  static const String lastUsernameChange = 'last_username_change';
  static const String userCreatedAt = 'user_created_at';
  static const String userUpdatedAt = 'user_updated_at';
  static const String userProfilePicture = 'user_profile_picture';
  static const String userStatus = 'user_status'; // online, offline, away, busy
  static const String userLastSeen = 'user_last_seen';
  
  // Deprecated keys (for migration)
  static const String username = 'username'; // Will migrate to userHandle
  static const String userDisplayName = 'user_display_name'; // Will migrate to userFullName
  
  // Onboarding Keys
  static const String onboardingCompleted = 'onboarding_completed';
  static const String onboardingData = 'onboarding_data';
  static const String userPin = 'user_pin';
  
  // App Settings Keys
  static const String themeMode = 'theme_mode';
  static const String selectedLocale = 'selected_locale';
  
  // Notification Settings Keys
  static const String messageNotifications = 'message_notifications';
  static const String soundEnabled = 'sound_enabled';
  static const String vibrationEnabled = 'vibration_enabled';
  
  // Media Settings Keys
  static const String autoDownloadImages = 'auto_download_images';
  static const String autoDownloadVideos = 'auto_download_videos';
  static const String autoDownloadDocuments = 'auto_download_documents';
  
  // Chat Settings Keys
  static const String archivedChats = 'archived_chats';
  static const String blockedUsers = 'blocked_users';
  static const String mutedChats = 'muted_chats';
  static const String friendsData = 'friends_data';
  
  // Archive Settings Keys
  static const String archiveButtonPosition = 'archive_button_position';
  static const String keepChatsArchived = 'keep_chats_archived';
  static const String archiveSearchTrigger = 'archive_search_trigger';
  
  // Mode Manager Keys (if still needed)
  static const String userPreferredMode = 'user_preferred_mode';
  static const String autoSyncEnabled = 'auto_sync_enabled';
  static const String showModeNotifications = 'show_mode_notifications';
  
  /// Get SharedPreferences instance
  static Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();
  
  // String operations
  static Future<bool> setString(String key, String value) async {
    final prefs = await _prefs;
    return await prefs.setString(key, value);
  }
  
  static Future<String?> getString(String key) async {
    final prefs = await _prefs;
    return prefs.getString(key);
  }
  
  // Bool operations
  static Future<bool> setBool(String key, bool value) async {
    final prefs = await _prefs;
    return await prefs.setBool(key, value);
  }
  
  static Future<bool> getBool(String key, {bool defaultValue = false}) async {
    final prefs = await _prefs;
    return prefs.getBool(key) ?? defaultValue;
  }
  
  // Int operations
  static Future<bool> setInt(String key, int value) async {
    final prefs = await _prefs;
    return await prefs.setInt(key, value);
  }
  
  static Future<int?> getInt(String key) async {
    final prefs = await _prefs;
    return prefs.getInt(key);
  }
  
  // Remove operations
  static Future<bool> remove(String key) async {
    final prefs = await _prefs;
    return await prefs.remove(key);
  }
  
  // Clear all data
  static Future<bool> clearAll() async {
    final prefs = await _prefs;
    return await prefs.clear();
  }
  
  // Get all keys (for debugging)
  static Future<Set<String>> getAllKeys() async {
    final prefs = await _prefs;
    return prefs.getKeys();
  }
  
  /// Migration helper to move data from old keys to new unified keys
  static Future<void> migrateOldKeys() async {
    final prefs = await _prefs;
    
    // Migrate old virtual number key if exists
    final oldVirtualNumber = prefs.getString('virtual_number');
    if (oldVirtualNumber != null) {
      await setString(userVirtualNumber, oldVirtualNumber);
      await prefs.remove('virtual_number');
    }
    
    // Migrate old username to userHandle
    final oldUsername = prefs.getString('username');
    if (oldUsername != null && prefs.getString(userHandle) == null) {
      await setString(userHandle, oldUsername);
      // Keep old username key for now for compatibility
    }
    
    // Migrate old display name to userFullName
    final oldDisplayName = prefs.getString('user_display_name');
    if (oldDisplayName != null && prefs.getString(userFullName) == null) {
      await setString(userFullName, oldDisplayName);
      await prefs.remove('user_display_name');
    }
    
    // Migrate old user name key if exists (different from username)
    final oldUserName = prefs.getString('user_name');
    if (oldUserName != null && prefs.getString(userFullName) == null) {
      await setString(userFullName, oldUserName);
      await prefs.remove('user_name');
    }
    
    // Generate user ID if doesn't exist
    if (prefs.getString(userId) == null) {
      await setString(userId, _generateUserId());
      await setString(userCreatedAt, DateTime.now().toIso8601String());
    }
    
    // Set updated timestamp
    await setString(userUpdatedAt, DateTime.now().toIso8601String());
  }
  
  /// Generate a unique numeric user ID with current date
  static String _generateUserId() {
    final now = DateTime.now();
    
    // Format: YYYYMMDDHHMMSS + 4-digit random number
    // Example: 20250106143045 + 1234 = 202501061430451234
    final dateTime = now.year.toString() +
        now.month.toString().padLeft(2, '0') +
        now.day.toString().padLeft(2, '0') +
        now.hour.toString().padLeft(2, '0') +
        now.minute.toString().padLeft(2, '0') +
        now.second.toString().padLeft(2, '0');
    
    final random = (now.millisecond * 10 + (now.microsecond % 10)).toString().padLeft(4, '0');
    
    return '$dateTime$random';
  }
}