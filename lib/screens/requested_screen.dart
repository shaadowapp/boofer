import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/friend_request_provider.dart';
import '../models/friend_request_model.dart';
import '../services/user_service.dart';
import '../models/user_model.dart';

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
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        title: const Text('Requested'),
        centerTitle: true,
      ),
      body: Consumer<FriendRequestProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.sentRequests.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          final sentRequests = provider.sentRequests;

          if (sentRequests.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.person_add_outlined,
                    size: 64,
                    color: theme.colorScheme.onSurface.withOpacity(0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Pending Requests',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Friend requests you send will appear here',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _loadSentRequests,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: sentRequests.length,
              itemBuilder: (context, index) {
                final request = sentRequests[index];
                return _buildRequestedItem(context, request, provider);
              },
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

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: CircleAvatar(
          radius: 28,
          backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
          child: isLoadingUser
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : user?.profilePicture != null
                  ? ClipOval(
                      child: Image.network(
                        user!.profilePicture!,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.person,
                            size: 28,
                            color: theme.colorScheme.primary,
                          );
                        },
                      ),
                    )
                  : Icon(
                      Icons.person,
                      size: 28,
                      color: theme.colorScheme.primary,
                    ),
        ),
        title: Text(
          user?.fullName ?? 'Loading...',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (user?.handle != null)
              Text(
                '@${user!.handle}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            const SizedBox(height: 4),
            Text(
              'Sent ${_formatTimestamp(request.sentAt)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: TextButton(
          onPressed: () => _showCancelConfirmation(context, request, provider),
          style: TextButton.styleFrom(
            foregroundColor: Colors.red,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          child: const Text('Cancel'),
        ),
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
              backgroundColor: Colors.red,
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
