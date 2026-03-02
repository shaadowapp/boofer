import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../models/system_status_model.dart';

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

        // 1. Global Maintenance (The Nuclear Option)
        if (status.isGlobalMaintenance) {
          return _buildMaintenanceOverlay(context, status.maintenanceMessage,
              isGlobal: true);
        }

        // 2. Feature-specific check
        if (!check(status)) {
          return _buildMaintenanceOverlay(context, status.maintenanceMessage,
              isGlobal: false);
        }

        return child;
      },
    );
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
                color: theme.colorScheme.primary.withOpacity(0.7),
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
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
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
