import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/follow_provider.dart';
import '../models/user_model.dart';

/// Screen showing followers list
class FollowersScreen extends StatefulWidget {
  final String userId;
  final String? userName;

  const FollowersScreen({super.key, required this.userId, this.userName});

  @override
  State<FollowersScreen> createState() => _FollowersScreenState();
}

class _FollowersScreenState extends State<FollowersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FollowProvider>().loadFollowers(widget.userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.userName != null
              ? '${widget.userName}\'s Followers'
              : 'Followers',
        ),
        elevation: 0,
      ),
      body: Consumer<FollowProvider>(
        builder: (context, followProvider, child) {
          final followers = followProvider.getFollowers(widget.userId);
          final isLoading = followProvider.isLoading;
          final error = followProvider.error;

          if (isLoading && followers.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (error != null && followers.isEmpty) {
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
                    'Failed to load followers',
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
                      followProvider.loadFollowers(
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

          if (followers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No followers yet',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'When people follow this user, they\'ll appear here',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              await followProvider.loadFollowers(widget.userId, refresh: true);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: followers.length,
              itemBuilder: (context, index) {
                final user = followers[index];
                return _buildFollowerItem(context, user, followProvider);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildFollowerItem(
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
                    _confirmRemoveFollower(context, user, followProvider),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: const Text('Remove'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmRemoveFollower(
    BuildContext context,
    User user,
    FollowProvider followProvider,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Follower?'),
        content: Text(
          'Boofer will stop ${user.fullName} from following you. They won\'t be notified.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final success = await followProvider.removeFollower(user.id);
      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Removed ${user.fullName} from followers')),
        );
      }
    }
  }
}
