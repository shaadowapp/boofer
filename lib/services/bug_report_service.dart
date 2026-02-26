import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../core/models/app_error.dart';

class BugReportService {
  static final BugReportService instance = BugReportService._internal();
  BugReportService._internal();

  final _supabase = Supabase.instance.client;

  Future<void> reportError(AppError error) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final deviceInfo = kIsWeb
          ? 'Web'
          : '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
      final userId = _supabase.auth.currentUser?.id;

      await _supabase.from('bug_reports').insert({
        'id': 'BUG_${DateTime.now().millisecondsSinceEpoch}',
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
