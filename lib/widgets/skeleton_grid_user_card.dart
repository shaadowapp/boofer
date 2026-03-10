import 'package:flutter/material.dart';
import 'skeleton_loader.dart';

/// Skeleton loading for user cards in the discovery grid
class SkeletonGridUserCard extends StatelessWidget {
  const SkeletonGridUserCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: ShimmerEffect(
        baseColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE0E0E0),
        highlightColor: isDark ? const Color(0xFF404040) : const Color(0xFFF5F5F5),
        child: Column(
          children: [
            // Avatar Placeholder
            const SkeletonAvatar(size: 80),
            
            const SizedBox(height: 14),
            
            // Name Placeholder
            SkeletonBox(
              width: 100,
              height: 16,
              borderRadius: BorderRadius.circular(4),
            ),
            
            const SizedBox(height: 4),
            
            // Handle Placeholder
            SkeletonBox(
              width: 60,
              height: 12,
              borderRadius: BorderRadius.circular(4),
            ),
            
            const SizedBox(height: 12),
            
            // Bio Placeholder
            Column(
              children: [
                SkeletonBox(
                  width: double.infinity,
                  height: 10,
                  borderRadius: BorderRadius.circular(2),
                ),
                const SizedBox(height: 4),
                SkeletonBox(
                  width: 120,
                  height: 10,
                  borderRadius: BorderRadius.circular(2),
                ),
              ],
            ),
            
            const Spacer(),
            
            // Button Placeholder
            SkeletonBox(
              width: double.infinity,
              height: 32,
              borderRadius: BorderRadius.circular(16),
            ),
          ],
        ),
      ),
    );
  }
}
