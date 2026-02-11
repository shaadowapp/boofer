import 'package:flutter/material.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('Terms of Service'),
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
                  '1. Acceptance of Terms',
                  'By accessing or using Boofer, you agree to be bound by these Terms. If you do not agree to these terms, you may not use the service. Boofer is a communication tool provided "AS IS" without any warranties.',
                  Icons.check_circle_outline,
                  Colors.green,
                ),
                _buildSection(
                  context,
                  '2. User Responsibility & Conduct',
                  'You are solely responsible for all content, messages, and calls you transmit through Boofer. You agree NOT to use the service for:\n\n'
                      '• Illegal activities or promotion of illegal acts.\n'
                      '• Harassment, bullying, or hate speech.\n'
                      '• Distribution of malware or spam.\n'
                      '• Infringement of intellectual property rights.',
                  Icons.person_outline,
                  Colors.blue,
                ),
                _buildSection(
                  context,
                  '3. Monitoring & Enforcement',
                  'Boofer is an encrypted, anonymous platform. We CANNOT monitor your private conversations. We rely on user reports to identify violations. We reserve the right to suspend or ban any user found violating these terms, at our sole discretion, without notice.',
                  Icons.admin_panel_settings_outlined,
                  Colors.orange,
                ),
                _buildSection(
                  context,
                  '4. Limitation of Liability',
                  'TO THE MAXIMUM EXTENT PERMITTED BY LAW, BOOFER AND ITS CREATORS SHALL NOT BE LIABLE FOR ANY INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, OR PUNITIVE DAMAGES, OR ANY LOSS OF PROFITS OR REVENUES, WHETHER INCURRED DIRECTLY OR INDIRECTLY, OR ANY LOSS OF DATA, USE, GOODWILL, OR OTHER INTANGIBLE LOSSES, RESULTING FROM (A) YOUR ACCESS TO OR USE OF OR INABILITY TO ACCESS OR USE THE SERVICE; (B) ANY CONDUCT OR CONTENT OF ANY THIRD PARTY ON THE SERVICE.',
                  Icons.warning_amber_rounded,
                  Colors.red,
                ),
                _buildSection(
                  context,
                  '5. Indemnification',
                  'You agree to defend, indemnify, and hold harmless Boofer and its team from and against any claims, liabilities, damages, losses, and expenses, including, without limitation, reasonable legal and accounting fees, arising out of or in any way connected with your access to or use of the Service or your violation of these Terms.',
                  Icons.shield_outlined,
                  Colors.indigo,
                ),
                _buildSection(
                  context,
                  '6. Governing Law',
                  'These Terms shall be governed by and construed in accordance with the laws of the jurisdiction in which the app developers reside, without regard to its conflict of law provisions.',
                  Icons.gavel_outlined,
                  Colors.grey,
                ),
                const SizedBox(height: 40),
                Center(
                  child: Text(
                    '© 2025 Boofer Technologies',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
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
      alignment: Alignment.center,
      child: Text(
        'Effective Date: February 12, 2025',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.bold,
        ),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 12),
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
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow.withValues(
                alpha: 0.3,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.05),
              ),
            ),
            child: Text(
              content,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.5,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
