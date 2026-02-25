import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../services/follow_service.dart';
import '../services/user_service.dart';
import '../widgets/unified_friend_card.dart';
import '../providers/follow_provider.dart';
import '../core/constants.dart';

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
          // Hide boofer and all official accounts from follower/following lists
          _followers = results[0]
              .where(
                (u) =>
                    !AppConstants.officialIds.contains(u.id) &&
                    u.handle.toLowerCase() != 'boofer',
              )
              .toList();
          _following = results[1]
              .where(
                (u) =>
                    !AppConstants.officialIds.contains(u.id) &&
                    u.handle.toLowerCase() != 'boofer',
              )
              .toList();
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
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Followers (${_followers.length})'),
            Tab(text: 'Following (${_following.length})'),
          ],
          indicatorColor:
              theme.appBarTheme.foregroundColor ?? theme.colorScheme.primary,
          indicatorWeight: 2.5,
          labelColor:
              theme.appBarTheme.foregroundColor ?? theme.colorScheme.primary,
          unselectedLabelColor:
              (theme.appBarTheme.foregroundColor ?? theme.colorScheme.onSurface)
                  .withValues(alpha: 0.55),
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w400,
            fontSize: 14,
          ),
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
              Icons.people_outline_rounded,
              size: 64,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.55),
              ),
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
