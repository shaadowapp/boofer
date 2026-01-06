# Storage Architecture Documentation

## Overview
The app now uses a **unified storage system** to prevent key conflicts and ensure consistency across all user data and app settings.

## Unified Storage Service
All storage operations go through `UnifiedStorageService` which provides:
- Centralized key management
- Type-safe storage operations
- Migration support for existing data
- Consistent API across the app

## Storage Keys

### User Profile
- `user_virtual_number` - User's virtual phone number
- `username` - User's username (with change restrictions)
- `user_display_name` - User's display name
- `user_bio` - User's bio/description
- `user_is_discoverable` - Whether user can be discovered by others
- `last_username_change` - Timestamp of last username change

### Onboarding
- `onboarding_completed` - Whether onboarding is complete
- `onboarding_data` - Complete onboarding data as JSON
- `user_pin` - User's security PIN (stored securely)

### App Settings
- `theme_mode` - App theme preference (light/dark/system)
- `selected_locale` - User's language preference

### Notification Settings
- `message_notifications` - Enable/disable message notifications
- `sound_enabled` - Enable/disable notification sounds
- `vibration_enabled` - Enable/disable vibration

### Media Settings
- `auto_download_images` - Auto-download images setting
- `auto_download_videos` - Auto-download videos setting
- `auto_download_documents` - Auto-download documents setting

### Chat Settings
- `archived_chats` - List of archived chats
- `blocked_users` - List of blocked users
- `muted_chats` - List of muted chats
- `friends_data` - Friends list data

### Archive Settings
- `archive_button_position` - Position of archive button
- `keep_chats_archived` - Keep chats archived setting
- `archive_search_trigger` - Archive search trigger setting

## Services Using Unified Storage

### UserService
- Handles all user profile data
- Uses unified storage for consistency
- Provides high-level user operations

### UsernameProvider
- Manages username with change restrictions
- Synced with UserService through unified storage
- Provides reactive updates to UI

### Settings Screen
- All settings use unified storage keys
- Consistent with other parts of the app
- No more key conflicts

## Migration
- Automatic migration runs on app startup
- Moves data from old keys to new unified keys
- Preserves existing user data
- Removes old keys after migration

## Benefits
1. **No Key Conflicts** - All keys are centrally managed
2. **Consistency** - Same storage API across the app
3. **Type Safety** - Proper typing for all operations
4. **Migration Support** - Seamless updates for existing users
5. **Debugging** - Easy to see all storage keys in one place
6. **Maintenance** - Single point of change for storage logic

## Usage Example
```dart
// Save a setting
await UnifiedStorageService.setBool(UnifiedStorageService.messageNotifications, true);

// Get a setting
final notifications = await UnifiedStorageService.getBool(
  UnifiedStorageService.messageNotifications, 
  defaultValue: true
);

// Save user data
await UnifiedStorageService.setString(UnifiedStorageService.username, 'john_doe');
```

## Fixed Issues
1. ✅ Username sync between settings and home screen
2. ✅ Removed duplicate storage keys
3. ✅ Centralized all storage operations
4. ✅ Added migration for existing users
5. ✅ Removed color palette section from settings
6. ✅ Consistent storage architecture across the app