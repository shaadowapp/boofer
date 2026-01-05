// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Boofer Chat';

  @override
  String get settings => 'Settings';

  @override
  String get appearance => 'Appearance';

  @override
  String get theme => 'Theme';

  @override
  String get language => 'Language';

  @override
  String get light => 'Light';

  @override
  String get dark => 'Dark';

  @override
  String get systemDefault => 'System Default';

  @override
  String get followSystemTheme => 'Follow system theme';

  @override
  String get chooseTheme => 'Choose Theme';

  @override
  String get chooseLanguage => 'Choose Language';

  @override
  String get cancel => 'Cancel';

  @override
  String get privacyAndSecurity => 'Privacy & Security';

  @override
  String get privacySettings => 'Privacy Settings';

  @override
  String get managePrivacyPreferences => 'Manage your privacy preferences';

  @override
  String get blockedUsers => 'Blocked Users';

  @override
  String get manageBlockedContacts => 'Manage blocked contacts';

  @override
  String get twoFactorAuthentication => 'Two-Factor Authentication';

  @override
  String get addExtraSecurityToAccount => 'Add extra security to your account';

  @override
  String get notifications => 'Notifications';

  @override
  String get messageNotifications => 'Message Notifications';

  @override
  String get receiveNotificationsForNewMessages =>
      'Receive notifications for new messages';

  @override
  String get soundAndVibration => 'Sound & Vibration';

  @override
  String get customizeNotificationSounds => 'Customize notification sounds';

  @override
  String get storage => 'Storage';

  @override
  String get storageUsage => 'Storage Usage';

  @override
  String get manageAppStorage => 'Manage app storage';

  @override
  String get autoDownloadMedia => 'Auto-Download Media';

  @override
  String get configureMediaDownloadSettings =>
      'Configure media download settings';

  @override
  String get support => 'Support';

  @override
  String get helpCenter => 'Help Center';

  @override
  String get getHelpAndSupport => 'Get help and support';

  @override
  String get contactUs => 'Contact Us';

  @override
  String get sendFeedbackOrReportIssues => 'Send feedback or report issues';

  @override
  String get aboutBoofer => 'About Boofer';

  @override
  String get appVersionAndInformation => 'App version and information';

  @override
  String languageChangedTo(String language) {
    return 'Language changed to $language';
  }

  @override
  String get english => 'English';

  @override
  String get spanish => 'Spanish';

  @override
  String get french => 'French';

  @override
  String get german => 'German';

  @override
  String get italian => 'Italian';

  @override
  String get portuguese => 'Portuguese';

  @override
  String get russian => 'Russian';

  @override
  String get chinese => 'Chinese';

  @override
  String get japanese => 'Japanese';

  @override
  String get korean => 'Korean';

  @override
  String get username => 'Username';

  @override
  String get changeUsername => 'Change Username';

  @override
  String usernameCannotBeChanged(int days) {
    return 'Username can be changed in $days days';
  }

  @override
  String get enterNewUsername => 'Enter new username';

  @override
  String get usernameRules =>
      'Username rules:\n• 3-20 characters\n• Letters, numbers, underscores only\n• Must start with a letter\n• Cannot end with underscore';

  @override
  String get usernameChangedSuccessfully => 'Username changed successfully!';

  @override
  String get usernameChangeError =>
      'Failed to change username. Please try again.';

  @override
  String get save => 'Save';

  @override
  String get archived => 'Archived';

  @override
  String get archiveChat => 'Archive Chat';

  @override
  String get unarchiveChat => 'Unarchive Chat';

  @override
  String get archivedChats => 'Archived Chats';

  @override
  String get noArchivedChats => 'No archived chats';

  @override
  String get chatArchived => 'Chat archived';

  @override
  String get chatUnarchived => 'Chat unarchived';

  @override
  String get darkMode => 'Dark Mode';

  @override
  String get lightMode => 'Light Mode';

  @override
  String get themeToggle => 'Theme Toggle';
}
