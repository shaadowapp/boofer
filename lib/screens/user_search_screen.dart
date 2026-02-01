import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../services/friendship_service.dart';
import '../services/user_service.dart';
import '../providers/firestore_user_provider.dart';
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
  List<User> _suggestedUsers = [];
  List<User> _trendingUsers = [];
  List<User> _recentSearches = [];
  Map<String, bool> _followingStatus = {};
  bool _loading = false;
  bool _hasSearched = false;
  String? _currentUserId;
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
      });
    }
  }

  Future<void> _loadExploreUsers() async {
    setState(() {
      _loading = true;
    });

    try {
      // Get real users from Firestore
      final userProvider = context.read<FirestoreUserProvider>();
      
      // Get discoverable users
      final discoverableUsers = await userProvider.getDiscoverableUsers(limit: 20);
      
      // Filter out current user
      final filteredUsers = discoverableUsers.where((user) => user.id != _currentUserId).toList();
      
      // Shuffle and split into suggested and trending
      filteredUsers.shuffle();
      
      final halfPoint = (filteredUsers.length / 2).ceil();
      
      setState(() {
        _suggestedUsers = filteredUsers.take(halfPoint).toList();
        _trendingUsers = filteredUsers.skip(halfPoint).toList();
        _recentSearches = []; // Could implement recent searches from local storage
        _loading = false;
      });
      
      print('✅ Loaded ${filteredUsers.length} real users from Firestore');
      print('   - Suggested: ${_suggestedUsers.length}');
      print('   - Trending: ${_trendingUsers.length}');
      
    } catch (e) {
      print('❌ Error loading real users: $e');
      
      // Fallback to demo users if Firestore fails
      setState(() {
        _suggestedUsers = _generateDemoUsers('suggested');
        _trendingUsers = _generateDemoUsers('trending');
        _recentSearches = _generateDemoUsers('recent').take(3).toList();
        _loading = false;
      });
    }
  }

  List<User> _generateDemoUsers(String type) {
    final random = Random();
    final users = <User>[];
    
    final profiles = [
      {'name': 'Alex Johnson', 'bio': '🎨 Digital artist & coffee enthusiast'},
      {'name': 'Sarah Chen', 'bio': '📚 Book lover | World traveler ✈️'},
      {'name': 'Mike Rodriguez', 'bio': '🏃‍♂️ Marathon runner | Fitness coach'},
      {'name': 'Emma Wilson', 'bio': '🎵 Music producer & DJ 🎧'},
      {'name': 'David Kim', 'bio': '👨‍💻 Full-stack developer | Tech enthusiast'},
    ];

    final shuffledProfiles = List.from(profiles)..shuffle(random);
    final count = type == 'recent' ? 5 : 15;
    
    for (int i = 0; i < count && i < shuffledProfiles.length; i++) {
      final profile = shuffledProfiles[i];
      final name = profile['name'] as String;
      final handle = name.toLowerCase().replaceAll(' ', '_').replaceAll('.', '');
      final user = User(
        id: '${type}_user_$i',
        email: '${handle}@demo.com',
        virtualNumber: 'VN${(type == 'suggested' ? 2000 : type == 'trending' ? 3000 : 4000) + i}',
        handle: handle,
        fullName: name,
        bio: profile['bio'] as String,
        isDiscoverable: true,
        createdAt: DateTime.now().subtract(Duration(days: random.nextInt(365) + 1)),
        updatedAt: DateTime.now(),
      );
      users.add(user);
      
      // Initialize follow status (some already followed for demo)
      _followingStatus[user.id] = random.nextBool() && i % 5 == 0;
    }
    
    return users;
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
      final userProvider = context.read<FirestoreUserProvider>();
      final results = await userProvider.searchUsers(query);
      
      // Filter out current user
      final filteredResults = results.where((user) => user.id != _currentUserId).toList();
      
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
        title: const Text('Find Friends'),
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
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
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
              ),
            ),
          ),
          
          // Content
          Expanded(
            child: _buildContent(),
          ),
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

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return _buildExploreContent();
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
        return _buildUserCard(user);
      },
    );
  }

  Widget _buildExploreContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_trendingUsers.isNotEmpty) ...[
            _buildSectionHeader('Trending'),
            _buildUserList(_trendingUsers),
            const SizedBox(height: 24),
          ],
          
          if (_suggestedUsers.isNotEmpty) ...[
            _buildSectionHeader('Suggested for you'),
            _buildUserList(_suggestedUsers),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildUserList(List<User> users) {
    return Column(
      children: users.map((user) => _buildUserCard(user)).toList(),
    );
  }

  Widget _buildUserCard(User user) {
    final isFollowing = _followingStatus[user.id] ?? false;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: user.profilePicture?.isNotEmpty == true
              ? NetworkImage(user.profilePicture!)
              : null,
          child: user.profilePicture?.isEmpty != false
              ? Text(user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?')
              : null,
        ),
        title: Text(user.fullName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('@${user.handle}'),
            if (user.virtualNumber?.isNotEmpty == true)
              Text(
                user.virtualNumber!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
          ],
        ),
        trailing: SizedBox(
          width: 100,
          child: ElevatedButton(
            onPressed: () => _handleUserAction(user),
            style: ElevatedButton.styleFrom(
              backgroundColor: isFollowing 
                  ? Theme.of(context).colorScheme.surfaceContainerHighest
                  : Theme.of(context).colorScheme.primary,
              foregroundColor: isFollowing 
                  ? Theme.of(context).colorScheme.onSurface
                  : Theme.of(context).colorScheme.onPrimary,
            ),
            child: Text(isFollowing ? 'Message' : 'Follow'),
          ),
        ),
        onTap: () => _showUserProfile(user),
      ),
    );
  }

  void _showUserProfile(User user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(user.fullName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundImage: user.profilePicture?.isNotEmpty == true
                  ? NetworkImage(user.profilePicture!)
                  : null,
              child: user.profilePicture?.isEmpty != false
                  ? Text(user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?')
                  : null,
            ),
            const SizedBox(height: 16),
            Text('@${user.handle}'),
            if (user.bio.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(user.bio),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _handleUserAction(user);
            },
            child: const Text('Follow'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleUserAction(User user) async {
    final isFollowing = _followingStatus[user.id] ?? false;
    
    if (isFollowing) {
      // Navigate to chat
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => FriendChatScreen(
            recipientId: user.id,
            recipientName: user.fullName,
            recipientHandle: user.handle,
            recipientAvatar: user.profilePicture ?? '',
          ),
        ),
      );
    } else {
      // Send friend request
      await _sendFriendRequest(user);
    }
  }

  Future<void> _sendFriendRequest(User user) async {
    final currentUser = await UserService.getCurrentUser();
    if (currentUser == null) return;

    try {
      final success = await FriendshipService.instance.sendFriendRequest(
        currentUser.id,
        user.id,
        message: 'Hi! I\'d like to be friends so we can chat.',
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Friend request sent to ${user.fullName}'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to send friend request'),
              backgroundColor: Colors.red,
            ),
          );
        }
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