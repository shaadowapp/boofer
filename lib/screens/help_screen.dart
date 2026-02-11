import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('Help Center'),
            centerTitle: true,
            backgroundColor: theme.colorScheme.surface,
            scrolledUnderElevation: 0,
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Quick Actions
                _buildSectionContainer(
                  context,
                  title: 'Quick Actions',
                  icon: Icons.flash_on_rounded,
                  color: Colors.amber,
                  children: [
                    _buildHelpTile(
                      context,
                      title: 'Getting Started',
                      subtitle: 'Learn the basics of Boofer',
                      icon: Icons.play_circle_outline,
                      color: Colors.blue,
                      onTap: () => _showGettingStarted(context),
                    ),
                    _buildHelpTile(
                      context,
                      title: 'Contact Support',
                      subtitle: 'Get help from our team',
                      icon: Icons.support_agent,
                      color: Colors.green,
                      onTap: () => _showContactSupport(context),
                    ),
                    _buildHelpTile(
                      context,
                      title: 'Report a Problem',
                      subtitle: 'Report bugs or issues',
                      icon: Icons.bug_report_outlined,
                      color: Colors.red,
                      onTap: () => _showReportProblem(context),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Frequently Asked Questions
                _buildSectionContainer(
                  context,
                  title: 'Frequently Asked Questions',
                  icon: Icons.question_answer_outlined,
                  color: Colors.purple,
                  children: [
                    _buildFAQTile(
                      context,
                      'How do I find friends?',
                      'Use the search bar on the home screen to find users by their unique username or virtual number. You can also scan their QR code if available.',
                    ),
                    _buildFAQTile(
                      context,
                      'Is my real phone number visible?',
                      'No! Boofer assigns you a unique virtual number. Your real phone number is never shared with anyone on the app, ensuring complete privacy.',
                    ),
                    _buildFAQTile(
                      context,
                      'Are my messages secure?',
                      'Yes, all messages are end-to-end encrypted. We cannot read your messages, and they are not stored on our servers after delivery.',
                    ),
                    _buildFAQTile(
                      context,
                      'Can I use Boofer on multiple devices?',
                      'Currently, Boofer is designed for a single device to maintain maximum security. Multi-device support is planned for the future.',
                    ),
                    _buildFAQTile(
                      context,
                      'How do I backup my chats?',
                      'Go to Settings > Chat > Backups to create a local backup of your chat history. Cloud backups are coming soon.',
                    ),
                    _buildFAQTile(
                      context,
                      'What is a "Virtual Identity"?',
                      'Your Virtual Identity includes your virtual number, display name, and avatar. You can change your display name and avatar at any time.',
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Features Guide
                _buildSectionContainer(
                  context,
                  title: 'Features Guide',
                  icon: Icons.explore_outlined,
                  color: Colors.teal,
                  children: [
                    _buildHelpTile(
                      context,
                      title: 'Virtual Identity',
                      subtitle: 'Understanding your anonymous profile',
                      icon: Icons.perm_identity,
                      color: Colors.indigo,
                      onTap: () => _showGettingStarted(context),
                    ),
                    _buildHelpTile(
                      context,
                      title: 'Secure Messaging',
                      subtitle: 'Encryption and privacy',
                      icon: Icons.lock_outline,
                      color: Colors.deepOrange,
                      onTap: () => _showPrivacyGuide(context),
                    ),
                    _buildHelpTile(
                      context,
                      title: 'Voice & Video',
                      subtitle: 'Calling features guide',
                      icon: Icons.call_outlined,
                      color: Colors.cyan,
                      onTap: () => _showCallingGuide(context),
                    ),
                    _buildHelpTile(
                      context,
                      title: 'Friend System',
                      subtitle: 'Managing requests and contacts',
                      icon: Icons.people_outline,
                      color: Colors.pink,
                      onTap: () => _showProfileGuide(context),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Troubleshooting
                _buildSectionContainer(
                  context,
                  title: 'Troubleshooting',
                  icon: Icons.build_outlined,
                  color: Colors.blueGrey,
                  children: [
                    _buildHelpTile(
                      context,
                      title: 'Connection Issues',
                      subtitle: 'Fix connectivity problems',
                      icon: Icons.wifi_off_outlined,
                      color: Colors.orange,
                      onTap: () => _showConnectionTroubleshooting(context),
                    ),
                    _buildHelpTile(
                      context,
                      title: 'Notification Problems',
                      subtitle: 'Fix notification issues',
                      icon: Icons.notifications_off_outlined,
                      color: Colors.deepPurple,
                      onTap: () => _showNotificationTroubleshooting(context),
                    ),
                    _buildHelpTile(
                      context,
                      title: 'App Performance',
                      subtitle: 'Improve app speed and stability',
                      icon: Icons.speed_outlined,
                      color: Colors.blue,
                      onTap: () => _showPerformanceTips(context),
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

  Widget _buildHelpTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        title,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
        size: 20,
      ),
      onTap: onTap,
    );
  }

  Widget _buildFAQTile(BuildContext context, String question, String answer) {
    final theme = Theme.of(context);

    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(
        question,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      ),
      iconColor: theme.colorScheme.primary,
      collapsedIconColor: theme.colorScheme.onSurfaceVariant,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            answer,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  void _showGettingStarted(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Getting Started with Boofer'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView(
            children: [
              _buildGuideStep(
                context,
                '1',
                'Create Your Profile',
                'Set up your name, bio, and add links to your Link Tree.',
                Colors.blue,
              ),
              _buildGuideStep(
                context,
                '2',
                'Discover People',
                'Use the search feature to find and connect with friends.',
                Colors.green,
              ),
              _buildGuideStep(
                context,
                '3',
                'Start Messaging',
                'Send secure messages using your virtual number.',
                Colors.orange,
              ),
              _buildGuideStep(
                context,
                '4',
                'Make Calls',
                'Use voice and video calling features for real-time communication.',
                Colors.purple,
              ),
              _buildGuideStep(
                context,
                '5',
                'Customize Settings',
                'Adjust privacy, notifications, and appearance settings.',
                Colors.pink,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideStep(
    BuildContext context,
    String step,
    String title,
    String description,
    Color color,
  ) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Center(
              child: Text(
                step,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showContactSupport(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contact Support'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.email_outlined, color: Colors.blue),
              title: const Text('Email Support'),
              subtitle: const Text('support@boofer.com'),
              onTap: () {
                Clipboard.setData(
                  const ClipboardData(text: 'support@boofer.com'),
                );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Email copied to clipboard')),
                );
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.chat_bubble_outline,
                color: Colors.green,
              ),
              title: const Text('Live Chat'),
              subtitle: const Text('Available 24/7'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Live chat coming soon!')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.phone_outlined, color: Colors.orange),
              title: const Text('Phone Support'),
              subtitle: const Text('+1-800-BOOFER'),
              onTap: () {
                Clipboard.setData(const ClipboardData(text: '+1-800-BOOFER'));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Phone number copied to clipboard'),
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
    );
  }

  void _showReportProblem(BuildContext context) {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    String problemType = 'Bug Report';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Report a Problem'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: problemType,
                  decoration: const InputDecoration(
                    labelText: 'Problem Type',
                    border: OutlineInputBorder(),
                  ),
                  items:
                      [
                            'Bug Report',
                            'Feature Request',
                            'Account Issue',
                            'Performance Issue',
                            'Other',
                          ]
                          .map(
                            (type) => DropdownMenuItem(
                              value: type,
                              child: Text(type),
                            ),
                          )
                          .toList(),
                  onChanged: (value) => setState(() => problemType = value!),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Problem Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
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
                    content: Text('Problem report submitted successfully!'),
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

  void _showCallingGuide(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Voice & Video Calls'),
        content: SizedBox(
          width: double.maxFinite,
          height: 250,
          child: ListView(
            children: [
              _buildFeatureItem(
                context,
                'Voice Calls',
                'Tap the phone icon in any chat',
              ),
              _buildFeatureItem(
                context,
                'Video Calls',
                'Tap the video icon in any chat',
              ),
              _buildFeatureItem(
                context,
                'Call Controls',
                'Mute, speaker, and camera controls',
              ),
              _buildFeatureItem(
                context,
                'Call History',
                'View all calls in the Calls tab',
              ),
              _buildFeatureItem(
                context,
                'Call Quality',
                'Calls use your virtual number for privacy',
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

  void _showPrivacyGuide(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy Features'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView(
            children: [
              _buildFeatureItem(
                context,
                'Virtual Numbers',
                'Your real number stays private',
              ),
              _buildFeatureItem(
                context,
                'End-to-End Encryption',
                'All messages are encrypted',
              ),
              _buildFeatureItem(
                context,
                'Read Receipts',
                'Control who sees when you read messages',
              ),
              _buildFeatureItem(
                context,
                'Last Seen',
                'Choose who can see when you were online',
              ),
              _buildFeatureItem(
                context,
                'Profile Privacy',
                'Control who sees your profile info',
              ),
              _buildFeatureItem(
                context,
                'Block Users',
                'Block unwanted contacts easily',
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

  void _showProfileGuide(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Profile & Link Tree'),
        content: SizedBox(
          width: double.maxFinite,
          height: 250,
          child: ListView(
            children: [
              _buildFeatureItem(
                context,
                'Profile Setup',
                'Add your name, bio, and photo',
              ),
              _buildFeatureItem(
                context,
                'Link Tree',
                'Add links to your products or services',
              ),
              _buildFeatureItem(
                context,
                'Share Profile',
                'Share your profile with others',
              ),
              _buildFeatureItem(
                context,
                'Virtual Number',
                'Your unique number for contacts',
              ),
              _buildFeatureItem(
                context,
                'Profile Privacy',
                'Control who sees your information',
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

  void _showConnectionTroubleshooting(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connection Issues'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView(
            children: [
              _buildTroubleshootingStep(
                context,
                'Check Internet Connection',
                'Ensure you have a stable internet connection',
              ),
              _buildTroubleshootingStep(
                context,
                'Restart the App',
                'Close and reopen Boofer',
              ),
              _buildTroubleshootingStep(
                context,
                'Check App Permissions',
                'Ensure Boofer has network permissions',
              ),
              _buildTroubleshootingStep(
                context,
                'Update the App',
                'Make sure you have the latest version',
              ),
              _buildTroubleshootingStep(
                context,
                'Restart Device',
                'Restart your phone if issues persist',
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

  void _showNotificationTroubleshooting(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notification Problems'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView(
            children: [
              _buildTroubleshootingStep(
                context,
                'Check Notification Settings',
                'Go to Settings > Notifications',
              ),
              _buildTroubleshootingStep(
                context,
                'Allow Notifications',
                'Enable notifications in device settings',
              ),
              _buildTroubleshootingStep(
                context,
                'Check Do Not Disturb',
                'Disable Do Not Disturb mode',
              ),
              _buildTroubleshootingStep(
                context,
                'Battery Optimization',
                'Disable battery optimization for Boofer',
              ),
              _buildTroubleshootingStep(
                context,
                'Restart App',
                'Close and reopen the app',
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

  void _showPerformanceTips(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Performance Tips'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView(
            children: [
              _buildTroubleshootingStep(
                context,
                'Clear Cache',
                'Go to Settings > Storage > Clear Cache',
              ),
              _buildTroubleshootingStep(
                context,
                'Free Up Storage',
                'Delete old messages and media',
              ),
              _buildTroubleshootingStep(
                context,
                'Close Other Apps',
                'Close unused apps running in background',
              ),
              _buildTroubleshootingStep(
                context,
                'Restart Device',
                'Restart your phone regularly',
              ),
              _buildTroubleshootingStep(
                context,
                'Update App',
                'Keep Boofer updated to latest version',
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

  Widget _buildFeatureItem(
    BuildContext context,
    String title,
    String description,
  ) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 6, right: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
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

  Widget _buildTroubleshootingStep(
    BuildContext context,
    String title,
    String description,
  ) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle_outline,
            color: theme.colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
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
