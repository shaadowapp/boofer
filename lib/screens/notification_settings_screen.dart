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
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar.large(
            title: const Text('Notifications'),
            centerTitle: true,
            backgroundColor: theme.colorScheme.surface,
            scrolledUnderElevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                tooltip: 'System Settings',
                onPressed: () => _openSystemSettings(context),
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildSectionContainer(
                  context,
                  title: 'Communication',
                  icon: Icons.chat_bubble_outline_rounded,
                  color: Colors.blue,
                  children: [
                    _buildChannelTile(
                      context,
                      icon: Icons.message_rounded,
                      title: 'Messages',
                      subtitle: 'Direct messages',
                      channelId: NotificationChannels.messages,
                      color: Colors.blue,
                    ),
                    const Divider(height: 1),

                    const Divider(height: 1),
                    _buildChannelTile(
                      context,
                      icon: Icons.call_rounded,
                      title: 'Calls',
                      subtitle: 'Incoming voice & video calls',
                      channelId: NotificationChannels.calls,
                      color: Colors.green,
                    ),
                    const Divider(height: 1),
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
                const SizedBox(height: 24),
                _buildSectionContainer(
                  context,
                  title: 'Social Activity',
                  icon: Icons.people_outline_rounded,
                  color: Colors.pink,
                  children: [
                    _buildChannelTile(
                      context,
                      icon: Icons.alternate_email_rounded,
                      title: 'Mentions',
                      subtitle: 'When someone mentions you',
                      channelId: NotificationChannels.mentions,
                      color: Colors.indigo,
                    ),
                    const Divider(height: 1),
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
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionContainer(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
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
    final isEnabled = _channelEnabled[channelId] ?? true;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isEnabled
              ? color.withValues(alpha: 0.1)
              : theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: isEnabled
              ? color
              : theme.colorScheme.onSurface.withValues(alpha: 0.4),
          size: 24,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: isEnabled
              ? theme.colorScheme.onSurface
              : theme.colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: theme.colorScheme.onSurfaceVariant.withValues(
            alpha: isEnabled ? 1.0 : 0.5,
          ),
          fontSize: 12,
        ),
      ),
      trailing: Switch(
        value: isEnabled,
        activeColor: color,
        onChanged: (value) {
          setState(() => _channelEnabled[channelId] = value);
          HapticFeedback.lightImpact();
        },
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
      useSafeArea: true,
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
