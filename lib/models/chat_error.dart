import 'package:flutter/foundation.dart';

/// Severity levels for chat errors
enum ErrorSeverity {
  low,      // Minor issues that don't affect core functionality
  medium,   // Issues that affect some functionality but app remains usable
  high,     // Critical issues that significantly impact user experience
  critical, // Fatal errors that prevent core functionality
}

/// Categories of chat errors
enum ErrorCategory {
  network,      // Network connectivity issues
  mesh,         // Mesh networking specific errors
  online,       // Online service (Supabase) errors
  database,     // Local database errors
  message,      // Message processing errors
  sync,         // Synchronization errors
  initialization, // Service initialization errors
  unknown,      // Uncategorized errors
}

/// Comprehensive error class for the chat application
class ChatError implements Exception {
  final String code;
  final String message;
  final ErrorSeverity severity;
  final ErrorCategory category;
  final DateTime timestamp;
  final String? stackTrace;
  final Map<String, dynamic>? context;
  final Exception? originalException;
  final bool isRetryable;
  final int maxRetries;

  ChatError._internal({
    required this.code,
    required this.message,
    required this.severity,
    required this.category,
    required this.timestamp,
    this.stackTrace,
    this.context,
    this.originalException,
    this.isRetryable = false,
    this.maxRetries = 3,
  });

  factory ChatError({
    required String code,
    required String message,
    required ErrorSeverity severity,
    required ErrorCategory category,
    String? stackTrace,
    Map<String, dynamic>? context,
    Exception? originalException,
    bool isRetryable = false,
    int maxRetries = 3,
  }) {
    return ChatError._internal(
      code: code,
      message: message,
      severity: severity,
      category: category,
      timestamp: DateTime.now(),
      stackTrace: stackTrace,
      context: context,
      originalException: originalException,
      isRetryable: isRetryable,
      maxRetries: maxRetries,
    );
  }

  /// Factory constructors for common error types
  
  factory ChatError.networkError({
    required String message,
    String? stackTrace,
    Map<String, dynamic>? context,
    Exception? originalException,
  }) {
    return ChatError(
      code: 'NETWORK_ERROR',
      message: message,
      severity: ErrorSeverity.high,
      category: ErrorCategory.network,
      stackTrace: stackTrace,
      context: context,
      originalException: originalException,
      isRetryable: true,
      maxRetries: 5,
    );
  }

  factory ChatError.meshError({
    required String message,
    String? stackTrace,
    Map<String, dynamic>? context,
    Exception? originalException,
  }) {
    return ChatError(
      code: 'MESH_ERROR',
      message: message,
      severity: ErrorSeverity.medium,
      category: ErrorCategory.mesh,
      stackTrace: stackTrace,
      context: context,
      originalException: originalException,
      isRetryable: true,
      maxRetries: 3,
    );
  }

  factory ChatError.onlineError({
    required String message,
    String? stackTrace,
    Map<String, dynamic>? context,
    Exception? originalException,
  }) {
    return ChatError(
      code: 'ONLINE_ERROR',
      message: message,
      severity: ErrorSeverity.medium,
      category: ErrorCategory.online,
      stackTrace: stackTrace,
      context: context,
      originalException: originalException,
      isRetryable: true,
      maxRetries: 3,
    );
  }

  factory ChatError.databaseError({
    required String message,
    String? stackTrace,
    Map<String, dynamic>? context,
    Exception? originalException,
  }) {
    return ChatError(
      code: 'DATABASE_ERROR',
      message: message,
      severity: ErrorSeverity.critical,
      category: ErrorCategory.database,
      stackTrace: stackTrace,
      context: context,
      originalException: originalException,
      isRetryable: false,
    );
  }

  factory ChatError.messageError({
    required String message,
    String? stackTrace,
    Map<String, dynamic>? context,
    Exception? originalException,
  }) {
    return ChatError(
      code: 'MESSAGE_ERROR',
      message: message,
      severity: ErrorSeverity.medium,
      category: ErrorCategory.message,
      stackTrace: stackTrace,
      context: context,
      originalException: originalException,
      isRetryable: true,
    );
  }

  factory ChatError.syncError({
    required String message,
    String? stackTrace,
    Map<String, dynamic>? context,
    Exception? originalException,
  }) {
    return ChatError(
      code: 'SYNC_ERROR',
      message: message,
      severity: ErrorSeverity.low,
      category: ErrorCategory.sync,
      stackTrace: stackTrace,
      context: context,
      originalException: originalException,
      isRetryable: true,
    );
  }

  factory ChatError.initializationError({
    required String message,
    String? stackTrace,
    Map<String, dynamic>? context,
    Exception? originalException,
  }) {
    return ChatError(
      code: 'INIT_ERROR',
      message: message,
      severity: ErrorSeverity.critical,
      category: ErrorCategory.initialization,
      stackTrace: stackTrace,
      context: context,
      originalException: originalException,
      isRetryable: true,
      maxRetries: 2,
    );
  }

  /// Create a copy of this error with updated properties
  ChatError copyWith({
    String? code,
    String? message,
    ErrorSeverity? severity,
    ErrorCategory? category,
    String? stackTrace,
    Map<String, dynamic>? context,
    Exception? originalException,
    bool? isRetryable,
    int? maxRetries,
  }) {
    return ChatError._internal(
      code: code ?? this.code,
      message: message ?? this.message,
      severity: severity ?? this.severity,
      category: category ?? this.category,
      timestamp: timestamp,
      stackTrace: stackTrace ?? this.stackTrace,
      context: context ?? this.context,
      originalException: originalException ?? this.originalException,
      isRetryable: isRetryable ?? this.isRetryable,
      maxRetries: maxRetries ?? this.maxRetries,
    );
  }

  /// Convert error to a user-friendly message
  String get userMessage {
    switch (category) {
      case ErrorCategory.network:
        return 'Network connection issue. Please check your internet connection.';
      case ErrorCategory.mesh:
        return 'Mesh network issue. Some nearby devices may not be reachable.';
      case ErrorCategory.online:
        return 'Online service temporarily unavailable. Trying to reconnect...';
      case ErrorCategory.database:
        return 'Local storage issue. Please restart the app.';
      case ErrorCategory.message:
        return 'Message could not be processed. Please try again.';
      case ErrorCategory.sync:
        return 'Synchronization issue. Messages may not be up to date.';
      case ErrorCategory.initialization:
        return 'App initialization failed. Please restart the app.';
      case ErrorCategory.unknown:
        return 'An unexpected error occurred. Please try again.';
    }
  }

  /// Convert error to JSON for logging
  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'message': message,
      'severity': severity.name,
      'category': category.name,
      'timestamp': timestamp.toIso8601String(),
      'stackTrace': stackTrace,
      'context': context,
      'originalException': originalException?.toString(),
      'isRetryable': isRetryable,
      'maxRetries': maxRetries,
    };
  }

  /// Create ChatError from JSON
  factory ChatError.fromJson(Map<String, dynamic> json) {
    return ChatError._internal(
      code: json['code'] as String,
      message: json['message'] as String,
      severity: ErrorSeverity.values.firstWhere(
        (e) => e.name == json['severity'],
        orElse: () => ErrorSeverity.medium,
      ),
      category: ErrorCategory.values.firstWhere(
        (e) => e.name == json['category'],
        orElse: () => ErrorCategory.unknown,
      ),
      timestamp: DateTime.parse(json['timestamp'] as String),
      stackTrace: json['stackTrace'] as String?,
      context: json['context'] as Map<String, dynamic>?,
      isRetryable: json['isRetryable'] as bool? ?? false,
      maxRetries: json['maxRetries'] as int? ?? 3,
    );
  }

  @override
  String toString() {
    return 'ChatError(code: $code, message: $message, severity: ${severity.name}, category: ${category.name}, timestamp: $timestamp)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChatError &&
        other.code == code &&
        other.message == message &&
        other.severity == severity &&
        other.category == category;
  }

  @override
  int get hashCode {
    return Object.hash(code, message, severity, category);
  }
}