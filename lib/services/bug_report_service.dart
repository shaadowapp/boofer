import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../core/models/app_error.dart';

class BugReportService {
  static final BugReportService instance = BugReportService._internal();
  BugReportService._internal();

  final _supabase = Supabase.instance.client;

  // Cache to track recently reported errors to prevent duplicates
  // Key: Hash of (error category + message)
  final Map<String, DateTime> _recentReports = {};
  static const Duration _throttleDuration = Duration(minutes: 2);

  Future<void> reportError(AppError error) async {
    try {
      // 1. Generate unique signature for this error
      final String errorKey = '${error.category.name}_${error.message}';
      final DateTime now = DateTime.now();

      // 2. Check if we've reported this recently (within cooldown period)
      if (_recentReports.containsKey(errorKey)) {
        final lastReportAt = _recentReports[errorKey]!;
        if (now.difference(lastReportAt) < _throttleDuration) {
          debugPrint('⏭️ BugReportService: Throttling duplicate auto-report for: ${error.message}');
          return;
        }
      }

      // 3. Update cache with current time
      _recentReports[errorKey] = now;

      // 4. Periodically cleanup old entries to prevent memory leaks
      if (_recentReports.length > 50) {
        _recentReports.removeWhere((key, date) => now.difference(date) > _throttleDuration);
      }

      final packageInfo = await PackageInfo.fromPlatform();
      final deviceInfo = kIsWeb
          ? 'Web'
          : '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
      final userId = _supabase.auth.currentUser?.id;

      await _supabase.from('bug_reports').insert({
        'id': 'BUG_${now.millisecondsSinceEpoch}',
        'user_id': userId,
        'title': 'Auto-reported: ${error.category.name}',
        'description': error.message,
        'actual_behavior': error.originalException?.toString(),
        'steps_to_reproduce': 'Stacktrace: ${error.stackTrace?.toString()}',
        'device_info': deviceInfo,
        'app_version': '${packageInfo.version}+${packageInfo.buildNumber}',
        'severity': _mapSeverity(error.severity),
        'status': 'open',
      });
      debugPrint('✅ Bug report auto-inserted for error: ${error.message}');
    } catch (e) {
      debugPrint('❌ Failed to auto-report bug: $e');
    }
  }

  String _mapSeverity(ErrorSeverity severity) {
    switch (severity) {
      case ErrorSeverity.critical:
        return 'critical';
      case ErrorSeverity.high:
        return 'high';
      case ErrorSeverity.medium:
        return 'medium';
      case ErrorSeverity.low:
        return 'low';
    }
  }
}
