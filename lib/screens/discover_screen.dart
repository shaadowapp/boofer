import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/supabase_service.dart';
import '../services/chat_cache_service.dart';
import '../services/user_service.dart';
import '../models/user_model.dart'; // Import User model
import '../widgets/unified_friend_card.dart'; // Import UnifiedFriendCard
import '../providers/follow_provider.dart';
import 'user_profile_screen.dart'; // Import UserProfileScreen

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
    );
  }

  Future<void> _loadUsers({bool forceRefresh = false}) async {
    final currentUser = await UserService.getCurrentUser();
    if (currentUser == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    _currentUserId = currentUser.id;

    // 1. Load from cache first
    final cachedUsersData = await ChatCacheService.instance
        .getCachedDiscoverUsers(_currentUserId!);

    List<User> currentUsers = [];

    if (mounted && cachedUsersData.isNotEmpty) {
      // Convert cached maps to User objects
      currentUsers = cachedUsersData.map((data) => _mapToUser(data)).toList();

      // Seed FollowProvider with cached status
      final followProvider = Provider.of<FollowProvider>(
        context,
        listen: false,
      );
      for (var data in cachedUsersData) {
        if (data['isFollowing'] == true || data['is_following'] == 1) {
          final userId = data['id'] ?? data['profile_id'];
          if (userId != null) {
            followProvider.setLocalFollowingStatus(userId, true);
          }
        }
      }

      setState(() {
        _users = currentUsers;
        if (!forceRefresh) _isLoading = false;
      });
    }

    // 2. Check cache validity
    final isCacheValid = await ChatCacheService.instance.isDiscoverCacheValid();

    // If cache is valid, we have data, and not forcing refresh, we are done.
    if (!forceRefresh && isCacheValid && cachedUsersData.isNotEmpty) {
      debugPrint(
        '✅ Discover cache is valid and populated. Skipping network fetch.',
      );
      return;
    }

    // 3. Fetch fresh from network if needed
    try {
      debugPrint(
        '🔍 DiscoverScreen: Fetching network users for $_currentUserId (Force: $forceRefresh)',
      );

      final freshUsersData = await SupabaseService.instance.getDiscoverUsers(
        _currentUserId!,
      );

      debugPrint(
        '🔍 DiscoverScreen: Network returned ${freshUsersData.length} users',
      );

      if (mounted) {
        // Convert fresh maps to User objects
        final freshUsers = freshUsersData
            .map((data) => _mapToUser(data))
            .toList();

        // Update FollowProvider with fresh status
        final followProvider = Provider.of<FollowProvider>(
          context,
          listen: false,
        );
        for (var data in freshUsersData) {
          final userId = data['id'];
          final isFollowing = data['isFollowing'] == true;
          if (userId != null) {
            followProvider.setLocalFollowingStatus(userId, isFollowing);
          }
        }

        // MERGE LOGIC: Add fresh treasures to the bag
        // Create a map by ID for deduplication
        final Map<String, User> userMap = {
          for (var user in currentUsers) user.id: user,
        };

        // Upsert fresh users
        for (var user in freshUsers) {
          userMap[user.id] = user;
        }

        final mergedUsers = userMap.values.toList();

        // Optional: Sort (e.g., by name or newly added)
        // mergedUsers.sort((a, b) => a.fullName.compareTo(b.fullName));

        setState(() {
          _users = mergedUsers;
          _isLoading = false;
        });

        // 4. Update cache (Service handles upsert/merge)
        await ChatCacheService.instance.cacheDiscoverUsers(
          _currentUserId!,
          freshUsersData,
        );
      }
    } catch (e) {
      debugPrint('Error loading discover users: $e');
      if (mounted && _users.isEmpty) {
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover People'),
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      body: _isLoading && _users.isEmpty
          ? const Center(child: CircularProgressIndicator())
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
