import 'package:flutter/material.dart';

class UserAvatar extends StatelessWidget {
  final String? avatar;
  final String? profilePicture;
  final String? name;
  final double radius;
  final double? fontSize;
  final Color? backgroundColor;

  const UserAvatar({
    super.key,
    this.avatar,
    this.profilePicture,
    this.name,
    this.radius = 20.0,
    this.fontSize,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = backgroundColor ?? theme.colorScheme.primary.withOpacity(0.1);

    // 1. Profile Picture (URL)
    if (profilePicture != null &&
        profilePicture!.isNotEmpty &&
        profilePicture!.startsWith('http')) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: bg,
        backgroundImage: NetworkImage(profilePicture!),
        onBackgroundImageError: (_, __) {
          // Fallback silently to background color if image fails
          // In a real app, we might want to cascade to avatar/initials here
        },
      );
    }

    // 2. Avatar (Emoji/Text)
    // Trust the DB content unless it looks like a virtual number or URL artifact
    if (avatar != null &&
        avatar!.isNotEmpty &&
        !avatar!.startsWith('http') &&
        !avatar!.startsWith('BN-') && // Filter legacy virtual numbers
        !avatar!.startsWith('VN-')) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: bg,
        child: Text(
          avatar!,
          style: TextStyle(fontSize: fontSize ?? (radius * 1.0), height: 1.1),
          textAlign: TextAlign.center,
        ),
      );
    }

    // 3. Fallback to Initials
    return CircleAvatar(
      radius: radius,
      backgroundColor: bg,
      child: Text(
        _getInitials(name),
        style: TextStyle(
          fontSize: fontSize ?? (radius * 0.8),
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }

  String _getInitials(String? fullName) {
    if (fullName == null || fullName.trim().isEmpty) return '?';

    final names = fullName.trim().split(RegExp(r'\s+'));
    if (names.isEmpty) return '?';

    if (names.length >= 2) {
      return '${names.first[0]}${names.last[0]}'.toUpperCase();
    }
    return names.first[0].toUpperCase();
  }
}
