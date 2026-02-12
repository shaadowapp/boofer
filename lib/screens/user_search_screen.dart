import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';
import '../services/supabase_service.dart';
import '../providers/friend_request_provider.dart';
import '../widgets/unified_friend_card.dart';
import 'friend_requests_screen.dart';

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
  final Map<String, bool> _followingStatus = {};
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
      print(
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

      // Get discoverable users from Supabase
      final discoverableUsers = await supabaseService.searchUsers('');

      // Filter out current user by both ID and handle
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

      print('✅ Loaded ${filteredUsers.length} real users from Supabase');
    } catch (e) {
      print('❌ Error loading users from Supabase: $e');

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
      final results = await supabaseService.searchUsers(query);

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover'),
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        actions: [
          // Friend Requests button with badge
          Consumer<FriendRequestProvider>(
            builder: (context, provider, child) {
              final receivedCount = provider.receivedRequests.length;

              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.person_add_outlined),
                    tooltip: 'Requests',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const FriendRequestsScreen(),
                        ),
                      );
                    },
                  ),
                  if (receivedCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.error,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          receivedCount > 9 ? '9+' : receivedCount.toString(),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onError,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                ),
              ),
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name, username, or virtual number...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchResults = [];
                            _hasSearched = false;
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withOpacity(0.3),
              ),
            ),
          ),

          // Content
          Expanded(child: _buildContent()),
        ],
      ),
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
