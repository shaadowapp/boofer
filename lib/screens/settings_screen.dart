import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/locale_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../l10n/app_localizations.dart';
import '../services/notification_service.dart';
import '../services/unified_storage_service.dart';
import 'help_screen.dart';
import 'about_screen.dart';
import 'requested_screen.dart';
import 'archived_chats_screen.dart';
import 'archive_settings_screen.dart';
import 'account_settings_screen.dart';
import 'privacy_settings_screen.dart';
import 'storage_usage_screen.dart';
import 'network_usage_screen.dart';
import 'blocked_users_screen.dart';
import 'chat_backup_screen.dart';
import 'privacy_policy_screen.dart';
import 'terms_of_service_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _messageNotifications = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final messageNotifications = await UnifiedStorageService.getBool(
      UnifiedStorageService.messageNotifications,
      defaultValue: true,
    );

    setState(() {
      _messageNotifications = messageNotifications;
    });
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    if (value is bool) {
      await UnifiedStorageService.setBool(key, value);
    } else if (value is String) {
      await UnifiedStorageService.setString(key, value);
    }
  }

  @override
  @override
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localeProvider = Provider.of<LocaleProvider>(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Text(l10n.settings),
            centerTitle: true,
            backgroundColor: theme.colorScheme.surface,
            scrolledUnderElevation: 0,
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search settings...',
                  prefixIcon: Icon(
                    Icons.search,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.3),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (value) =>
                    setState(() => _searchQuery = value.toLowerCase()),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Personalization Section
                if (_matchesSearch(
                  'personalization appearance theme color language font',
                ))
                  _buildSettingsSection(
                    context,
                    title: 'Personalization',
                    children: [
                      _buildColorfulTile(
                        context,
                        title: 'Appearance',
                        subtitle: 'Theme, colors, font size',
                        icon: Icons.palette_outlined,
                        color: Colors.purple,
                        onTap: () => Navigator.pushNamed(
                          context,
                          '/appearance-settings',
                        ),
                      ),
                      _buildColorfulTile(
                        context,
                        title: l10n.language,
                        subtitle: localeProvider.getLanguageName(
                          localeProvider.locale.languageCode,
                        ),
                        icon: Icons.language_outlined,
                        color: Colors.indigo,
                        onTap: () =>
                            _showLanguageDialog(context, localeProvider, l10n),
                      ),
                    ],
                  ),

                // Privacy & Security Section
                if (_matchesSearch('privacy security account sign out logout'))
                  _buildSettingsSection(
                    context,
                    title: 'Privacy & Security',
                    children: [
                      _buildColorfulTile(
                        context,
                        title: 'Account',
                        subtitle: 'Manage your account',
                        icon: Icons.person_outline,
                        color: Colors.blue,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AccountSettingsScreen(),
                          ),
                        ),
                      ),
                      _buildColorfulTile(
                        context,
                        title: 'Privacy',
                        subtitle: 'Visibility and data',
                        icon: Icons.lock_outline,
                        color: Colors.teal,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PrivacySettingsScreen(),
                          ),
                        ),
                      ),
                      _buildColorfulTile(
                        context,
                        title: 'Blocked',
                        subtitle: 'Manage blocked users',
                        icon: Icons.block_outlined,
                        color: Colors.red,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const BlockedUsersScreen(),
                          ),
                        ),
                      ),
                    ],
                  ),

                // Notifications Section
                if (_matchesSearch('notifications sound vibration alerts'))
                  _buildSettingsSection(
                    context,
                    title: l10n.notifications,
                    children: [
                      _buildColorfulSwitchTile(
                        context,
                        title: l10n.messageNotifications,
                        icon: Icons.notifications_none_outlined,
                        color: Colors.orange,
                        value: _messageNotifications,
                        onChanged: (value) async {
                          setState(() => _messageNotifications = value);
                          await _saveSetting(
                            UnifiedStorageService.messageNotifications,
                            value,
                          );
                          if (value) {
                            await NotificationService.instance
                                .requestPermission();
                          }
                        },
                      ),
                      _buildColorfulTile(
                        context,
                        title: 'Notification Channels',
                        subtitle: 'Customize alerts',
                        icon: Icons.tune_outlined,
                        color: Colors.deepOrange,
                        onTap: () => Navigator.pushNamed(
                          context,
                          '/notification-settings',
                        ),
                      ),
                    ],
                  ),

                // Chat & Messaging Section
                if (_matchesSearch('chat messaging archive backup'))
                  _buildSettingsSection(
                    context,
                    title: 'Chat',
                    children: [
                      Consumer<ChatProvider>(
                        builder: (context, chatProvider, child) {
                          final archivedCount =
                              chatProvider.archivedChats.length;
                          return _buildColorfulTile(
                            context,
                            title: 'Archived Chats',
                            subtitle: archivedCount > 0
                                ? '$archivedCount archived'
                                : 'No archived chats',
                            icon: Icons.archive_outlined,
                            color: Colors.green,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const ArchivedChatsScreen(),
                              ),
                            ),
                          );
                        },
                      ),
                      _buildColorfulTile(
                        context,
                        title: 'Archive Settings',
                        subtitle: 'Auto-archive options',
                        icon: Icons.settings_outlined,
                        color: Colors.teal,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ArchiveSettingsScreen(),
                          ),
                        ),
                      ),
                      _buildColorfulTile(
                        context,
                        title: 'Backups',
                        subtitle: 'Chat history backup',
                        icon: Icons.backup_outlined,
                        color: Colors.lightGreen,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ChatBackupScreen(),
                          ),
                        ),
                      ),
                    ],
                  ),

                // Data & Storage Section
                if (_matchesSearch('data storage cache offline'))
                  _buildSettingsSection(
                    context,
                    title: 'Data & Storage',
                    children: [
                      _buildColorfulTile(
                        context,
                        title: 'Storage Usage',
                        subtitle: 'Manage space',
                        icon: Icons.storage_outlined,
                        color: Colors.cyan,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const StorageUsageScreen(),
                          ),
                        ),
                      ),
                      _buildColorfulTile(
                        context,
                        title: 'Network Usage',
                        subtitle: 'Data usage statistics',
                        icon: Icons.data_usage,
                        color: Colors.blue,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const NetworkUsageScreen(),
                          ),
                        ),
                      ),
                      _buildColorfulTile(
                        context,
                        title: 'Clear Cache',
                        subtitle: 'Free up space',
                        icon: Icons.cleaning_services_outlined,
                        color: Colors.amber,
                        onTap: () => _showClearCacheDialog(context),
                      ),
                    ],
                  ),

                // Accessibility Section
                if (_matchesSearch('accessibility text size screen reader'))
                  _buildSettingsSection(
                    context,
                    title: 'Accessibility',
                    children: [
                      _buildColorfulTile(
                        context,
                        title: 'Text Size',
                        subtitle: 'Adjust font size',
                        icon: Icons.format_size,
                        color: Colors.deepPurple,
                        onTap: () => Navigator.pushNamed(
                          context,
                          '/appearance-settings',
                        ),
                      ),
                      _buildColorfulTile(
                        context,
                        title: 'High Contrast',
                        subtitle: 'Increase visibility',
                        icon: Icons.contrast,
                        color: Colors.purple,
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'High Contrast feature coming soon',
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),

                // Support & About Section
                if (_matchesSearch('help support about feedback'))
                  _buildSettingsSection(
                    context,
                    title: 'About',
                    children: [
                      _buildColorfulTile(
                        context,
                        title: l10n.helpCenter,
                        subtitle: 'FAQ and support',
                        icon: Icons.help_outline,
                        color: Colors.pink,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const HelpScreen(),
                          ),
                        ),
                      ),
                      _buildColorfulTile(
                        context,
                        title: 'Send Feedback',
                        subtitle: 'Share your thoughts',
                        icon: Icons.feedback_outlined,
                        color: Colors.deepOrange,
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Feedback feature coming soon'),
                            ),
                          );
                        },
                      ),
                      _buildColorfulTile(
                        context,
                        title: 'Privacy Policy',
                        subtitle: 'Read our privacy policy',
                        icon: Icons.privacy_tip_outlined,
                        color: Colors.teal,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PrivacyPolicyScreen(),
                          ),
                        ),
                      ),
                      _buildColorfulTile(
                        context,
                        title: 'Terms of Service',
                        subtitle: 'Read our terms of service',
                        icon: Icons.description_outlined,
                        color: Colors.deepPurple,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const TermsOfServiceScreen(),
                          ),
                        ),
                      ),
                      _buildColorfulTile(
                        context,
                        title: l10n.aboutBoofer,
                        subtitle: 'Version info',
                        icon: Icons.info_outline,
                        color: Colors.blue,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AboutScreen(),
                          ),
                        ),
                      ),
                    ],
                  ),

                // Account Actions
                if (_matchesSearch('requested sign out logout'))
                  _buildSettingsSection(
                    context,
                    title: 'Actions',
                    children: [
                      _buildColorfulTile(
                        context,
                        title: 'Sent Requests',
                        subtitle: 'View sent friend requests',
                        icon: Icons.person_add_outlined,
                        color: Colors.blue,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const RequestedScreen(),
                          ),
                        ),
                      ),
                      _buildColorfulTile(
                        context,
                        title: 'Sign Out',
                        subtitle: 'Log out of Boofer',
                        icon: Icons.logout,
                        color: Colors.red,
                        isDanger: true,
                        onTap: () => _showSignOutDialog(context),
                      ),
                    ],
                  ),

                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  bool _matchesSearch(String keywords) {
    if (_searchQuery.isEmpty) return true;
    return keywords.toLowerCase().contains(_searchQuery);
  }

  Widget _buildSettingsSection(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(
            title,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.hardEdge,
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildColorfulTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool isDanger = false,
  }) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: isDanger
                            ? theme.colorScheme.error
                            : theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildColorfulSwitchTile(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  void _showLanguageDialog(
    BuildContext context,
    LocaleProvider localeProvider,
    AppLocalizations l10n,
  ) {
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
                    if (context.mounted) {
                      Navigator.pop(context);
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

  void _showClearCacheDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text(
          'This will delete all cached data including images and temporary files. Your messages and settings will not be affected.',
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
                  content: Text('Cache cleared successfully'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showSignOutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text(
          'Are you sure you want to sign out? You will need to sign in again to access your account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              // Show loading indicator
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const AlertDialog(
                  content: Row(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(width: 16),
                      Text('Signing out...'),
                    ],
                  ),
                ),
              );

              try {
                final authProvider = context.read<AuthProvider>();
                await authProvider.signOut();

                if (context.mounted) {
                  Navigator.pop(context); // Close loading dialog

                  // Navigate to onboarding screen
                  Navigator.of(
                    context,
                  ).pushNamedAndRemoveUntil('/onboarding', (route) => false);

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Signed out successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context); // Close loading dialog

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Sign out failed: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}
