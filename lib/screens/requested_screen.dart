import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/friend_request_provider.dart';
import '../models/friend_request_model.dart';
import '../services/user_service.dart';
import '../models/user_model.dart';
import '../widgets/unified_friend_card.dart';

/// Screen showing sent friend requests (renamed from "Sent" to "Requested")
class RequestedScreen extends StatefulWidget {
  const RequestedScreen({super.key});

  @override
  State<RequestedScreen> createState() => _RequestedScreenState();
}

class _RequestedScreenState extends State<RequestedScreen> {
  final Map<String, User?> _userCache = {};
  bool _isLoadingUsers = false;

  @override
  void initState() {
    super.initState();
    _loadSentRequests();
  }

  Future<void> _loadSentRequests() async {
    final provider = context.read<FriendRequestProvider>();
    await provider.loadSentRequests(refresh: true);
    _loadUserDetails();
  }

  Future<void> _loadUserDetails() async {
    if (_isLoadingUsers) return;

    setState(() => _isLoadingUsers = true);

    final provider = context.read<FriendRequestProvider>();
    final requests = provider.sentRequests;

    for (final request in requests) {
      if (!_userCache.containsKey(request.toUserId)) {
        try {
          final user = await UserService.instance.getUser(request.toUserId);
          if (mounted) {
            setState(() => _userCache[request.toUserId] = user);
          }
        } catch (e) {
          print('Error loading user ${request.toUserId}: $e');
          if (mounted) {
            setState(() => _userCache[request.toUserId] = null);
          }
        }
      }
    }

    if (mounted) {
      setState(() => _isLoadingUsers = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Consumer<FriendRequestProvider>(
        builder: (context, provider, child) {
          final sentRequests = provider.sentRequests;

          if (provider.isLoading && sentRequests.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          return RefreshIndicator(
            onRefresh: _loadSentRequests,
            edgeOffset: 100, // Adjust for large app bar
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverAppBar.large(
                  title: const Text('Requested'),
                  centerTitle: true,
                  backgroundColor: theme.colorScheme.surface,
                  scrolledUnderElevation: 0,
                ),
                if (sentRequests.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.person_add_disabled_outlined,
                            size: 64,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.3,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No Pending Requests',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Friend requests you send will appear here',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final request = sentRequests[index];
                        return _buildRequestedItem(context, request, provider);
                      }, childCount: sentRequests.length),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRequestedItem(
    BuildContext context,
    FriendRequest request,
    FriendRequestProvider provider,
  ) {
    final theme = Theme.of(context);
    final user = _userCache[request.toUserId];
    final isLoadingUser = !_userCache.containsKey(request.toUserId);

    if (isLoadingUser || user == null) {
      return Card(
        margin: const EdgeInsets.only(bottom: 16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        children: [
          UnifiedFriendCard(
            user: user,
            onStatusChanged: () {
              provider.loadSentRequests(refresh: true);
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Icon(
                  Icons.access_time_rounded,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  'Sent ${_formatTimestamp(request.sentAt)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () =>
                      _showCancelConfirmation(context, request, provider),
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: const Text('Cancel'),
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                    backgroundColor: theme.colorScheme.errorContainer
                        .withValues(alpha: 0.2),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCancelConfirmation(
    BuildContext context,
    FriendRequest request,
    FriendRequestProvider provider,
  ) {
    final user = _userCache[request.toUserId];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Request'),
        content: Text(
          'Are you sure you want to cancel your friend request to ${user?.fullName ?? 'this user'}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              final success = await provider.cancelFriendRequest(request.id);

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'Friend request cancelled'
                          : 'Failed to cancel request',
                    ),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }
}
