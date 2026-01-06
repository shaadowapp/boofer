import 'package:flutter/material.dart';
import '../models/connection_request_model.dart';
import '../models/user_model.dart';
import '../services/connection_service.dart';
import '../widgets/user_profile_card.dart';

class ConnectionRequestsScreen extends StatefulWidget {
  const ConnectionRequestsScreen({super.key});

  @override
  State<ConnectionRequestsScreen> createState() => _ConnectionRequestsScreenState();
}

class _ConnectionRequestsScreenState extends State<ConnectionRequestsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ConnectionService _connectionService = ConnectionService.instance;
  
  List<ConnectionRequest> _receivedRequests = [];
  List<ConnectionRequest> _sentRequests = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadRequests();
    
    // Listen to connection request updates
    _connectionService.connectionRequestsStream.listen((requests) {
      if (mounted) {
        setState(() {
          _receivedRequests = _connectionService.getPendingRequests();
          _sentRequests = _connectionService.getSentRequests();
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadRequests() {
    setState(() {
      _receivedRequests = _connectionService.getPendingRequests();
      _sentRequests = _connectionService.getSentRequests();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connection Requests'),
        elevation: 0,
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
    if (_receivedRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No connection requests',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'When people send you connection requests, they\'ll appear here',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _receivedRequests.length,
      itemBuilder: (context, index) {
        final request = _receivedRequests[index];
        return _buildReceivedRequestTile(request);
      },
    );
  }

  Widget _buildSentRequestsTab() {
    if (_sentRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.outbox_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No sent requests',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Connection requests you send will appear here',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _sentRequests.length,
      itemBuilder: (context, index) {
        final request = _sentRequests[index];
        return _buildSentRequestTile(request);
      },
    );
  }

  Widget _buildReceivedRequestTile(ConnectionRequest request) {
    return FutureBuilder<User?>(
      future: _connectionService.getUserById(request.fromUserId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }
        
        final user = snapshot.data!;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User profile card
              UserProfileCard(
                user: user,
                showOnlineStatus: true,
              ),
              
              // Message if present
              if (request.message.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    request.message,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
              
              const SizedBox(height: 12),
              
              // Time and actions
              Row(
                children: [
                  Text(
                    _formatTime(request.sentAt),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: () => _declineRequest(request),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Decline'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade600,
                      side: BorderSide(color: Colors.red.shade600),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => _acceptRequest(request),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Accept'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSentRequestTile(ConnectionRequest request) {
    return FutureBuilder<User?>(
      future: _connectionService.getUserById(request.toUserId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }
        
        final user = snapshot.data!;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User profile card
              UserProfileCard(
                user: user,
                showOnlineStatus: false,
              ),
              
              const SizedBox(height: 8),
              
              // Status and time
              Row(
                children: [
                  Icon(
                    _getStatusIcon(request.status),
                    size: 14,
                    color: _getStatusColor(request.status),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _getStatusText(request.status),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _getStatusColor(request.status),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatTime(request.sentAt),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  IconData _getStatusIcon(ConnectionRequestStatus status) {
    switch (status) {
      case ConnectionRequestStatus.pending:
        return Icons.schedule;
      case ConnectionRequestStatus.accepted:
        return Icons.check_circle;
      case ConnectionRequestStatus.declined:
        return Icons.cancel;
      case ConnectionRequestStatus.blocked:
        return Icons.block;
    }
  }

  Color _getStatusColor(ConnectionRequestStatus status) {
    switch (status) {
      case ConnectionRequestStatus.pending:
        return Colors.orange;
      case ConnectionRequestStatus.accepted:
        return Colors.green;
      case ConnectionRequestStatus.declined:
        return Colors.red;
      case ConnectionRequestStatus.blocked:
        return Colors.red.shade800;
    }
  }

  String _getStatusText(ConnectionRequestStatus status) {
    switch (status) {
      case ConnectionRequestStatus.pending:
        return 'Pending';
      case ConnectionRequestStatus.accepted:
        return 'Accepted';
      case ConnectionRequestStatus.declined:
        return 'Declined';
      case ConnectionRequestStatus.blocked:
        return 'Blocked';
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return 'now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${time.day}/${time.month}';
    }
  }

  Future<void> _acceptRequest(ConnectionRequest request) async {
    try {
      final success = await _connectionService.acceptConnectionRequest(request.id);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connection request accepted!'),
            backgroundColor: Colors.green,
          ),
        );
        _loadRequests();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _declineRequest(ConnectionRequest request) async {
    try {
      final success = await _connectionService.declineConnectionRequest(request.id);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connection request declined'),
            backgroundColor: Colors.orange,
          ),
        );
        _loadRequests();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}