import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/notification_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
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
              ),
              _buildChannelTile(
                context,
                icon: Icons.groups_rounded,
                title: 'Groups',
                subtitle: 'Group chat messages',
                channelId: NotificationChannels.groupMessages,
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
              ),
              _buildChannelTile(
                context,
                icon: Icons.phone_missed_rounded,
                title: 'Missed Calls',
                subtitle: 'Missed call alerts',
                channelId: NotificationChannels.missedCalls,
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
              ),
              _buildChannelTile(
                context,
                icon: Icons.alternate_email_rounded,
                title: 'Mentions',
                subtitle: 'When someone mentions you',
                channelId: NotificationChannels.mentions,
              ),
              _buildChannelTile(
                context,
                icon: Icons.favorite_rounded,
                title: 'Reactions',
                subtitle: 'Message reactions',
                channelId: NotificationChannels.reactions,
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
  }) {
    final theme = Theme.of(context);

    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.onSurface),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Icon(
        Icons.chevron_right,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
      ),
      onTap: () => _openChannelSettings(context, channelId, title),
    );
  }

  void _openChannelSettings(BuildContext context, String channelId, String channelName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(channelName),
        content: const Text(
          'Notification channels are managed in your device settings.\n\n'
          'You can customize:\n'
          '• Sound\n'
          '• Vibration\n'
          '• Importance level\n'
          '• Do Not Disturb override',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _openSystemSettings(context);
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _openSystemSettings(BuildContext context) async {
    try {
      const platform = MethodChannel('com.shaadow.boofer/settings');
      await platform.invokeMethod('openNotificationSettings');
    } catch (e) {
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Open Notification Settings'),
            content: const Text(
              'To customize notifications:\n\n'
              '1. Open device Settings\n'
              '2. Go to Apps & notifications\n'
              '3. Find "Boofer"\n'
              '4. Tap Notifications\n'
              '5. Customize each channel',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }
}
