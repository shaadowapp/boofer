import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/friend_request_provider.dart';
import '../providers/firestore_user_provider.dart';
import '../models/friend_request_model.dart';
import '../models/user_model.dart';
import '../widgets/unified_friend_card.dart';

/// Screen showing friend requests (like Instagram/Snapchat)
class FriendRequestsScreen extends StatefulWidget {
  const FriendRequestsScreen({super.key});

  @override
  State<FriendRequestsScreen> createState() => _FriendRequestsScreenState();
}

class _FriendRequestsScreenState extends State<FriendRequestsScreen> {
  final Map<String, User?> _userCache = {};

  @override
  void initState() {
    super.initState();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<FriendRequestProvider>();
      provider.loadReceivedRequests(refresh: true);
    });
  }

  /// Get user by ID with caching to prevent UI freezing
  Future<User?> _getUserById(String userId) async {
    // Check cache first
    if (_userCache.containsKey(userId)) {
      return _userCache[userId];
    }

    try {
      final userProvider = context.read<FirestoreUserProvider>();
      final user = await userProvider.getUserById(userId);
      _userCache[userId] = user;
      return user;
    } catch (e) {
      print('❌ Error getting user $userId: $e');
      _userCache[userId] = null;
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Requests'),
        elevation: 0,
      ),
      body: _buildReceivedRequestsTab(),
    );
  }

  Widget _buildReceivedRequestsTab() {
    return Consumer<FriendRequestProvider>(
      builder: (context, provider, child) {
        final requests = provider.receivedRequests;
        final isLoading = provider.isLoading;
        final error = provider.error;

        if (isLoading && requests.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (error != null && requests.isEmpty) {
          return _buildErrorState(error, () {
            provider.loadReceivedRequests(refresh: true);
          });
        }

        if (requests.isEmpty) {
          return _buildEmptyState(
            icon: Icons.inbox_outlined,
            title: 'No requests',
            subtitle: 'When people send you friend requests, they\'ll appear here',
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            await provider.loadReceivedRequests(refresh: true);
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];
              return _buildReceivedRequestItem(context, request, provider);
            },
          ),
        );
      },
    );
  }

  Widget _buildReceivedRequestItem(
    BuildContext context,
    FriendRequest request,
    FriendRequestProvider provider,
  ) {
    return FutureBuilder<User?>(
      future: _getUserById(request.fromUserId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final user = snapshot.data!;
        return Column(
          children: [
            UnifiedFriendCard(
              user: user,
              onStatusChanged: () {
                provider.loadReceivedRequests(refresh: true);
              },
            ),
            if (request.message != null && request.message!.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.message_outlined,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        request.message!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final success = await provider.acceptFriendRequest(request.id);
                        if (success && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('You are now friends with ${user.displayName}'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      ),
                      child: const Text('Accept'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final success = await provider.rejectFriendRequest(request.id);
                        if (success && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Friend request rejected'),
                            ),
                          );
                        }
                      },
                      child: const Text('Reject'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildErrorState(String error, VoidCallback onRetry) {
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
            'Something went wrong',
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
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Consumer<FriendRequestProvider>(
      builder: (context, provider, child) {
        return RefreshIndicator(
          onRefresh: () async {
            await provider.loadReceivedRequests(refresh: true);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: MediaQuery.of(context).size.height - 200,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: 64,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${(difference.inDays / 7).floor()}w ago';
    }
  }
}