import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import '../models/app_error.dart';
import '../../services/bug_report_service.dart';

/// Global error handler for the application
class ErrorHandler {
  static final ErrorHandler _instance = ErrorHandler._internal();
  factory ErrorHandler() => _instance;
  ErrorHandler._internal();

  final StreamController<AppError> _errorController =
      StreamController<AppError>.broadcast();
  final List<AppError> _errorHistory = [];

  Stream<AppError> get errorStream => _errorController.stream;
  List<AppError> get errorHistory => List.unmodifiable(_errorHistory);

  /// Handle and log an error
  void handleError(AppError error) {
    _errorHistory.add(error);
    _errorController.add(error);

    // Log to console in debug mode
    if (kDebugMode) {
      developer.log(
        error.message,
        name: 'ErrorHandler',
        error: error.originalException,
        stackTrace: error.stackTrace,
        level: _getLogLevel(error.severity),
      );
    }

    // Auto-report bugs to Supabase
    BugReportService.instance.reportError(error);

    // In production, send to crash reporting service
    if (kReleaseMode && error.severity == ErrorSeverity.critical) {
      _reportToCrashlytics(error);
    }
  }

  /// Handle exceptions and convert to AppError
  void handleException(
    Exception exception, {
    String? message,
    ErrorSeverity severity = ErrorSeverity.medium,
    ErrorCategory category = ErrorCategory.unknown,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) {
    final error = AppError(
      code: _generateErrorCode(category),
      message: message ?? exception.toString(),
      severity: severity,
      category: category,
      stackTrace: stackTrace,
      context: context,
      originalException: exception,
    );

    handleError(error);
  }

  /// Clear error history
  void clearHistory() {
    _errorHistory.clear();
  }

  /// Get errors by severity
  List<AppError> getErrorsBySeverity(ErrorSeverity severity) {
    return _errorHistory.where((error) => error.severity == severity).toList();
  }

  /// Get errors by category
  List<AppError> getErrorsByCategory(ErrorCategory category) {
    return _errorHistory.where((error) => error.category == category).toList();
  }

  int _getLogLevel(ErrorSeverity severity) {
    switch (severity) {
      case ErrorSeverity.low:
        return 500; // INFO
      case ErrorSeverity.medium:
        return 900; // WARNING
      case ErrorSeverity.high:
        return 1000; // SEVERE
      case ErrorSeverity.critical:
        return 1200; // SHOUT
    }
  }

  String _generateErrorCode(ErrorCategory category) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${category.name.toUpperCase()}_${timestamp % 10000}';
  }

  void _reportToCrashlytics(AppError error) {
    // Production crash reporting
    // TODO: Uncomment when Firebase Crashlytics is configured
    // FirebaseCrashlytics.instance.recordError(
    //   error.originalException,
    //   error.stackTrace,
    //   reason: error.message,
    //   fatal: error.severity == ErrorSeverity.critical,
    // );

    // For now, log to console in release mode for debugging
    if (kReleaseMode) {
      developer.log(
        'CRITICAL ERROR: ${error.message}',
        name: 'CrashReport',
        error: error.originalException,
        stackTrace: error.stackTrace,
      );
    }
  }

  void dispose() {
    _errorController.close();
  }
}
