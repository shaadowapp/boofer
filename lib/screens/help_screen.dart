import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        title: const Text('Help Center'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Quick Actions
            _buildSection(
              context,
              title: 'Quick Actions',
              children: [
                _buildHelpTile(
                  context,
                  title: 'Getting Started',
                  subtitle: 'Learn the basics of Boofer',
                  icon: Icons.play_circle_outline,
                  onTap: () => _showGettingStarted(context),
                ),
                _buildHelpTile(
                  context,
                  title: 'Contact Support',
                  subtitle: 'Get help from our team',
                  icon: Icons.support_agent,
                  onTap: () => _showContactSupport(context),
                ),
                _buildHelpTile(
                  context,
                  title: 'Report a Problem',
                  subtitle: 'Report bugs or issues',
                  icon: Icons.bug_report,
                  onTap: () => _showReportProblem(context),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Frequently Asked Questions
            _buildSection(
              context,
              title: 'Frequently Asked Questions',
              children: [
                _buildFAQTile(
                  'How do I change my virtual number?',
                  'Virtual numbers are assigned automatically and cannot be changed. Each user gets a unique number for privacy and security.',
                ),
                _buildFAQTile(
                  'How do I backup my messages?',
                  'Messages are automatically saved on your device. Cloud backup feature is coming soon in future updates.',
                ),
                _buildFAQTile(
                  'Can I use Boofer on multiple devices?',
                  'Currently, Boofer works on one device at a time. Multi-device support is planned for future updates.',
                ),
                _buildFAQTile(
                  'How do I delete my account?',
                  'You can delete your account by going to Profile > Settings > Privacy & Security > Delete Account. This action cannot be undone.',
                ),
                _buildFAQTile(
                  'Why can\'t I see someone\'s last seen?',
                  'Users can choose to hide their last seen status in privacy settings. You can only see last seen if the user has enabled it.',
                ),
                _buildFAQTile(
                  'How do I block/unblock someone?',
                  'Go to the chat with the person, tap their name, and select "Block". To unblock, go to Settings > Privacy & Security > Blocked Users.',
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Features Guide
            _buildSection(
              context,
              title: 'Features Guide',
              children: [
                _buildHelpTile(
                  context,
                  title: 'Messaging',
                  subtitle: 'Send text, images, and files',
                  icon: Icons.message,
                  onTap: () => _showMessagingGuide(context),
                ),
                _buildHelpTile(
                  context,
                  title: 'Voice & Video Calls',
                  subtitle: 'Make secure calls',
                  icon: Icons.call,
                  onTap: () => _showCallingGuide(context),
                ),
                _buildHelpTile(
                  context,
                  title: 'Privacy Features',
                  subtitle: 'Virtual numbers and security',
                  icon: Icons.privacy_tip,
                  onTap: () => _showPrivacyGuide(context),
                ),
                _buildHelpTile(
                  context,
                  title: 'Profile & Link Tree',
                  subtitle: 'Manage your profile and links',
                  icon: Icons.person,
                  onTap: () => _showProfileGuide(context),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Troubleshooting
            _buildSection(
              context,
              title: 'Troubleshooting',
              children: [
                _buildHelpTile(
                  context,
                  title: 'Connection Issues',
                  subtitle: 'Fix connectivity problems',
                  icon: Icons.wifi_off,
                  onTap: () => _showConnectionTroubleshooting(context),
                ),
                _buildHelpTile(
                  context,
                  title: 'Notification Problems',
                  subtitle: 'Fix notification issues',
                  icon: Icons.notifications_off,
                  onTap: () => _showNotificationTroubleshooting(context),
                ),
                _buildHelpTile(
                  context,
                  title: 'App Performance',
                  subtitle: 'Improve app speed and stability',
                  icon: Icons.speed,
                  onTap: () => _showPerformanceTips(context),
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

  Widget _buildHelpTile(
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

  Widget _buildFAQTile(String question, String answer) {
    return ExpansionTile(
      title: Text(
        question,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Text(
            answer,
            style: TextStyle(
              color: Colors.grey.shade700,
              height: 1.4,
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
              _buildGuideStep('1', 'Create Your Profile', 'Set up your name, bio, and add links to your Link Tree.'),
              _buildGuideStep('2', 'Find Friends', 'Use the search feature to find and connect with friends.'),
              _buildGuideStep('3', 'Start Messaging', 'Send secure messages using your virtual number.'),
              _buildGuideStep('4', 'Make Calls', 'Use voice and video calling features for real-time communication.'),
              _buildGuideStep('5', 'Customize Settings', 'Adjust privacy, notifications, and appearance settings.'),
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

  Widget _buildGuideStep(String step, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                step,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
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
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey.shade600,
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
              leading: const Icon(Icons.email, color: Colors.blue),
              title: const Text('Email Support'),
              subtitle: const Text('support@boofer.com'),
              onTap: () {
                Clipboard.setData(const ClipboardData(text: 'support@boofer.com'));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Email copied to clipboard')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat, color: Colors.green),
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
              leading: const Icon(Icons.phone, color: Colors.orange),
              title: const Text('Phone Support'),
              subtitle: const Text('+1-800-BOOFER'),
              onTap: () {
                Clipboard.setData(const ClipboardData(text: '+1-800-BOOFER'));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Phone number copied to clipboard')),
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
                  value: problemType,
                  decoration: const InputDecoration(
                    labelText: 'Problem Type',
                    border: OutlineInputBorder(),
                  ),
                  items: ['Bug Report', 'Feature Request', 'Account Issue', 'Performance Issue', 'Other']
                      .map((type) => DropdownMenuItem(value: type, child: Text(type)))
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
                  const SnackBar(content: Text('Problem report submitted successfully!')),
                );
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  void _showMessagingGuide(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Messaging Guide'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView(
            children: [
              _buildFeatureItem('Send Text Messages', 'Type your message and tap send'),
              _buildFeatureItem('Share Images', 'Tap the camera icon to share photos'),
              _buildFeatureItem('Send Files', 'Tap the attachment icon to share documents'),
              _buildFeatureItem('Voice Messages', 'Hold the microphone button to record'),
              _buildFeatureItem('Message Reactions', 'Long press on messages to react'),
              _buildFeatureItem('Delete Messages', 'Long press and select delete'),
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
              _buildFeatureItem('Voice Calls', 'Tap the phone icon in any chat'),
              _buildFeatureItem('Video Calls', 'Tap the video icon in any chat'),
              _buildFeatureItem('Call Controls', 'Mute, speaker, and camera controls'),
              _buildFeatureItem('Call History', 'View all calls in the Calls tab'),
              _buildFeatureItem('Call Quality', 'Calls use your virtual number for privacy'),
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
              _buildFeatureItem('Virtual Numbers', 'Your real number stays private'),
              _buildFeatureItem('End-to-End Encryption', 'All messages are encrypted'),
              _buildFeatureItem('Read Receipts', 'Control who sees when you read messages'),
              _buildFeatureItem('Last Seen', 'Choose who can see when you were online'),
              _buildFeatureItem('Profile Privacy', 'Control who sees your profile info'),
              _buildFeatureItem('Block Users', 'Block unwanted contacts easily'),
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
              _buildFeatureItem('Profile Setup', 'Add your name, bio, and photo'),
              _buildFeatureItem('Link Tree', 'Add links to your products or services'),
              _buildFeatureItem('Share Profile', 'Share your profile with others'),
              _buildFeatureItem('Virtual Number', 'Your unique number for contacts'),
              _buildFeatureItem('Profile Privacy', 'Control who sees your information'),
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
              _buildTroubleshootingStep('Check Internet Connection', 'Ensure you have a stable internet connection'),
              _buildTroubleshootingStep('Restart the App', 'Close and reopen Boofer'),
              _buildTroubleshootingStep('Check App Permissions', 'Ensure Boofer has network permissions'),
              _buildTroubleshootingStep('Update the App', 'Make sure you have the latest version'),
              _buildTroubleshootingStep('Restart Device', 'Restart your phone if issues persist'),
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
              _buildTroubleshootingStep('Check Notification Settings', 'Go to Settings > Notifications'),
              _buildTroubleshootingStep('Allow Notifications', 'Enable notifications in device settings'),
              _buildTroubleshootingStep('Check Do Not Disturb', 'Disable Do Not Disturb mode'),
              _buildTroubleshootingStep('Battery Optimization', 'Disable battery optimization for Boofer'),
              _buildTroubleshootingStep('Restart App', 'Close and reopen the app'),
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
              _buildTroubleshootingStep('Clear Cache', 'Go to Settings > Storage > Clear Cache'),
              _buildTroubleshootingStep('Free Up Storage', 'Delete old messages and media'),
              _buildTroubleshootingStep('Close Other Apps', 'Close unused apps running in background'),
              _buildTroubleshootingStep('Restart Device', 'Restart your phone regularly'),
              _buildTroubleshootingStep('Update App', 'Keep Boofer updated to latest version'),
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

  Widget _buildFeatureItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 6, right: 12),
            decoration: const BoxDecoration(
              color: Colors.blue,
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
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTroubleshootingStep(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_outline,
            color: Colors.green,
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
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
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