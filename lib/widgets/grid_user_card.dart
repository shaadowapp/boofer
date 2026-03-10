import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';
import 'follow_button.dart';
import '../core/constants.dart';
import '../widgets/user_avatar.dart';

class GridUserCard extends StatefulWidget {
  final User user;
  final VoidCallback? onStatusChanged;
  final VoidCallback? onTap;

  const GridUserCard({
    super.key,
    required this.user,
    this.onStatusChanged,
    this.onTap,
  });

  @override
  State<GridUserCard> createState() => _GridUserCardState();
}

class _GridUserCardState extends State<GridUserCard> {
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

  void _handleTap() {
    if (widget.onTap != null) {
      widget.onTap!();
    } else {
      Navigator.pushNamed(context, '/profile', arguments: widget.user.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Filter verified status for display
    final showVerifiedBadge = widget.user.isCompany ||
        widget.user.isVerified ||
        AppConstants.officialIds.contains(widget.user.id);

    return InkWell(
      onTap: _handleTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: theme.dividerColor.withValues(alpha: 0.08),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Avatar
            UserAvatar(
              avatar: widget.user.avatar,
              profilePicture: widget.user.profilePicture,
              name: widget.user.fullName,
              radius: 40,
              fontSize: 32,
              isCompany: widget.user.isCompany,
            ),
            
            const SizedBox(height: 14),
            
            // Name
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    widget.user.fullName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
                if (showVerifiedBadge) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.verified,
                    size: 15,
                    color: widget.user.id == AppConstants.booferId ||
                            widget.user.isCompany
                        ? Colors.green
                        : theme.colorScheme.primary,
                  ),
                ],
              ],
            ),
            
            const SizedBox(height: 2),
            
            // Handle
            Text(
              widget.user.formattedHandle,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 10),
            
            // Bio
            Expanded(
              child: Text(
                widget.user.bio.isNotEmpty ? widget.user.bio : 'No bio available',
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  fontSize: 12,
                  height: 1.3,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
            
            const SizedBox(height: 12),

            // Action Button
            if (_currentUserId != widget.user.id &&
                widget.user.id != AppConstants.booferId &&
                widget.user.handle.toLowerCase() != 'boofer')
              SizedBox(
                width: double.infinity,
                child: FollowButton(
                  user: widget.user,
                  compact: true,
                  onStatusChanged: widget.onStatusChanged,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
