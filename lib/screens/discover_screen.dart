import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/supabase_service.dart';
import '../services/chat_cache_service.dart';
import '../services/user_service.dart';
import '../models/user_model.dart'; // Import User model
import '../widgets/unified_friend_card.dart'; // Import UnifiedFriendCard
import '../providers/follow_provider.dart';
import 'user_profile_screen.dart'; // Import UserProfileScreen
import 'manage_friends_screen.dart';
import '../core/constants.dart';
import '../widgets/skeleton_user_card.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  bool _isLoading = true;
  List<User> _users = []; // Use User objects for UI
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  // Helper method to convert map to User
  User _mapToUser(Map<String, dynamic> data) {
    return User(
      id: data['id'] ?? data['profile_id'] ?? '',
      email: data['email'] ?? '',
      handle: data['handle'] ?? '',
      fullName: data['full_name'] ?? data['name'] ?? 'Unknown User',
      bio: data['bio'] ?? '',
      isDiscoverable: true,
      createdAt: DateTime.now(), // Placeholder
      updatedAt: DateTime.now(), // Placeholder
      profilePicture: data['profile_picture'],
      avatar: data['avatar'],
      virtualNumber: data['virtual_number'],
      isVerified: data['is_verified'] == true || data['is_verified'] == 1,
      isCompany: data['is_company'] == true || data['is_company'] == 1,
      age: data['age'] as int?,
      followerCount: (data['follower_count'] as num?)?.toInt() ?? 0,
      followingCount: (data['following_count'] as num?)?.toInt() ?? 0,
    );
  }

  Future<void> _loadUsers({bool forceRefresh = false}) async {
    final currentUser = await UserService.getCurrentUser();
    if (currentUser == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    _currentUserId = currentUser.id;

    // 1. Load from cache first (Instant UI)
    final cachedUsersData = await ChatCacheService.instance
        .getCachedDiscoverUsers(_currentUserId!);

    List<User> currentUsers = [];

    if (mounted && cachedUsersData.isNotEmpty) {
      currentUsers = cachedUsersData
          .where((data) {
            final id = data['id']?.toString() ?? '';
            final handle = (data['handle'] ?? '').toString().toLowerCase();
            return !AppConstants.officialIds.contains(id) && handle != 'boofer';
          })
          .map((data) => _mapToUser(data))
          .toList();

      // Update local state and FollowProvider with cached data
      final followProvider = Provider.of<FollowProvider>(
        context,
        listen: false,
      );
      for (var data in cachedUsersData) {
        final userId = data['id'] ?? data['profile_id'];
        if (userId != null &&
            (data['isFollowing'] == true || data['is_following'] == 1)) {
          followProvider.setLocalFollowingStatus(userId, true);
        }
      }

      setState(() {
        _users = currentUsers;
        // If we have cached data, we can stop showing the main loader immediately
        _isLoading = false;
      });
      debugPrint('✅ Loaded ${currentUsers.length} users from cache');
    }

    // 2. Handle Throttling for manual refreshes
    if (forceRefresh) {
      final isThrottled = await ChatCacheService.instance
          .isDiscoverRefreshThrottled();
      if (isThrottled) {
        debugPrint('⏳ Discover refresh throttled. Using cache.');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please wait a moment before refreshing again'),
              duration: Duration(seconds: 1),
            ),
          );
        }
        return;
      }
    }

    // 3. Network Fetch Check
    // We fetch if:
    // - User explicitly requested refresh (forceRefresh = true)
    // - Cache is empty
    // - Cache is stale (validity check)
    final isCacheValid = await ChatCacheService.instance.isDiscoverCacheValid();

    if (!forceRefresh && isCacheValid && currentUsers.isNotEmpty) {
      debugPrint(
        '✅ Discover cache is fresh and populated. Skipping background fetch.',
      );
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    // 4. Fetch from network
    try {
      if (currentUsers.isEmpty && mounted) {
        setState(() => _isLoading = true);
      }

      debugPrint(
        '🔍 DiscoverScreen: Fetching network users (Force: $forceRefresh)',
      );
      final freshUsersData = await SupabaseService.instance.getDiscoverUsers(
        _currentUserId!,
      );

      if (mounted) {
        final freshUsers = freshUsersData
            .where((data) {
              final id = data['id']?.toString() ?? '';
              final handle = (data['handle'] ?? '').toString().toLowerCase();
              return !AppConstants.officialIds.contains(id) &&
                  handle != 'boofer';
            })
            .map((data) => _mapToUser(data))
            .toList();

        // Update FollowProvider
        final followProvider = Provider.of<FollowProvider>(
          context,
          listen: false,
        );
        for (var data in freshUsersData) {
          final userId = data['id'];
          if (userId != null) {
            followProvider.setLocalFollowingStatus(
              userId,
              data['isFollowing'] == true,
            );
          }
        }

        // Merge logic
        final Map<String, User> userMap = {
          for (var user in currentUsers) user.id: user,
        };
        for (var user in freshUsers) {
          userMap[user.id] = user;
        }

        setState(() {
          _users = userMap.values.toList();
          _isLoading = false;
        });

        // Update cache
        await ChatCacheService.instance.cacheDiscoverUsers(
          _currentUserId!,
          freshUsersData,
        );
      }
    } catch (e) {
      debugPrint('❌ Error loading discover users: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _navigateToUserProfile(User user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserProfileScreen(userId: user.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Discover'),
            const SizedBox(width: 12),
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ManageFriendsScreen(),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: theme.colorScheme.primary.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Manage',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        centerTitle: false,
      ),
      body: _isLoading && _users.isEmpty
          ? ListView.builder(
              itemCount: 8,
              itemBuilder: (context, index) => const SkeletonUserCard(),
            )
          : _users.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.person_search_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No users found to follow',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: () => _loadUsers(forceRefresh: true),
              child: ListView.builder(
                itemCount: _users.length,
                itemBuilder: (context, index) {
                  final user = _users[index];
                  return UnifiedFriendCard(
                    user: user,
                    showOnlineStatus:
                        false, // Not relevant for discover usually
                    onTap: () => _navigateToUserProfile(user),
                    // key: ValueKey(user.id), // Optional optimization
                  );
                },
              ),
            ),
    );
  }
}
