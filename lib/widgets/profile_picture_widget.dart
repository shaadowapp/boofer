import 'package:flutter/material.dart';
import '../services/profile_picture_service.dart';

/// Reusable widget that displays profile picture with automatic updates
/// Uses broadcast stream to update across all app screens instantly
class ProfilePictureWidget extends StatelessWidget {
  final double size;
  final bool showBorder;
  final Color? borderColor;
  final double borderWidth;
  final String? fallbackUrl;

  const ProfilePictureWidget({
    super.key,
    this.size = 40.0,
    this.showBorder = false,
    this.borderColor,
    this.borderWidth = 2.0,
    this.fallbackUrl,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String?>(
      stream: ProfilePictureService.instance.profilePictureStream,
      initialData: ProfilePictureService.instance.currentProfilePicture ?? fallbackUrl,
      builder: (context, snapshot) {
        final profilePictureUrl = snapshot.data ?? fallbackUrl;
        
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: showBorder
                ? Border.all(
                    color: borderColor ?? Theme.of(context).colorScheme.primary,
                    width: borderWidth,
                  )
                : null,
          ),
          child: ClipOval(
            child: profilePictureUrl != null && profilePictureUrl.isNotEmpty
                ? Image.network(
                    profilePictureUrl,
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return _buildDefaultAvatar(context);
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return _buildDefaultAvatar(context);
                    },
                  )
                : _buildDefaultAvatar(context),
          ),
        );
      },
    );
  }

  Widget _buildDefaultAvatar(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
      ),
      child: Icon(
        Icons.person,
        size: size * 0.6,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}
