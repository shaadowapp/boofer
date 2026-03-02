import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';
import '../services/unified_storage_service.dart';
import '../services/code_push_service.dart';
import 'changelogs_screen.dart';

class UpdatesScreen extends StatefulWidget {
  const UpdatesScreen({super.key});

  @override
  State<UpdatesScreen> createState() => _UpdatesScreenState();
}

class _UpdatesScreenState extends State<UpdatesScreen> {
  final _updater = ShorebirdUpdater();
  bool _autoUpdate = true;
  String? _currentVersion;
  int? _currentPatch;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadVersionInfo();
  }

  Future<void> _loadSettings() async {
    final autoUpdate = await UnifiedStorageService.getBool(
      'auto_update_enabled',
      defaultValue: true,
    );

    if (!mounted) return;
    setState(() {
      _autoUpdate = autoUpdate;
    });
  }

  Future<void> _loadVersionInfo() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      await CodePushService.instance.syncPatchInfo();

      if (!mounted) return;
      setState(() {
        _currentVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
        _currentPatch = CodePushService.instance.currentPatch.value;
      });
    } catch (e) {
      debugPrint('Error loading version info: $e');
    }
  }

  Future<void> _manualCheck() async {
    if (_isChecking) return;

    setState(() => _isChecking = true);

    try {
      await CodePushService.instance.checkForUpdates(context);
      await _loadVersionInfo(); // Refresh UI values
    } catch (e) {
      if (mounted) _showSnackBar('Update check failed: $e', Colors.red);
    } finally {
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          'Software Updates',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildShorebirdWarning(),
            _buildStatusHeader(),
            const SizedBox(height: 30),
            _buildVersionInfoCard(),
            const SizedBox(height: 20),
            _buildSettingsSection(),
            const SizedBox(height: 30),
            _buildInfoSection(),
            const SizedBox(height: 40),
            Center(
              child: Opacity(
                opacity: 0.5,
                child: Text(
                  'Powered by Shorebird Engine',
                  style: theme.textTheme.labelSmall,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildShorebirdWarning() {
    return FutureBuilder<bool>(
      future: CodePushService.instance.isShorebirdAvailable,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const SizedBox.shrink();
        final available = snapshot.data ?? false;
        if (available) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.only(bottom: 24),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.orange.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.orange),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Shorebird Not Detected',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                    Text(
                      'Update engine is only active in Release mode. If you are testing, build a release APK/Bundle.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusHeader() {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
            ),
            Icon(
              _isChecking ? Icons.sync : Icons.verified_user_rounded,
              size: 50,
              color: colorScheme.primary,
            ).animate(_isChecking),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          _isChecking
              ? 'Checking for updates...'
              : CodePushService.instance.isUpdateReady.value
                  ? 'Update is ready!'
                  : 'System is up to date',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        if (!_isChecking)
          Text(
            CodePushService.instance.isUpdateReady.value
                ? 'High-speed update downloaded & staged'
                : 'Version: $_currentVersion',
            style: TextStyle(
              color: colorScheme.onSurface.withOpacity(0.5),
              fontSize: 13,
            ),
          ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _isChecking ? null : _manualCheck,
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            elevation: 0,
          ),
          child: _isChecking
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text(
                  'Check for Updates',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
        ),
      ],
    );
  }

  Widget _buildVersionInfoCard() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.4),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          _buildInfoRow(
            Icons.info_outline,
            'Current Version',
            _currentVersion ?? 'Loading...',
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1),
          ),
          _buildInfoRow(
            Icons.memory_rounded,
            'Patch Level',
            _currentPatch == null
                ? 'Base Version (No Patch)'
                : 'Patch #$_currentPatch',
            trailing: _currentPatch != null ? _buildPatchBadge() : null,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value, {
    Widget? trailing,
  }) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _buildPatchBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: const Text(
        'ACTIVE',
        style: TextStyle(
          color: Colors.green,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSettingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'SETTINGS',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withOpacity(0.4),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              SwitchListTile(
                value: _autoUpdate,
                onChanged: (value) async {
                  setState(() => _autoUpdate = value);
                  await UnifiedStorageService.setBool(
                      'auto_update_enabled', value);
                },
                title: const Text('Automatic Fast Downloads'),
                subtitle: const Text(
                  'Always downloads critical security and feature fixes in under 30s',
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ChangelogsScreen(),
                  ),
                ),
                title: const Text('View Changelogs'),
                subtitle: const Text('What\'s new in this version'),
                trailing: const Icon(Icons.chevron_right, size: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoSection() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withOpacity(0.05),
            theme.colorScheme.secondary.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              const Text(
                'Instant Delivery',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Our app uses instant patching technology. This allows us to fix bugs and add features immediately without waiting for app store reviews. Updates download silently in the background and apply when you next start the app.',
            style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }
}

extension on Widget {
  Widget animate(bool active) {
    if (!active) return this;
    return _AnimatedWidget(child: this);
  }
}

class _AnimatedWidget extends StatefulWidget {
  final Widget child;
  const _AnimatedWidget({required this.child});
  @override
  State<_AnimatedWidget> createState() => _AnimatedWidgetState();
}

class _AnimatedWidgetState extends State<_AnimatedWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(turns: _controller, child: widget.child);
  }
}
