import 'dart:io';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';
import '../services/code_push_service.dart';

class SoftwareUpdateScreen extends StatefulWidget {
  const SoftwareUpdateScreen({super.key});

  @override
  State<SoftwareUpdateScreen> createState() => _SoftwareUpdateScreenState();
}

class _SoftwareUpdateScreenState extends State<SoftwareUpdateScreen> {
  bool _isChecking = false;

  Future<void> _handleCheckForUpdates() async {
    setState(() {
      _isChecking = true;
    });

    try {
      await CodePushService.instance.checkForUpdates(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isChecking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Software Update'),
        elevation: 0,
      ),
      body: FutureBuilder<List<dynamic>>(
        future: Future.wait([
          PackageInfo.fromPlatform(),
          CodePushService.instance.isShorebirdAvailable,
          CodePushService.instance.syncPatchInfo().then((_) => CodePushService.instance.currentPatch.value),
        ]),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final packageInfo = snapshot.data![0] as PackageInfo;
          final isShorebirdAvailable = snapshot.data![1] as bool;
          final patchNumber = snapshot.data![2] as int?;

          final version = packageInfo.version;
          final buildNumber = packageInfo.buildNumber;

          return Column(
            children: [
              const SizedBox(height: 48),
              // Icon Section
              Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.system_update_rounded,
                    size: 80,
                    color: colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              
              // Version Info
              Text(
                'Boofer OS',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Version $version+$buildNumber ${patchNumber != null ? '(Patch $patchNumber)' : ''}',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              
              if (!isShorebirdAvailable)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.withOpacity(0.3)),
                    ),
                    child: const Text(
                      '⚠️ DEBUG MODE: Updates disabled',
                      style: TextStyle(
                        color: Colors.amber,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 48),

              // Status Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    ValueListenableBuilder<UpdateStatus>(
                      valueListenable: CodePushService.instance.updateStatus,
                      builder: (context, status, _) {
                        return Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceVariant.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: colorScheme.outline.withOpacity(0.1),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _getStatusIcon(status),
                                color: _getStatusColor(status, colorScheme),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _getStatusTitle(status),
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _getStatusSubtitle(status),
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              if (status == UpdateStatus.restartRequired)
                                TextButton(
                                  onPressed: () => exit(0),
                                  child: const Text('RESTART'),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                    ValueListenableBuilder<String?>(
                      valueListenable: CodePushService.instance.lastError,
                      builder: (context, error, _) {
                        if (error == null) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            error,
                            style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Action Button
              Padding(
                padding: const EdgeInsets.all(24),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isChecking ? null : _handleCheckForUpdates,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: _isChecking
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Check for Update',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }

  IconData _getStatusIcon(UpdateStatus status) {
    if (_isChecking) return Icons.sync;
    switch (status) {
      case UpdateStatus.outdated: return Icons.downloading_rounded;
      case UpdateStatus.restartRequired: return Icons.restart_alt_rounded;
      case UpdateStatus.unavailable: return Icons.cloud_off_rounded;
      case UpdateStatus.upToDate: return Icons.check_circle_outline;
    }
  }

  Color _getStatusColor(UpdateStatus status, ColorScheme colorScheme) {
    if (_isChecking) return colorScheme.primary;
    switch (status) {
      case UpdateStatus.outdated: return Colors.orange;
      case UpdateStatus.restartRequired: return Colors.blue;
      case UpdateStatus.unavailable: return Colors.grey;
      case UpdateStatus.upToDate: return Colors.green;
    }
  }

  String _getStatusTitle(UpdateStatus status) {
    if (_isChecking) return 'Checking...';
    switch (status) {
      case UpdateStatus.outdated: return 'New update found!';
      case UpdateStatus.restartRequired: return 'Restart required';
      case UpdateStatus.unavailable: return 'Service unavailable';
      case UpdateStatus.upToDate: return 'Up to date';
    }
  }

  String _getStatusSubtitle(UpdateStatus status) {
    if (_isChecking) return 'Connecting to Boofer servers';
    switch (status) {
      case UpdateStatus.outdated: return 'Downloading the latest patch';
      case UpdateStatus.restartRequired: return 'Finish applying changes now';
      case UpdateStatus.unavailable: return 'Updates disabled in debug mode';
      case UpdateStatus.upToDate: return 'You have the latest version';
    }
  }
}
