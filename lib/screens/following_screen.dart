import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/follow_provider.dart';
import '../models/user_model.dart';

/// Screen showing following list
class FollowingScreen extends StatefulWidget {
  final String userId;
  final String? userName;

  const FollowingScreen({super.key, required this.userId, this.userName});

  @override
  State<FollowingScreen> createState() => _FollowingScreenState();
}

class _FollowingScreenState extends State<FollowingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FollowProvider>().loadFollowing(widget.userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.userName != null
              ? '${widget.userName} Following'
              : 'Following',
        ),
        elevation: 0,
      ),
      body: Consumer<FollowProvider>(
        builder: (context, followProvider, child) {
          final following = followProvider.getFollowing(widget.userId);
          final isLoading = followProvider.isLoading;
          final error = followProvider.error;

          if (isLoading && following.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (error != null && following.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load following',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    error,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      followProvider.loadFollowing(
                        widget.userId,
                        refresh: true,
                      );
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (following.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.person_search_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.userId == followProvider.currentUserId
                        ? 'You\'re not following anyone yet'
                        : 'Not following anyone yet',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.userId == followProvider.currentUserId
                        ? 'Discover and follow people to see their posts in your feed'
                        : 'When this user follows people, they\'ll appear here',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  if (widget.userId == followProvider.currentUserId) ...[
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        // Navigate to discover users screen
                        Navigator.of(context).pushNamed('/discover');
                      },
                      child: const Text('Discover People'),
                    ),
                  ],
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              await followProvider.loadFollowing(widget.userId, refresh: true);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: following.length,
              itemBuilder: (context, index) {
                final user = following[index];
                return _buildFollowingItem(context, user, followProvider);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildFollowingItem(
    BuildContext context,
    User user,
    FollowProvider followProvider,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // User avatar
            CircleAvatar(
              radius: 24,
              backgroundImage: user.profilePicture != null &&
                      user.profilePicture!.startsWith('http')
                  ? NetworkImage(user.profilePicture!)
                  : null,
              child: user.avatar != null && user.avatar!.isNotEmpty
                  ? Text(user.avatar!)
                  : (user.profilePicture == null ||
                          !user.profilePicture!.startsWith('http')
                      ? Text(
                          user.initials,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null),
            ),
            const SizedBox(width: 12),

            // User info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  Text(
                    user.formattedHandle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  if (user.bio.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      user.bio,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(width: 12),
            if (widget.userId == followProvider.currentUserId)
              TextButton(
                onPressed: () =>
                    _confirmUnfollow(context, user, followProvider),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  side: BorderSide(
                    color: Theme.of(context)
                        .colorScheme
                        .outline
                        .withValues(alpha: 0.2),
                  ),
                ),
                child: const Text('Following'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmUnfollow(
    BuildContext context,
    User user,
    FollowProvider followProvider,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Unfollow ${user.fullName}?'),
        content: const Text('Their posts will no longer show up in your feed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Unfollow'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final success = await followProvider.unfollowUser(user.id);
      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unfollowed ${user.fullName}')),
        );
      }
    }
  }
}
