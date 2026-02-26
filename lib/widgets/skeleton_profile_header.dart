import 'package:flutter/material.dart';
import 'skeleton_loader.dart';

/// Skeleton loading for profile screen header
class SkeletonProfileHeader extends StatelessWidget {
  const SkeletonProfileHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerEffect(
      child: Column(
        children: [
          const SizedBox(height: 24),
          const SkeletonAvatar(size: 100),
          const SizedBox(height: 16),
          Center(
            child: SkeletonBox(
              width: 150,
              height: 20,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: SkeletonBox(
              width: 100,
              height: 16,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatSkeleton(),
              _buildStatSkeleton(),
              _buildStatSkeleton(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatSkeleton() {
    return Column(
      children: [
        SkeletonBox(
          width: 40,
          height: 20,
          borderRadius: BorderRadius.circular(4),
        ),
        const SizedBox(height: 4),
        SkeletonBox(
          width: 60,
          height: 14,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }
}
