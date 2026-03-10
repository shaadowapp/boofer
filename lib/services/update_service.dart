import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:upgrader/upgrader.dart';
import 'supabase_service.dart';
import 'package:version/version.dart';

class UpdateService {
  static final UpdateService instance = UpdateService._internal();
  UpdateService._internal();

  final upgrader = Upgrader(
    debugLogging: true,
    durationUntilAlertAgain: const Duration(seconds: 1),
  );

  /// Checks if a forceful update is required based on Supabase system status
  Future<bool> isUpdateRequired() async {
    try {
      final status = SupabaseService.instance.currentStatus;
      if (!status.forceUpdate) return false;

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = Version.parse(packageInfo.version);
      final minVersion = Version.parse(status.minAppVersion);

      return currentVersion < minVersion;
    } catch (e) {
      debugPrint('⚠️ [UPDATE] Error checking for required update: $e');
      return false;
    }
  }

  /// Displays the update UI if required.
  /// Typically called from a widget build method or a post-frame callback.
  Widget wrapWithUpgradeAlert({required Widget child}) {
    return UpgradeAlert(
      upgrader: upgrader,
      child: child,
    );
  }
}
