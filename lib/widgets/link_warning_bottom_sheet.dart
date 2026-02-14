import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/local_storage_service.dart';

class LinkWarningBottomSheet extends StatelessWidget {
  final String url;
  final String domain;

  const LinkWarningBottomSheet({
    super.key,
    required this.url,
    required this.domain,
  });

  static Future<void> show(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    final domain = uri.host.toLowerCase();

    // Check if domain is trusted
    final trustedDomains = await LocalStorageService.getTrustedDomains();
    if (trustedDomains.any((d) => domain == d || domain.endsWith('.$d'))) {
      // It's trusted, open directly
      final launchUri = Uri.parse(url);
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri, mode: LaunchMode.externalApplication);
      }
      return;
    }

    if (!context.mounted) return;

    return showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => LinkWarningBottomSheet(url: url, domain: domain),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.amber,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Potential Harmful Link',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'The link you are trying to open goes to a domain that is not in your trust list:',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Text(
              domain,
              style: theme.textTheme.titleMedium?.copyWith(
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final launchUri = Uri.parse(url);
              if (await canLaunchUrl(launchUri)) {
                await launchUrl(
                  launchUri,
                  mode: LaunchMode.externalApplication,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Open anyway'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () async {
              await LocalStorageService.addTrustedDomain(domain);
              if (!context.mounted) return;
              Navigator.pop(context);
              final launchUri = Uri.parse(url);
              if (await canLaunchUrl(launchUri)) {
                await launchUrl(
                  launchUri,
                  mode: LaunchMode.externalApplication,
                );
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$domain added to trust list')),
              );
            },
            child: const Text('Add to trust list'),
          ),
        ],
      ),
    );
  }
}
