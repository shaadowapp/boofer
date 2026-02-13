import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../providers/follow_provider.dart';
import '../providers/appearance_provider.dart';
import '../models/user_model.dart';

/// Follow button widget (Instagram style)
class FollowButton extends StatefulWidget {
  final User user;
  final VoidCallback? onStatusChanged;
  final ButtonStyle? style;
  final bool compact;

  const FollowButton({
    super.key,
    required this.user,
    this.onStatusChanged,
    this.style,
    this.compact = false,
  });

  @override
  State<FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<FollowButton> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<FollowProvider>(
      builder: (context, provider, child) {
        final isFollowing = provider.isFollowing(widget.user.id);
        final isLoading = provider.isLoading || _isProcessing;
        final isSelf = provider.currentUserId == widget.user.id;

        if (isSelf) {
          return const SizedBox.shrink(); // Don't show button for self
        }

        if (widget.compact) {
          return _buildCompactButton(context, isFollowing, isLoading, provider);
        }

        return _buildFullButton(context, isFollowing, isLoading, provider);
      },
    );
  }

  Widget _buildFullButton(
    BuildContext context,
    bool isFollowing,
    bool isLoading,
    FollowProvider provider,
  ) {
    final theme = Theme.of(context);
    final appearanceProvider = Provider.of<AppearanceProvider>(context);

    // Only apply gradient to primary actions: Follow
    final showGradient = appearanceProvider.useGradientAccent && !isFollowing;
    final borderRadius = BorderRadius.circular(appearanceProvider.cornerRadius);

    return Container(
      width:
          double.infinity, // Fill available width (usually Expanded in parent)
      height: 44, // Standard height for better UI
      decoration: showGradient
          ? BoxDecoration(
              gradient: appearanceProvider.getAccentGradient(),
              borderRadius: borderRadius,
            )
          : null,
      child: ElevatedButton(
        onPressed: isLoading
            ? null
            : () => _handleButtonPress(context, isFollowing, provider),
        style: ElevatedButton.styleFrom(
          backgroundColor: isFollowing
              ? theme.colorScheme.surfaceContainerHighest
              : (showGradient ? Colors.transparent : theme.colorScheme.primary),
          foregroundColor: isFollowing
              ? theme.colorScheme.onSurfaceVariant
              : (showGradient ? Colors.white : theme.colorScheme.onPrimary),
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(borderRadius: borderRadius),
        ),
        child: isLoading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isFollowing
                        ? theme.colorScheme.onSurfaceVariant
                        : (showGradient
                              ? Colors.white
                              : theme.colorScheme.onPrimary),
                  ),
                ),
              )
            : Text(
                isFollowing ? 'Following' : 'Follow',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Widget _buildCompactButton(
    BuildContext context,
    bool isFollowing,
    bool isLoading,
    FollowProvider provider,
  ) {
    final theme = Theme.of(context);
    final appearanceProvider = Provider.of<AppearanceProvider>(context);
    final borderRadius = BorderRadius.circular(appearanceProvider.cornerRadius);

    return SizedBox(
      width: 90, // Reduced from 100
      height: 30, // Minimal height
      child: ElevatedButton(
        onPressed: isLoading
            ? null
            : () => _handleButtonPress(context, isFollowing, provider),
        style: ElevatedButton.styleFrom(
          backgroundColor: isFollowing
              ? theme.colorScheme.surfaceContainerHighest
              : theme.colorScheme.primary,
          foregroundColor: isFollowing
              ? theme.colorScheme.onSurfaceVariant
              : theme.colorScheme.onPrimary,
          elevation: 0,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: borderRadius),
        ),
        child: isLoading
            ? SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isFollowing
                        ? theme.colorScheme.onSurfaceVariant
                        : theme.colorScheme.onPrimary,
                  ),
                ),
              )
            : Text(
                isFollowing ? 'Following' : 'Follow',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Future<void> _handleButtonPress(
    BuildContext context,
    bool isFollowing,
    FollowProvider provider,
  ) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      bool success = false;
      String message = '';

      if (isFollowing) {
        success = await _showUnfollowDialog(context, provider);
        message = success ? 'Unfollowed ${widget.user.displayName}' : '';
      } else {
        success = await provider.followUser(widget.user.id);
        message = success
            ? 'Following ${widget.user.displayName}'
            : 'Failed to follow';
      }

      if (success) {
        widget.onStatusChanged?.call();
        if (mounted && message.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<bool> _showUnfollowDialog(
    BuildContext context,
    FollowProvider provider,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unfollow?'),
        content: Text('Stop following ${widget.user.displayName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Unfollow'),
          ),
        ],
      ),
    );

    if (result == true) {
      return await provider.unfollowUser(widget.user.id);
    }
    return false;
  }
}
