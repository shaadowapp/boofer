import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import '../services/supabase_service.dart';
import '../services/chat_cache_service.dart';
import '../services/user_service.dart';
import '../models/user_model.dart';
import '../widgets/unified_friend_card.dart';
import '../providers/follow_provider.dart';
import 'user_profile_screen.dart';
import 'manage_friends_screen.dart';
import '../core/constants.dart';
import '../widgets/skeleton_user_card.dart';
import '../widgets/skeleton_grid_user_card.dart';
import '../utils/screenshot_mode.dart';
import '../widgets/smart_maintenance.dart';
import '../widgets/custom_search_bar.dart';
import '../widgets/grid_user_card.dart';

class DiscoverScreen extends StatefulWidget {
  final bool showAppBar;
  final bool showManageFriendsButton;
  final bool isGridView;
  final VoidCallback? onToggleGridView;

  const DiscoverScreen({
    super.key,
    this.showAppBar = true,
    this.showManageFriendsButton = false,
    this.isGridView = false,
    this.onToggleGridView,
  });

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen>
    with AutomaticKeepAliveClientMixin {
  bool _isLoading = true;
  List<User> _users = [];
  String? _currentUserId;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  // Helper method to convert map to User
  User _mapToUser(Map<String, dynamic> data) {
    // Prioritize profile_id because cached data from SQLite has an auto-increment integer 'id'
    final actualId =
        data['profile_id']?.toString() ?? data['id']?.toString() ?? '';
    return User(
      id: actualId,
      handle: data['handle'] ?? '',
      fullName: data['full_name'] ?? data['name'] ?? 'Unknown User',
      bio: data['bio'] ?? '',
      isDiscoverable: true,
      createdAt: DateTime.now(), // Placeholder
      updatedAt: DateTime.now(), // Placeholder
      profilePicture: data['profile_picture'],
      avatar: data['avatar'],
      virtualNumber: data['virtual_number']?.toString(),
      isVerified: data['is_verified'] == true || data['is_verified'] == 1,
      isCompany: data['is_company'] == true || data['is_company'] == 1,
      age: data['age'] as int?,
      followerCount: (data['follower_count'] as num?)?.toInt() ?? 0,
      followingCount: (data['following_count'] as num?)?.toInt() ?? 0,
    );
  }

  Future<void> _loadUsers({bool forceRefresh = false}) async {
    final currentUser = await UserService.getCurrentUser();

    if (ScreenshotMode.isEnabled) {
      if (mounted) {
        setState(() {
          _users = ScreenshotMode.dummyDiscoverUsers;
          _isLoading = false;
        });
      }
      return;
    }

    if (currentUser == null) {
      debugPrint('⚠️ DiscoverScreen: No current user found in UserService');
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    _currentUserId = currentUser.id;
    debugPrint('🔍 DiscoverScreen: Loading users for ID: $_currentUserId');

    // 1. Load from cache first (Instant UI)
    final cachedUsersData =
        await ChatCacheService.instance.getCachedDiscoverUsers(_currentUserId!);

    List<User> currentUsers = [];

    if (mounted && cachedUsersData.isNotEmpty) {
      currentUsers = cachedUsersData
          .where((data) {
            final id =
                data['profile_id']?.toString() ?? data['id']?.toString() ?? '';
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
        final userId = data['profile_id']?.toString() ?? data['id']?.toString();
        if (userId != null &&
            (data['isFollowing'] == true || data['is_following'] == 1)) {
          followProvider.setLocalFollowingStatus(userId.toString(), true);
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
      final isThrottled =
          await ChatCacheService.instance.isDiscoverRefreshThrottled();
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
      if (currentUsers.isEmpty && mounted) setState(() => _isLoading = true);

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
              userId.toString(),
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
      if (mounted) setState(() => _isLoading = false);
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
    super.build(context);
    final theme = Theme.of(context);

    // Filter users based on search
    final filteredUsers = _searchQuery.isEmpty
        ? _users
        : _users.where((user) {
            final query = _searchQuery.toLowerCase();
            return user.fullName.toLowerCase().contains(query) ||
                user.handle.toLowerCase().contains(query);
          }).toList();

    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Discover'),
                  const SizedBox(width: 12),
                  _buildSecondaryManageButton(theme),
                ],
              ),
              elevation: 0,
              backgroundColor: theme.colorScheme.surface,
              centerTitle: false,
            )
          : null,
      body: SmartMaintenance(
        featureName: 'Discover',
        check: (status) => status.isDiscoverActive,
        child: RefreshIndicator(
          onRefresh: () => _loadUsers(forceRefresh: true),
          child: Column(
            children: [
              // Only show search bar and manage button if used as a tab
              if (!widget.showAppBar) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: CustomSearchBar(
                    controller: _searchController,
                    hintText: 'Search people...',
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value.trim().toLowerCase();
                      });
                    },
                  ),
                ),
                if (widget.showManageFriendsButton)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Find Friends',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const ManageFriendsScreen(),
                              ),
                            );
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'Manage friends',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
              ],

              Expanded(
                child: _isLoading && filteredUsers.isEmpty
                    ? widget.isGridView
                        ? GridView.builder(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 0.70,
                            ),
                            itemCount: 8,
                            itemBuilder: (context, index) =>
                                const SkeletonGridUserCard(),
                          )
                        : ListView.builder(
                            itemCount: 8,
                            itemBuilder: (context, index) =>
                                const SkeletonUserCard(),
                          )
                    : filteredUsers.isEmpty
                        ? LayoutBuilder(
                            builder: (context, constraints) {
                              return SingleChildScrollView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minHeight: constraints.maxHeight,
                                  ),
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          _searchQuery.isEmpty
                                              ? Icons.person_search_outlined
                                              : Icons.search_off,
                                          size: 64,
                                          color: theme.colorScheme.outline,
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          _searchQuery.isEmpty
                                              ? 'No users found to follow'
                                              : 'No matches found',
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                            color: theme
                                                .colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        if (_searchQuery.isEmpty)
                                          TextButton(
                                            onPressed: () =>
                                                _loadUsers(forceRefresh: true),
                                            child: const Text('Tap to Retry'),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          )
                        : widget.isGridView
                            ? GridView.builder(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio:
                                      0.70, // Slightly taller to fit bio nicely
                                ),
                                itemCount: filteredUsers.length,
                                itemBuilder: (context, index) {
                                  final user = filteredUsers[index];
                                  return GridUserCard(
                                    user: user,
                                    onTap: () => _navigateToUserProfile(user),
                                  );
                                },
                              )
                            : ListView.builder(
                                itemCount: filteredUsers.length,
                                itemBuilder: (context, index) {
                                  final user = filteredUsers[index];
                                  return UnifiedFriendCard(
                                    user: user,
                                    showOnlineStatus: false,
                                    onTap: () => _navigateToUserProfile(user),
                                  );
                                },
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryManageButton(ThemeData theme) {
    return InkWell(
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
          color: theme.colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.2),
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
    );
  }
}
