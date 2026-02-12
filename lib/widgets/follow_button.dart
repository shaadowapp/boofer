import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/friend_request_provider.dart';
import '../providers/appearance_provider.dart';
import '../models/user_model.dart';

/// Friend request button widget (Instagram/Snapchat style)
class FriendRequestButton extends StatefulWidget {
  final User user;
  final VoidCallback? onStatusChanged;
  final ButtonStyle? style;
  final bool compact;

  const FriendRequestButton({
    super.key,
    required this.user,
    this.onStatusChanged,
    this.style,
    this.compact = false,
  });

  @override
  State<FriendRequestButton> createState() => _FriendRequestButtonState();
}

/// Alias for backward compatibility
typedef FollowButton = FriendRequestButton;

class _FriendRequestButtonState extends State<FriendRequestButton> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<FriendRequestProvider>(
      builder: (context, provider, child) {
        final relationshipStatus = provider.getRelationshipStatus(
          widget.user.id,
        );
        final isLoading = provider.isLoading || _isProcessing;

        if (relationshipStatus == 'self') {
          return const SizedBox.shrink(); // Don't show button for self
        }

        if (widget.compact) {
          return _buildCompactButton(
            context,
            relationshipStatus,
            isLoading,
            provider,
          );
        }

        return _buildFullButton(
          context,
          relationshipStatus,
          isLoading,
          provider,
        );
      },
    );
  }

  Widget _buildFullButton(
    BuildContext context,
    String relationshipStatus,
    bool isLoading,
    FriendRequestProvider provider,
  ) {
    final theme = Theme.of(context);
    final appearanceProvider = Provider.of<AppearanceProvider>(context);

    // Only apply gradient to primary actions: Follow/Accept
    final showGradient =
        appearanceProvider.useGradientAccent &&
        (relationshipStatus == 'none' ||
            relationshipStatus == 'request_received' ||
            relationshipStatus == 'request_rejected' ||
            relationshipStatus == 'request_cancelled');

    final borderRadius = BorderRadius.circular(appearanceProvider.cornerRadius);

    return Container(
      width: 120,
      height: 36,
      decoration: showGradient
          ? BoxDecoration(
              gradient: appearanceProvider.getAccentGradient(),
              borderRadius: borderRadius,
              boxShadow: [
                BoxShadow(
                  color:
                      (appearanceProvider.getAccentGradient()?.colors.first ??
                              theme.colorScheme.primary)
                          .withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            )
          : null,
      child: ElevatedButton(
        onPressed: isLoading
            ? null
            : () => _handleButtonPress(context, relationshipStatus, provider),
        style:
            widget.style ??
            (showGradient
                ? ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(borderRadius: borderRadius),
                  )
                : _getButtonStyle(theme, relationshipStatus)),
        child: isLoading
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    showGradient
                        ? Colors.white
                        : _getButtonTextColor(theme, relationshipStatus),
                  ),
                ),
              )
            : Text(
                _getButtonText(relationshipStatus),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: showGradient
                      ? Colors.white
                      : _getButtonTextColor(theme, relationshipStatus),
                ),
              ),
      ),
    );
  }

  Widget _buildCompactButton(
    BuildContext context,
    String relationshipStatus,
    bool isLoading,
    FriendRequestProvider provider,
  ) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 32,
      height: 32,
      child: IconButton(
        onPressed: isLoading
            ? null
            : () => _handleButtonPress(context, relationshipStatus, provider),
        style: IconButton.styleFrom(
          backgroundColor: _getButtonBackgroundColor(theme, relationshipStatus),
          foregroundColor: _getButtonTextColor(theme, relationshipStatus),
          padding: EdgeInsets.zero,
        ),
        icon: isLoading
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _getButtonTextColor(theme, relationshipStatus),
                  ),
                ),
              )
            : Icon(_getButtonIcon(relationshipStatus), size: 18),
      ),
    );
  }

  String _getButtonText(String relationshipStatus) {
    switch (relationshipStatus) {
      case 'friends':
        return 'Friends';
      case 'request_sent':
        return 'Pending';
      case 'request_received':
        return 'Accept';
      case 'request_rejected':
      case 'request_cancelled':
      case 'none':
      default:
        return 'Follow';
    }
  }

  IconData _getButtonIcon(String relationshipStatus) {
    switch (relationshipStatus) {
      case 'friends':
        return Icons.check;
      case 'request_sent':
        return Icons.schedule;
      case 'request_received':
        return Icons.person_add;
      case 'request_rejected':
      case 'request_cancelled':
      case 'none':
      default:
        return Icons.person_add_outlined;
    }
  }

  ButtonStyle _getButtonStyle(ThemeData theme, String relationshipStatus) {
    switch (relationshipStatus) {
      case 'friends':
        return ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.secondaryContainer,
          foregroundColor: theme.colorScheme.onSecondaryContainer,
          elevation: 0,
          side: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.3),
            width: 1,
          ),
        );
      case 'request_sent':
        return ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          foregroundColor: theme.colorScheme.onSurfaceVariant,
          elevation: 0,
        );
      case 'request_received':
        return ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          elevation: 2,
        );
      case 'request_rejected':
      case 'request_cancelled':
      case 'none':
      default:
        return ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
          elevation: 2,
        );
    }
  }

  Color _getButtonBackgroundColor(ThemeData theme, String relationshipStatus) {
    switch (relationshipStatus) {
      case 'friends':
        return theme.colorScheme.secondaryContainer;
      case 'request_sent':
        return theme.colorScheme.surfaceContainerHighest;
      case 'request_received':
        return Colors.green;
      case 'request_rejected':
      case 'request_cancelled':
      case 'none':
      default:
        return theme.colorScheme.primary;
    }
  }

  Color _getButtonTextColor(ThemeData theme, String relationshipStatus) {
    switch (relationshipStatus) {
      case 'friends':
        return theme.colorScheme.onSecondaryContainer;
      case 'request_sent':
        return theme.colorScheme.onSurfaceVariant;
      case 'request_received':
        return Colors.white;
      case 'request_rejected':
      case 'request_cancelled':
      case 'none':
      default:
        return theme.colorScheme.onPrimary;
    }
  }

  Future<void> _handleButtonPress(
    BuildContext context,
    String relationshipStatus,
    FriendRequestProvider provider,
  ) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      bool success = false;
      String message = '';

      switch (relationshipStatus) {
        case 'friends':
          success = await _showUnfriendDialog(context, provider);
          message = success ? 'Removed from friends' : '';
          break;

        case 'request_sent':
          success = await _showCancelRequestDialog(context, provider);
          message = success ? 'Friend request cancelled' : '';
          break;

        case 'request_received':
          final request = provider.getFriendRequestStatus(widget.user.id);
          if (request != null) {
            success = await provider.acceptFriendRequest(request.id);
            message = success
                ? 'Friend request accepted'
                : 'Failed to accept request';
          }
          break;

        case 'request_rejected':
        case 'request_cancelled':
        case 'none':
        default:
          success = await _showSendRequestDialog(context, provider);
          message = success ? 'Follow request sent' : 'Failed to send request';
          break;
      }

      if (success) {
        widget.onStatusChanged?.call();

        if (mounted && message.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else if (provider.error != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.error!),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<bool> _showSendRequestDialog(
    BuildContext context,
    FriendRequestProvider provider,
  ) async {
    final messageController = TextEditingController();
    messageController.text = 'Hi! I\'d like to be friends.';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Send Follow Request to ${widget.user.displayName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Add a message (optional):'),
            const SizedBox(height: 12),
            TextField(
              controller: messageController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Write a message...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Send Request'),
          ),
        ],
      ),
    );

    if (result == true) {
      return await provider.sendFriendRequest(
        widget.user.id,
        message: messageController.text.trim().isEmpty
            ? null
            : messageController.text.trim(),
      );
    }

    return false;
  }

  Future<bool> _showCancelRequestDialog(
    BuildContext context,
    FriendRequestProvider provider,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Follow Request'),
        content: Text('Cancel follow request to ${widget.user.displayName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Cancel Request'),
          ),
        ],
      ),
    );

    if (result == true) {
      final request = provider.getFriendRequestStatus(widget.user.id);
      if (request != null) {
        return await provider.cancelFriendRequest(request.id);
      }
    }

    return false;
  }

  Future<bool> _showUnfriendDialog(
    BuildContext context,
    FriendRequestProvider provider,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Friend'),
        content: Text(
          'Remove ${widget.user.displayName} from your friends? '
          'You will no longer be able to message each other.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (result == true) {
      return await provider.removeFriend(widget.user.id);
    }

    return false;
  }
}

/// Widget showing friend request stats
class FriendRequestStatsWidget extends StatelessWidget {
  final VoidCallback? onFriendsPressed;
  final VoidCallback? onRequestsPressed;

  const FriendRequestStatsWidget({
    super.key,
    this.onFriendsPressed,
    this.onRequestsPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<FriendRequestProvider>(
      builder: (context, provider, child) {
        final stats = provider.stats;

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildStatItem(
              context,
              count: stats.totalFriends,
              label: 'Friends',
              onPressed: onFriendsPressed,
            ),
            _buildStatItem(
              context,
              count: stats.pendingReceived,
              label: 'Requests',
              onPressed: onRequestsPressed,
              showBadge: stats.pendingReceived > 0,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatItem(
    BuildContext context, {
    required int count,
    required String label,
    VoidCallback? onPressed,
    bool showBadge = false,
  }) {
    final theme = Theme.of(context);

    final child = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          children: [
            Text(
              count.toString(),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            if (showBadge)
              Positioned(
                right: -8,
                top: -4,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );

    if (onPressed != null) {
      return InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Padding(padding: const EdgeInsets.all(8), child: child),
      );
    }

    return child;
  }
}
