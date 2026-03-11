import 'package:flutter/material.dart';
import 'skeleton_loader.dart';

/// Shimmer loading state for the chat screen
class SkeletonChatLoading extends StatelessWidget {
  const SkeletonChatLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 10,
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      itemBuilder: (context, index) {
        final isOwn = index % 3 == 0;
        final widthFactor = (index % 2 == 0) ? 0.6 : 0.4;
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ShimmerEffect(
            child: Row(
              mainAxisAlignment:
                  isOwn ? MainAxisAlignment.end : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!isOwn) ...[
                  const SkeletonAvatar(size: 32),
                  const SizedBox(width: 8),
                ],
                Column(
                  crossAxisAlignment:
                      isOwn ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(
                      width: MediaQuery.of(context).size.width * widthFactor,
                      height: 40,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft: Radius.circular(isOwn ? 20 : 4),
                        bottomRight: Radius.circular(isOwn ? 4 : 20),
                      ),
                    ),
                    const SizedBox(height: 4),
                    SkeletonBox(
                      width: 40,
                      height: 10,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
