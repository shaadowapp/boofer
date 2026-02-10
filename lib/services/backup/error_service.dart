import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../models/chat_error.dart';

/// Service for handling error logging, notification, and retry logic
class ErrorService {
  static final ErrorService _instance = ErrorService._internal();
  factory ErrorService() => _instance;
  ErrorService._internal();

  final StreamController<ChatError> _errorStreamController = StreamController<ChatError>.broadcast();
  final Queue<ChatError> _errorHistory = Queue<ChatError>();
  final Map<String, int> _retryAttempts = <String, int>{};
  final Map<String, DateTime> _lastRetryTime = <String, DateTime>{};
  
  static const int maxErrorHistorySize = 100;
  static const Duration minRetryDelay = Duration(seconds: 1);
  static const Duration maxRetryDelay = Duration(minutes: 5);

  /// Stream of errors for UI to listen to
  Stream<ChatError> get errorStream => _errorStreamController.stream;

  /// Get recent error history
  List<ChatError> get errorHistory => _errorHistory.toList();

  /// Log an error and potentially notify the user
  Future<void> logError(ChatError error) async {
    // Add to history
    _errorHistory.addLast(error);
    if (_errorHistory.length > maxErrorHistorySize) {
      _errorHistory.removeFirst();
    }

    // Log to console in debug mode
    if (kDebugMode) {
      debugPrint('ChatError: ${error.toString()}');
      if (error.stackTrace != null) {
        debugPrint('Stack trace: ${error.stackTrace}');
      }
      if (error.context != null) {
        debugPrint('Context: ${error.context}');
      }
    }

    // Emit error to stream for UI handling
    _errorStreamController.add(error);

    // Handle automatic retry if applicable
    if (error.isRetryable) {
      await _scheduleRetry(error);
    }
  }

  /// Log an error from an exception
  Future<void> logException(
    Exception exception, {
    required ErrorCategory category,
    ErrorSeverity severity = ErrorSeverity.medium,
    String? customMessage,
    Map<String, dynamic>? context,
    bool isRetryable = false,
  }) async {
    final error = ChatError(
      code: '${category.name.toUpperCase()}_EXCEPTION',
      message: customMessage ?? exception.toString(),
      severity: severity,
      category: category,
      stackTrace: StackTrace.current.toString(),
      context: context,
      originalException: exception,
      isRetryable: isRetryable,
    );

    await logError(error);
  }

  /// Schedule a retry for a retryable error
  Future<void> _scheduleRetry(ChatError error) async {
    final retryKey = '${error.code}_${error.message.hashCode}';
    final currentAttempts = _retryAttempts[retryKey] ?? 0;

    if (currentAttempts >= error.maxRetries) {
      debugPrint('Max retries exceeded for error: ${error.code}');
      return;
    }

    // Calculate exponential backoff delay
    final delay = _calculateRetryDelay(currentAttempts);
    final lastRetry = _lastRetryTime[retryKey];
    
    if (lastRetry != null && DateTime.now().difference(lastRetry) < delay) {
      // Too soon to retry
      return;
    }

    _retryAttempts[retryKey] = currentAttempts + 1;
    _lastRetryTime[retryKey] = DateTime.now();

    // Schedule the retry
    Timer(delay, () {
      _performRetry(error, currentAttempts + 1);
    });
  }

  /// Calculate exponential backoff delay
  Duration _calculateRetryDelay(int attemptNumber) {
    final baseDelay = minRetryDelay.inMilliseconds;
    final exponentialDelay = baseDelay * pow(2, attemptNumber);
    final jitteredDelay = exponentialDelay + Random().nextInt(1000); // Add jitter
    
    return Duration(
      milliseconds: min(jitteredDelay.toInt(), maxRetryDelay.inMilliseconds),
    );
  }

  /// Perform the actual retry logic
  Future<void> _performRetry(ChatError error, int attemptNumber) async {
    debugPrint('Retrying error: ${error.code} (attempt $attemptNumber/${error.maxRetries})');

    // Create a retry notification error
    final retryError = ChatError(
      code: 'RETRY_ATTEMPT',
      message: 'Retrying: ${error.message}',
      severity: ErrorSeverity.low,
      category: error.category,
      context: {
        'originalError': error.code,
        'attemptNumber': attemptNumber,
        'maxRetries': error.maxRetries,
      },
      isRetryable: false,
    );

    _errorStreamController.add(retryError);

    // Here you would implement the actual retry logic based on error category
    // For now, we'll just simulate a retry
    await _simulateRetry(error);
  }

  /// Simulate retry logic (to be replaced with actual retry implementations)
  Future<void> _simulateRetry(ChatError error) async {
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Simulate success/failure
    final success = Random().nextBool();
    
    if (success) {
      final successError = ChatError(
        code: 'RETRY_SUCCESS',
        message: 'Retry successful for: ${error.message}',
        severity: ErrorSeverity.low,
        category: error.category,
        context: {'originalError': error.code},
        isRetryable: false,
      );
      _errorStreamController.add(successError);
      
      // Clear retry attempts on success
      final retryKey = '${error.code}_${error.message.hashCode}';
      _retryAttempts.remove(retryKey);
      _lastRetryTime.remove(retryKey);
    }
  }

  /// Clear error history
  void clearErrorHistory() {
    _errorHistory.clear();
  }

  /// Get errors by category
  List<ChatError> getErrorsByCategory(ErrorCategory category) {
    return _errorHistory.where((error) => error.category == category).toList();
  }

  /// Get errors by severity
  List<ChatError> getErrorsBySeverity(ErrorSeverity severity) {
    return _errorHistory.where((error) => error.severity == severity).toList();
  }

  /// Get recent errors (last N errors)
  List<ChatError> getRecentErrors(int count) {
    final errors = _errorHistory.toList();
    return errors.length <= count 
        ? errors 
        : errors.sublist(errors.length - count);
  }

  /// Check if there are any critical errors
  bool get hasCriticalErrors {
    return _errorHistory.any((error) => error.severity == ErrorSeverity.critical);
  }

  /// Get error statistics
  Map<String, dynamic> getErrorStatistics() {
    final stats = <String, dynamic>{
      'totalErrors': _errorHistory.length,
      'criticalErrors': _errorHistory.where((e) => e.severity == ErrorSeverity.critical).length,
      'highSeverityErrors': _errorHistory.where((e) => e.severity == ErrorSeverity.high).length,
      'retryableErrors': _errorHistory.where((e) => e.isRetryable).length,
      'categoryCounts': <String, int>{},
      'severityCounts': <String, int>{},
    };

    // Count by category
    for (final category in ErrorCategory.values) {
      stats['categoryCounts'][category.name] = 
          _errorHistory.where((e) => e.category == category).length;
    }

    // Count by severity
    for (final severity in ErrorSeverity.values) {
      stats['severityCounts'][severity.name] = 
          _errorHistory.where((e) => e.severity == severity).length;
    }

    return stats;
  }

  /// Reset retry attempts for a specific error
  void resetRetryAttempts(String errorCode) {
    _retryAttempts.removeWhere((key, value) => key.startsWith(errorCode));
    _lastRetryTime.removeWhere((key, value) => key.startsWith(errorCode));
  }

  /// Dispose of the service
  void dispose() {
    _errorStreamController.close();
    _errorHistory.clear();
    _retryAttempts.clear();
    _lastRetryTime.clear();
  }
}