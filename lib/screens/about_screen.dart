import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        title: const Text('About Boofer'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // App Logo and Info
            _buildAppHeader(context),
            
            const SizedBox(height: 32),
            
            // App Information
            _buildSection(
              context,
              title: 'App Information',
              children: [
                _buildInfoTile('Version', '1.0.0'),
                _buildInfoTile('Build Number', '100'),
                _buildInfoTile('Release Date', 'January 2025'),
                _buildInfoTile('Platform', 'Flutter'),
                _buildInfoTile('Minimum OS', 'Android 6.0 / iOS 12.0'),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Company Information
            _buildSection(
              context,
              title: 'Company',
              children: [
                _buildInfoTile('Developer', 'Boofer Technologies'),
                _buildInfoTile('Website', 'www.boofer.com'),
                _buildInfoTile('Support Email', 'support@boofer.com'),
                _buildInfoTile('Location', 'San Francisco, CA'),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Features
            _buildSection(
              context,
              title: 'Key Features',
              children: [
                _buildFeatureTile('Virtual Numbers', 'Protect your real phone number'),
                _buildFeatureTile('End-to-End Encryption', 'Secure messaging and calls'),
                _buildFeatureTile('Link Tree', 'Share your products and services'),
                _buildFeatureTile('Cross-Platform', 'Available on Android and iOS'),
                _buildFeatureTile('Privacy First', 'Your data stays private'),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Legal and Links
            _buildSection(
              context,
              title: 'Legal & Links',
              children: [
                _buildActionTile(
                  context,
                  title: 'Privacy Policy',
                  icon: Icons.privacy_tip,
                  onTap: () => _showPrivacyPolicy(context),
                ),
                _buildActionTile(
                  context,
                  title: 'Terms of Service',
                  icon: Icons.description,
                  onTap: () => _showTermsOfService(context),
                ),
                _buildActionTile(
                  context,
                  title: 'Open Source Licenses',
                  icon: Icons.code,
                  onTap: () => _showOpenSourceLicenses(context),
                ),
                _buildActionTile(
                  context,
                  title: 'Rate the App',
                  icon: Icons.star,
                  onTap: () => _showRateApp(context),
                ),
              ],
            ),
            
            const SizedBox(height: 32),
            
            // Footer
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildAppHeader(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(
            Icons.message,
            color: Colors.white,
            size: 50,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Boofer',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Secure messaging with virtual numbers',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.7),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'Version 1.0.0',
            style: TextStyle(
              color: theme.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
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

  Widget _buildInfoTile(String label, String value) {
    return ListTile(
      title: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      trailing: Text(
        value,
        style: TextStyle(
          color: Colors.grey.shade600,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  Widget _buildFeatureTile(String title, String description) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Icon(
          Icons.check,
          color: Colors.green,
          size: 16,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        description,
        style: TextStyle(
          color: Colors.grey.shade600,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required String title,
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
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: theme.colorScheme.onSurface.withOpacity(0.5),
      ),
      onTap: onTap,
    );
  }

  Widget _buildFooter(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      children: [
        Text(
          'Made with ❤️ by Boofer Technologies',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          '© 2025 Boofer Technologies. All rights reserved.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.5),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildSocialButton(
              context,
              icon: Icons.language,
              label: 'Website',
              onTap: () => _copyToClipboard(context, 'www.boofer.com', 'Website URL'),
            ),
            const SizedBox(width: 16),
            _buildSocialButton(
              context,
              icon: Icons.email,
              label: 'Email',
              onTap: () => _copyToClipboard(context, 'support@boofer.com', 'Email'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSocialButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(
            color: theme.colorScheme.outline.withOpacity(0.3),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied to clipboard')),
    );
  }

  void _showPrivacyPolicy(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy Policy'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPolicySection('Data Collection', 'We collect minimal data necessary for app functionality. Your messages are encrypted and stored locally.'),
                _buildPolicySection('Virtual Numbers', 'Virtual numbers are generated randomly and not linked to your real phone number.'),
                _buildPolicySection('Message Encryption', 'All messages use end-to-end encryption. We cannot read your messages.'),
                _buildPolicySection('Data Sharing', 'We do not share your personal data with third parties.'),
                _buildPolicySection('Data Retention', 'Messages are stored locally on your device. We do not store messages on our servers.'),
                _buildPolicySection('Account Deletion', 'You can delete your account and all associated data at any time.'),
              ],
            ),
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

  void _showTermsOfService(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terms of Service'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPolicySection('Acceptance', 'By using Boofer, you agree to these terms and conditions.'),
                _buildPolicySection('Service Usage', 'Use Boofer responsibly and in accordance with applicable laws.'),
                _buildPolicySection('Prohibited Activities', 'Do not use Boofer for spam, harassment, or illegal activities.'),
                _buildPolicySection('Account Responsibility', 'You are responsible for maintaining the security of your account.'),
                _buildPolicySection('Service Availability', 'We strive to maintain service availability but cannot guarantee 100% uptime.'),
                _buildPolicySection('Modifications', 'We may update these terms from time to time. Continued use constitutes acceptance.'),
              ],
            ),
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

  void _showOpenSourceLicenses(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Open Source Licenses'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView(
            children: [
              _buildLicenseTile(context, 'Flutter', 'BSD 3-Clause License', 'https://flutter.dev'),
              _buildLicenseTile(context, 'Provider', 'MIT License', 'https://pub.dev/packages/provider'),
              _buildLicenseTile(context, 'Shared Preferences', 'BSD 3-Clause License', 'https://pub.dev/packages/shared_preferences'),
              _buildLicenseTile(context, 'Flutter SVG', 'MIT License', 'https://pub.dev/packages/flutter_svg'),
              _buildLicenseTile(context, 'Path Provider', 'BSD 3-Clause License', 'https://pub.dev/packages/path_provider'),
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

  void _showRateApp(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rate Boofer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enjoying Boofer? Please rate us on the app store!'),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) => 
                Icon(
                  Icons.star,
                  color: Colors.amber,
                  size: 32,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Your feedback helps us improve the app for everyone.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Maybe Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Thank you for your feedback!')),
              );
            },
            child: const Text('Rate Now'),
          ),
        ],
      ),
    );
  }

  Widget _buildPolicySection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
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
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              color: Colors.grey.shade700,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLicenseTile(BuildContext context, String name, String license, String url) {
    return ListTile(
      title: Text(
        name,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(license),
      trailing: const Icon(Icons.open_in_new, size: 16),
      onTap: () {
        // In a real app, this would open the URL
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Would open: $url')),
        );
      },
    );
  }
}