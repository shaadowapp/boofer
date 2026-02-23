import 'dart:async';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';
import '../services/supabase_service.dart';
import '../widgets/unified_friend_card.dart';
import '../providers/follow_provider.dart';
import 'manage_friends_screen.dart';
import 'package:provider/provider.dart';

class UserSearchScreen extends StatefulWidget {
  const UserSearchScreen({super.key});

  @override
  State<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends State<UserSearchScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<User> _searchResults = [];
  List<User> _suggestedUsers = [];
  List<User> _trendingUsers = [];
  List<User> _recentSearches = [];

  bool _loading = false;
  bool _hasSearched = false;
  String? _currentUserId;
  String? _currentUserHandle;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _loadExploreUsers();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    final currentUser = await UserService.getCurrentUser();
    if (currentUser != null) {
      setState(() {
        _currentUserId = currentUser.id;
        _currentUserHandle = currentUser.handle;
      });
      debugPrint(
        '✅ Current user loaded: ${currentUser.handle} (ID: ${currentUser.id})',
      );
    }
  }

  Future<void> _loadExploreUsers() async {
    setState(() {
      _loading = true;
    });

    try {
      final supabaseService = SupabaseService.instance;
      // 1. Get raw search results (with isFollowing status)
      final rawResults = await supabaseService.searchUsers('');

      // 2. Seed FollowProvider with follow status
      if (mounted) {
        final followProvider = context.read<FollowProvider>();
        for (var data in rawResults) {
          final userId = data['id'];
          final isFollowing = data['isFollowing'] == true;
          if (userId != null) {
            followProvider.setLocalFollowingStatus(userId, isFollowing);
          }
        }
      }

      // 3. Convert to User objects and filter
      final discoverableUsers = rawResults
          .map((e) => User.fromJson(e))
          .toList();

      final filteredUsers = discoverableUsers.where((user) {
        final isDifferentId = user.id != _currentUserId;
        final isDifferentHandle = user.handle != _currentUserHandle;
        return isDifferentId && isDifferentHandle;
      }).toList();

      // Shuffle and split into suggested and trending
      filteredUsers.shuffle();

      final halfPoint = (filteredUsers.length / 2).ceil();

      setState(() {
        _suggestedUsers = filteredUsers.take(halfPoint).toList();
        _trendingUsers = filteredUsers.skip(halfPoint).toList();
        _recentSearches = [];
        _loading = false;
      });

      debugPrint(
        '✅ Loaded ${filteredUsers.length} real users from Supabase and synced follow status',
      );
    } catch (e) {
      debugPrint('❌ Error loading users from Supabase: $e');

      setState(() {
        _suggestedUsers = [];
        _trendingUsers = [];
        _recentSearches = [];
        _loading = false;
      });
    }
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (_searchController.text.trim().isNotEmpty) {
        _performSearch(_searchController.text.trim());
      } else {
        setState(() {
          _searchResults = [];
          _hasSearched = false;
        });
      }
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.length < 2) return;

    setState(() {
      _loading = true;
      _hasSearched = true;
    });

    try {
      final supabaseService = SupabaseService.instance;
      final rawResults = await supabaseService.searchUsers(query);

      // Seed FollowProvider
      if (mounted) {
        final followProvider = context.read<FollowProvider>();
        for (var data in rawResults) {
          final userId = data['id'];
          final isFollowing = data['isFollowing'] == true;
          if (userId != null) {
            followProvider.setLocalFollowingStatus(userId, isFollowing);
          }
        }
      }

      final results = rawResults.map((e) => User.fromJson(e)).toList();

      // Filter out current user by both ID and handle
      final filteredResults = results.where((user) {
        final isDifferentId = user.id != _currentUserId;
        final isDifferentHandle = user.handle != _currentUserHandle;
        return isDifferentId && isDifferentHandle;
      }).toList();

      if (mounted) {
        setState(() {
          _searchResults = filteredResults;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _loading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Search failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover'),
        elevation: 0,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ManageFriendsScreen()),
            ),
            icon: const Icon(Icons.people_outline_rounded, size: 18),
            label: const Text('Manage'),
            style: TextButton.styleFrom(
              foregroundColor:
                  theme.appBarTheme.foregroundColor ??
                  theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: SizedBox(
              height: 38,
              child: TextField(
                controller: _searchController,
                autofocus: false,
                textAlignVertical: TextAlignVertical.center,
                decoration: InputDecoration(
                  hintText: 'Search people...',
                  hintStyle: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.50),
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.50),
                    size: 20,
                  ),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 38,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            setState(() {
                              _searchResults = [];
                              _hasSearched = false;
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: Icon(
                              Icons.close_rounded,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.55,
                              ),
                              size: 18,
                            ),
                          ),
                        )
                      : null,
                  suffixIconConstraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  filled: true,
                  fillColor: theme.brightness == Brightness.dark
                      ? Colors.white.withValues(alpha: 0.09)
                      : Colors.black.withValues(alpha: 0.07),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(9),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(9),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(9),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                ),
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
      ),
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_hasSearched && _searchResults.isEmpty) {
      return _buildEmptySearchResults();
    }

    if (_hasSearched && _searchResults.isNotEmpty) {
      return _buildSearchResults();
    }

    return _buildAllUsersContent();
  }

  Widget _buildAllUsersContent() {
    // Show all users when not searching
    final allUsers = [..._suggestedUsers, ..._trendingUsers];

    if (allUsers.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadExploreUsers,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height - 200,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 64,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No users found',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Check back later for new users',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadExploreUsers,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: allUsers.length,
        itemBuilder: (context, index) {
          final user = allUsers[index];
          return UnifiedFriendCard(
            user: user,
            onStatusChanged: () {
              setState(() {});
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptySearchResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No users found',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Try searching with a different term',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        return UnifiedFriendCard(
          user: user,
          onStatusChanged: () {
            // Refresh the list if needed
            setState(() {});
          },
        );
      },
    );
  }
}
