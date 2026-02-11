import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'privacy_policy_screen.dart';
import 'terms_of_service_screen.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('About Boofer'),
            centerTitle: true,
            backgroundColor: theme.colorScheme.surface,
            scrolledUnderElevation: 0,
          ),
          SliverToBoxAdapter(child: _buildAppHeader(context)),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // App Information
                _buildSectionContainer(
                  context,
                  title: 'App Information',
                  icon: Icons.info_outline,
                  color: Colors.blue,
                  children: [
                    _buildInfoTile(context, 'Version', '1.0.0'),
                    _buildInfoTile(context, 'Build Number', '100'),
                    _buildInfoTile(context, 'Release Date', 'January 2025'),
                    _buildInfoTile(context, 'Platform', 'Flutter'),
                    _buildInfoTile(
                      context,
                      'Minimum OS',
                      'Android 6.0 / iOS 12.0',
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Company Information
                _buildSectionContainer(
                  context,
                  title: 'Company',
                  icon: Icons.business_outlined,
                  color: Colors.indigo,
                  children: [
                    _buildInfoTile(context, 'Developer', 'Boofer Team'),
                    _buildInfoTile(context, 'Website', 'boofer.app'),
                    _buildInfoTile(
                      context,
                      'Support Email',
                      'support@boofer.app',
                    ),
                    _buildInfoTile(context, 'Location', 'Global'),
                  ],
                ),

                const SizedBox(height: 24),

                // Features
                _buildSectionContainer(
                  context,
                  title: 'Key Features',
                  icon: Icons.star_outline,
                  color: Colors.amber,
                  children: [
                    _buildFeatureTile(
                      context,
                      'Virtual Identity',
                      'Anonymous profile with virtual number',
                      Colors.purple,
                    ),
                    _buildFeatureTile(
                      context,
                      'Private Messaging',
                      'Secure, end-to-end encrypted chats',
                      Colors.green,
                    ),
                    _buildFeatureTile(
                      context,
                      'Friend Discovery',
                      'Find friends via username or QR',
                      Colors.blue,
                    ),
                    _buildFeatureTile(
                      context,
                      'Media Sharing',
                      'Share photos, videos, and files',
                      Colors.orange,
                    ),
                    _buildFeatureTile(
                      context,
                      'No Data Tracking',
                      'Your conversations belong to you',
                      Colors.red,
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Legal and Links
                _buildSectionContainer(
                  context,
                  title: 'Legal & Links',
                  icon: Icons.gavel_outlined,
                  color: Colors.blueGrey,
                  children: [
                    _buildActionTile(
                      context,
                      title: 'Privacy Policy',
                      icon: Icons.privacy_tip_outlined,
                      color: Colors.teal,
                      onTap: () => _showPrivacyPolicy(context),
                    ),
                    _buildActionTile(
                      context,
                      title: 'Terms of Service',
                      icon: Icons.description_outlined,
                      color: Colors.deepPurple,
                      onTap: () => _showTermsOfService(context),
                    ),
                    _buildActionTile(
                      context,
                      title: 'Open Source Licenses',
                      icon: Icons.code_outlined,
                      color: Colors.black87,
                      onTap: () => _showOpenSourceLicenses(context),
                    ),
                    _buildActionTile(
                      context,
                      title: 'Rate the App',
                      icon: Icons.star_rate_rounded,
                      color: Colors.amber,
                      onTap: () => _showRateApp(context),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Footer
                _buildFooter(context),
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppHeader(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        const SizedBox(height: 16),
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [theme.colorScheme.primary, theme.colorScheme.tertiary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(
            Icons.message_rounded,
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
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Secure messaging with virtual numbers',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
            ),
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

  Widget _buildInfoTile(BuildContext context, String label, String value) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureTile(
    BuildContext context,
    String title,
    String description,
    Color color,
  ) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.check_rounded, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
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

  Widget _buildActionTile(
    BuildContext context, {
    required String title,
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
      trailing: Icon(
        Icons.chevron_right,
        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
        size: 20,
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
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          '© 2025 Boofer Technologies. All rights reserved.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildSocialButton(
              context,
              icon: Icons.language,
              label: 'Website',
              onTap: () =>
                  _copyToClipboard(context, 'www.boofer.com', 'Website URL'),
            ),
            const SizedBox(width: 16),
            _buildSocialButton(
              context,
              icon: Icons.email_outlined,
              label: 'Email',
              onTap: () =>
                  _copyToClipboard(context, 'support@boofer.com', 'Email'),
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
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
          ),
          borderRadius: BorderRadius.circular(12),
          color: theme.colorScheme.surface,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$label copied to clipboard')));
  }

  void _showPrivacyPolicy(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PrivacyPolicyScreen()),
    );
  }

  void _showTermsOfService(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TermsOfServiceScreen()),
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
              _buildLicenseTile(
                context,
                'Flutter',
                'BSD 3-Clause License',
                'https://flutter.dev',
              ),
              _buildLicenseTile(
                context,
                'Provider',
                'MIT License',
                'https://pub.dev/packages/provider',
              ),
              _buildLicenseTile(
                context,
                'Shared Preferences',
                'BSD 3-Clause License',
                'https://pub.dev/packages/shared_preferences',
              ),
              _buildLicenseTile(
                context,
                'Flutter SVG',
                'MIT License',
                'https://pub.dev/packages/flutter_svg',
              ),
              _buildLicenseTile(
                context,
                'Path Provider',
                'BSD 3-Clause License',
                'https://pub.dev/packages/path_provider',
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
              children: List.generate(
                5,
                (index) => const Icon(
                  Icons.star_rounded,
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

  Widget _buildLicenseTile(
    BuildContext context,
    String name,
    String license,
    String url,
  ) {
    final theme = Theme.of(context);

    return ListTile(
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(
        license,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Icon(
        Icons.open_in_new,
        size: 16,
        color: theme.colorScheme.primary,
      ),
      onTap: () {
        // In a real app, this would open the URL
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Would open: $url')));
      },
    );
  }
}
