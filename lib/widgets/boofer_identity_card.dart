import 'package:flutter/material.dart';
import '../models/user_model.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../core/constants.dart';

class BooferIdentityCard extends StatelessWidget {
  final User user;
  final VoidCallback onCopyNumber;
  final bool showStats; // Whether to show counts/interests
  final bool showFollowStats; // Whether to show followers/following

  final bool showQrInsteadOfCopy;

  const BooferIdentityCard({
    super.key,
    required this.user,
    required this.onCopyNumber,
    this.showQrInsteadOfCopy = false,
    this.showStats = true,
    this.showFollowStats = true,
    this.showInterests = true,
    this.onFollowersTap,
    this.onFollowingTap,
  });

  final bool showInterests;
  final VoidCallback? onFollowersTap;
  final VoidCallback? onFollowingTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E30) : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 10,
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF845EF7), Color(0xFFFF6B6B)],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        children: [
                          Container(
                            width: 80,
                            height: 100,
                            decoration: BoxDecoration(
                              color: user.isCompany
                                  ? const Color(0xFFFFD700)
                                      .withValues(alpha: 0.08)
                                  : theme.colorScheme.onSurface.withValues(
                                      alpha: 0.05,
                                    ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: user.isCompany
                                    ? const Color(0xFFFFD700)
                                        .withValues(alpha: 0.35)
                                    : theme.colorScheme.onSurface.withValues(
                                        alpha: 0.1,
                                      ),
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Center(
                                child: user.isCompany
                                    ? const Text('🏢',
                                        style: TextStyle(fontSize: 44))
                                    : (user.profilePicture != null &&
                                            user.profilePicture!.isNotEmpty
                                        ? Image.network(
                                            user.profilePicture!,
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                            height: double.infinity,
                                            errorBuilder:
                                                (context, error, stackTrace) =>
                                                    Text(
                                              user.avatar ?? '👤',
                                              style:
                                                  const TextStyle(fontSize: 44),
                                            ),
                                          )
                                        : Text(
                                            user.avatar ?? '👤',
                                            style:
                                                const TextStyle(fontSize: 44),
                                          )),
                              ),
                            ),
                          ),
                          if (user.isCompany)
                            Positioned(
                              right: 3,
                              bottom: 3,
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF845EF7,
                                  ), // deep purple — contrasts with gold crown
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isDark
                                        ? const Color(0xFF1E1E30)
                                        : theme.colorScheme.surface,
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF845EF7,
                                      ).withValues(alpha: 0.5),
                                      blurRadius: 5,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: const Center(
                                  child: Text(
                                    '👑',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.isCompany
                                  ? 'OFFICIAL BOOFER ENTITY'
                                  : 'BOOFER IDENTITY',
                              style: TextStyle(
                                color: user.isCompany
                                    ? const Color(0xFF20C997)
                                    : const Color(0xFF845EF7),
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              user.fullName,
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '@${user.handle}',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.4),
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (!user.isCompany &&
                                (user.age != null ||
                                    (user.gender != null &&
                                        user.gender!.isNotEmpty))) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  if (user.age != null)
                                    Text(
                                      '${user.age} yrs',
                                      style: TextStyle(
                                        color: theme.colorScheme.onSurface
                                            .withValues(alpha: 0.4),
                                        fontSize: 13,
                                      ),
                                    ),
                                  if (user.age != null &&
                                      (user.gender != null &&
                                          user.gender!.isNotEmpty))
                                    Container(
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      width: 4,
                                      height: 4,
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.onSurface
                                            .withValues(alpha: 0.2),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  if (user.gender != null &&
                                      user.gender!.isNotEmpty)
                                    Text(
                                      user.gender!.toLowerCase() == 'male'
                                          ? '♂ Male'
                                          : user.gender!.toLowerCase() ==
                                                  'female'
                                              ? '♀ Female'
                                              : user.gender![0].toUpperCase() +
                                                  user.gender!.substring(1),
                                      style: TextStyle(
                                        color: theme.colorScheme.onSurface
                                            .withValues(alpha: 0.4),
                                        fontSize: 13,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 10),
                            if (user.bio.isNotEmpty)
                              Text(
                                user.bio,
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.7),
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              )
                            else
                              Text(
                                user.id == AppConstants.booferId
                                    ? 'Official Support Chatbot'
                                    : user.isCompany
                                        ? 'Official Verified Entity'
                                        : 'Identity established on Boofer.',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.5),
                                  fontSize: 13,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (showStats && user.id != AppConstants.booferId) ...[
                    if (!user.isCompany &&
                        showInterests &&
                        (user.interests.isNotEmpty ||
                            user.hobbies.isNotEmpty)) ...[
                      const SizedBox(height: 16),
                      _buildInterestsAndHobbies(theme),
                    ],
                  ],
                  const SizedBox(height: 20),
                  Container(
                    height: 0.5,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'VIRTUAL NUMBER',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.3,
                              ),
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user.formattedVirtualNumber,
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                      if (showQrInsteadOfCopy)
                        Container(
                          width: 50,
                          height: 50,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.1,
                              ),
                            ),
                          ),
                          child: QrImageView(
                            data: 'boofer://profile/@${user.handle}',
                            version: QrVersions.auto,
                            padding: const EdgeInsets.all(0),
                            eyeStyle: const QrEyeStyle(
                              eyeShape: QrEyeShape.circle,
                              color: Colors.black,
                            ),
                            dataModuleStyle: const QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.circle,
                              color: Colors.black,
                            ),
                          ),
                        )
                      else
                        IconButton(
                          onPressed: onCopyNumber,
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF845EF7)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.copy_rounded,
                              color: Color(0xFF845EF7),
                              size: 18,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              width: double.infinity,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.05),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(24),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.policy_rounded,
                    color: theme.colorScheme.primary.withValues(alpha: 0.5),
                    size: 14,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'GOVERNMENT OF BOOFER',
                    style: TextStyle(
                      color: theme.colorScheme.primary.withValues(alpha: 0.7),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInterestsAndHobbies(ThemeData theme) {
    return Column(
      children: [
        if (user.interests.isNotEmpty)
          _buildItemsRow(
            theme,
            'INTERESTS',
            user.interests.take(3).toList(),
            const Color(0xFF845EF7),
          ),
        if (user.interests.isNotEmpty && user.hobbies.isNotEmpty)
          const SizedBox(height: 8),
        if (user.hobbies.isNotEmpty)
          _buildItemsRow(
            theme,
            'HOBBIES',
            user.hobbies.take(3).toList(),
            const Color(0xFFFF6B6B),
          ),
      ],
    );
  }

  Widget _buildItemsRow(
      ThemeData theme, String label, List<String> items, Color color) {
    return Row(
      children: [
        SizedBox(
          width: 65,
          child: Text(
            label,
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              fontSize: 7,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Expanded(
          child: Wrap(
            spacing: 4,
            children: items.map((item) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: color.withValues(alpha: 0.1),
                  ),
                ),
                child: Text(
                  item,
                  style: TextStyle(
                    color: color.withValues(alpha: 0.7),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
