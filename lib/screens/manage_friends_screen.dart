import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../services/follow_service.dart';
import '../services/user_service.dart';
import '../widgets/unified_friend_card.dart';
import '../providers/follow_provider.dart';

class ManageFriendsScreen extends StatefulWidget {
  const ManageFriendsScreen({super.key});

  @override
  State<ManageFriendsScreen> createState() => _ManageFriendsScreenState();
}

class _ManageFriendsScreenState extends State<ManageFriendsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FollowService _followService = FollowService.instance;

  List<User> _followers = [];
  List<User> _following = [];
  bool _isLoading = true;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final currentUser = await UserService.getCurrentUser();
      if (currentUser == null) return;

      _currentUserId = currentUser.id;

      // Load followers and following in parallel
      final results = await Future.wait([
        _followService.getFollowers(userId: _currentUserId!),
        _followService.getFollowing(userId: _currentUserId!),
      ]);

      if (mounted) {
        setState(() {
          _followers = results[0];
          _following = results[1];
          _isLoading = false;
        });

        // Seed the FollowProvider with initial follow status
        if (_following.isNotEmpty) {
          final followProvider = context.read<FollowProvider>();
          for (var user in _following) {
            followProvider.setLocalFollowingStatus(user.id, true);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading friends: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Friends'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Followers (${_followers.length})'),
            Tab(text: 'Following (${_following.length})'),
          ],
          indicatorColor: theme.colorScheme.primary,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.colorScheme.onSurface.withOpacity(0.6),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildUserList(_followers, 'No followers yet'),
                _buildUserList(_following, 'You are not following anyone yet'),
              ],
            ),
    );
  }

  Widget _buildUserList(List<User> users, String emptyMessage) {
    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: Colors.grey.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        return UnifiedFriendCard(
          user: user,
          onStatusChanged: _loadData, // Reload when follow status changes
        );
      },
    );
  }
}
