import 'package:flutter/foundation.dart';

/// Simple logging utility for the application
/// Wraps Flutter's debugPrint with different log levels
class AppLogger {
  /// Log an informational message
  static void info(String message, [dynamic data]) {
    if (kDebugMode) {
      final output = data != null ? '$message: $data' : message;
      debugPrint('[INFO] $output');
    }
  }

  /// Log a warning message
  static void warning(String message, [dynamic data]) {
    if (kDebugMode) {
      final output = data != null ? '$message: $data' : message;
      debugPrint('[WARNING] $output');
    }
  }

  /// Log an error message
  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      debugPrint('[ERROR] $message');
      if (error != null) {
        debugPrint('[ERROR] Error: $error');
      }
      if (stackTrace != null) {
        debugPrint('[ERROR] Stack trace:\n$stackTrace');
      }
    }
  }

  /// Log a debug message (only in debug mode)
  static void debug(String message, [dynamic data]) {
    if (kDebugMode) {
      final output = data != null ? '$message: $data' : message;
      debugPrint('[DEBUG] $output');
    }
  }
}
