import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/notification_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  // Channel preferences state
  final Map<String, bool> _channelEnabled = {};
  final Map<String, bool> _soundEnabled = {};
  final Map<String, bool> _vibrationEnabled = {};
  final Map<String, bool> _previewsEnabled = {};
  final Map<String, String> _importance = {};

  @override
  void initState() {
    super.initState();
    _initializeDefaults();
  }

  void _initializeDefaults() {
    // Initialize all channels with default values
    final channels = [
      NotificationChannels.messages,
      NotificationChannels.groupMessages,
      NotificationChannels.calls,
      NotificationChannels.missedCalls,
      NotificationChannels.friendRequests,
      NotificationChannels.mentions,
      NotificationChannels.reactions,
    ];

    for (final channel in channels) {
      _channelEnabled[channel] = true;
      _soundEnabled[channel] = true;
      _vibrationEnabled[channel] = true;
      _previewsEnabled[channel] = true;
      _importance[channel] = 'High';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        title: const Text('Notifications'),
      ),
      body: ListView(
        children: [
          _buildSection(
            context,
            title: 'MESSAGES',
            children: [
              _buildChannelTile(
                context,
                icon: Icons.message_rounded,
                title: 'Messages',
                subtitle: 'Direct messages',
                channelId: NotificationChannels.messages,
                color: Colors.blue,
              ),
              _buildChannelTile(
                context,
                icon: Icons.groups_rounded,
                title: 'Groups',
                subtitle: 'Group chat messages',
                channelId: NotificationChannels.groupMessages,
                color: Colors.purple,
              ),
            ],
          ),
          _buildSection(
            context,
            title: 'CALLS',
            children: [
              _buildChannelTile(
                context,
                icon: Icons.call_rounded,
                title: 'Calls',
                subtitle: 'Incoming calls',
                channelId: NotificationChannels.calls,
                color: Colors.green,
              ),
              _buildChannelTile(
                context,
                icon: Icons.phone_missed_rounded,
                title: 'Missed Calls',
                subtitle: 'Missed call alerts',
                channelId: NotificationChannels.missedCalls,
                color: Colors.orange,
              ),
            ],
          ),
          _buildSection(
            context,
            title: 'OTHER',
            children: [
              _buildChannelTile(
                context,
                icon: Icons.person_add_rounded,
                title: 'Friend Requests',
                subtitle: 'New friend requests',
                channelId: NotificationChannels.friendRequests,
                color: Colors.teal,
              ),
              _buildChannelTile(
                context,
                icon: Icons.alternate_email_rounded,
                title: 'Mentions',
                subtitle: 'When someone mentions you',
                channelId: NotificationChannels.mentions,
                color: Colors.indigo,
              ),
              _buildChannelTile(
                context,
                icon: Icons.favorite_rounded,
                title: 'Reactions',
                subtitle: 'Message reactions',
                channelId: NotificationChannels.reactions,
                color: Colors.pink,
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
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
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        ...children,
      ],
    );
  }

  Widget _buildChannelTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String channelId,
    required Color color,
  }) {
    final theme = Theme.of(context);

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Icon(
        Icons.chevron_right,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
      ),
      onTap: () => _openChannelSettings(context, channelId, title, icon, color),
    );
  }

  void _openChannelSettings(
    BuildContext context,
    String channelId,
    String channelName,
    IconData icon,
    Color color,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ChannelSettingsBottomSheet(
        channelId: channelId,
        channelName: channelName,
        icon: icon,
        color: color,
        isEnabled: _channelEnabled[channelId] ?? true,
        soundEnabled: _soundEnabled[channelId] ?? true,
        vibrationEnabled: _vibrationEnabled[channelId] ?? true,
        previewsEnabled: _previewsEnabled[channelId] ?? true,
        importance: _importance[channelId] ?? 'High',
        onToggle: (value) {
          setState(() => _channelEnabled[channelId] = value);
        },
        onSoundToggle: (value) {
          setState(() => _soundEnabled[channelId] = value);
        },
        onVibrationToggle: (value) {
          setState(() => _vibrationEnabled[channelId] = value);
        },
        onPreviewsToggle: (value) {
          setState(() => _previewsEnabled[channelId] = value);
        },
        onImportanceChange: (value) {
          setState(() => _importance[channelId] = value);
        },
        onOpenSystemSettings: () => _openSystemSettings(context),
      ),
    );
  }

  Future<void> _openSystemSettings(BuildContext context) async {
    try {
      const platform = MethodChannel('com.shaadow.boofer/settings');
      await platform.invokeMethod('openNotificationSettings');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to open system settings automatically'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }
}

class _ChannelSettingsBottomSheet extends StatefulWidget {
  final String channelId;
  final String channelName;
  final IconData icon;
  final Color color;
  final bool isEnabled;
  final bool soundEnabled;
  final bool vibrationEnabled;
  final bool previewsEnabled;
  final String importance;
  final ValueChanged<bool> onToggle;
  final ValueChanged<bool> onSoundToggle;
  final ValueChanged<bool> onVibrationToggle;
  final ValueChanged<bool> onPreviewsToggle;
  final ValueChanged<String> onImportanceChange;
  final VoidCallback onOpenSystemSettings;

  const _ChannelSettingsBottomSheet({
    required this.channelId,
    required this.channelName,
    required this.icon,
    required this.color,
    required this.isEnabled,
    required this.soundEnabled,
    required this.vibrationEnabled,
    required this.previewsEnabled,
    required this.importance,
    required this.onToggle,
    required this.onSoundToggle,
    required this.onVibrationToggle,
    required this.onPreviewsToggle,
    required this.onImportanceChange,
    required this.onOpenSystemSettings,
  });

  @override
  State<_ChannelSettingsBottomSheet> createState() =>
      _ChannelSettingsBottomSheetState();
}

class _ChannelSettingsBottomSheetState
    extends State<_ChannelSettingsBottomSheet> {
  late bool _localEnabled;
  late bool _localSound;
  late bool _localVibration;
  late bool _localPreviews;
  late String _localImportance;

  @override
  void initState() {
    super.initState();
    _localEnabled = widget.isEnabled;
    _localSound = widget.soundEnabled;
    _localVibration = widget.vibrationEnabled;
    _localPreviews = widget.previewsEnabled;
    _localImportance = widget.importance;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with gradient background
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    widget.color.withValues(alpha: isDark ? 0.3 : 0.15),
                    widget.color.withValues(alpha: isDark ? 0.15 : 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Drag handle
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Channel icon
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: widget.color.withValues(
                        alpha: isDark ? 0.25 : 0.2,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(widget.icon, color: widget.color, size: 36),
                  ),
                  const SizedBox(height: 16),
                  // Channel name
                  Text(
                    widget.channelName,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Enable/Disable toggle
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _localEnabled ? 'Enabled' : 'Disabled',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: _localEnabled
                              ? widget.color
                              : theme.colorScheme.onSurface.withValues(
                                  alpha: 0.5,
                                ),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Switch(
                        value: _localEnabled,
                        activeColor: widget.color,
                        onChanged: (value) {
                          setState(() => _localEnabled = value);
                          widget.onToggle(value);
                          HapticFeedback.lightImpact();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Settings options
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sound toggle
                  _buildSettingTile(
                    context,
                    icon: Icons.volume_up_rounded,
                    title: 'Sound',
                    subtitle: 'Play notification sound',
                    value: _localSound,
                    enabled: _localEnabled,
                    onChanged: (value) {
                      setState(() => _localSound = value);
                      widget.onSoundToggle(value);
                      HapticFeedback.lightImpact();
                    },
                  ),

                  // Vibration toggle
                  _buildSettingTile(
                    context,
                    icon: Icons.vibration_rounded,
                    title: 'Vibration',
                    subtitle: 'Vibrate on notification',
                    value: _localVibration,
                    enabled: _localEnabled,
                    onChanged: (value) {
                      setState(() => _localVibration = value);
                      widget.onVibrationToggle(value);
                      HapticFeedback.lightImpact();
                    },
                  ),

                  // Previews toggle
                  _buildSettingTile(
                    context,
                    icon: Icons.visibility_rounded,
                    title: 'Show Previews',
                    subtitle: 'Display message content',
                    value: _localPreviews,
                    enabled: _localEnabled,
                    onChanged: (value) {
                      setState(() => _localPreviews = value);
                      widget.onPreviewsToggle(value);
                      HapticFeedback.lightImpact();
                    },
                  ),

                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),

                  // Importance level
                  Text(
                    'Importance Level',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildImportanceChip(context, 'High', Colors.red),
                      const SizedBox(width: 8),
                      _buildImportanceChip(context, 'Medium', Colors.orange),
                      const SizedBox(width: 8),
                      _buildImportanceChip(context, 'Low', Colors.blue),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // System settings button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onOpenSystemSettings();
                      },
                      icon: const Icon(Icons.settings_rounded),
                      label: const Text('Advanced Settings'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(
                          color: theme.colorScheme.outline.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required bool enabled,
    required ValueChanged<bool> onChanged,
  }) {
    final theme = Theme.of(context);
    final opacity = enabled ? 1.0 : 0.4;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        enabled: enabled,
        leading: Icon(
          icon,
          color: theme.colorScheme.onSurface.withValues(alpha: opacity),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: theme.colorScheme.onSurface.withValues(alpha: opacity),
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: theme.colorScheme.onSurface.withValues(alpha: opacity * 0.7),
          ),
        ),
        trailing: Switch(
          value: value,
          onChanged: enabled ? onChanged : null,
          activeColor: widget.color,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }

  Widget _buildImportanceChip(BuildContext context, String level, Color color) {
    final theme = Theme.of(context);
    final isSelected = _localImportance == level;
    final isEnabled = _localEnabled;

    return Expanded(
      child: FilterChip(
        selected: isSelected,
        label: Center(
          child: Text(
            level,
            style: TextStyle(
              color: isSelected && isEnabled
                  ? Colors.white
                  : theme.colorScheme.onSurface.withValues(
                      alpha: isEnabled ? 0.8 : 0.4,
                    ),
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
        backgroundColor: theme.colorScheme.surface,
        selectedColor: isEnabled ? color : color.withValues(alpha: 0.3),
        onSelected: isEnabled
            ? (selected) {
                if (selected) {
                  setState(() => _localImportance = level);
                  widget.onImportanceChange(level);
                  HapticFeedback.selectionClick();
                }
              }
            : null,
        side: BorderSide(
          color: isSelected && isEnabled
              ? color
              : theme.colorScheme.outline.withValues(alpha: 0.3),
          width: isSelected ? 2 : 1,
        ),
      ),
    );
  }
}
