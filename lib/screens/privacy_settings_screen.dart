import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../models/privacy_settings_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  final SupabaseService _supabaseService = SupabaseService.instance;
  UserPrivacySettings? _settings;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final settings = await _supabaseService.getPrivacySettings(user.id);
      if (mounted) {
        setState(() {
          _settings = settings;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateSetting(UserPrivacySettings newSettings) async {
    setState(() => _settings = newSettings);
    await _supabaseService.updatePrivacySettings(newSettings);
  }

  void _showOptionsDialog({
    required String title,
    required String currentValue,
    required List<String> options,
    required Function(String) onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              ...options.map((option) {
                return RadioListTile<String>(
                  title: Text(_formatValue(option)),
                  value: option,
                  groupValue: currentValue,
                  onChanged: (value) {
                    if (value != null) {
                      onSelected(value);
                      Navigator.pop(context);
                    }
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  String _formatValue(String value) {
    if (value == 'everyone') return 'Everyone';
    if (value == 'friends') return 'Friends';
    if (value == 'nobody') return 'Nobody';
    if (value == 'off') return 'Off';
    if (value == 'after_seen') return 'After Seen';
    if (value.endsWith('_hours')) {
      final hours = value.split('_')[0];
      return '$hours Hours';
    }
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Privacy')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final s = _settings!;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('Privacy'),
            centerTitle: true,
            backgroundColor: theme.colorScheme.surface,
            scrolledUnderElevation: 0,
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildSectionHeader(context, 'Who can see my personal info'),
                _buildPrivacyItem(
                  context,
                  title: 'Last Seen & Online',
                  value: _formatValue(s.lastSeen),
                  icon: Icons.visibility_outlined,
                  onTap: () => _showOptionsDialog(
                    title: 'Last Seen & Online',
                    currentValue: s.lastSeen,
                    options: ['everyone', 'friends', 'nobody'],
                    onSelected: (val) =>
                        _updateSetting(s.copyWith(lastSeen: val)),
                  ),
                ),
                _buildPrivacyItem(
                  context,
                  title: 'Profile Photo',
                  value: _formatValue(s.profilePhoto),
                  icon: Icons.account_circle_outlined,
                  onTap: () => _showOptionsDialog(
                    title: 'Profile Photo',
                    currentValue: s.profilePhoto,
                    options: ['everyone', 'friends', 'nobody'],
                    onSelected: (val) =>
                        _updateSetting(s.copyWith(profilePhoto: val)),
                  ),
                ),
                _buildPrivacyItem(
                  context,
                  title: 'About',
                  value: _formatValue(s.about),
                  icon: Icons.info_outline,
                  onTap: () => _showOptionsDialog(
                    title: 'About',
                    currentValue: s.about,
                    options: ['everyone', 'friends', 'nobody'],
                    onSelected: (val) => _updateSetting(s.copyWith(about: val)),
                  ),
                ),
                const SizedBox(height: 24),
                _buildSwitchItem(
                  context,
                  title: 'Read Receipts',
                  subtitle:
                      'If turned off, you won\'t send or receive Read Receipts. Read Receipts are always sent for group chats.',
                  value: s.readReceipts,
                  icon: Icons.done_all,
                  onChanged: (value) =>
                      _updateSetting(s.copyWith(readReceipts: value)),
                ),
                const SizedBox(height: 24),
                _buildSectionHeader(context, 'Disappearing messages'),
                _buildPrivacyItem(
                  context,
                  title: 'Default message timer',
                  value: _formatValue(s.defaultMessageTimer),
                  icon: Icons.timer_outlined,
                  onTap: () => _showOptionsDialog(
                    title: 'Default message timer',
                    currentValue: s.defaultMessageTimer,
                    options: [
                      'after_seen',
                      '12_hours',
                      '24_hours',
                      '48_hours',
                      'custom',
                    ],
                    onSelected: (val) {
                      if (val == 'custom') {
                        _showCustomTimerDialog();
                      } else {
                        _updateSetting(s.copyWith(defaultMessageTimer: val));
                      }
                    },
                  ),
                ),
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  void _showCustomTimerDialog() {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Custom Timer (Hours)'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: 'Enter hours (1-72)',
            suffixText: 'hours',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final hours = int.tryParse(controller.text);
              if (hours != null && hours > 0 && hours <= 72) {
                _updateSetting(
                  _settings!.copyWith(defaultMessageTimer: '${hours}_hours'),
                );
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter 1-72 hours')),
                );
              }
            },
            child: const Text('Set'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildPrivacyItem(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    const color = Colors.teal;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
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
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
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

  Widget _buildSwitchItem(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool value,
    required IconData icon,
    required ValueChanged<bool> onChanged,
  }) {
    final theme = Theme.of(context);
    const color = Colors.teal;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                Row(
                  children: [
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
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
