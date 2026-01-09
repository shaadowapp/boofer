import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
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

    // Simulate loading delay
    await Future.delayed(const Duration(milliseconds: 800));

    setState(() {
      _suggestedUsers = _generateDemoUsers('suggested');
      _trendingUsers = _generateDemoUsers('trending');
      _recentSearches = _generateDemoUsers('recent').take(3).toList();
      _loading = false;
    });
  }

  List<User> _generateDemoUsers(String type) {
    final random = Random();
    final users = <User>[];
    
    final profiles = [
      {'name': 'Alex Johnson', 'bio': '🎨 Digital artist & coffee enthusiast', 'followers': '12.5K'},
      {'name': 'Sarah Chen', 'bio': '📚 Book lover | World traveler ✈️', 'followers': '8.2K'},
      {'name': 'Mike Rodriguez', 'bio': '🏃‍♂️ Marathon runner | Fitness coach', 'followers': '15.7K'},
      {'name': 'Emma Wilson', 'bio': '🎵 Music producer & DJ 🎧', 'followers': '22.1K'},
      {'name': 'David Kim', 'bio': '👨‍💻 Full-stack developer | Tech enthusiast', 'followers': '9.8K'},
      {'name': 'Lisa Thompson', 'bio': '🌱 Plant parent | Sustainability advocate', 'followers': '6.4K'},
      {'name': 'Ryan Martinez', 'bio': '📸 Street photographer | Visual storyteller', 'followers': '18.3K'},
      {'name': 'Sophie Anderson', 'bio': '🍳 Chef | Food blogger & recipe creator', 'followers': '11.9K'},
      {'name': 'Jake Miller', 'bio': '🎮 Pro gamer | Twitch streamer', 'followers': '25.6K'},
      {'name': 'Maya Patel', 'bio': '🧘‍♀️ Yoga instructor | Mindfulness coach', 'followers': '7.1K'},
      {'name': 'Chris Taylor', 'bio': '🎭 Theater actor | Drama teacher', 'followers': '4.8K'},
      {'name': 'Zoe Davis', 'bio': '🔬 Research scientist | Science communicator', 'followers': '13.2K'},
      {'name': 'Noah Brown', 'bio': '🎨 Graphic designer | Creative director', 'followers': '16.5K'},
      {'name': 'Ava Garcia', 'bio': '🏔️ Adventure seeker | Mountain climber', 'followers': '19.7K'},
      {'name': 'Ethan Lee', 'bio': '📝 Content writer | Storyteller', 'followers': '5.9K'},
      {'name': 'Jordan Smith', 'bio': '🎪 Circus performer | Acrobat', 'followers': '14.3K'},
      {'name': 'Casey Wong', 'bio': '🎯 Marketing strategist | Brand consultant', 'followers': '10.1K'},
      {'name': 'Taylor Swift', 'bio': '🎤 Singer-songwriter | Music lover', 'followers': '89.2M'},
      {'name': 'Morgan Freeman', 'bio': '🎬 Actor | Voice artist | Narrator', 'followers': '45.7M'},
      {'name': 'Riley Cooper', 'bio': '⚽ Professional athlete | Sports enthusiast', 'followers': '32.4K'},
    ];

    final shuffledProfiles = List.from(profiles)..shuffle(random);
    final count = type == 'recent' ? 5 : 15;
    
    for (int i = 0; i < count && i < shuffledProfiles.length; i++) {
      final profile = shuffledProfiles[i];
      final name = profile['name'] as String;
      final handle = name.toLowerCase().replaceAll(' ', '_').replaceAll('.', '');
      final user = User(
        id: '${type}_user_$i',
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

  Future<void> _toggleFollow(User user) async {
    final isCurrentlyFollowing = _followingStatus[user.id] ?? false;
    
    // Optimistic update
    setState(() {
      _followingStatus[user.id] = !isCurrentlyFollowing;
    });

    try {
      // Simulate API call
      await Future.delayed(const Duration(milliseconds: 500));
      
      // In a real app, you would call your friendship service here
      // await _friendshipService.sendFriendRequest(user.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isCurrentlyFollowing 
                ? 'Unfollowed ${user.displayName}' 
                : 'Following ${user.displayName}',
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: isCurrentlyFollowing 
                ? Colors.orange 
                : Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      // Revert on error
      if (mounted) {
        setState(() {
          _followingStatus[user.id] = isCurrentlyFollowing;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to ${isCurrentlyFollowing ? 'unfollow' : 'follow'} user'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading users...'),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header section
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Discover People',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Find and connect with interesting people',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          
          // Trending Users Section
          if (_trendingUsers.isNotEmpty) ...[
            _buildSectionHeader('Trending', Icons.trending_up),
            _buildHorizontalUserList(_trendingUsers),
            const SizedBox(height: 24),
          ],
          
          // Suggested Users Section
          if (_suggestedUsers.isNotEmpty) ...[
            _buildSectionHeader('Suggested for You', Icons.people_outline),
            _buildVerticalUserList(_suggestedUsers),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalUserList(List<User> users) {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: users.length,
        itemBuilder: (context, index) {
          final user = users[index];
          return Container(
            width: 140,
            margin: const EdgeInsets.only(right: 12),
            child: _buildHorizontalUserCard(user),
          );
        },
      ),
    );
  }

  Widget _buildHorizontalUserCard(User user) {
    final isFollowing = _followingStatus[user.id] ?? false;
    final random = Random(user.id.hashCode);
    final followerCount = ['1.2K', '5.8K', '12.3K', '890', '25.1K', '3.4K'][random.nextInt(6)];
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // Profile Picture
            CircleAvatar(
              radius: 30,
              backgroundColor: _getAvatarColor(user.id),
              child: Text(
                user.displayName.substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  fontSize: 24,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
            
            // Name
            Text(
              user.displayName,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            
            // Handle
            Text(
              '@${user.handle}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            
            // Followers
            Text(
              '$followerCount followers',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
              textAlign: TextAlign.center,
            ),
            
            const Spacer(),
            
            // Follow Button
            SizedBox(
              width: double.infinity,
              height: 32,
              child: ElevatedButton(
                onPressed: () => _toggleFollow(user),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isFollowing 
                      ? Theme.of(context).colorScheme.surfaceVariant
                      : Theme.of(context).colorScheme.primary,
                  foregroundColor: isFollowing 
                      ? Theme.of(context).colorScheme.onSurfaceVariant
                      : Theme.of(context).colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: EdgeInsets.zero,
                ),
                child: Text(
                  isFollowing ? 'Following' : 'Follow',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerticalUserList(List<User> users) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        return _buildVerticalUserCard(user);
      },
    );
  }

  Widget _buildVerticalUserCard(User user) {
    final isFollowing = _followingStatus[user.id] ?? false;
    final random = Random(user.id.hashCode);
    final followerCount = ['1.2K', '5.8K', '12.3K', '890', '25.1K', '3.4K'][random.nextInt(6)];
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: _getAvatarColor(user.id),
          child: Text(
            user.displayName.substring(0, 1).toUpperCase(),
            style: const TextStyle(
              fontSize: 18,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                user.displayName,
                style: const TextStyle(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (user.displayName.contains('Swift') || user.displayName.contains('Freeman'))
              Icon(
                Icons.verified,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '@${user.handle}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              user.bio ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$followerCount followers',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ],
        ),
        trailing: SizedBox(
          width: 80,
          height: 32,
          child: ElevatedButton(
            onPressed: () => _toggleFollow(user),
            style: ElevatedButton.styleFrom(
              backgroundColor: isFollowing 
                  ? Theme.of(context).colorScheme.surfaceVariant
                  : Theme.of(context).colorScheme.primary,
              foregroundColor: isFollowing 
                  ? Theme.of(context).colorScheme.onSurfaceVariant
                  : Theme.of(context).colorScheme.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: EdgeInsets.zero,
            ),
            child: Text(
              isFollowing ? 'Following' : 'Follow',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        onTap: () => _showUserProfile(user),
      ),
    );
  }

  Color _getAvatarColor(String userId) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.indigo,
      Colors.pink,
    ];
    return colors[userId.hashCode % colors.length];
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
    final isFollowing = _followingStatus[user.id] ?? false;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: _getAvatarColor(user.id),
          child: Text(
            user.displayName.substring(0, 1).toUpperCase(),
            style: const TextStyle(
              fontSize: 18,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          user.displayName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '@${user.handle}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            if (user.bio != null && user.bio!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                user.bio!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                ),
              ),
            ],
          ],
        ),
        trailing: SizedBox(
          width: 80,
          height: 32,
          child: ElevatedButton(
            onPressed: () => _toggleFollow(user),
            style: ElevatedButton.styleFrom(
              backgroundColor: isFollowing 
                  ? Theme.of(context).colorScheme.surfaceVariant
                  : Theme.of(context).colorScheme.primary,
              foregroundColor: isFollowing 
                  ? Theme.of(context).colorScheme.onSurfaceVariant
                  : Theme.of(context).colorScheme.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: EdgeInsets.zero,
            ),
            child: Text(
              isFollowing ? 'Following' : 'Follow',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        onTap: () => _showUserProfile(user),
      ),
    );
  }

  void _showUserProfile(User user) {
    final isFollowing = _followingStatus[user.id] ?? false;
    final random = Random(user.id.hashCode);
    final followerCount = ['1.2K', '5.8K', '12.3K', '890', '25.1K', '3.4K'][random.nextInt(6)];
    final followingCount = ['234', '1.1K', '567', '89', '2.3K', '445'][random.nextInt(6)];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        contentPadding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Container(
          width: 300,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Profile Picture
              CircleAvatar(
                radius: 40,
                backgroundColor: _getAvatarColor(user.id),
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
              
              // Name and verification
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    user.displayName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (user.displayName.contains('Swift') || user.displayName.contains('Freeman')) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.verified,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ],
                ],
              ),
              
              // Handle
              Text(
                '@${user.handle}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Bio
              if (user.bio != null && user.bio!.isNotEmpty)
                Text(
                  user.bio!,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              
              const SizedBox(height: 16),
              
              // Stats
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatColumn('Followers', followerCount),
                  _buildStatColumn('Following', followingCount),
                  _buildStatColumn('Joined', _formatDate(user.createdAt)),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _toggleFollow(user),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isFollowing 
                            ? Theme.of(context).colorScheme.surfaceVariant
                            : Theme.of(context).colorScheme.primary,
                        foregroundColor: isFollowing 
                            ? Theme.of(context).colorScheme.onSurfaceVariant
                            : Theme.of(context).colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(isFollowing ? 'Following' : 'Follow'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _openChatWithUser(user);
                      },
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Message'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      ],
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