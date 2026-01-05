import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/theme_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/username_provider.dart';
import '../l10n/app_localizations.dart';
import '../services/notification_service.dart';
import 'help_screen.dart';
import 'about_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _messageNotifications = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _autoDownloadImages = true;
  bool _autoDownloadVideos = false;
  bool _autoDownloadDocuments = false;
  
  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _messageNotifications = prefs.getBool('message_notifications') ?? true;
      _soundEnabled = prefs.getBool('sound_enabled') ?? true;
      _vibrationEnabled = prefs.getBool('vibration_enabled') ?? true;
      _autoDownloadImages = prefs.getBool('auto_download_images') ?? true;
      _autoDownloadVideos = prefs.getBool('auto_download_videos') ?? false;
      _autoDownloadDocuments = prefs.getBool('auto_download_documents') ?? false;
    });
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final localeProvider = Provider.of<LocaleProvider>(context);
    final usernameProvider = Provider.of<UsernameProvider>(context);
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        title: Text(l10n.settings),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Appearance Section
            _buildSection(
              context,
              title: l10n.appearance,
              children: [
                _buildSettingsTile(
                  context,
                  title: l10n.username,
                  subtitle: usernameProvider.username.isEmpty 
                      ? 'Not set' 
                      : usernameProvider.getFormattedUsername(),
                  icon: Icons.alternate_email,
                  onTap: () => _showUsernameDialog(context, usernameProvider, l10n),
                ),
                _buildSettingsTile(
                  context,
                  title: l10n.theme,
                  subtitle: themeProvider.themeModeString,
                  icon: themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                  onTap: () => _showThemeDialog(context, themeProvider),
                ),
                _buildSettingsTile(
                  context,
                  title: l10n.language,
                  subtitle: localeProvider.getLanguageName(localeProvider.locale.languageCode),
                  icon: Icons.language,
                  onTap: () => _showLanguageDialog(context, localeProvider, l10n),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Privacy & Security Section
            _buildSection(
              context,
              title: l10n.privacyAndSecurity,
              children: [
                _buildSettingsTile(
                  context,
                  title: l10n.privacySettings,
                  subtitle: l10n.managePrivacyPreferences,
                  icon: Icons.privacy_tip,
                  onTap: () => _showPrivacySettings(context),
                ),
                _buildSettingsTile(
                  context,
                  title: l10n.blockedUsers,
                  subtitle: l10n.manageBlockedContacts,
                  icon: Icons.block,
                  onTap: () => _showBlockedUsers(context),
                ),
                _buildSettingsTile(
                  context,
                  title: l10n.twoFactorAuthentication,
                  subtitle: l10n.addExtraSecurityToAccount,
                  icon: Icons.security,
                  onTap: () => _showTwoFactorAuth(context),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Notifications Section
            _buildSection(
              context,
              title: l10n.notifications,
              children: [
                _buildSwitchTile(
                  context,
                  title: l10n.messageNotifications,
                  subtitle: l10n.receiveNotificationsForNewMessages,
                  icon: Icons.notifications,
                  value: _messageNotifications,
                  onChanged: (value) async {
                    setState(() => _messageNotifications = value);
                    await _saveSetting('message_notifications', value);
                    if (value) {
                      await NotificationService.instance.requestPermission();
                    }
                  },
                ),
                _buildSettingsTile(
                  context,
                  title: l10n.soundAndVibration,
                  subtitle: l10n.customizeNotificationSounds,
                  icon: Icons.volume_up,
                  onTap: () => _showSoundSettings(context),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Storage Section
            _buildSection(
              context,
              title: l10n.storage,
              children: [
                _buildSettingsTile(
                  context,
                  title: l10n.storageUsage,
                  subtitle: l10n.manageAppStorage,
                  icon: Icons.storage,
                  onTap: () => _showStorageUsage(context),
                ),
                _buildSettingsTile(
                  context,
                  title: l10n.autoDownloadMedia,
                  subtitle: l10n.configureMediaDownloadSettings,
                  icon: Icons.download,
                  onTap: () => _showAutoDownloadSettings(context),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Support Section
            _buildSection(
              context,
              title: l10n.support,
              children: [
                _buildSettingsTile(
                  context,
                  title: l10n.helpCenter,
                  subtitle: l10n.getHelpAndSupport,
                  icon: Icons.help,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const HelpScreen(),
                    ),
                  ),
                ),
                _buildSettingsTile(
                  context,
                  title: l10n.contactUs,
                  subtitle: l10n.sendFeedbackOrReportIssues,
                  icon: Icons.contact_support,
                  onTap: () => _showContactUs(context),
                ),
                _buildSettingsTile(
                  context,
                  title: l10n.aboutBoofer,
                  subtitle: l10n.appVersionAndInformation,
                  icon: Icons.info,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AboutScreen(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Card(
          elevation: 0,
          color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSwitchTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final theme = Theme.of(context);
    
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: theme.colorScheme.primary,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface.withOpacity(0.7),
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: theme.colorScheme.primary,
      ),
    );
  }

  Widget _buildSettingsTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: theme.colorScheme.primary,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface.withOpacity(0.7),
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: theme.colorScheme.onSurface.withOpacity(0.5),
      ),
      onTap: onTap,
    );
  }

  void _showThemeDialog(BuildContext context, ThemeProvider themeProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<AppThemeMode>(
              title: const Text('Light'),
              value: AppThemeMode.light,
              groupValue: themeProvider.themeMode,
              onChanged: (value) {
                if (value != null) {
                  themeProvider.setThemeMode(value);
                  Navigator.pop(context);
                }
              },
            ),
            RadioListTile<AppThemeMode>(
              title: const Text('Dark'),
              value: AppThemeMode.dark,
              groupValue: themeProvider.themeMode,
              onChanged: (value) {
                if (value != null) {
                  themeProvider.setThemeMode(value);
                  Navigator.pop(context);
                }
              },
            ),
            RadioListTile<AppThemeMode>(
              title: const Text('System Default'),
              subtitle: const Text('Follow system theme'),
              value: AppThemeMode.system,
              groupValue: themeProvider.themeMode,
              onChanged: (value) {
                if (value != null) {
                  themeProvider.setThemeMode(value);
                  Navigator.pop(context);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showLanguageDialog(BuildContext context, LocaleProvider localeProvider, AppLocalizations l10n) {
    final supportedLanguages = [
      {'code': 'en', 'name': l10n.english},
      {'code': 'es', 'name': l10n.spanish},
      {'code': 'fr', 'name': l10n.french},
      {'code': 'de', 'name': l10n.german},
      {'code': 'it', 'name': l10n.italian},
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.chooseLanguage),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: supportedLanguages.length,
            itemBuilder: (context, index) {
              final language = supportedLanguages[index];
              final languageCode = language['code'] as String;
              final languageName = language['name'] as String;
              
              return RadioListTile<String>(
                title: Text(languageName),
                value: languageCode,
                groupValue: localeProvider.locale.languageCode,
                onChanged: (value) async {
                  if (value != null) {
                    await localeProvider.setLocale(Locale(value));
                    Navigator.pop(context);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.languageChangedTo(languageName)),
                        ),
                      );
                    }
                  }
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
  }

  void _showUsernameDialog(BuildContext context, UsernameProvider usernameProvider, AppLocalizations l10n) {
    final usernameController = TextEditingController(text: usernameProvider.username);
    String? errorMessage;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.changeUsername),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!usernameProvider.canChangeUsername()) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info, color: Colors.orange.shade700, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.usernameCannotBeChanged(usernameProvider.daysUntilNextChange()),
                            style: TextStyle(
                              color: Colors.orange.shade700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ] else ...[
                  TextField(
                    controller: usernameController,
                    decoration: InputDecoration(
                      labelText: l10n.enterNewUsername,
                      prefixText: '@',
                      border: const OutlineInputBorder(),
                      errorText: errorMessage,
                    ),
                    onChanged: (value) {
                      setState(() {
                        errorMessage = usernameProvider.validateUsername(value);
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  l10n.usernameRules,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
            if (usernameProvider.canChangeUsername())
              ElevatedButton(
                onPressed: errorMessage != null || usernameController.text.trim().isEmpty
                    ? null
                    : () async {
                        final success = await usernameProvider.setUsername(usernameController.text);
                        Navigator.pop(context);
                        
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                success 
                                    ? l10n.usernameChangedSuccessfully
                                    : l10n.usernameChangeError,
                              ),
                              backgroundColor: success ? Colors.green : Colors.red,
                            ),
                          );
                        }
                      },
                child: Text(l10n.save),
              ),
          ],
        ),
      ),
    );
  }

  void _showComingSoonSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('This feature is coming soon!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showPrivacySettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Read Receipts'),
              subtitle: const Text('Let others know when you\'ve read their messages'),
              trailing: Switch(
                value: true,
                onChanged: (value) {
                  // Handle read receipts toggle
                },
              ),
            ),
            ListTile(
              title: const Text('Last Seen'),
              subtitle: const Text('Show when you were last online'),
              trailing: Switch(
                value: true,
                onChanged: (value) {
                  // Handle last seen toggle
                },
              ),
            ),
            ListTile(
              title: const Text('Profile Photo'),
              subtitle: const Text('Who can see your profile photo'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // Show profile photo privacy options
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showBlockedUsers(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Blocked Users'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: Column(
            children: [
              const Text('No blocked users'),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  children: [
                    // This would show actual blocked users
                    ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.person),
                      ),
                      title: const Text('Example User'),
                      subtitle: const Text('Blocked 2 days ago'),
                      trailing: TextButton(
                        onPressed: () {
                          // Unblock user
                        },
                        child: const Text('Unblock'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showTwoFactorAuth(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Two-Factor Authentication'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Secure your account with two-factor authentication.'),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.sms, color: Colors.blue),
              title: const Text('SMS Authentication'),
              subtitle: const Text('Receive codes via SMS'),
              trailing: const Text('Not Set Up'),
              onTap: () {
                Navigator.pop(context);
                _showSMSSetup(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.apps, color: Colors.green),
              title: const Text('Authenticator App'),
              subtitle: const Text('Use Google Authenticator or similar'),
              trailing: const Text('Not Set Up'),
              onTap: () {
                Navigator.pop(context);
                _showAuthenticatorSetup(context);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showSMSSetup(BuildContext context) {
    final phoneController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('SMS Two-Factor Authentication'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter your phone number to receive SMS codes:'),
            const SizedBox(height: 16),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                prefixText: '+1 ',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // Send verification SMS
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Verification SMS sent!'),
                ),
              );
            },
            child: const Text('Send Code'),
          ),
        ],
      ),
    );
  }

  void _showAuthenticatorSetup(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Authenticator App Setup'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('1. Download Google Authenticator or similar app'),
            const SizedBox(height: 8),
            const Text('2. Scan this QR code:'),
            const SizedBox(height: 16),
            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text('QR Code\n(Demo)', textAlign: TextAlign.center),
              ),
            ),
            const SizedBox(height: 16),
            const Text('3. Enter the 6-digit code from your app:'),
            const SizedBox(height: 8),
            const TextField(
              decoration: InputDecoration(
                labelText: '6-digit code',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              maxLength: 6,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Two-factor authentication enabled!'),
                ),
              );
            },
            child: const Text('Verify'),
          ),
        ],
      ),
    );
  }

  void _showSoundSettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Sound & Vibration'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: const Text('Sound'),
                subtitle: const Text('Play notification sounds'),
                value: _soundEnabled,
                onChanged: (value) {
                  setState(() => _soundEnabled = value);
                  _saveSetting('sound_enabled', value);
                },
              ),
              SwitchListTile(
                title: const Text('Vibration'),
                subtitle: const Text('Vibrate for notifications'),
                value: _vibrationEnabled,
                onChanged: (value) {
                  setState(() => _vibrationEnabled = value);
                  _saveSetting('vibration_enabled', value);
                },
              ),
              ListTile(
                title: const Text('Notification Sound'),
                subtitle: const Text('Default'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // Show sound picker
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Sound picker coming soon!'),
                    ),
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  void _showStorageUsage(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Storage Usage'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('App Storage Usage:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildStorageItem('Messages', '45.2 MB'),
            _buildStorageItem('Images', '128.7 MB'),
            _buildStorageItem('Videos', '256.3 MB'),
            _buildStorageItem('Documents', '12.8 MB'),
            _buildStorageItem('Cache', '23.1 MB'),
            const Divider(),
            _buildStorageItem('Total', '466.1 MB', isTotal: true),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _showClearCacheDialog(context);
                },
                child: const Text('Clear Cache'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildStorageItem(String label, String size, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            size,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  void _showClearCacheDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text('This will clear temporary files and free up storage space. Your messages and media will not be affected.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Cache cleared successfully!'),
                ),
              );
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showAutoDownloadSettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Auto-Download Media'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Choose which media types to download automatically:'),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Images'),
                subtitle: const Text('Auto-download images'),
                value: _autoDownloadImages,
                onChanged: (value) {
                  setState(() => _autoDownloadImages = value);
                  _saveSetting('auto_download_images', value);
                },
              ),
              SwitchListTile(
                title: const Text('Videos'),
                subtitle: const Text('Auto-download videos'),
                value: _autoDownloadVideos,
                onChanged: (value) {
                  setState(() => _autoDownloadVideos = value);
                  _saveSetting('auto_download_videos', value);
                },
              ),
              SwitchListTile(
                title: const Text('Documents'),
                subtitle: const Text('Auto-download documents'),
                value: _autoDownloadDocuments,
                onChanged: (value) {
                  setState(() => _autoDownloadDocuments = value);
                  _saveSetting('auto_download_documents', value);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  void _showContactUs(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contact Us'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.email),
              title: const Text('Email Support'),
              subtitle: const Text('support@boofer.com'),
              onTap: () {
                Clipboard.setData(const ClipboardData(text: 'support@boofer.com'));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Email copied to clipboard'),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat),
              title: const Text('Live Chat'),
              subtitle: const Text('Chat with our support team'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Live chat coming soon!'),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.feedback),
              title: const Text('Send Feedback'),
              subtitle: const Text('Share your thoughts and suggestions'),
              onTap: () {
                Navigator.pop(context);
                _showFeedbackForm(context);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showFeedbackForm(BuildContext context) {
    final feedbackController = TextEditingController();
    String feedbackType = 'General';
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Send Feedback'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: feedbackType,
                  decoration: const InputDecoration(
                    labelText: 'Feedback Type',
                    border: OutlineInputBorder(),
                  ),
                  items: ['General', 'Bug Report', 'Feature Request', 'Complaint', 'Compliment']
                      .map((type) => DropdownMenuItem(
                            value: type,
                            child: Text(type),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() => feedbackType = value!);
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: feedbackController,
                  decoration: const InputDecoration(
                    labelText: 'Your Feedback',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 4,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Feedback submitted! Thank you for helping us improve.'),
                  ),
                );
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }
}