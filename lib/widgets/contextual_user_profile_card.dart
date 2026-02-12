import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/friend_request_service.dart';
import '../services/user_service.dart';

/// Profile card for list view (like in search screen) - shows connect button on the right
class ListUserProfileCard extends StatefulWidget {
  final User user;
  final VoidCallback? onTap;
  final VoidCallback? onStatusChanged;
  final bool showOnlineStatus;

  const ListUserProfileCard({
    super.key,
    required this.user,
    this.onTap,
    this.onStatusChanged,
    this.showOnlineStatus = true,
  });

  @override
  State<ListUserProfileCard> createState() => _ListUserProfileCardState();
}

class _ListUserProfileCardState extends State<ListUserProfileCard> {
  final FriendRequestService _friendRequestService =
      FriendRequestService.instance;
  String _relationshipStatus = 'none';
  String? _requestId;
  bool _loading = false;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadFriendshipStatus();
  }

  Future<void> _loadFriendshipStatus() async {
    final currentUser = await UserService.getCurrentUser();
    if (currentUser == null) return;

    setState(() {
      _currentUserId = currentUser.id;
      _loading = true;
    });

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
            // Avatar with online status
            _buildAvatar(),

            const SizedBox(width: 16),

            // User info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Full name
                  Text(
                    widget.user.displayName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 4),

                  // Handle
                  Text(
                    widget.user.formattedHandle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  if (widget.user.bio.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      widget.user.bio,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(width: 12),

            // Follow button on the right
            if (_shouldShowButton()) _buildFollowButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    final theme = Theme.of(context);

    return Stack(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
          child: Text(
            widget.user.initials,
            style: TextStyle(
              fontSize: 16,
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
              width: 12,
              height: 12,
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
      return const SizedBox(
        width: 80,
        height: 32,
        child: Center(
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
    return ElevatedButton(
      onPressed: _sendFriendRequest,
      style: ElevatedButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        minimumSize: const Size(80, 32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: const Text(
        'Follow',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildRequestedButton() {
    return OutlinedButton(
      onPressed: null,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.grey.shade600,
        side: BorderSide(color: Colors.grey.shade300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        minimumSize: const Size(80, 32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: const Text(
        'Followed',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildAcceptButton() {
    return ElevatedButton(
      onPressed: _acceptRequest,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        minimumSize: const Size(80, 32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: const Text(
        'Accept',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildFriendsButton() {
    return OutlinedButton(
      onPressed: null,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.green.shade700,
        side: BorderSide(color: Colors.green.shade300),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: const Size(80, 32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check, size: 14, color: Colors.green.shade700),
          const SizedBox(width: 4),
          const Text(
            'Friends',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
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

/// Profile card for grid view (like in home screen sections) - shows follow button below
class GridUserProfileCard extends StatefulWidget {
  final User user;
  final VoidCallback? onTap;
  final VoidCallback? onStatusChanged;
  final bool showOnlineStatus;
  final bool showBio;

  const GridUserProfileCard({
    super.key,
    required this.user,
    this.onTap,
    this.onStatusChanged,
    this.showOnlineStatus = true,
    this.showBio = true,
  });

  @override
  State<GridUserProfileCard> createState() => _GridUserProfileCardState();
}

class _GridUserProfileCardState extends State<GridUserProfileCard> {
  final FriendRequestService _friendRequestService =
      FriendRequestService.instance;
  String _relationshipStatus = 'none';
  String? _requestId;
  bool _loading = false;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadFriendshipStatus();
  }

  Future<void> _loadFriendshipStatus() async {
    final currentUser = await UserService.getCurrentUser();
    if (currentUser == null) return;

    setState(() {
      _currentUserId = currentUser.id;
      _loading = true;
    });

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
            // Avatar with online status
            _buildAvatar(),

            const SizedBox(height: 12),

            // Full name
            Text(
              widget.user.displayName,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 4),

            // Handle
            Text(
              widget.user.formattedHandle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 8),

            // Virtual number (always show for grid)
            Text(
              widget.user.virtualNumber ?? '',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),

            if (widget.showBio && widget.user.bio.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                widget.user.bio,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            const SizedBox(height: 12),

            // Follow button at bottom (removed Spacer to prevent overflow)
            if (_shouldShowButton())
              SizedBox(width: double.infinity, child: _buildFollowButton()),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    final theme = Theme.of(context);

    return Stack(
      children: [
        CircleAvatar(
          radius: 32,
          backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
          child: Text(
            widget.user.initials,
            style: TextStyle(
              fontSize: 20,
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
              width: 16,
              height: 16,
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
      return const SizedBox(
        height: 32,
        child: Center(
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
    return ElevatedButton(
      onPressed: _sendFriendRequest,
      style: ElevatedButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: const Text(
        'Follow',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildRequestedButton() {
    return OutlinedButton(
      onPressed: null,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.grey.shade600,
        side: BorderSide(color: Colors.grey.shade300),
        padding: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: const Text(
        'Followed',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildAcceptButton() {
    return ElevatedButton(
      onPressed: _acceptRequest,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: const Text(
        'Accept',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildFriendsButton() {
    return OutlinedButton(
      onPressed: null,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.green.shade700,
        side: BorderSide(color: Colors.green.shade300),
        padding: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check, size: 16, color: Colors.green.shade700),
          const SizedBox(width: 4),
          const Text(
            'Friends',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
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
