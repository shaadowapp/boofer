import 'package:flutter/material.dart';
import 'skeleton_loader.dart';

/// Skeleton loading for user cards in discover and manage friends screens
class SkeletonUserCard extends StatelessWidget {
  final bool showBio;

  const SkeletonUserCard({
    super.key,
    this.showBio = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ShimmerEffect(
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
            const SkeletonAvatar(size: 48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(
                    width: 140,
                    height: 16,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 6),
                  SkeletonBox(
                    width: 100,
                    height: 14,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  if (showBio) ...[
                    const SizedBox(height: 6),
                    SkeletonBox(
                      width: double.infinity,
                      height: 12,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            SkeletonBox(
              width: 80,
              height: 32,
              borderRadius: BorderRadius.circular(16),
            ),
          ],
        ),
      ),
    );
  }
}
