import 'package:flutter/material.dart';
import '../services/unified_storage_service.dart';

class NetworkUsageScreen extends StatefulWidget {
  const NetworkUsageScreen({super.key});

  @override
  State<NetworkUsageScreen> createState() => _NetworkUsageScreenState();
}

class _NetworkUsageScreenState extends State<NetworkUsageScreen> {
  int _sentMessages = 0;
  int _receivedMessages = 0;
  int _sentMedia = 0;
  int _receivedMedia = 0;
  int _sentCalls = 0;
  int _receivedCalls = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final msgsSent =
        await UnifiedStorageService.getInt(
          UnifiedStorageService.networkUsageMessagesSent,
        ) ??
        0;
    final msgsRecv =
        await UnifiedStorageService.getInt(
          UnifiedStorageService.networkUsageMessagesReceived,
        ) ??
        0;
    final mediaSent =
        await UnifiedStorageService.getInt(
          UnifiedStorageService.networkUsageMediaSent,
        ) ??
        0;
    final mediaRecv =
        await UnifiedStorageService.getInt(
          UnifiedStorageService.networkUsageMediaReceived,
        ) ??
        0;
    final callsSent =
        await UnifiedStorageService.getInt(
          UnifiedStorageService.networkUsageCallsSent,
        ) ??
        0;
    final callsRecv =
        await UnifiedStorageService.getInt(
          UnifiedStorageService.networkUsageCallsReceived,
        ) ??
        0;

    if (mounted) {
      setState(() {
        _sentMessages = msgsSent;
        _receivedMessages = msgsRecv;
        _sentMedia = mediaSent;
        _receivedMedia = mediaRecv;
        _sentCalls = callsSent;
        _receivedCalls = callsRecv;
        _isLoading = false;
      });
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('Network Usage'),
            centerTitle: true,
            backgroundColor: theme.colorScheme.surface,
            scrolledUnderElevation: 0,
          ),
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildUsageInfo(
                    context,
                    title: 'Messages',
                    sent: _sentMessages,
                    received: _receivedMessages,
                    icon: Icons.message_outlined,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 16),
                  _buildUsageInfo(
                    context,
                    title: 'Media',
                    sent: _sentMedia,
                    received: _receivedMedia,
                    icon: Icons.image_outlined,
                    color: Colors.purple,
                  ),
                  const SizedBox(height: 16),
                  _buildUsageInfo(
                    context,
                    title: 'Calls',
                    sent: _sentCalls,
                    received: _receivedCalls,
                    icon: Icons.call_outlined,
                    color: Colors.green,
                  ),
                  const SizedBox(height: 32),
                  _buildResetButton(context),
                ]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUsageInfo(
    BuildContext context, {
    required String title,
    required int sent,
    required int received,
    required IconData icon,
    required Color color,
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
                width: 44,
                height: 44,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _formatBytes(sent + received),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.arrow_upward_rounded,
                          size: 16,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Sent',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatBytes(sent),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: theme.colorScheme.outlineVariant,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          'Received',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_downward_rounded,
                          size: 16,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatBytes(received),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResetButton(BuildContext context) {
    return Center(
      child: TextButton.icon(
        onPressed: () async {
          await UnifiedStorageService.resetNetworkUsage();
          await _loadData();
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Statistics reset')));
          }
        },
        icon: const Icon(Icons.refresh),
        label: const Text('Reset Statistics'),
        style: TextButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.error,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
    );
  }
}
