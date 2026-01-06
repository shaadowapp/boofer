import 'dart:async';
import 'package:flutter/material.dart';
import '../models/connection_request_model.dart';
import '../models/user_model.dart';
import '../services/friendship_service.dart';
import '../services/user_service.dart';
import '../widgets/user_profile_card.dart';

class FriendRequestsScreen extends StatefulWidget {
  const FriendRequestsScreen({super.key});

  @override
  State<FriendRequestsScreen> createState() => _FriendRequestsScreenState();
}

class _FriendRequestsScreenState extends State<FriendRequestsScreen>
    with SingleTickerProviderStateMixin {
  final FriendshipService _friendshipService = FriendshipService.instance;
  late TabController _tabController;
  
  List<ConnectionRequest> _receivedRequests = [];
  List<ConnectionRequest> _sentRequests = [];
  bool _loading = true;
  String? _currentUserId;
  late StreamSubscription<List<ConnectionRequest>> _requestsSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadRequests();
    
    // Listen to request updates
    _requestsSubscription = _friendshipService.requestsStream.listen((requests) {
      if (mounted) {
        setState(() {
          _receivedRequests = requests;
          _loading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _requestsSubscription.cancel();
    super.dispose();
  }

  Future<void> _loadRequests() async {
    final currentUser = await UserService.getCurrentUser();
    if (currentUser == null) return;

    setState(() {
      _currentUserId = currentUser.id;
      _loading = true;
    });

    // Load both received and sent requests
    final receivedFuture = _friendshipService.getPendingRequests(currentUser.id);
    final sentFuture = _friendshipService.getSentRequests(currentUser.id);

    final results = await Future.wait([receivedFuture, sentFuture]);
    
    if (mounted) {
      setState(() {
        _receivedRequests = results[0];
        _sentRequests = results[1];
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Friend Requests'),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loadRequests,
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              text: 'Received (${_receivedRequests.length})',
              icon: const Icon(Icons.inbox),
            ),
            Tab(
              text: 'Sent (${_sentRequests.length})',
              icon: const Icon(Icons.outbox),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildReceivedRequestsTab(),
          _buildSentRequestsTab(),
        ],
      ),
    );
  }

  Widget _buildReceivedRequestsTab() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_receivedRequests.isEmpty) {
      return _buildEmptyState(
        icon: Icons.inbox_outlined,
        title: 'No friend requests',
        subtitle: 'You don\'t have any pending friend requests',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRequests,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _receivedRequests.length,
        itemBuilder: (context, index) {
          final request = _receivedRequests[index];
          return _buildReceivedRequestTile(request);
        },
      ),
    );
  }

  Widget _buildSentRequestsTab() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_sentRequests.isEmpty) {
      return _buildEmptyState(
        icon: Icons.outbox_outlined,
        title: 'No sent requests',
        subtitle: 'You haven\'t sent any friend requests yet',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRequests,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _sentRequests.length,
        itemBuilder: (context, index) {
          final request = _sentRequests[index];
          return _buildSentRequestTile(request);
        },
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildReceivedRequestTile(ConnectionRequest request) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: Text(
                  request.fromUserId.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.fromUserId, // You might want to resolve this to a display name
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      _formatDateTime(request.sentAt),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (request.message.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                request.message,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _declineRequest(request),
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Decline'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade600,
                    side: BorderSide(color: Colors.red.shade600),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _acceptRequest(request),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Accept'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSentRequestTile(ConnectionRequest request) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: Text(
                  request.toUserId.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.toUserId, // You might want to resolve this to a display name
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Sent ${_formatDateTime(request.sentAt)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.schedule,
                      size: 14,
                      color: Colors.orange.shade700,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Pending',
                      style: TextStyle(
                        color: Colors.orange.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (request.message.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                request.message,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  Future<void> _acceptRequest(ConnectionRequest request) async {
    final success = await _friendshipService.acceptFriendRequest(request.id);
    
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Friend request accepted!'),
            backgroundColor: Colors.green,
          ),
        );
        _loadRequests(); // Refresh the list
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to accept friend request'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _declineRequest(ConnectionRequest request) async {
    final success = await _friendshipService.declineFriendRequest(request.id);
    
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Friend request declined'),
            backgroundColor: Colors.orange,
          ),
        );
        _loadRequests(); // Refresh the list
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to decline friend request'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}