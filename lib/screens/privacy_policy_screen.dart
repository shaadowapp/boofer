import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('Privacy Policy'),
            centerTitle: true,
            backgroundColor: theme.colorScheme.surface,
            scrolledUnderElevation: 0,
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16.0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildLastUpdated(context),
                const SizedBox(height: 24),
                _buildSection(
                  context,
                  '1. Commitment to Anonymity',
                  'Boofer is designed with a "Privacy First" architecture. We do not require, collect, or store your personal phone number, email address, or real-world identity. Your identity on Boofer is strictly virtual and anonymous.',
                  Icons.visibility_off_outlined,
                  Colors.purple,
                ),
                _buildSection(
                  context,
                  '2. Data Collection & Minimization',
                  'We practice extreme data minimization. The only data we process is what is strictly necessary for the app to function:\n\n'
                      '• **Virtual Identity**: Your chosen display name and avatar.\n'
                      '• **Device Tokens**: Used solely for delivering notifications and are not linked to personal identities.\n'
                      '• ** ephemeral metadata**: Temporary connection data required to route messages.',
                  Icons.data_usage_outlined,
                  Colors.blue,
                ),
                _buildSection(
                  context,
                  '3. Local-First Storage',
                  'Your messages and media are stored locally on your device. Boofer does not store your conversation history on our servers. Once a message is delivered, it is deleted from our delivery queue. You have full control and ownership of your data.',
                  Icons.storage_outlined,
                  Colors.amber,
                ),
                _buildSection(
                  context,
                  '4. End-to-End Encryption',
                  'All private messages and calls are protected by end-to-end encryption. This means only you and the person you are communicating with can read or listen to them. Boofer (and anyone else) cannot access your private communications.',
                  Icons.lock_outline,
                  Colors.green,
                ),
                _buildSection(
                  context,
                  '5. No Third-Party Tracking',
                  'We do not sell your data. We do not use third-party trackers or analytics frameworks that monitor your individual behavior. Your usage patterns remain private.',
                  Icons.do_not_disturb_on_outlined,
                  Colors.red,
                ),
                _buildSection(
                  context,
                  '6. Account Deletion',
                  'You can delete your account at any time from the Settings menu. Deleting your account legally and physically wipes your virtual identity from our directory. Since messages are stored locally, you must manually clear your app data to remove local history.',
                  Icons.delete_forever_outlined,
                  Colors.deepOrange,
                ),
                _buildSection(
                  context,
                  '7. Disclaimer of Liability',
                  'As an anonymous platform, Boofer cannot verify user identities. We are not responsible for the content, conduct, or authenticity of any user interactions. Users interact at their own risk.',
                  Icons.warning_amber_rounded,
                  Colors.grey,
                ),
                _buildFooter(context),
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLastUpdated(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.access_time,
            size: 16,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Text(
            'Last Updated: February 2025',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    String content,
    IconData icon,
    Color color,
  ) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.3),
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
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            content,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.6,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Icon(
            Icons.gavel,
            size: 40,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),
          Text(
            'For legal inquiries, contact legal@boofer.app',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}
