import 'package:flutter/material.dart';

class StorageUsageScreen extends StatefulWidget {
  const StorageUsageScreen({super.key});

  @override
  State<StorageUsageScreen> createState() => _StorageUsageScreenState();
}

class _StorageUsageScreenState extends State<StorageUsageScreen> {
  // Mock data
  final int _imagesSize = 125000000; // 125 MB
  final int _videosSize = 450000000; // 450 MB
  final int _audioSize = 45000000; // 45 MB
  final int _documentsSize = 15000000; // 15 MB
  final int _otherSize = 50000000; // 50 MB

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalSize =
        _imagesSize + _videosSize + _audioSize + _documentsSize + _otherSize;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('Storage Usage'),
            centerTitle: true,
            backgroundColor: theme.colorScheme.surface,
            scrolledUnderElevation: 0,
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildUsageChart(context, totalSize),
                const SizedBox(height: 32),
                Text(
                  'DETAILS',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                _buildUsageItem(
                  context,
                  title: 'Images',
                  size: _imagesSize,
                  icon: Icons.image_outlined,
                  color: Colors.purple,
                ),
                _buildUsageItem(
                  context,
                  title: 'Videos',
                  size: _videosSize,
                  icon: Icons.videocam_outlined,
                  color: Colors.blue,
                ),
                _buildUsageItem(
                  context,
                  title: 'Audio',
                  size: _audioSize,
                  icon: Icons.audiotrack_outlined,
                  color: Colors.orange,
                ),
                _buildUsageItem(
                  context,
                  title: 'Documents',
                  size: _documentsSize,
                  icon: Icons.description_outlined,
                  color: Colors.green,
                ),
                _buildUsageItem(
                  context,
                  title: 'Other',
                  size: _otherSize,
                  icon: Icons.folder_outlined,
                  color: Colors.grey,
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsageChart(BuildContext context, int totalSize) {
    final theme = Theme.of(context);

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 160,
                  height: 160,
                  child: CircularProgressIndicator(
                    value: 1.0,
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.3,
                    ),
                    strokeWidth: 16,
                  ),
                ),
                SizedBox(
                  width: 160,
                  height: 160,
                  child: CircularProgressIndicator(
                    value: 0.7, // Mock usage
                    color: theme.colorScheme.primary,
                    strokeWidth: 16,
                    backgroundColor: Colors.transparent,
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatSize(totalSize),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      'Used',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUsageItem(
    BuildContext context, {
    required String title,
    required int size,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {}, // Detail view could differ
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
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
                  child: Text(
                    title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Text(
                  _formatSize(size),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
