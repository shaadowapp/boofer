import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../models/message_model.dart';
import '../providers/appearance_provider.dart';
import 'link_warning_bottom_sheet.dart';
import '../services/supabase_service.dart';
import '../models/user_model.dart' as app_user;

class MessageBubble extends StatelessWidget {
  final Message message;
  final String currentUserId;
  final String? senderName;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Function(Message)? onReply;

  const MessageBubble({
    super.key,
    required this.message,
    required this.currentUserId,
    this.senderName,
    this.onTap,
    this.onLongPress,
    this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    final isOwnMessage = message.senderId.trim() == currentUserId.trim();
    final theme = Theme.of(context);
    final appearance = Provider.of<AppearanceProvider>(context);
    final hasWallpaper = appearance.selectedWallpaper != 'none';

    final reactionsData = message.metadata?['reactions'];
    final hasReactions =
        reactionsData != null &&
        (reactionsData as Map).values.any((v) => (v as List).isNotEmpty);

    BoxDecoration decoration = BoxDecoration(
      color: isOwnMessage
          ? appearance.accentColor
          : (hasWallpaper
                ? theme.colorScheme.surface.withAlpha(204)
                : theme.colorScheme.surfaceContainerHighest),
      borderRadius: _getBorderRadius(isOwnMessage, appearance.chatBubbleShape),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withAlpha(20),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ],
    );

    final bubbleInternal = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.75,
        minWidth: 60,
      ),
      decoration: decoration,
      child: Padding(
        // Add extra bottom padding if there are reactions to avoid overlap with text
        padding: EdgeInsets.fromLTRB(14, 10, 14, hasReactions ? 18 : 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.metadata != null &&
                message.metadata!['reply_to'] != null)
              _buildReplyBubble(
                context,
                isOwnMessage,
                theme,
                (message.metadata!['reply_to'] as Map).cast<String, dynamic>(),
                appearance,
              ),
            _buildMessageText(
              context,
              isOwnMessage,
              theme,
              appearance.bubbleFontSize,
            ),
          ],
        ),
      ),
    );

    final bubbleContent = Stack(
      clipBehavior: Clip.none,
      children: [
        bubbleInternal,
        if (hasReactions)
          Positioned(
            bottom: -10,
            left: isOwnMessage ? null : 12,
            right: isOwnMessage ? 12 : null,
            child: _buildReactions(context, isOwnMessage, theme),
          ),
      ],
    );

    return RepaintBoundary(
      child: Padding(
        // Extra padding at bottom for the overflowing reactions
        padding: const EdgeInsets.fromLTRB(12, 2, 12, 12),
        child: _SwipeReplyWrapper(
          isOwnMessage: isOwnMessage,
          onReply: () {
            HapticFeedback.lightImpact();
            onReply?.call(message);
          },
          child: Row(
            mainAxisAlignment: isOwnMessage
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Builder(
                  builder: (context) => GestureDetector(
                    onTap: onTap,
                    onLongPressStart: (details) {
                      if (onLongPress != null) {
                        onLongPress!();
                        return;
                      }
                      HapticFeedback.mediumImpact();
                      final RenderBox box =
                          context.findRenderObject() as RenderBox;
                      final position = box.localToGlobal(Offset.zero);
                      final size = box.size;

                      _showReactionOverlay(
                        context,
                        position,
                        size,
                        bubbleContent,
                        isOwnMessage,
                      );
                    },
                    child: Hero(tag: message.id, child: bubbleContent),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ... (lines 136-770 omitted or unchanged)

  Widget _buildReactions(
    BuildContext context,
    bool isOwnMessage,
    ThemeData theme,
  ) {
    if (message.metadata == null || message.metadata!['reactions'] == null) {
      return const SizedBox.shrink();
    }

    final reactions = Map<String, dynamic>.from(
      message.metadata!['reactions'] as Map,
    );
    if (reactions.isEmpty) return const SizedBox.shrink();

    // Flatten reactions to show first 3
    final reactionItems = <Widget>[];
    int totalCount = 0;

    reactions.forEach((emoji, userIds) {
      final ids = List<String>.from(userIds as List);
      if (ids.isNotEmpty) {
        if (reactionItems.length < 3) {
          reactionItems.add(
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(emoji, style: const TextStyle(fontSize: 18)),
            ),
          );
        }
        totalCount++;
      }
    });

    if (reactionItems.isEmpty) return const SizedBox.shrink();

    // Add count if more than 1
    if (totalCount > 1) {
      // Optional: Add logic to show +N count
    }

    return GestureDetector(
      onTap: () {
        // Find first populated reaction to show details, or show summary
        final firstEmoji = reactions.keys.firstWhere(
          (k) => (reactions[k] as List).isNotEmpty,
        );
        final ids = List<String>.from(reactions[firstEmoji] as List);
        _showReactionDetailsOverlay(context, firstEmoji, ids, currentUserId);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withOpacity(0.5),
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...reactionItems,
            if (totalCount > 3) ...[
              const SizedBox(width: 4),
              Text(
                '+$totalCount',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showReactionOverlay(
    BuildContext context,
    Offset position,
    Size size,
    Widget bubbleContent,
    bool isOwnMessage,
  ) {
    final overlayState = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (ctx) => _ReactionOverlayContent(
        parentContext: context, // Pass original context
        message: message,
        currentUserId: currentUserId,
        senderName: senderName,
        position: position,
        size: size,
        bubbleContent: bubbleContent,
        isOwnMessage: isOwnMessage,
        onReply: onReply,
        onDismiss: () => overlayEntry.remove(),
      ),
    );

    overlayState.insert(overlayEntry);
  }

  Widget _buildEmojiPickerRow(BuildContext context) {
    // Top 5 emojis + Custom (+)
    final emojis = ['❤️', '😂', '😮', '😢', '👍'];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...emojis.map((emoji) {
          final isReacted =
              message.metadata?['reactions']?[emoji]?.contains(currentUserId) ??
              false;
          return GestureDetector(
            onTap: () {
              Navigator.pop(context);
              _handleReaction(emoji);
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isReacted
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(emoji, style: const TextStyle(fontSize: 26)),
            ),
          );
        }),
        // Plus button for custom reaction
        GestureDetector(
          onTap: () {
            // Placeholder for full emoji picker
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Custom reactions coming soon!'),
                duration: Duration(seconds: 1),
                behavior: SnackBarBehavior.floating,
              ),
            );
            Navigator.pop(context);
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.add,
              size: 24,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionBar(BuildContext context, bool isOwnMessage) {
    final theme = Theme.of(context);
    final iconColor = theme.iconTheme.color;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: () {
            Navigator.pop(context);
            onReply?.call(message);
          },
          icon: Icon(Icons.reply_rounded, color: iconColor),
          tooltip: 'Reply',
        ),
        IconButton(
          onPressed: () => _copyMessage(context),
          icon: Icon(Icons.copy_rounded, color: iconColor),
          tooltip: 'Copy',
        ),
        IconButton(
          onPressed: () {
            Navigator.pop(context);
            _showMessageInfo(context);
          },
          icon: Icon(Icons.info_outline_rounded, color: iconColor),
          tooltip: 'Info',
        ),
        IconButton(
          onPressed: () => _shareMessage(context),
          icon: Icon(Icons.share_rounded, color: iconColor),
          tooltip: 'Share',
        ),
        if (isOwnMessage)
          IconButton(
            onPressed: () => _showDeleteDialog(context, isOwnMessage),
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
            tooltip: 'Delete',
          ),
      ],
    );
  }

  void _copyMessage(BuildContext context) {
    Clipboard.setData(ClipboardData(text: message.text));
    // Removed toast message as requested
  }

  void _shareMessage(BuildContext context) {
    Share.share(message.text);
  }

  void _showMessageInfo(BuildContext context) async {
    final theme = Theme.of(context);

    app_user.User? profile;
    try {
      profile = await SupabaseService.instance.getUserProfile(message.senderId);
    } catch (_) {}

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Message Info'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoField(
              'Sender',
              profile?.fullName ?? senderName ?? 'Unknown',
              theme,
            ),
            _buildInfoField(
              'Handle',
              profile?.handle != null ? '@${profile!.handle}' : 'N/A',
              theme,
            ),
            _buildInfoField(
              'Time',
              DateFormat('MMM d, yyyy • hh:mm a').format(message.timestamp),
              theme,
            ),
            _buildInfoField(
              'Status',
              message.status.name.toUpperCase(),
              theme,
              isStatus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoField(
    String label,
    String value,
    ThemeData theme, {
    bool isStatus = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: theme.textTheme.bodySmall?.color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              color: isStatus ? _getStatusColor(message.status) : null,
              fontWeight: isStatus ? FontWeight.bold : null,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(MessageStatus status) {
    switch (status) {
      case MessageStatus.read:
        return Colors.blue;
      case MessageStatus.delivered:
        return Colors.green;
      case MessageStatus.sent:
        return Colors.grey;
      case MessageStatus.failed:
        return Colors.red;
      case MessageStatus.pending:
        return Colors.orange;
    }
  }

  void _showDeleteDialog(BuildContext context, bool isOwnMessage) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete message?'),
        content: const Text('Would you like to delete this message?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _executeDelete(context, forEveryone: false);
            },
            child: const Text('Delete for me'),
          ),
          if (isOwnMessage)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _executeDelete(context, forEveryone: true);
              },
              child: const Text(
                'Delete for everyone',
                style: TextStyle(color: Colors.red),
              ),
            ),
        ],
      ),
    );
  }

  void _executeDelete(BuildContext context, {required bool forEveryone}) async {
    try {
      if (forEveryone) {
        await SupabaseService.instance.deleteMessageForEveryone(message.id);
      } else {
        await SupabaseService.instance.deleteMsgForMe(
          message.id,
          currentUserId,
        );
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              forEveryone ? 'Deleted for everyone' : 'Deleted for you',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  BorderRadius _getBorderRadius(bool isOwnMessage, ChatBubbleShape shape) {
    switch (shape) {
      case ChatBubbleShape.round:
        return BorderRadius.circular(32);
      case ChatBubbleShape.curve:
        return BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: isOwnMessage
              ? const Radius.circular(20)
              : const Radius.circular(6),
          bottomRight: isOwnMessage
              ? const Radius.circular(6)
              : const Radius.circular(20),
        );
      case ChatBubbleShape.square:
        return BorderRadius.only(
          topLeft: const Radius.circular(8),
          topRight: const Radius.circular(8),
          bottomLeft: isOwnMessage
              ? const Radius.circular(8)
              : const Radius.circular(2),
          bottomRight: isOwnMessage
              ? const Radius.circular(2)
              : const Radius.circular(8),
        );
      case ChatBubbleShape.capsule:
        return BorderRadius.only(
          topLeft: const Radius.circular(28),
          topRight: const Radius.circular(28),
          bottomLeft: isOwnMessage
              ? const Radius.circular(28)
              : const Radius.circular(12),
          bottomRight: isOwnMessage
              ? const Radius.circular(12)
              : const Radius.circular(28),
        );
      case ChatBubbleShape.leaf:
        return BorderRadius.only(
          topLeft: const Radius.circular(24),
          topRight: isOwnMessage
              ? const Radius.circular(4)
              : const Radius.circular(24),
          bottomLeft: isOwnMessage
              ? const Radius.circular(24)
              : const Radius.circular(4),
          bottomRight: const Radius.circular(24),
        );
    }
  }

  Widget _buildReplyBubble(
    BuildContext context,
    bool isOwnMessage,
    ThemeData theme,
    Map<String, dynamic> replyData,
    AppearanceProvider appearance,
  ) {
    // Calculate a complementary radius for the inner bubble
    // Usually slightly less than the outer bubble radius for a nested look
    double radius = 8;
    switch (appearance.chatBubbleShape) {
      case ChatBubbleShape.round: // radius 32
      case ChatBubbleShape.capsule: // radius 28
      case ChatBubbleShape.leaf: // radius 24
        radius = 16;
        break;
      case ChatBubbleShape.curve: // radius 20
        radius = 12;
        break;
      case ChatBubbleShape.square: // radius 8
        radius = 4;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      constraints: const BoxConstraints(minWidth: 120),
      decoration: BoxDecoration(
        color: isOwnMessage
            ? Colors.black.withOpacity(0.1)
            : theme.colorScheme.surface.withOpacity(0.4),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: IntrinsicHeight(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 4,
                color: isOwnMessage
                    ? Colors.white70
                    : theme.colorScheme.primary,
              ),
              Flexible(
                fit: FlexFit.loose,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        replyData['sender_name'] ?? 'Unknown',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isOwnMessage
                              ? Colors.white
                              : theme.colorScheme.primary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        replyData['text'] ?? '',
                        style: TextStyle(
                          fontSize: 12,
                          color: isOwnMessage
                              ? Colors.white.withOpacity(0.8)
                              : theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageText(
    BuildContext context,
    bool isOwnMessage,
    ThemeData theme,
    double fontSize,
  ) {
    final text = message.text;
    final urlRegExp = RegExp(
      r'((https?:\/\/|www\.)[a-zA-Z0-9\-\.]+\.[a-zA-Z]{2,}(?:/[^\s\)\],\.?!]*)?|(?<![a-zA-Z0-9\-\.])(?:[a-zA-Z0-9\-]+\.)+(?:com|org|net|dev|io|app|gov|edu|me|info|biz|co|us|uk|in|tv|xyz)(?![a-zA-Z0-9\-\.]))',
      caseSensitive: false,
    );

    if (!text.contains(urlRegExp)) {
      return Text(
        text,
        style: TextStyle(
          color: isOwnMessage ? Colors.white : theme.colorScheme.onSurface,
          fontSize: fontSize,
          fontFamily: theme.textTheme.bodyMedium?.fontFamily,
        ),
      );
    }

    final List<TextSpan> spans = [];
    int start = 0;
    for (final match in urlRegExp.allMatches(text)) {
      if (match.start > start) {
        spans.add(
          TextSpan(
            text: text.substring(start, match.start),
            style: TextStyle(
              color: isOwnMessage ? Colors.white : theme.colorScheme.onSurface,
              fontSize: fontSize,
            ),
          ),
        );
      }
      final url = match.group(0)!;
      final fullUrl = url.startsWith('http') ? url : 'https://$url';
      spans.add(
        TextSpan(
          text: url,
          style: TextStyle(
            color: isOwnMessage ? Colors.white : theme.colorScheme.primary,
            fontSize: fontSize,
            decoration: TextDecoration.underline,
            fontWeight: FontWeight.w500,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              LinkWarningBottomSheet.show(context, fullUrl);
            },
        ),
      );
      start = match.end;
    }
    if (start < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(start),
          style: TextStyle(
            color: isOwnMessage ? Colors.white : theme.colorScheme.onSurface,
            fontSize: fontSize,
          ),
        ),
      );
    }

    return RichText(
      text: TextSpan(
        style: TextStyle(
          color: isOwnMessage ? Colors.white : theme.colorScheme.onSurface,
          fontSize: fontSize,
          fontFamily: theme.textTheme.bodyMedium?.fontFamily,
        ),
        children: spans,
      ),
    );
  }

  Future<void> _handleReaction(String emoji) async {
    HapticFeedback.lightImpact();

    // Check if I already reacted
    if (message.metadata != null && message.metadata!['reactions'] != null) {
      final reactions = message.metadata!['reactions'];
      if (reactions[emoji] != null) {
        final ids = List<String>.from(reactions[emoji]);
        if (ids.contains(currentUserId)) {
          await SupabaseService.instance.removeMessageReaction(
            message.id,
            emoji,
          );
          return;
        }
      }
    }
    await SupabaseService.instance.addMessageReaction(message.id, emoji);
  }

  void _showReactionDetails(
    BuildContext context,
    String emoji,
    List<String> userIds,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Reactions $emoji',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: userIds.length,
                itemBuilder: (context, index) {
                  final id = userIds[index];
                  // If it's me, show "You"
                  if (id == currentUserId) {
                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: const Text('You'),
                      trailing: TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _handleReaction(
                            emoji,
                          ); // This will remove it since we checked logic above
                        },
                        child: const Text('Remove'),
                      ),
                    );
                  }

                  return FutureBuilder<app_user.User?>(
                    future: SupabaseService.instance.getUserProfile(id),
                    builder: (context, snapshot) {
                      final user = snapshot.data;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: user?.profilePicture != null
                              ? NetworkImage(user!.profilePicture!)
                              : null,
                          child: user?.profilePicture == null
                              ? const Icon(Icons.person)
                              : null,
                        ),
                        title: Text(user?.fullName ?? 'User'),
                        subtitle: Text(
                          user?.handle != null ? '@${user!.handle}' : '',
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SwipeReplyWrapper extends StatefulWidget {
  final Widget child;
  final bool isOwnMessage;
  final VoidCallback onReply;

  const _SwipeReplyWrapper({
    required this.child,
    required this.isOwnMessage,
    required this.onReply,
  });

  @override
  State<_SwipeReplyWrapper> createState() => _SwipeReplyWrapperState();
}

class _SwipeReplyWrapperState extends State<_SwipeReplyWrapper>
    with SingleTickerProviderStateMixin {
  double _dragOffset = 0.0;
  late AnimationController _controller;
  late Animation<double> _animation;
  final double _triggerThreshold = 40.0;
  final double _maxDragDistance = 80.0;
  bool _triggered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _animation = Tween<double>(begin: 0, end: 0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (_controller.isAnimating) return;

    double delta = details.primaryDelta!;

    // Only allow swipe inwards
    // Own message (Right side) -> Swipe Left (negative delta)
    // Other message (Left side) -> Swipe Right (positive delta)
    if (widget.isOwnMessage && delta > 0 && _dragOffset == 0) return;
    if (!widget.isOwnMessage && delta < 0 && _dragOffset == 0) return;

    setState(() {
      _dragOffset += delta;

      // Apply friction/limit
      if (widget.isOwnMessage) {
        // Swipe left, offset should be negative
        if (_dragOffset > 0) _dragOffset = 0;
        if (_dragOffset < -_maxDragDistance) {
          // Resistance effect
          double over = -_dragOffset - _maxDragDistance;
          _dragOffset = -_maxDragDistance - (over * 0.1);
        }
      } else {
        // Swipe right, offset should be positive
        if (_dragOffset < 0) _dragOffset = 0;
        if (_dragOffset > _maxDragDistance) {
          // Resistance effect
          double over = _dragOffset - _maxDragDistance;
          _dragOffset = _maxDragDistance + (over * 0.1);
        }
      }

      // Haptic feedback trigger
      if (!_triggered && _dragOffset.abs() > _triggerThreshold) {
        _triggered = true;
        HapticFeedback.selectionClick();
      } else if (_triggered && _dragOffset.abs() < _triggerThreshold) {
        _triggered = false;
      }
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    if (_triggered) {
      widget.onReply();
    }

    _triggered = false;

    _animation = Tween<double>(
      begin: _dragOffset,
      end: 0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.reset();
    _controller.forward();

    _controller.addListener(() {
      setState(() {
        _dragOffset = _animation.value;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: _handleDragUpdate,
      onHorizontalDragEnd: _handleDragEnd,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Reply Icon Background
          if (_dragOffset.abs() > 10)
            Positioned(
              right: widget.isOwnMessage ? 10 : null,
              left: widget.isOwnMessage ? null : 10,
              child: Opacity(
                opacity: (_dragOffset.abs() / _triggerThreshold).clamp(
                  0.0,
                  1.0,
                ),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.reply_rounded,
                    size: 20,
                    color: _triggered
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          Transform.translate(
            offset: Offset(_dragOffset, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}

class _ReactionOverlayContent extends StatefulWidget {
  final BuildContext parentContext;
  final Message message;
  final String currentUserId;
  final String? senderName;
  final Offset position;
  final Size size;
  final Widget bubbleContent;
  final bool isOwnMessage;
  final VoidCallback onDismiss;
  final Function(Message)? onReply;

  const _ReactionOverlayContent({
    super.key,
    required this.parentContext,
    required this.message,
    required this.currentUserId,
    this.senderName,
    required this.position,
    required this.size,
    required this.bubbleContent,
    required this.isOwnMessage,
    required this.onDismiss,
    this.onReply,
  });

  @override
  State<_ReactionOverlayContent> createState() =>
      _ReactionOverlayContentState();
}

class _ReactionOverlayContentState extends State<_ReactionOverlayContent>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    await _controller.reverse();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    // Position logic
    final showMenuBelow =
        (widget.position.dy + widget.size.height + 250) < screenHeight;

    double? emojiTop = widget.position.dy - 60;
    double? actionTop = widget.position.dy + widget.size.height + 8;

    // Adjust if too close to top
    if (widget.position.dy < 70) {
      emojiTop = widget.position.dy + widget.size.height + 8;
      actionTop = emojiTop + 60;
    }

    // Adjust if too close to bottom
    if (screenHeight - widget.position.dy - widget.size.height < 150) {
      actionTop = widget.position.dy - 60;
      emojiTop = actionTop - 60;
    }

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // Background dismiss detector
          Positioned.fill(
            child: GestureDetector(
              onTap: _close,
              behavior: HitTestBehavior.translucent,
              child: Container(color: Colors.black12),
            ),
          ),

          // The Clone Message Bubble (Static)
          Positioned(
            top: widget.position.dy,
            left: widget.position.dx,
            width: widget.size.width,
            height: widget.size.height,
            child: IgnorePointer(child: widget.bubbleContent),
          ),

          // Emoji Reaction Bar
          Positioned(
            top: emojiTop,
            left: widget.isOwnMessage ? null : widget.position.dx,
            right: widget.isOwnMessage
                ? (screenWidth - widget.position.dx - widget.size.width)
                : null,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: _buildEmojiBar(context),
            ),
          ),

          // Action Bar
          Positioned(
            top: actionTop,
            left: widget.isOwnMessage ? null : widget.position.dx,
            right: widget.isOwnMessage
                ? (screenWidth - widget.position.dx - widget.size.width)
                : null,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: _buildActionBar(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmojiBar(BuildContext context) {
    final emojis = ['❤️', '😂', '😮', '😢', '👍'];
    final reactions = widget.message.metadata?['reactions'] != null
        ? Map<String, dynamic>.from(
            widget.message.metadata!['reactions'] as Map,
          )
        : <String, dynamic>{};

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ), // Reduced padding
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...emojis.map((emoji) {
            final isReacted =
                reactions[emoji]?.contains(widget.currentUserId) ?? false;
            return GestureDetector(
              onTap: () async {
                await _close();
                _handleReaction(emoji);
              },
              child: Container(
                margin: const EdgeInsets.symmetric(
                  horizontal: 2,
                ), // Reduced margin
                padding: const EdgeInsets.all(4), // Reduced padding
                decoration: BoxDecoration(
                  color: isReacted
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  emoji,
                  style: const TextStyle(fontSize: 22),
                ), // Reduced font size slightly
              ),
            );
          }),
          GestureDetector(
            onTap: () {
              _close(); // Close the menu overlay
              _showCustomReactionPicker(
                widget.parentContext,
                (emoji) {
                   Navigator.of(widget.parentContext).pop(); // Close picker dialog
                   _handleReaction(emoji);
                },
              );
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.add,
                size: 20, // Reduced size
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = theme.iconTheme.color;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 4,
        vertical: 2,
      ), // Reduced padding
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            padding: EdgeInsets.zero, // Remove internal padding
            constraints: const BoxConstraints(
              minWidth: 36,
              minHeight: 40,
            ), // Tighter constraints
            onPressed: () {
              _close();
              if (widget.onReply != null) widget.onReply!(widget.message);
            },
            icon: Icon(
              Icons.reply_rounded,
              color: iconColor,
              size: 20,
            ), // Smaller icon
            tooltip: 'Reply',
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 40),
            onPressed: () {
              _close();
              _copyMessage(widget.parentContext); // Use parentContext
            },
            icon: Icon(Icons.copy_rounded, color: iconColor, size: 20),
            tooltip: 'Copy',
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 40),
            onPressed: () {
              _close();
              _showMessageInfo(widget.parentContext); // Use parentContext
            },
            icon: Icon(Icons.info_outline_rounded, color: iconColor, size: 20),
            tooltip: 'Info',
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 40),
            onPressed: () {
              _close();
              _shareMessage();
            },
            icon: Icon(Icons.share_rounded, color: iconColor, size: 20),
            tooltip: 'Share',
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 40),
            onPressed: () {
              _close();
              _showDeleteDialog(widget.parentContext); // Use parentContext
            },
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: Colors.red,
              size: 20,
            ),
            tooltip: 'Delete',
          ),
        ],
      ),
    );
  }

  Future<void> _handleReaction(String emoji) async {
    HapticFeedback.lightImpact();
    // Use widget.message and widget.currentUserId
    final messageId = widget.message.id;
    final userId = widget.currentUserId;

    if (widget.message.metadata?['reactions'] != null) {
      final reactions = widget.message.metadata!['reactions'];
      if (reactions[emoji] != null) {
        final ids = List<String>.from(reactions[emoji]);
        if (ids.contains(userId)) {
          await SupabaseService.instance.removeMessageReaction(
            messageId,
            emoji,
          );
          return;
        }
      }
    }
    await SupabaseService.instance.addMessageReaction(messageId, emoji);
  }

  void _copyMessage(BuildContext context) {
    Clipboard.setData(ClipboardData(text: widget.message.text));
  }

  void _shareMessage() {
    Share.share(widget.message.text);
  }

  void _showMessageInfo(BuildContext context) async {
    final theme = Theme.of(context);
    app_user.User? profile;
    try {
      profile = await SupabaseService.instance.getUserProfile(
        widget.message.senderId,
      );
    } catch (_) {}

    if (!context.mounted) return;

    _showOverlayDialog(
      context: context,
      title: 'Message Info',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow(
            'Sender',
            profile?.fullName ?? widget.senderName ?? 'Unknown',
            theme,
          ),
          _buildInfoRow(
            'Handle',
            profile?.handle != null ? '@${profile!.handle}' : 'N/A',
            theme,
          ),
          _buildInfoRow(
            'Time',
            DateFormat(
              'MMM d, yyyy • hh:mm a',
            ).format(widget.message.timestamp),
            theme,
          ),
          _buildInfoRow(
            'Status',
            widget.message.status.name.toUpperCase(),
            theme,
          ),
        ],
      ),
      actionBuilder: (close) => [
        TextButton(
          onPressed:
              close, // Handled by overlay dismissal, but we need a close button logic
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, ThemeData theme) {
    // Minimal design as requested: "Label: Value" in one or two lines but compact.
    // Actually user said: "show full name (@userhandle) and status read/seen/sent (at timestamp)"
    // So this generic row might be used differently.
    // I'll update the CALLER instead?
    // No, let's just make this row compact.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: theme.textTheme.bodySmall?.color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    // We need to construct actions that can close the overlay
    // But _showOverlayDialog injects onDismiss into the widget
    // So we can pass a builder for actions?
    // Let's allow passing a callback-aware builder for actions or just handle it in the widget

    // Simpler: The _OverlayDialog will provide 'onDismiss' to its children if we structure it right.
    // Or we just capture the overlay removal in a closure here?
    // No, we can't capture 'overlayEntry.remove' before we create it easily without a wrapper.

    // Solution: _showOverlayDialog returns a close function? No.
    // I'll make _showOverlayDialog take a builder for actions: List<Widget> Function(VoidCallback close)

    _showOverlayDialog(
      context: context,
      title: 'Delete message?',
      content: const Text('Would you like to delete this message?'),
      actionBuilder: (close) => [
        TextButton(onPressed: close, child: const Text('Cancel')),
        TextButton(
          onPressed: () {
            close();
            _executeDelete(context, forEveryone: false);
          },
          child: const Text('Delete for me'),
        ),
        if (widget.isOwnMessage)
          TextButton(
            onPressed: () {
              close();
              _executeDelete(context, forEveryone: true);
            },
            child: const Text(
              'Delete for everyone',
              style: TextStyle(color: Colors.red),
            ),
          ),
      ],
    );
  }

  // Methods moved to global helpers

  // Moved to top-level helper functions

  void _executeDelete(BuildContext context, {required bool forEveryone}) async {
    try {
      if (forEveryone) {
        await SupabaseService.instance.deleteMessageForEveryone(
          widget.message.id,
        );
      } else {
        await SupabaseService.instance.deleteMsgForMe(
          widget.message.id,
          widget.currentUserId,
        );
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              forEveryone ? 'Deleted for everyone' : 'Deleted for you',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

class _OverlayDialog extends StatefulWidget {
  final String title;
  final Widget content;
  final List<Widget> actions;
  final VoidCallback onDismiss;

  const _OverlayDialog({
    required this.title,
    required this.content,
    required this.actions,
    required this.onDismiss,
  });

  @override
  State<_OverlayDialog> createState() => _OverlayDialogState();
}

class _OverlayDialogState extends State<_OverlayDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _controller.forward();
  }

  Future<void> _close() async {
    await _controller.reverse();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _close,
              behavior: HitTestBehavior.opaque,
              child: Container(color: Colors.black54),
            ),
          ),
          Center(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.85,
                    constraints: const BoxConstraints(maxWidth: 400),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).dialogBackgroundColor,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          widget.title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        DefaultTextStyle(
                          style: Theme.of(context).textTheme.bodyMedium!,
                          child: widget.content,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: widget.actions,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void _showOverlayDialog({
  required BuildContext context,
  required String title,
  required Widget content,
  List<Widget> Function(VoidCallback close)? actionBuilder,
}) {
  final overlayState = Overlay.of(context);
  late OverlayEntry overlayEntry;

  overlayEntry = OverlayEntry(
    builder: (ctx) => _OverlayDialog(
      title: title,
      content: content,
      actions: actionBuilder != null
          ? actionBuilder(() => overlayEntry.remove())
          : [],
      onDismiss: () => overlayEntry.remove(),
    ),
  );

  overlayState.insert(overlayEntry);
}

void _showCustomReactionPicker(
  BuildContext context,
  Function(String) onEmojiSelected,
) {
  _showOverlayDialog(
    context: context,
    title: 'React with...',
    content: SizedBox(
      height: 300,
      width: double.maxFinite,
      child: EmojiPicker(
        onEmojiSelected: (category, emoji) {
          onEmojiSelected(emoji.emoji);
        },
        config: Config(
          height: 256,
          checkPlatformCompatibility: true,
          emojiViewConfig: EmojiViewConfig(
            emojiSizeMax: 28,
            columns: 7,
            verticalSpacing: 0,
            horizontalSpacing: 0,
            gridPadding: EdgeInsets.zero,
            recentsLimit: 28,
            replaceEmojiOnLimitExceed: false,
            noRecents: const Text(
              'No Recents',
              style: TextStyle(fontSize: 20, color: Colors.black26),
              textAlign: TextAlign.center,
            ),
            backgroundColor: Theme.of(context).dialogBackgroundColor,
            buttonMode: ButtonMode.MATERIAL,
          ),
          skinToneConfig: SkinToneConfig(
            dialogBackgroundColor: Theme.of(context).dialogBackgroundColor,
            indicatorColor: Theme.of(context).colorScheme.onSurface,
            enabled: true,
          ),
          categoryViewConfig: CategoryViewConfig(
            initCategory: Category.SMILEYS,
            backgroundColor: Theme.of(context).dialogBackgroundColor,
            indicatorColor: Theme.of(context).colorScheme.primary,
            iconColor: Theme.of(context).colorScheme.onSurfaceVariant,
            iconColorSelected: Theme.of(context).colorScheme.primary,
            backspaceColor: Theme.of(context).colorScheme.onSurfaceVariant,
            tabIndicatorAnimDuration: kTabScrollDuration,
            categoryIcons: const CategoryIcons(),
          ),
          bottomActionBarConfig: const BottomActionBarConfig(
            enabled: false,
          ),
          searchViewConfig: const SearchViewConfig(),
        ),
      ),
    ),
    actionBuilder: (close) => [
      TextButton(onPressed: close, child: const Text('Cancel')),
    ],
  );
}

// Top-level Helper Functions for Overlays
// Method removed - provided by global helper

void _showReactionDetailsOverlay(
  BuildContext context,
  String emoji,
  List<String> userIds,
  String? currentUserId,
) async {
  _showOverlayDialog(
    context: context,
    title: 'Reactions $emoji',
    content: SizedBox(
      width: double.maxFinite,
      height: 200,
      child: FutureBuilder<List<Map<String, String?>>>(
        future: _fetchReactors(userIds, currentUserId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No details available'));
          }
          return ListView.builder(
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final user = snapshot.data![index];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundImage: user['avatar'] != null
                      ? NetworkImage(user['avatar']!)
                      : null,
                  child: user['avatar'] == null
                      ? Text((user['name'] ?? '?')[0].toUpperCase())
                      : null,
                ),
                title: Text(user['name'] ?? 'Unknown'),
              );
            },
          );
        },
      ),
    ),
    actionBuilder: (close) => [
      TextButton(onPressed: close, child: const Text('Close')),
    ],
  );
}

Future<List<Map<String, String?>>> _fetchReactors(
  List<String> userIds,
  String? currentUserId,
) async {
  final List<Map<String, String?>> reactors = [];
  for (final id in userIds) {
    if (id == currentUserId) {
      reactors.add({'name': 'You', 'avatar': null});
      continue;
    }
    try {
      final profile = await SupabaseService.instance.getUserProfile(id);
      reactors.add({
        'name': profile?.fullName ?? 'Unknown',
        'avatar': profile?.avatar,
      });
    } catch (e) {
      reactors.add({'name': 'Unknown User', 'avatar': null});
    }
  }
  return reactors;
}
