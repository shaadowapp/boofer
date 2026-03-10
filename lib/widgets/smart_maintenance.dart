import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../models/system_status_model.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:version/version.dart';
import '../screens/force_update_screen.dart';

/// A smart wrapper that shows a maintenance message for specific features
class SmartMaintenance extends StatelessWidget {
  final Widget child;
  final bool Function(SystemStatus status) check;
  final String? featureName;

  const SmartMaintenance({
    super.key,
    required this.child,
    required this.check,
    this.featureName,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SystemStatus>(
      stream: SupabaseService.instance.systemStatusStream,
      initialData: SupabaseService.instance.currentStatus,
      builder: (context, snapshot) {
        final status = snapshot.data ?? SystemStatus.initial();

        // 1. Force Update (The Critical Requirement)
        if (status.forceUpdate) {
          return FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, packageSnapshot) {
              if (packageSnapshot.hasData) {
                try {
                  final packageInfo = packageSnapshot.data!;
                  final currentVersion = Version.parse(packageInfo.version);
                  final minVersion = Version.parse(status.minAppVersion);

                  if (currentVersion < minVersion) {
                    return ForceUpdateScreen(
                      updateUrl: status.updateUrl,
                      currentVersion: packageInfo.version,
                      minVersion: status.minAppVersion,
                    );
                  }
                } catch (e) {
                  debugPrint('⚠️ [UPDATE] Version parsing error: $e');
                }
              }
              return _buildOverlayCheck(context, status, check);
            },
          );
        }

        return _buildOverlayCheck(context, status, check);
      },
    );
  }

  Widget _buildOverlayCheck(BuildContext context, SystemStatus status, bool Function(SystemStatus status) check) {
    // 2. Global Maintenance (The Nuclear Option)
    if (status.isGlobalMaintenance) {
      return _buildMaintenanceOverlay(context, status.maintenanceMessage,
          isGlobal: true);
    }

    // 3. Feature-specific check
    if (!check(status)) {
      return _buildMaintenanceOverlay(context, status.maintenanceMessage,
          isGlobal: false);
    }

    return child;
  }

  Widget _buildMaintenanceOverlay(BuildContext context, String message,
      {required bool isGlobal}) {
    final theme = Theme.of(context);

    return Container(
      color: isGlobal ? theme.scaffoldBackgroundColor : Colors.transparent,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isGlobal ? Icons.construction : Icons.auto_fix_high,
                size: 64,
                color: theme.colorScheme.primary.withValues(alpha: 0.7),
              ),
              const SizedBox(height: 24),
              Text(
                isGlobal
                    ? 'Global Maintenance'
                    : '${featureName ?? "Feature"} Maintenance',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
              if (!isGlobal) ...[
                const SizedBox(height: 32),
                TextButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Go Back'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
