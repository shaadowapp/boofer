import 'package:flutter/material.dart';
import '../models/chat_error.dart';

/// Widget for displaying error notifications to users
class ErrorNotification extends StatelessWidget {
  final ChatError error;
  final VoidCallback? onDismiss;
  final VoidCallback? onRetry;
  final bool showDetails;

  const ErrorNotification({
    super.key,
    required this.error,
    this.onDismiss,
    this.onRetry,
    this.showDetails = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      color: _getBackgroundColor(),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  _getErrorIcon(),
                  color: _getIconColor(),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    error.userMessage,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _getTextColor(context),
                    ),
                  ),
                ),
                if (onDismiss != null)
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: onDismiss,
                    color: _getTextColor(context),
                  ),
              ],
            ),
            if (showDetails) ...[
              const SizedBox(height: 8),
              Text(
                'Error: ${error.code}',
                style: TextStyle(
                  fontSize: 12,
                  color: _getTextColor(context).withOpacity(0.7),
                  fontFamily: 'monospace',
                ),
              ),
              Text(
                'Time: ${_formatTimestamp(error.timestamp)}',
                style: TextStyle(
                  fontSize: 12,
                  color: _getTextColor(context).withOpacity(0.7),
                ),
              ),
            ],
            if (error.isRetryable && onRetry != null) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: onRetry,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getBackgroundColor() {
    switch (error.severity) {
      case ErrorSeverity.low:
        return Colors.blue.shade900.withOpacity(0.3);
      case ErrorSeverity.medium:
        return Colors.orange.shade900.withOpacity(0.3);
      case ErrorSeverity.high:
        return Colors.red.shade900.withOpacity(0.3);
      case ErrorSeverity.critical:
        return Colors.red.shade800.withOpacity(0.5);
    }
  }

  Color _getIconColor() {
    switch (error.severity) {
      case ErrorSeverity.low:
        return Colors.blue.shade400;
      case ErrorSeverity.medium:
        return Colors.orange.shade400;
      case ErrorSeverity.high:
        return Colors.red.shade400;
      case ErrorSeverity.critical:
        return Colors.red.shade300;
    }
  }

  Color _getTextColor(BuildContext context) {
    return Theme.of(context).colorScheme.onSurface;
  }

  IconData _getErrorIcon() {
    switch (error.category) {
      case ErrorCategory.network:
        return Icons.wifi_off;
      case ErrorCategory.mesh:
        return Icons.device_hub;
      case ErrorCategory.online:
        return Icons.cloud_off;
      case ErrorCategory.database:
        return Icons.storage;
      case ErrorCategory.message:
        return Icons.message;
      case ErrorCategory.sync:
        return Icons.sync_problem;
      case ErrorCategory.initialization:
        return Icons.error_outline;
      case ErrorCategory.unknown:
        return Icons.warning;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}

/// Snackbar for quick error notifications
class ErrorSnackBar {
  static void show(
    BuildContext context,
    ChatError error, {
    VoidCallback? onRetry,
  }) {
    final snackBar = SnackBar(
      content: Row(
        children: [
          Icon(
            _getErrorIcon(error.category),
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error.userMessage,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      backgroundColor: _getSnackBarColor(error.severity),
      duration: _getSnackBarDuration(error.severity),
      action: error.isRetryable && onRetry != null
          ? SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: onRetry,
            )
          : null,
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  static IconData _getErrorIcon(ErrorCategory category) {
    switch (category) {
      case ErrorCategory.network:
        return Icons.wifi_off;
      case ErrorCategory.mesh:
        return Icons.device_hub;
      case ErrorCategory.online:
        return Icons.cloud_off;
      case ErrorCategory.database:
        return Icons.storage;
      case ErrorCategory.message:
        return Icons.message;
      case ErrorCategory.sync:
        return Icons.sync_problem;
      case ErrorCategory.initialization:
        return Icons.error_outline;
      case ErrorCategory.unknown:
        return Icons.warning;
    }
  }

  static Color _getSnackBarColor(ErrorSeverity severity) {
    switch (severity) {
      case ErrorSeverity.low:
        return Colors.blue.shade700;
      case ErrorSeverity.medium:
        return Colors.orange.shade700;
      case ErrorSeverity.high:
        return Colors.red.shade700;
      case ErrorSeverity.critical:
        return Colors.red.shade800;
    }
  }

  static Duration _getSnackBarDuration(ErrorSeverity severity) {
    switch (severity) {
      case ErrorSeverity.low:
        return const Duration(seconds: 2);
      case ErrorSeverity.medium:
        return const Duration(seconds: 4);
      case ErrorSeverity.high:
        return const Duration(seconds: 6);
      case ErrorSeverity.critical:
        return const Duration(seconds: 8);
    }
  }
}

/// Dialog for detailed error information
class ErrorDetailsDialog extends StatelessWidget {
  final ChatError error;

  const ErrorDetailsDialog({
    super.key,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            _getErrorIcon(error.category),
            color: _getIconColor(error.severity),
          ),
          const SizedBox(width: 8),
          const Text('Error Details'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDetailRow('Code', error.code),
            _buildDetailRow('Message', error.message),
            _buildDetailRow('Category', error.category.name),
            _buildDetailRow('Severity', error.severity.name),
            _buildDetailRow('Time', error.timestamp.toString()),
            _buildDetailRow('Retryable', error.isRetryable ? 'Yes' : 'No'),
            if (error.isRetryable)
              _buildDetailRow('Max Retries', error.maxRetries.toString()),
            if (error.context != null) ...[
              const SizedBox(height: 8),
              const Text(
                'Context:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade800,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  error.context.toString(),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ),
            ],
            if (error.stackTrace != null) ...[
              const SizedBox(height: 8),
              const Text(
                'Stack Trace:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Container(
                height: 200,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade800,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    error.stackTrace!,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        if (error.isRetryable)
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Trigger retry logic here
            },
            child: const Text('Retry'),
          ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getErrorIcon(ErrorCategory category) {
    switch (category) {
      case ErrorCategory.network:
        return Icons.wifi_off;
      case ErrorCategory.mesh:
        return Icons.device_hub;
      case ErrorCategory.online:
        return Icons.cloud_off;
      case ErrorCategory.database:
        return Icons.storage;
      case ErrorCategory.message:
        return Icons.message;
      case ErrorCategory.sync:
        return Icons.sync_problem;
      case ErrorCategory.initialization:
        return Icons.error_outline;
      case ErrorCategory.unknown:
        return Icons.warning;
    }
  }

  Color _getIconColor(ErrorSeverity severity) {
    switch (severity) {
      case ErrorSeverity.low:
        return Colors.blue.shade400;
      case ErrorSeverity.medium:
        return Colors.orange.shade400;
      case ErrorSeverity.high:
        return Colors.red.shade400;
      case ErrorSeverity.critical:
        return Colors.red.shade300;
    }
  }
}