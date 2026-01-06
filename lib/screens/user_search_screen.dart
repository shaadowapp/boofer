import 'dart:async';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/friendship_service.dart';
import '../services/user_service.dart';
import '../widgets/contextual_user_profile_card.dart';
import 'friend_chat_screen.dart';
import 'friend_requests_screen.dart';

class UserSearchScreen extends StatefulWidget {
  const UserSearchScreen({super.key});

  @override
  State<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends State<UserSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FriendshipService _friendshipService = FriendshipService.instance;
  
  List<User> _searchResults = [];
  List<User> _recentSearches = [];
  bool _loading = false;
  bool _hasSearched = false;
  String? _currentUserId;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _loadRecentSearches();
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
      });
    }
  }

  Future<void> _loadRecentSearches() async {
    // In a real app, this would load from local storage
    // For now, we'll use mock data
    setState(() {
      _recentSearches = [];
    });
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
      // In a real app, this would search through a user database
      // For now, we'll create mock search results
      await Future.delayed(const Duration(milliseconds: 500));
      
      final mockResults = _generateMockSearchResults(query);
      
      if (mounted) {
        setState(() {
          _searchResults = mockResults;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
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

  List<User> _generateMockSearchResults(String query) {
    // Generate mock users based on search query
    final results = <User>[];
    final queryLower = query.toLowerCase();
    
    // Create some mock users that match the search
    for (int i = 1; i <= 5; i++) {
      final handle = '${queryLower}_user$i';
      final user = User(
        id: 'user_${handle}_${DateTime.now().millisecondsSinceEpoch + i}',
        virtualNumber: 'VN${1000 + i}',
        handle: handle,
        fullName: '${queryLower.substring(0, 1).toUpperCase()}${queryLower.substring(1)} User $i',
        bio: 'Hello, I\'m ${queryLower} user $i',
        isDiscoverable: true,
        createdAt: DateTime.now().subtract(Duration(days: i * 10)),
        updatedAt: DateTime.now(),
      );
      
      // Don't include current user in results
      if (user.id != _currentUserId) {
        results.add(user);
      }
    }
    
    return results;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Friends'),
        elevation: 0,
        actions: [
          // Friend requests button
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FriendRequestsScreen(),
                ),
              );
            },
            icon: const Icon(Icons.person_add_outlined),
            tooltip: 'Friend requests',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: _buildSearchContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
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
          hintText: 'Search by username or name...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchResults = [];
                      _hasSearched = false;
                    });
                  },
                  icon: const Icon(Icons.clear),
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surfaceVariant,
        ),
        textInputAction: TextInputAction.search,
        onSubmitted: _performSearch,
      ),
    );
  }

  Widget _buildSearchContent() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Searching...'),
          ],
        ),
      );
    }

    if (_hasSearched && _searchResults.isEmpty) {
      return _buildNoResults();
    }

    if (_hasSearched && _searchResults.isNotEmpty) {
      return _buildSearchResults();
    }

    return _buildInitialState();
  }

  Widget _buildInitialState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Find Friends',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Search for users by their username or display name to send friend requests.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 24),
          if (_recentSearches.isNotEmpty) ...[
            Text(
              'Recent Searches',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ..._recentSearches.map((user) => _buildUserTile(user)).toList(),
          ],
          const SizedBox(height: 24),
          _buildSearchTips(),
        ],
      ),
    );
  }

  Widget _buildSearchTips() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Search Tips',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTip('• Search by exact username for best results'),
          _buildTip('• Use display names to find friends'),
          _buildTip('• Minimum 2 characters required'),
          _buildTip('• You can only message friends'),
        ],
      ),
    );
  }

  Widget _buildTip(String tip) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        tip,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
        ),
      ),
    );
  }

  Widget _buildNoResults() {
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
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try searching with a different username or name',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
            textAlign: TextAlign.center,
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
        return _buildUserTile(user);
      },
    );
  }

  Widget _buildUserTile(User user) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListUserProfileCard(
        user: user,
        onTap: () => _showUserProfile(user),
        onStatusChanged: () {
          // Refresh the search results or handle status change
        },
      ),
    );
  }

  void _showUserProfile(User user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(user.displayName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Text(
                user.displayName.substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  fontSize: 32,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              user.displayName,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              '@${user.handle}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Joined ${_formatDate(user.createdAt)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 16),
            ListUserProfileCard(
              user: user,
              showOnlineStatus: false,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _openChatWithUser(user);
            },
            child: const Text('Chat'),
          ),
        ],
      ),
    );
  }

  void _openChatWithUser(User user) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FriendChatScreen(
          recipientId: user.id,
          recipientName: user.displayName,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()} year${(difference.inDays / 365).floor() == 1 ? '' : 's'} ago';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} month${(difference.inDays / 30).floor() == 1 ? '' : 's'} ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else {
      return 'Today';
    }
  }
}