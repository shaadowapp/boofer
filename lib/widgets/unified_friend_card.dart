import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/friend_request_service.dart';
import '../services/user_service.dart';
import '../screens/friend_chat_screen.dart';

/// Unified friend profile card with 3 segments:
/// 1. Profile picture (clickable -> opens profile screen)
/// 2. User info (name, handle, virtual number) (clickable -> opens chat if friend)
/// 3. Action button (Follow/Following/etc.) (only shown if not friend and showActionButton is true)
class UnifiedFriendCard extends StatefulWidget {
  final User user;
  final VoidCallback? onStatusChanged;
  final bool showOnlineStatus;
  final bool
  showActionButton; // New parameter to control action button visibility

  const UnifiedFriendCard({
    super.key,
    required this.user,
    this.onStatusChanged,
    this.showOnlineStatus = true,
    this.showActionButton = true, // Default to true
  });

  @override
  State<UnifiedFriendCard> createState() => _UnifiedFriendCardState();
}

class _UnifiedFriendCardState extends State<UnifiedFriendCard> {
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

  bool get _isFriend => _relationshipStatus == 'friends';
  bool get _shouldShowButton =>
      widget.showActionButton &&
      _currentUserId != null &&
      _currentUserId != widget.user.id &&
      !_isFriend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor.withOpacity(0.3),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          // SEGMENT 1: Profile Picture (clickable -> profile screen)
          _buildProfilePictureSegment(theme),

          const SizedBox(width: 16),

          // SEGMENT 2: User Info (clickable -> chat if friend)
          Expanded(child: _buildUserInfoSegment(theme)),

          // SEGMENT 3: Action Button (only if not friend)
          if (_shouldShowButton) ...[
            const SizedBox(width: 12),
            _buildActionButtonSegment(),
          ],
        ],
      ),
    );
  }

  /// SEGMENT 1: Profile Picture - Opens Profile Screen
  Widget _buildProfilePictureSegment(ThemeData theme) {
    return GestureDetector(
      onTap: () => _openProfileScreen(),
      child: Stack(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
            backgroundImage:
                widget.user.profilePicture != null &&
                    widget.user.profilePicture!.isNotEmpty
                ? NetworkImage(widget.user.profilePicture!)
                : null,
            child:
                widget.user.profilePicture == null ||
                    widget.user.profilePicture!.isEmpty
                ? Text(
                    widget.user.initials,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  )
                : null,
          ),
          if (widget.showOnlineStatus &&
              widget.user.status == UserStatus.online)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 14,
                height: 14,
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
      ),
    );
  }

  /// SEGMENT 2: User Info - Opens Chat if Friend, otherwise does nothing
  Widget _buildUserInfoSegment(ThemeData theme) {
    return GestureDetector(
      onTap: () => _handleInfoTap(),
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

          // User handle
          Text(
            widget.user.formattedHandle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 2),

          // Virtual number
          if (widget.user.virtualNumber != null &&
              widget.user.virtualNumber!.isNotEmpty)
            Text(
              widget.user.virtualNumber!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
        ],
      ),
    );
  }

  /// SEGMENT 3: Action Button - Only shown if not friend
  Widget _buildActionButtonSegment() {
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
        return _buildFollowButton();
      case 'request_sent':
        return _buildRequestedButton();
      case 'request_received':
        return _buildAcceptButton();
      case 'friends':
        return const SizedBox.shrink(); // Don't show button for friends
      case 'self':
        return const SizedBox.shrink();
      default:
        return _buildFollowButton();
    }
  }

  Widget _buildFollowButton() {
    return ElevatedButton(
      onPressed: _sendFriendRequest,
      style: ElevatedButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        minimumSize: const Size(90, 32),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20), // Fully rounded
        ),
      ),
      child: const Text(
        'Follow',
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildRequestedButton() {
    return OutlinedButton(
      onPressed: null,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.grey.shade600,
        side: BorderSide(color: Colors.grey.shade300),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        minimumSize: const Size(90, 32),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20), // Fully rounded
        ),
      ),
      child: const Text(
        'Requested',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildAcceptButton() {
    return ElevatedButton(
      onPressed: _acceptRequest,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        minimumSize: const Size(90, 32),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20), // Fully rounded
        ),
      ),
      child: const Text(
        'Accept',
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }

  // Navigation handlers
  void _openProfileScreen() {
    Navigator.pushNamed(
      context,
      '/profile',
      arguments: widget.user.id, // Pass user ID to profile screen
    );
  }

  void _handleInfoTap() {
    if (_isFriend) {
      // Open chat screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FriendChatScreen(
            recipientId: widget.user.id,
            recipientName: widget.user.displayName,
            recipientHandle: widget.user.handle,
            recipientAvatar: widget.user.profilePicture ?? '',
          ),
        ),
      );
    }
    // If not friend, do nothing (or optionally open profile)
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
      setState(() => _loading = false);

      if (success) {
        // Reload to get the requestId if needed
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
      setState(() => _loading = false);

      if (success) {
        await _loadFriendshipStatus();
        widget.onStatusChanged?.call();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'You are now friends with ${widget.user.displayName}',
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
}
