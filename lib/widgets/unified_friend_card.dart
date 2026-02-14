import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';
import '../screens/friend_chat_screen.dart';
import 'follow_button.dart';
import '../core/constants.dart';

/// Unified friend profile card with 3 segments:
/// 1. Profile picture (clickable -> opens profile screen)
/// 2. User info (name, handle, virtual number) (clickable -> opens chat)
/// 3. Action button (Follow/Following button)
class UnifiedFriendCard extends StatefulWidget {
  final User user;
  final VoidCallback? onStatusChanged;
  final bool showOnlineStatus;
  final bool showActionButton;
  final bool showMessageButton;
  final bool showBio;
  final bool showHandle;
  final VoidCallback? onTap;
  final VoidCallback? onMessagePressed;

  const UnifiedFriendCard({
    super.key,
    required this.user,
    this.onStatusChanged,
    this.showOnlineStatus = true,
    this.showActionButton = true,
    this.showMessageButton = false,
    this.showBio = false,
    this.showHandle = true,
    this.onTap,
    this.onMessagePressed,
  });

  @override
  State<UnifiedFriendCard> createState() => _UnifiedFriendCardState();
}

class _UnifiedFriendCardState extends State<UnifiedFriendCard> {
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserId();
  }

  Future<void> _loadCurrentUserId() async {
    final currentUser = await UserService.getCurrentUser();
    if (currentUser != null && mounted) {
      setState(() {
        _currentUserId = currentUser.id;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: widget.onTap ?? _handleInfoTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            bottom: BorderSide(
              color: theme.dividerColor.withOpacity(0.1),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            // SEGMENT 1: Profile Picture
            _buildProfilePictureSegment(theme),

            const SizedBox(width: 16),

            // SEGMENT 2: User Info
            Expanded(child: _buildUserInfoSegment(theme)),

            const SizedBox(width: 8),

            // SEGMENT 3: Action Button
            if (widget.showMessageButton)
              IconButton(
                onPressed: widget.onMessagePressed ?? _handleInfoTap,
                icon: Icon(
                  Icons.message_outlined,
                  color: theme.colorScheme.primary,
                ),
                tooltip: 'Message',
              )
            else if (widget.showActionButton &&
                _currentUserId != widget.user.id)
              FollowButton(
                user: widget.user,
                compact: true,
                onStatusChanged: widget.onStatusChanged,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfilePictureSegment(ThemeData theme) {
    return GestureDetector(
      onTap: _openProfileScreen,
      child: Stack(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
            backgroundImage:
                widget.user.profilePicture != null &&
                    widget.user.profilePicture!.startsWith('http')
                ? NetworkImage(widget.user.profilePicture!)
                : null,
            child: widget.user.avatar != null && widget.user.avatar!.isNotEmpty
                ? Text(
                    widget.user.avatar!,
                    style: const TextStyle(fontSize: 24),
                  )
                : (widget.user.profilePicture == null ||
                          !widget.user.profilePicture!.startsWith('http')
                      ? Text(
                          widget.user.fullName.isNotEmpty
                              ? widget.user.fullName
                                    .split(' ')
                                    .map((e) => e.isNotEmpty ? e[0] : '')
                                    .take(2)
                                    .join()
                                    .toUpperCase()
                              : widget.user.handle.isNotEmpty
                              ? widget.user.handle[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        )
                      : null),
          ),
          if (widget.showOnlineStatus &&
              widget.user.status == UserStatus.online)
            Positioned(
              right: 2,
              bottom: 2,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme.colorScheme.surface,
                    width: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUserInfoSegment(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                widget.user.fullName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (widget.user.isVerified ||
                AppConstants.officialIds.contains(widget.user.id)) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.verified,
                size: 16,
                color: widget.user.id == AppConstants.booferId
                    ? Colors.green
                    : theme.colorScheme.primary,
              ),
            ],
          ],
        ),
        if (widget.showHandle) ...[
          const SizedBox(height: 2),
          Text(
            widget.user.formattedHandle,
            style: TextStyle(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
              fontSize: 14,
            ),
          ),
        ],
        if (widget.showBio && widget.user.bio.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            widget.user.bio,
            style: TextStyle(
              color: theme.colorScheme.onSurface.withOpacity(0.8),
              fontSize: 13,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        if (widget.showHandle &&
            !widget.showBio &&
            widget.user.virtualNumber != null) ...[
          const SizedBox(height: 2),
          Text(
            widget.user.formattedVirtualNumber,
            style: TextStyle(
              color: theme.colorScheme.primary.withOpacity(0.8),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  void _openProfileScreen() {
    Navigator.pushNamed(context, '/profile', arguments: widget.user.id);
  }

  void _handleInfoTap() {
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
}

class BooferBadge extends StatelessWidget {
  final String letter;
  final String tooltip;

  const BooferBadge({
    super.key,
    this.letter = 'B',
    this.tooltip = 'Official Boofer Account',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: tooltip,
      child: Container(
        margin: const EdgeInsets.only(left: 4),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(8),
            bottomRight: Radius.circular(8),
            topRight: Radius.circular(2),
            bottomLeft: Radius.circular(2),
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
          ),
        ),
        child: Text(
          letter,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            fontFamily: 'Roboto',
          ),
        ),
      ),
    );
  }
}
