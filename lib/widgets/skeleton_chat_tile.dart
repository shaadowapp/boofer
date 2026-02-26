import 'package:flutter/material.dart';
import 'skeleton_loader.dart';

/// Skeleton loading for chat tiles in lobby screen
class SkeletonChatTile extends StatelessWidget {
  const SkeletonChatTile({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerEffect(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const SkeletonAvatar(size: 56),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SkeletonBox(
                        width: 120,
                        height: 16,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      SkeletonBox(
                        width: 40,
                        height: 12,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SkeletonBox(
                    width: double.infinity,
                    height: 14,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
