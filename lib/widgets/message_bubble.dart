import 'package:flutter/material.dart';
import '../models/message_model.dart';

/// Widget for displaying individual message bubbles
class MessageBubble extends StatelessWidget {
  final Message message;
  final String currentUserId;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const MessageBubble({
    super.key,
    required this.message,
    required this.currentUserId,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final isOwnMessage = message.senderId == currentUserId;
    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: Row(
        mainAxisAlignment: isOwnMessage 
            ? MainAxisAlignment.end 
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isOwnMessage) ...[
            _buildAvatar(context),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: GestureDetector(
              onTap: onTap,
              onLongPress: onLongPress,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _getBubbleColor(context, isOwnMessage),
                  borderRadius: _getBorderRadius(isOwnMessage),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isOwnMessage) _buildSenderName(context),
                    _buildMessageText(context, isOwnMessage),
                    const SizedBox(height: 4),
                    _buildMessageInfo(context, isOwnMessage),
                  ],
                ),
              ),
            ),
          ),
          if (isOwnMessage) ...[
            const SizedBox(width: 8),
            _buildAvatar(context),
          ],
        ],
      ),
    );
  }

  /// Build avatar widget
  Widget _buildAvatar(BuildContext context) {
    return CircleAvatar(
      radius: 16,
      backgroundColor: Theme.of(context).colorScheme.primary,
      child: Text(
        message.senderId.isNotEmpty 
            ? message.senderId[0].toUpperCase()
            : '?',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// Build sender name for received messages
  Widget _buildSenderName(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        message.senderId,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  /// Build message text
  Widget _buildMessageText(BuildContext context, bool isOwnMessage) {
    return Text(
      message.text,
      style: TextStyle(
        fontSize: 16,
        color: isOwnMessage 
            ? Colors.white
            : Theme.of(context).colorScheme.onSurface,
      ),
    );
  }

  /// Build message info (timestamp, status, mode indicator)
  Widget _buildMessageInfo(BuildContext context, bool isOwnMessage) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildModeIndicator(context, isOwnMessage),
        const SizedBox(width: 4),
        Text(
          _formatTimestamp(message.timestamp),
          style: TextStyle(
            fontSize: 11,
            color: isOwnMessage 
                ? Colors.white.withOpacity(0.8)
                : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        if (isOwnMessage) ...[
          const SizedBox(width: 4),
          _buildStatusIndicator(context),
        ],
      ],
    );
  }

  /// Build mode indicator (online/offline)
  Widget _buildModeIndicator(BuildContext context, bool isOwnMessage) {
    final color = isOwnMessage 
        ? Colors.white.withOpacity(0.8)
        : Theme.of(context).colorScheme.onSurface.withOpacity(0.6);
    
    return Icon(
      message.isOffline ? Icons.wifi_off : Icons.wifi,
      size: 12,
      color: color,
    );
  }

  /// Build status indicator for sent messages
  Widget _buildStatusIndicator(BuildContext context) {
    IconData icon;
    Color color;
    
    switch (message.status) {
      case MessageStatus.pending:
        icon = Icons.access_time;
        color = Colors.orange;
        break;
      case MessageStatus.sent:
        icon = Icons.check;
        color = Colors.white.withOpacity(0.8);
        break;
      case MessageStatus.delivered:
        icon = Icons.done_all;
        color = Colors.blue;
        break;
      case MessageStatus.read:
        icon = Icons.done_all;
        color = Colors.green;
        break;
      case MessageStatus.failed:
        icon = Icons.error_outline;
        color = Colors.red;
        break;
    }
    
    return Icon(
      icon,
      size: 12,
      color: color,
    );
  }

  /// Get bubble background color
  Color _getBubbleColor(BuildContext context, bool isOwnMessage) {
    if (isOwnMessage) {
      return Theme.of(context).colorScheme.primary;
    } else {
      return Theme.of(context).colorScheme.surfaceVariant;
    }
  }

  /// Get border radius for bubble
  BorderRadius _getBorderRadius(bool isOwnMessage) {
    const radius = Radius.circular(18);
    const smallRadius = Radius.circular(4);
    
    if (isOwnMessage) {
      return const BorderRadius.only(
        topLeft: radius,
        topRight: radius,
        bottomLeft: radius,
        bottomRight: smallRadius,
      );
    } else {
      return const BorderRadius.only(
        topLeft: radius,
        topRight: radius,
        bottomLeft: smallRadius,
        bottomRight: radius,
      );
    }
  }

  /// Format timestamp for display
  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 1) {
      return 'now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else {
      return '${timestamp.day}/${timestamp.month}';
    }
  }
}

/// Widget for displaying message status with tooltip
class MessageStatusWidget extends StatelessWidget {
  final MessageStatus status;
  final bool isOffline;

  const MessageStatusWidget({
    super.key,
    required this.status,
    required this.isOffline,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: _getStatusTooltip(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isOffline ? Icons.wifi_off : Icons.wifi,
            size: 12,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
          const SizedBox(width: 2),
          Icon(
            _getStatusIcon(),
            size: 12,
            color: _getStatusColor(context),
          ),
        ],
      ),
    );
  }

  IconData _getStatusIcon() {
    switch (status) {
      case MessageStatus.pending:
        return Icons.access_time;
      case MessageStatus.sent:
        return Icons.check;
      case MessageStatus.delivered:
        return Icons.done_all;
      case MessageStatus.read:
        return Icons.done_all;
      case MessageStatus.failed:
        return Icons.error_outline;
    }
  }

  Color _getStatusColor(BuildContext context) {
    switch (status) {
      case MessageStatus.pending:
        return Colors.orange;
      case MessageStatus.sent:
        return Theme.of(context).colorScheme.onSurface.withOpacity(0.6);
      case MessageStatus.delivered:
        return Colors.blue;
      case MessageStatus.read:
        return Colors.green;
      case MessageStatus.failed:
        return Colors.red;
    }
  }

  String _getStatusTooltip() {
    final modeText = isOffline ? 'Offline' : 'Online';
    final statusText = status.name.toUpperCase();
    return '$modeText - $statusText';
  }
}