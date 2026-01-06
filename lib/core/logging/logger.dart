import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

enum LogLevel {
  debug,
  info,
  warning,
  error,
  critical,
}

class Logger {
  static const String _name = 'Boofer';
  
  static void debug(String message, {Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.debug, message, error: error, stackTrace: stackTrace);
  }
  
  static void info(String message, {Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.info, message, error: error, stackTrace: stackTrace);
  }
  
  static void warning(String message, {Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.warning, message, error: error, stackTrace: stackTrace);
  }
  
  static void error(String message, {Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.error, message, error: error, stackTrace: stackTrace);
  }
  
  static void critical(String message, {Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.critical, message, error: error, stackTrace: stackTrace);
  }
  
  static void _log(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (kDebugMode) {
      final timestamp = DateTime.now().toIso8601String();
      final levelStr = level.name.toUpperCase().padRight(8);
      final logMessage = '[$timestamp] [$levelStr] $message';
      
      if (error != null) {
        developer.log(
          logMessage,
          name: _name,
          error: error,
          stackTrace: stackTrace,
          level: _getLogLevelValue(level),
        );
      } else {
        developer.log(
          logMessage,
          name: _name,
          level: _getLogLevelValue(level),
        );
      }
    }
  }
  
  static int _getLogLevelValue(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return 500;
      case LogLevel.info:
        return 800;
      case LogLevel.warning:
        return 900;
      case LogLevel.error:
        return 1000;
      case LogLevel.critical:
        return 1200;
    }
  }
}