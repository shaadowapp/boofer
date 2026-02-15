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

    final bubbleContent = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.75,
        minWidth: 60,
      ),
      decoration: decoration,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
            _buildReactions(context, isOwnMessage, theme),
          ],
        ),
      ),
    );

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 12),
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

  void _showReactionOverlay(
    BuildContext context,
    Offset position,
    Size size,
    Widget bubbleContent,
    bool isOwnMessage,
  ) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black54,
        transitionDuration: const Duration(milliseconds: 200),
        reverseTransitionDuration: const Duration(milliseconds: 150),
        pageBuilder: (context, animation, secondaryAnimation) {
          final screenHeight = MediaQuery.of(context).size.height;
          final screenWidth = MediaQuery.of(context).size.width;

          // Determine menu position (prefer below, flip if too close to bottom)
          final showMenuBelow =
              (position.dy + size.height + 250) < screenHeight;
          final menuTop = showMenuBelow
              ? position.dy + size.height + 8
              : position.dy - 120; // Adjusted offset for horizontal menu

          // Determine emoji bar position
          final emojiBarTop = showMenuBelow
              ? position.dy - 60
              : position.dy + size.height + 8;

          return Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  behavior: HitTestBehavior.translucent,
                  child: const SizedBox.expand(),
                ),
              ),
              // The Message Bubble (Static at position, no Hero for smoothness)
              Positioned(
                top: position.dy,
                left: position.dx,
                width: size.width,
                height: size.height,
                child: Material(
                  color: Colors.transparent,
                  // Use IgnorePointer to prevent interaction with the clone
                  child: IgnorePointer(child: bubbleContent),
                ),
              ),
              // Emoji Reaction Bar
              Positioned(
                top: emojiBarTop,
                left: isOwnMessage ? null : position.dx,
                right: isOwnMessage
                    ? (screenWidth - position.dx - size.width)
                    : null,
                child: Material(
                  color: Colors.transparent,
                  child: ScaleTransition(
                    scale: CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutBack,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: _buildEmojiPickerRow(context),
                    ),
                  ),
                ),
              ),
              // Action Bar (Horizontal)
              Positioned(
                top: menuTop,
                left: isOwnMessage ? null : position.dx,
                right: isOwnMessage
                    ? (screenWidth - position.dx - size.width)
                    : null,
                child: ScaleTransition(
                  scale: CurvedAnimation(
                    parent: animation,
                    curve: const Interval(0.1, 1.0, curve: Curves.easeOut),
                  ),
                  child: Material(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(30),
                    elevation: 8,
                    shadowColor: Colors.black.withOpacity(0.3),
                    clipBehavior: Clip.antiAlias,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: _buildActionBar(context, isOwnMessage),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          );
        },
      ),
    );
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
    Navigator.pop(context);
    // Removed toast message as requested
  }

  void _shareMessage(BuildContext context) {
    Navigator.pop(context);
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
    Navigator.pop(context);
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

    final reactionWidgets = <Widget>[];

    reactions.forEach((emoji, userIds) {
      final ids = List<String>.from(userIds as List);
      if (ids.isEmpty) return;

      final isMe = ids.contains(currentUserId);

      reactionWidgets.add(
        GestureDetector(
          onTap: () => _showReactionDetails(context, emoji, ids),
          child: Container(
            margin: const EdgeInsets.only(right: 4, top: 4),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isMe
                  ? theme.colorScheme.primaryContainer
                  : theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isMe
                    ? theme.colorScheme.primary.withOpacity(0.3)
                    : Colors.transparent,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 12)),
                if (ids.length > 1) ...[
                  const SizedBox(width: 4),
                  Text(
                    ids.length.toString(),
                    style: TextStyle(
                      fontSize: 10,
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    });

    return Wrap(
      alignment: isOwnMessage ? WrapAlignment.end : WrapAlignment.start,
      children: reactionWidgets,
    );
  }

  Widget _buildEmojiPicker(BuildContext context) {
    final emojis = ['❤️', '😂', '😮', '😢', '👍'];

    return SizedBox(
      height: 60,
      child: Center(
        child: ListView.separated(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal,
          itemCount: emojis.length,
          separatorBuilder: (context, index) => const SizedBox(width: 16),
          itemBuilder: (context, index) {
            final emoji = emojis[index];
            return GestureDetector(
              onTap: () {
                Navigator.pop(context);
                _handleReaction(emoji);
              },
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(emoji, style: const TextStyle(fontSize: 28)),
              ),
            );
          },
        ),
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
