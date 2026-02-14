import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/user_service.dart';
import '../services/supabase_service.dart';
import '../models/user_model.dart';
import '../providers/username_provider.dart';
import 'user_search_screen.dart';
import 'write_post_screen.dart';
import '../widgets/user_avatar.dart';

// Post model for demo posts
class Post {
  final String id;
  final User author;
  final String? caption;
  final String? imageUrl;
  final DateTime createdAt;
  final int likes;
  final int comments;
  final bool isLiked;

  Post({
    required this.id,
    required this.author,
    this.caption,
    this.imageUrl,
    required this.createdAt,
    this.likes = 0,
    this.comments = 0,
    this.isLiked = false,
  });
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _userNumber;
  User? _currentUser;
  List<User> _nearbyUsers = [];
  List<User> _suggestedUsers = [];
  List<Post> _feedPosts = [];
  bool _isLoading = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadCurrentUserFromDatabase(); // Load real user data only
  }

  Future<void> _loadCurrentUserFromDatabase() async {
    try {
      final supabaseService = SupabaseService.instance;

      // Get current user data
      final currentUser = await UserService.getCurrentUser();

      if (currentUser != null && mounted) {
        setState(() {
          _currentUser = currentUser;
          _userNumber = currentUser.virtualNumber;
        });

        // Fetch other data in parallel
        final results = await Future.wait([
          supabaseService.getNearbyUsers(),
          supabaseService.getSuggestedUsers(),
          supabaseService.getFeedPosts(),
        ]);

        if (mounted) {
          setState(() {
            _nearbyUsers = results[0] as List<User>;
            _suggestedUsers = results[1] as List<User>;
            _feedPosts = (results[2] as List<Map<String, dynamic>>).map((
              postData,
            ) {
              final authorData = postData['author'] as Map<String, dynamic>;
              return Post(
                id: postData['id'].toString(),
                author: User.fromJson(authorData),
                caption: postData['caption'],
                imageUrl: postData['image_url'],
                createdAt: DateTime.parse(postData['created_at']),
                likes: postData['likes_count'] ?? 0,
                comments: postData['comments_count'] ?? 0,
                isLiked: false, // In a real app, check if current user liked it
              );
            }).toList();
            _isLoading = false;
          });
        }

        // print('✅ Loaded environment from Supabase');
      } else {
        // print('⚠️ No current user found');
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      // print('❌ Error loading data from Supabase: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  List<User> _generateNearbyUsers() {
    return [
      User(
        id: 'nearby_1',
        email: 'alex.nyc@demo.com',
        virtualNumber: '555-901-2345',
        handle: 'alex_nyc',
        fullName: 'Alex Johnson',
        bio: '🎨 Digital artist & coffee enthusiast',
        isDiscoverable: true,
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
        updatedAt: DateTime.now(),
        status: UserStatus.online,
      ),
      User(
        id: 'nearby_2',
        email: 'sarah.coffee@demo.com',
        virtualNumber: '555-902-3456',
        handle: 'sarah_coffee',
        fullName: 'Sarah Wilson',
        bio: '📚 Book lover | World traveler ✈️',
        isDiscoverable: true,
        createdAt: DateTime.now().subtract(const Duration(days: 15)),
        updatedAt: DateTime.now(),
        status: UserStatus.offline,
      ),
      User(
        id: 'nearby_3',
        email: 'mike.tech@demo.com',
        virtualNumber: '555-903-4567',
        handle: 'mike_tech',
        fullName: 'Mike Chen',
        bio: '🏃‍♂️ Marathon runner | Fitness coach',
        isDiscoverable: true,
        createdAt: DateTime.now().subtract(const Duration(days: 7)),
        updatedAt: DateTime.now(),
        status: UserStatus.online,
      ),
    ];
  }

  List<User> _generateSuggestedUsers() {
    return [
      User(
        id: 'suggested_1',
        email: 'emma.artist@demo.com',
        virtualNumber: '555-801-2345',
        handle: 'emma_artist',
        fullName: 'Emma Davis',
        bio: '🎨 Artist from London, UK',
        isDiscoverable: true,
        createdAt: DateTime.now().subtract(const Duration(days: 45)),
        updatedAt: DateTime.now(),
        status: UserStatus.offline,
      ),
      User(
        id: 'suggested_2',
        email: 'james.music@demo.com',
        virtualNumber: '555-802-3456',
        handle: 'james_music',
        fullName: 'James Brown',
        bio: '🎵 Music producer from Tokyo',
        isDiscoverable: true,
        createdAt: DateTime.now().subtract(const Duration(days: 20)),
        updatedAt: DateTime.now(),
        status: UserStatus.online,
      ),
      User(
        id: 'suggested_3',
        email: 'lisa.travel@demo.com',
        virtualNumber: '555-803-4567',
        handle: 'lisa_travel',
        fullName: 'Lisa Garcia',
        bio: '✈️ Travel blogger from Paris',
        isDiscoverable: true,
        createdAt: DateTime.now().subtract(const Duration(days: 60)),
        updatedAt: DateTime.now(),
        status: UserStatus.online,
      ),
    ];
  }

  List<Post> _generateFeedPosts() {
    // Generate demo users for posts
    final friends = [
      ..._generateNearbyUsers(),
      ..._generateSuggestedUsers(),
      // Add a few more demo users for variety
      User(
        id: 'friend_1',
        email: 'maya.rodriguez@demo.com',
        virtualNumber: '555-111-1111',
        handle: 'creative_artist',
        fullName: 'Maya Rodriguez',
        bio: '🎨 Digital artist & designer',
        isDiscoverable: true,
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
        updatedAt: DateTime.now(),
        status: UserStatus.online,
      ),
      User(
        id: 'friend_2',
        email: 'alex.thompson@demo.com',
        virtualNumber: '555-222-2222',
        handle: 'travel_blogger',
        fullName: 'Alex Thompson',
        bio: '✈️ Travel enthusiast & blogger',
        isDiscoverable: true,
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
        updatedAt: DateTime.now(),
        status: UserStatus.offline,
      ),
    ];

    final posts = <Post>[];
    final random = Random();

    final captions = [
      'Just finished an amazing coffee painting! ☕🎨',
      'Beautiful sunset from my travels today 🌅',
      'New music track dropping soon! 🎵',
      'Morning run complete! Feeling energized 🏃‍♂️',
      'Exploring the streets of Tokyo 🏙️',
      'Book recommendation: just finished this amazing novel 📚',
      'Coding session with some great music 👨‍💻',
      'Weekend vibes with friends! 🎉',
      'New art piece in progress... 🎨',
      'Travel memories from last week ✈️',
      'Perfect weather for a bike ride! 🚴‍♀️',
      'Homemade pasta night 🍝',
      'Concert was absolutely incredible! 🎤',
      'Beach day with the squad 🏖️',
      'New recipe turned out amazing! 👨‍🍳',
    ];

    for (int i = 0; i < 15; i++) {
      final author = friends[random.nextInt(friends.length)];
      posts.add(
        Post(
          id: 'post_$i',
          author: author,
          caption: captions[random.nextInt(captions.length)],
          imageUrl: 'demo_image_$i', // Demo image placeholder
          createdAt: DateTime.now().subtract(
            Duration(hours: random.nextInt(48), minutes: random.nextInt(60)),
          ),
          likes: random.nextInt(100) + 5,
          comments: random.nextInt(20) + 1,
          isLiked: random.nextBool(),
        ),
      );
    }

    // Sort posts by creation time (newest first)
    posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return posts;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UsernameProvider>(
      builder: (context, usernameProvider, child) {
        return Scaffold(
          body: CustomScrollView(
            controller: _scrollController,
            slivers: [
              // Profile Header
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  child: _buildMinimalProfileCard(),
                ),
              ),

              // Feed Posts - Simplified for testing
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    // Just show posts for now to test
                    if (index < _feedPosts.length) {
                      return _buildPostCard(_feedPosts[index]);
                    }

                    // Show discovery sections after posts
                    if (index == _feedPosts.length) {
                      return _buildDiscoverySection(
                        'People Nearby',
                        _nearbyUsers,
                        Icons.location_on,
                      );
                    }

                    if (index == _feedPosts.length + 1) {
                      return _buildDiscoverySection(
                        'Suggested for You',
                        _suggestedUsers,
                        Icons.people_outline,
                      );
                    }

                    // End of feed message
                    return _buildEndOfFeedMessage();
                  },
                  childCount:
                      _feedPosts.length +
                      3, // posts + 2 discovery sections + 1 end message
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              if (_currentUser != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        WritePostScreen(currentUser: _currentUser!),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please wait while we load your profile...'),
                  ),
                );
              }
            },
            tooltip: 'Create Post',
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  Widget _buildMinimalProfileCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Profile Picture with online status
          Stack(
            children: [
              UserAvatar(
                avatar: _currentUser?.avatar,
                profilePicture: _currentUser?.profilePicture,
                name: _currentUser?.fullName ?? _currentUser?.handle ?? 'User',
                radius: 28,
                fontSize: 22,
              ),
              // Online status indicator
              if (_currentUser?.status == UserStatus.online)
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).cardColor,
                        width: 2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),

          // User Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Full Name
                Text(
                  _currentUser?.fullName ?? 'Alex Johnson',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),

                // Handle
                Text(
                  _currentUser?.formattedHandle ?? '@alex_johnson',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),

                // Virtual Number
                Row(
                  children: [
                    Icon(
                      Icons.phone_android,
                      size: 14,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.6),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _currentUser?.virtualNumber ?? 'VN-2024-001',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),

                // Status and Bio
                Row(
                  children: [
                    Icon(
                      _currentUser?.status == UserStatus.online
                          ? Icons.circle
                          : Icons.circle_outlined,
                      size: 12,
                      color: _currentUser?.status == UserStatus.online
                          ? Colors.green
                          : Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.5),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _currentUser?.status == UserStatus.online
                            ? 'Online • ${_currentUser?.bio ?? "🎨 Digital artist & coffee enthusiast"}'
                            : 'Offline • ${_currentUser?.bio ?? "🎨 Digital artist & coffee enthusiast"}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.6),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Explore Button
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const UserSearchScreen(),
                  ),
                );
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.explore,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Explore',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostCard(Post post) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Post Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                UserAvatar(
                  avatar: post.author.avatar,
                  profilePicture: post.author.profilePicture,
                  name: post.author.fullName,
                  radius: 20,
                  fontSize: 16,
                  backgroundColor: _getAvatarColor(post.author.id),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.author.displayName,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _formatPostTime(post.createdAt),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  icon: Icon(
                    Icons.more_horiz,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),

          // Post Image - Instagram/Facebook style
          if (post.imageUrl != null)
            Container(
              width: double.infinity,
              height: 400,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _buildPostImage(post),
              ),
            ),

          // Post Actions - Instagram style with theme-aware colors
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  onPressed: () {
                    setState(() {
                      // Toggle like status (demo functionality)
                    });
                  },
                  icon: Icon(
                    post.isLiked ? Icons.favorite : Icons.favorite_border,
                    color: post.isLiked
                        ? Colors.red
                        : Theme.of(context).colorScheme.onSurface,
                    size: 28,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 16),
                IconButton(
                  onPressed: () {},
                  icon: Icon(
                    Icons.chat_bubble_outline,
                    color: Theme.of(context).colorScheme.onSurface,
                    size: 28,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 16),
                IconButton(
                  onPressed: () {},
                  icon: Icon(
                    Icons.send_outlined,
                    color: Theme.of(context).colorScheme.onSurface,
                    size: 28,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () {},
                  icon: Icon(
                    Icons.bookmark_border,
                    color: Theme.of(context).colorScheme.onSurface,
                    size: 28,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // Likes count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '${post.likes} likes',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),

          // Post Caption
          if (post.caption != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '${post.author.displayName} ',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    TextSpan(
                      text: post.caption!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Comments preview
          if (post.comments > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'View all ${post.comments} comments',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildPostImage(Post post) {
    // Create different image styles based on post ID for variety
    final random = Random(post.id.hashCode);
    final imageType = random.nextInt(4);

    switch (imageType) {
      case 0:
        return _buildGradientImage(post, [Colors.purple, Colors.pink]);
      case 1:
        return _buildGradientImage(post, [Colors.blue, Colors.cyan]);
      case 2:
        return _buildGradientImage(post, [Colors.orange, Colors.red]);
      case 3:
        return _buildPatternImage(post);
      default:
        return _buildGradientImage(post, [Colors.green, Colors.teal]);
    }
  }

  Widget _buildGradientImage(Post post, List<Color> colors) {
    final random = Random(post.id.hashCode);
    final icons = [
      Icons.camera_alt,
      Icons.photo,
      Icons.image,
      Icons.photo_camera,
      Icons.collections,
    ];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icons[random.nextInt(icons.length)],
              size: 64,
              color: Colors.white.withOpacity(0.8),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                post.author.displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatternImage(Post post) {
    final random = Random(post.id.hashCode);
    final colors = [
      Colors.indigo,
      Colors.teal,
      Colors.amber,
      Colors.deepPurple,
    ];

    return Container(
      decoration: BoxDecoration(color: colors[random.nextInt(colors.length)]),
      child: Stack(
        children: [
          // Pattern background
          ...List.generate(20, (index) {
            return Positioned(
              left: random.nextDouble() * 400,
              top: random.nextDouble() * 400,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
              ),
            );
          }),
          // Content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.photo_library,
                    size: 48,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '📸 ${post.author.displayName}\'s Post',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscoverySection(String title, List<User> users, IconData icon) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
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
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const UserSearchScreen(),
                      ),
                    );
                  },
                  child: const Text('See All'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
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
                  child: _buildDiscoveryUserCard(user),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscoveryUserCard(User user) {
    final random = Random(user.id.hashCode);
    final followerCount = [
      '1.2K',
      '5.8K',
      '12.3K',
      '890',
      '25.1K',
      '3.4K',
    ][random.nextInt(6)];

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
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            // Bio
            Text(
              user.bio,
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
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Following ${user.displayName}'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: EdgeInsets.zero,
                ),
                child: const Text(
                  'Follow',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEndOfFeedMessage() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(
            Icons.people_outline,
            size: 64,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'You\'re all caught up!',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Follow more friends to see more posts in your feed',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const UserSearchScreen(),
                ),
              );
            },
            icon: const Icon(Icons.person_add),
            label: const Text('Discover'),
          ),
        ],
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

  String _formatPostTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else {
      return '${(difference.inDays / 7).floor()}w';
    }
  }
}
