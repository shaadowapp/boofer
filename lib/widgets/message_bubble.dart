import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/message_model.dart';
import '../providers/appearance_provider.dart';

/// Widget for displaying individual message bubbles
class MessageBubble extends StatelessWidget {
  final Message message;
  final String currentUserId;
  final String? senderName;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const MessageBubble({
    super.key,
    required this.message,
    required this.currentUserId,
    this.senderName,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final isOwnMessage = message.senderId.trim() == currentUserId.trim();
    final theme = Theme.of(context);
    final appearance = Provider.of<AppearanceProvider>(context);
    final hasWallpaper = appearance.selectedWallpaper != 'none';

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
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
                  decoration: BoxDecoration(
                    gradient: isOwnMessage
                        ? appearance.getAccentGradient()
                        : null,
                    color: isOwnMessage
                        ? (appearance.getAccentGradient() == null
                              ? appearance.accentColor
                              : null)
                        : (hasWallpaper
                              ? theme.colorScheme.surface.withOpacity(0.8)
                              : theme.colorScheme.surfaceVariant),
                    borderRadius: _getBorderRadius(
                      isOwnMessage,
                      appearance.chatBubbleShape,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: _getBorderRadius(
                      isOwnMessage,
                      appearance.chatBubbleShape,
                    ),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: hasWallpaper ? 10 : 0,
                        sigmaY: hasWallpaper ? 10 : 0,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!isOwnMessage && senderName != null) ...[
                              Text(
                                senderName!,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 2),
                            ],
                            Text(
                              message.text,
                              style: TextStyle(
                                color: isOwnMessage
                                    ? Colors.white
                                    : theme.colorScheme.onSurface,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  _formatTimestamp(message.timestamp),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isOwnMessage
                                        ? Colors.white.withOpacity(0.7)
                                        : theme.colorScheme.onSurface
                                              .withOpacity(0.5),
                                  ),
                                ),
                                if (isOwnMessage)
                                  _buildStatusIcon(
                                    message.status,
                                    appearance.accentColor,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build avatar widget
  Widget _buildAvatar(BuildContext context) {
    return CircleAvatar(
      radius: 16,
      backgroundColor: Theme.of(context).colorScheme.primary,
      child: Text(
        message.senderId.isNotEmpty ? message.senderId[0].toUpperCase() : '?',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// Build status icon for messages
  Widget _buildStatusIcon(MessageStatus status, Color accentColor) {
    IconData icon;
    Color color;
    double size = 16;

    switch (status) {
      case MessageStatus.pending:
        icon = Icons.access_time;
        color = Colors.white70;
        size = 12;
        break;
      case MessageStatus.sent: // This is user's "pending"
        icon = Icons.check;
        color = Colors.white70;
        size = 16;
        break;
      case MessageStatus.delivered: // This is user's "sent"
        icon = Icons.done_all;
        color = Colors.white70;
        size = 16;
        break;
      case MessageStatus.read: // This is user's "seen"
        icon = Icons.done_all;
        // Check if accent color is light or dark to decide tick color
        // But since text is white, background is likely dark/colored.
        // Using a light cyan or bright white makes it stand out as "active/read"
        // compared to white70 for delivered.
        color = const Color(0xFF64FFDA); // CyanAccent-like color
        size = 16;
        break;
      case MessageStatus.failed:
        icon = Icons.error_outline;
        color = Colors.redAccent.shade100;
        size = 16;
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Icon(icon, size: size, color: color),
    );
  }

  /// Get border radius for bubble
  BorderRadius _getBorderRadius(bool isOwnMessage, ChatBubbleShape shape) {
    var radius = const Radius.circular(18);
    var smallRadius = const Radius.circular(4);

    switch (shape) {
      case ChatBubbleShape.rounded:
        radius = const Radius.circular(24);
        smallRadius = const Radius.circular(24);
        break;
      case ChatBubbleShape.square:
        radius = const Radius.circular(4);
        smallRadius = const Radius.circular(4);
        break;
      case ChatBubbleShape.standard:
        radius = const Radius.circular(18);
        smallRadius = const Radius.circular(4);
        break;
    }

    if (isOwnMessage) {
      return BorderRadius.only(
        topLeft: radius,
        topRight: radius,
        bottomLeft: radius,
        bottomRight: smallRadius,
      );
    } else {
      return BorderRadius.only(
        topLeft: radius,
        topRight: radius,
        bottomLeft: smallRadius,
        bottomRight: radius,
      );
    }
  }

  /// Format timestamp for display (h:mm a)
  String _formatTimestamp(DateTime timestamp) {
    // Convert to local time if not already
    final localTime = timestamp.toLocal();
    final hour = localTime.hour > 12
        ? localTime.hour - 12
        : (localTime.hour == 0 ? 12 : localTime.hour);
    final minute = localTime.minute.toString().padLeft(2, '0');
    final period = localTime.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}
