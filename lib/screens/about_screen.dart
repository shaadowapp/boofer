import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
                FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (context, snapshot) {
                    final version = snapshot.data?.version ?? '1.0.0';
                    final build = snapshot.data?.buildNumber ?? '6';
                    return _buildSectionContainer(
                      context,
                      title: 'App Information',
                      icon: Icons.info_outline,
                      color: Colors.blue,
                      children: [
                        _buildInfoTile(context, 'Version', version),
                        _buildInfoTile(context, 'Build', build),
                        _buildInfoTile(context, 'Release Date', 'February 2026'),
                        _buildInfoTile(context, 'Engine', 'Shorebird Engine'),
                        _buildInfoTile(
                          context,
                          'Identity',
                          'Virtual Number System',
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 24),

                // Company Information
                _buildSectionContainer(
                  context,
                  title: 'Developer',
                  icon: Icons.business_outlined,
                  color: Colors.indigo,
                  children: [
                    _buildInfoTile(context, 'Developer', 'Shaadow Platforms'),
                    _buildInfoTile(context, 'Website', 'shaadow.com'),
                    _buildInfoTile(
                      context,
                      'Support Email',
                      'hello@shaadow.com',
                    ),
                    _buildInfoTile(context, 'Headquarters', 'Odisha, India'),
                  ],
                ),

                const SizedBox(height: 24),

                // Key Features
                _buildSectionContainer(
                  context,
                  title: 'Privacy Focus',
                  icon: Icons.security_rounded,
                  color: Colors.green,
                  children: [
                    _buildFeatureTile(
                      context,
                      'Virtual Numbers',
                      'Communicate without revealing your real SIM number.',
                      Colors.blue,
                    ),
                    _buildFeatureTile(
                      context,
                      'No Tracking',
                      'We do not collect personal usage metadata or logs.',
                      Colors.red,
                    ),
                    _buildFeatureTile(
                      context,
                      'End-to-End Encryption',
                      'Your data is encrypted before it leaves your device.',
                      Colors.green,
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

    // Using layout similar to MainScreen app bar branding but centered
    return Column(
      children: [
        const SizedBox(height: 32),
        // Just the logo, simpler and consistent with request
        SvgPicture.asset(
          'assets/images/logo/boofer-logo.svg',
          height: 60,
          width: 200,
          // Removed manual color filter to let original logo colors show
        ),
        const SizedBox(height: 16),
        Text(
          'Next-gen private messaging with virtual identities',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
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
        color: theme.colorScheme.surfaceContainerLow.withOpacity(0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
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
              color: color.withOpacity(0.1),
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
          color: color.withOpacity(0.1),
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
        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
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
          'Developed by Shaadow Platforms',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          '© 2026. Shaadow Platforms. All rights reserved.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
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
              _buildLicenseTile(context, 'Flutter Framework', 'Google (BSD-3)'),
              _buildLicenseTile(context, 'Supabase Flutter', 'MIT License'),
              _buildLicenseTile(context, 'Provider', 'MIT License'),
              _buildLicenseTile(context, 'SQLite (sqflite)', 'MIT License'),
              _buildLicenseTile(context, 'Flutter SVG', 'MIT License'),
              _buildLicenseTile(context, 'Shared Preferences', 'BSD-3'),
              _buildLicenseTile(context, 'Google Fonts', 'OFL'),
              _buildLicenseTile(context, 'Lucide Icons', 'ISC License'),
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

  Widget _buildLicenseTile(BuildContext context, String name, String subtitle) {
    final theme = Theme.of(context);

    return ListTile(
      title: Text(
        name,
        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
