import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/follow_provider.dart';
import '../providers/appearance_provider.dart';
import '../models/user_model.dart';
import '../core/constants.dart';

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
  static const String booferId = AppConstants.booferId;

  @override
  Widget build(BuildContext context) {
    return Consumer<FollowProvider>(
      builder: (context, provider, child) {
        final isFollowing = provider.isFollowing(widget.user.id);
        final isLoading = provider.isLoading || _isProcessing;
        final isSelf = provider.currentUserId == widget.user.id;
        final isBoofer = widget.user.id == booferId;

        if (isSelf) {
          return const SizedBox.shrink(); // Don't show button for self
        }

        if (widget.compact) {
          return _buildCompactButton(
            context,
            isFollowing,
            isLoading,
            isBoofer,
            provider,
          );
        }

        return _buildFullButton(
          context,
          isFollowing,
          isLoading,
          isBoofer,
          provider,
        );
      },
    );
  }

  Widget _buildFullButton(
    BuildContext context,
    bool isFollowing,
    bool isLoading,
    bool isBoofer,
    FollowProvider provider,
  ) {
    final theme = Theme.of(context);
    final appearanceProvider = Provider.of<AppearanceProvider>(context);

    // Only apply gradient to primary actions: Follow
    final showGradient = appearanceProvider.useGradientAccent && !isFollowing;
    final borderRadius = BorderRadius.circular(appearanceProvider.cornerRadius);

    // Boofer specific styling: Always "Following" and disabled
    if (isBoofer) {
      return Container(
        width: 120,
        height: 36,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
          borderRadius: borderRadius,
          border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
        ),
        child: const Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check, size: 16, color: Colors.blue),
              SizedBox(width: 4),
              Text(
                'Followed',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
        ),
      );
    }

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
            : () => _handleButtonPress(context, isFollowing, provider),
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
                : _getButtonStyle(theme, isFollowing)),
        child: isLoading
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    showGradient ? Colors.white : theme.colorScheme.primary,
                  ),
                ),
              )
            : Text(
                isFollowing ? 'Following' : 'Follow',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: showGradient
                      ? Colors.white
                      : (isFollowing
                            ? theme.colorScheme.onSurfaceVariant
                            : theme.colorScheme.onPrimary),
                ),
              ),
      ),
    );
  }

  Widget _buildCompactButton(
    BuildContext context,
    bool isFollowing,
    bool isLoading,
    bool isBoofer,
    FollowProvider provider,
  ) {
    final theme = Theme.of(context);

    if (isBoofer) {
      return const SizedBox(
        width: 32,
        height: 32,
        child: Center(
          child: Icon(Icons.check_circle, size: 20, color: Colors.blue),
        ),
      );
    }

    return SizedBox(
      width: 32,
      height: 32,
      child: IconButton(
        onPressed: isLoading
            ? null
            : () => _handleButtonPress(context, isFollowing, provider),
        style: IconButton.styleFrom(
          backgroundColor: isFollowing
              ? theme.colorScheme.surfaceContainerHighest
              : theme.colorScheme.primary,
          foregroundColor: isFollowing
              ? theme.colorScheme.onSurfaceVariant
              : theme.colorScheme.onPrimary,
          padding: EdgeInsets.zero,
        ),
        icon: isLoading
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isFollowing
                        ? theme.colorScheme.onSurfaceVariant
                        : theme.colorScheme.onPrimary,
                  ),
                ),
              )
            : Icon(isFollowing ? Icons.check : Icons.person_add, size: 18),
      ),
    );
  }

  ButtonStyle _getButtonStyle(ThemeData theme, bool isFollowing) {
    if (isFollowing) {
      return ElevatedButton.styleFrom(
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        foregroundColor: theme.colorScheme.onSurfaceVariant,
        elevation: 0,
        side: BorderSide(
          color: theme.colorScheme.outline.withOpacity(0.3),
          width: 1,
        ),
      );
    } else {
      return ElevatedButton.styleFrom(
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        elevation: 2,
      );
    }
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
