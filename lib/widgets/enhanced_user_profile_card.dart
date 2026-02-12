import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/friend_request_service.dart';
import '../services/user_service.dart';

enum ProfileCardStyle { grid, list }

/// Enhanced user profile card that can be displayed in two styles:
/// - Grid: Vertical layout with profile pic at top, centered elements
/// - List: Horizontal layout with profile pic on left, info in middle, button on right
class EnhancedUserProfileCard extends StatefulWidget {
  final User user;
  final ProfileCardStyle style;
  final VoidCallback? onTap;
  final VoidCallback? onStatusChanged;
  final bool showFollowButton;
  final bool showOnlineStatus;

  const EnhancedUserProfileCard({
    super.key,
    required this.user,
    required this.style,
    this.onTap,
    this.onStatusChanged,
    this.showFollowButton = true,
    this.showOnlineStatus = true,
  });

  @override
  State<EnhancedUserProfileCard> createState() =>
      _EnhancedUserProfileCardState();
}

class _EnhancedUserProfileCardState extends State<EnhancedUserProfileCard> {
  final FriendRequestService _friendRequestService =
      FriendRequestService.instance;
  String _relationshipStatus = 'none';
  String? _requestId;
  bool _loading = false;
  String? _currentUserId;

  bool get _isBoofer =>
      widget.user.id == '00000000-0000-4000-8000-000000000000';

  @override
  void initState() {
    super.initState();
    if (widget.showFollowButton) {
      _loadFriendshipStatus();
    }
  }

  Future<void> _loadFriendshipStatus() async {
    final currentUser = await UserService.getCurrentUser();
    if (currentUser == null) return;

    if (mounted) {
      setState(() {
        _currentUserId = currentUser.id;
        _loading = true;
      });
    }

    final relationData = await _friendRequestService.getRelationshipStatus(
      currentUser.id,
      widget.user.id,
    );

    if (mounted) {
      setState(() {
        _relationshipStatus = relationData['status'] as String;
        _requestId = relationData['requestId'] as String?;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.style == ProfileCardStyle.grid
        ? _buildGridStyle()
        : _buildListStyle();
  }

  Widget _buildGridStyle() {
    final theme = Theme.of(context);

    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize:
              MainAxisSize.min, // Important: Use min to prevent overflow
          children: [
            // Profile picture at top
            _buildAvatar(size: 32),

            const SizedBox(height: 12),

            // Full name (centered)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    widget.user.displayName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_isBoofer) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.verified,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                ],
              ],
            ),

            const SizedBox(height: 4),

            // User handle (small text, centered)
            Text(
              widget.user.formattedHandle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 8),

            // Virtual number (centered)
            Text(
              widget.user.virtualNumber ?? '',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 12),

            // Follow button (centered) - removed Spacer to prevent overflow
            if (widget.showFollowButton && _shouldShowButton())
              SizedBox(width: double.infinity, child: _buildFollowButton()),
          ],
        ),
      ),
    );
  }

  Widget _buildListStyle() {
    final theme = Theme.of(context);

    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Profile pic on left (1st section)
            _buildAvatar(size: 24),

            const SizedBox(width: 16),

            // 2nd section: full name with handle and virtual number below
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Full name with handle and badges
                  Row(
                    children: [
                      Flexible(
                        child: RichText(
                          text: TextSpan(
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            children: [
                              TextSpan(text: widget.user.displayName),
                              TextSpan(
                                text: ' (${widget.user.formattedHandle})',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_isBoofer) ...[
                        const SizedBox(width: 4),
                        // Special 'B' Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'B',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.verified,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 4),

                  // Virtual number below
                  Text(
                    widget.user.virtualNumber ?? '',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // 3rd section: follow button on right
            if (widget.showFollowButton && _shouldShowButton())
              _buildFollowButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar({required double size}) {
    final theme = Theme.of(context);

    return Stack(
      children: [
        CircleAvatar(
          radius: size,
          backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
          child: Text(
            widget.user.initials,
            style: TextStyle(
              fontSize: size * 0.6,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        if (widget.showOnlineStatus && widget.user.status == UserStatus.online)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: size * 0.4,
              height: size * 0.4,
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50),
                shape: BoxShape.circle,
                border: Border.all(
                  color: theme.scaffoldBackgroundColor,
                  width: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }

  bool _shouldShowButton() {
    return _currentUserId != null && _currentUserId != widget.user.id;
  }

  Widget _buildFollowButton() {
    if (_loading) {
      return SizedBox(
        width: widget.style == ProfileCardStyle.grid ? double.infinity : 80,
        height: 32,
        child: const Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    switch (_relationshipStatus) {
      case 'none':
        return _buildFollowButtonWidget();
      case 'request_sent':
        return _buildRequestedButton();
      case 'request_received':
        return _buildAcceptButton();
      case 'friends':
        return _buildFriendsButton();
      default:
        return _buildFollowButtonWidget();
    }
  }

  Widget _buildFollowButtonWidget() {
    final isGrid = widget.style == ProfileCardStyle.grid;

    return ElevatedButton(
      onPressed: _sendFriendRequest,
      style: ElevatedButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(
          horizontal: isGrid ? 24 : 16,
          vertical: 8,
        ),
        minimumSize: Size(isGrid ? double.infinity : 80, 32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(
        'Follow',
        style: TextStyle(
          fontSize: isGrid ? 14 : 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildRequestedButton() {
    final isGrid = widget.style == ProfileCardStyle.grid;

    return OutlinedButton(
      onPressed: null,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.grey.shade600,
        side: BorderSide(color: Colors.grey.shade300),
        padding: EdgeInsets.symmetric(
          horizontal: isGrid ? 24 : 16,
          vertical: 8,
        ),
        minimumSize: Size(isGrid ? double.infinity : 80, 32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(
        'Followed',
        style: TextStyle(
          fontSize: isGrid ? 14 : 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildAcceptButton() {
    final isGrid = widget.style == ProfileCardStyle.grid;

    return ElevatedButton(
      onPressed: _acceptRequest,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(
          horizontal: isGrid ? 24 : 16,
          vertical: 8,
        ),
        minimumSize: Size(isGrid ? double.infinity : 80, 32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(
        'Accept',
        style: TextStyle(
          fontSize: isGrid ? 14 : 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildFriendsButton() {
    final isGrid = widget.style == ProfileCardStyle.grid;

    return OutlinedButton(
      onPressed: null,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.green.shade700,
        side: BorderSide(color: Colors.green.shade300),
        padding: EdgeInsets.symmetric(
          horizontal: isGrid ? 24 : 12,
          vertical: 8,
        ),
        minimumSize: Size(isGrid ? double.infinity : 80, 32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Row(
        mainAxisSize: isGrid ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check,
            size: isGrid ? 16 : 14,
            color: Colors.green.shade700,
          ),
          const SizedBox(width: 4),
          Text(
            'Friends',
            style: TextStyle(
              fontSize: isGrid ? 14 : 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendFriendRequest() async {
    if (_currentUserId == null) return;

    setState(() => _loading = true);

    final success = await _friendRequestService.sendFriendRequest(
      fromUserId: _currentUserId!,
      toUserId: widget.user.id,
      message: 'Hi! I\'d like to connect with you.',
    );

    if (mounted) {
      if (success) {
        await _loadFriendshipStatus();
        widget.onStatusChanged?.call();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Follow request sent to ${widget.user.displayName}'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _acceptRequest() async {
    if (_currentUserId == null || _requestId == null) return;

    setState(() => _loading = true);

    final success = await _friendRequestService.acceptFriendRequest(
      requestId: _requestId!,
      userId: _currentUserId!,
    );

    if (mounted) {
      if (success) {
        await _loadFriendshipStatus();
        widget.onStatusChanged?.call();
      } else {
        setState(() => _loading = false);
      }
    }
  }
}

/// Compact version for backwards compatibility
class CompactUserProfileCard extends StatelessWidget {
  final User user;
  final VoidCallback? onTap;
  final bool showFollowButton;
  final bool showOnlineStatus;

  const CompactUserProfileCard({
    super.key,
    required this.user,
    this.onTap,
    this.showFollowButton = true,
    this.showOnlineStatus = true,
  });

  @override
  Widget build(BuildContext context) {
    return EnhancedUserProfileCard(
      user: user,
      style: ProfileCardStyle.list,
      onTap: onTap,
      showFollowButton: showFollowButton,
      showOnlineStatus: showOnlineStatus,
    );
  }
}
