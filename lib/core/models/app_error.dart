
/// Severity levels for application errors
enum ErrorSeverity {
  low,      // Minor issues that don't affect core functionality
  medium,   // Issues that affect some functionality but app remains usable
  high,     // Critical issues that significantly impact user experience
  critical, // Fatal errors that prevent core functionality
}

/// Categories of application errors
enum ErrorCategory {
  network,        // Network connectivity issues
  database,       // Database operation errors
  authentication, // Authentication and authorization errors
  validation,     // Data validation errors
  service,        // Service layer errors
  ui,            // User interface errors
  storage,       // Local storage errors
  permission,    // Permission-related errors
  initialization, // Service initialization errors
  unknown,       // Uncategorized errors
}

/// Comprehensive error class for the application
class AppError implements Exception {
  final String code;
  final String message;
  final ErrorSeverity severity;
  final ErrorCategory category;
  final DateTime timestamp;
  final StackTrace? stackTrace;
  final Map<String, dynamic>? context;
  final Exception? originalException;
  final bool isRetryable;
  final int maxRetries;

  AppError({
    required this.code,
    required this.message,
    required this.severity,
    required this.category,
    this.stackTrace,
    this.context,
    this.originalException,
    this.isRetryable = false,
    this.maxRetries = 3,
  }) : timestamp = DateTime.now();

  /// Factory constructors for common error types
  
  factory AppError.network({
    required String message,
    String? code,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
    Exception? originalException,
  }) {
    return AppError(
      code: code ?? 'NETWORK_ERROR',
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

  factory AppError.database({
    required String message,
    String? code,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
    Exception? originalException,
  }) {
    return AppError(
      code: code ?? 'DATABASE_ERROR',
      message: message,
      severity: ErrorSeverity.critical,
      category: ErrorCategory.database,
      stackTrace: stackTrace,
      context: context,
      originalException: originalException,
      isRetryable: false,
    );
  }

  factory AppError.authentication({
    required String message,
    String? code,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
    Exception? originalException,
  }) {
    return AppError(
      code: code ?? 'AUTH_ERROR',
      message: message,
      severity: ErrorSeverity.high,
      category: ErrorCategory.authentication,
      stackTrace: stackTrace,
      context: context,
      originalException: originalException,
      isRetryable: false,
    );
  }

  factory AppError.validation({
    required String message,
    String? code,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
    Exception? originalException,
  }) {
    return AppError(
      code: code ?? 'VALIDATION_ERROR',
      message: message,
      severity: ErrorSeverity.medium,
      category: ErrorCategory.validation,
      stackTrace: stackTrace,
      context: context,
      originalException: originalException,
      isRetryable: false,
    );
  }

  factory AppError.service({
    required String message,
    String? code,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
    Exception? originalException,
  }) {
    return AppError(
      code: code ?? 'SERVICE_ERROR',
      message: message,
      severity: ErrorSeverity.medium,
      category: ErrorCategory.service,
      stackTrace: stackTrace,
      context: context,
      originalException: originalException,
      isRetryable: true,
    );
  }

  /// Convert error to a user-friendly message
  String get userMessage {
    switch (category) {
      case ErrorCategory.network:
        return 'Network connection issue. Please check your internet connection.';
      case ErrorCategory.database:
        return 'Data storage issue. Please restart the app.';
      case ErrorCategory.authentication:
        return 'Authentication failed. Please log in again.';
      case ErrorCategory.validation:
        return 'Invalid data provided. Please check your input.';
      case ErrorCategory.service:
        return 'Service temporarily unavailable. Please try again.';
      case ErrorCategory.ui:
        return 'Interface error occurred. Please refresh the screen.';
      case ErrorCategory.storage:
        return 'Storage access issue. Please check app permissions.';
      case ErrorCategory.permission:
        return 'Permission required. Please grant necessary permissions.';
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
      'stackTrace': stackTrace?.toString(),
      'context': context,
      'originalException': originalException?.toString(),
      'isRetryable': isRetryable,
      'maxRetries': maxRetries,
    };
  }

  /// Create AppError from JSON
  factory AppError.fromJson(Map<String, dynamic> json) {
    return AppError(
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
      isRetryable: json['isRetryable'] as bool? ?? false,
      maxRetries: json['maxRetries'] as int? ?? 3,
    );
  }

  @override
  String toString() {
    return 'AppError(code: $code, message: $message, severity: ${severity.name}, category: ${category.name})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppError &&
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