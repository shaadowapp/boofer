import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/user_service.dart';
import '../models/friend_model.dart';
import '../models/user_model.dart';
import '../utils/svg_icons.dart';
import '../providers/username_provider.dart';
import '../widgets/user_profile_card.dart';
import '../widgets/contextual_user_profile_card.dart';
import '../widgets/enhanced_user_profile_card.dart';
import 'global_search_screen.dart';

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
  List<User> _globalUsers = [];

  @override
  void initState() {
    super.initState();
    _initializeWithDemoUser();
    _loadUserData();
    _loadDiscoveryData();
  }

  void _initializeWithDemoUser() {
    // Initialize with demo user immediately to avoid loading state
    final demoUser = User(
      id: 'demo_user',
      handle: 'demo_user',
      fullName: 'Demo User',
      virtualNumber: '555-000-0000',
      bio: 'Complete your profile setup to get started!',
      isDiscoverable: false,
      status: UserStatus.offline,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    
    setState(() {
      _userNumber = 'Complete setup';
      _currentUser = demoUser;
    });
  }

  Future<void> _loadUserData() async {
    try {
      // Get current user data from UserService
      final currentUser = await UserService.getCurrentUser();
      if (currentUser != null) {
        setState(() {
          _userNumber = currentUser.virtualNumber;
          _currentUser = currentUser;
        });
      }
      // If currentUser is null, keep the demo user that was set in initializeWithDemoUser
    } catch (e) {
      // On error, create a fallback user
      final fallbackUser = User(
        id: 'fallback_user',
        handle: 'new_user',
        fullName: 'New User',
        virtualNumber: '555-000-0000',
        bio: 'Welcome to Boofer! Complete your setup to get started.',
        isDiscoverable: false,
        status: UserStatus.offline,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      setState(() {
        _userNumber = 'Setup required';
        _currentUser = fallbackUser;
      });
    }
  }

  Future<void> _loadDiscoveryData() async {
    // Simulate loading nearby, suggested, and global users
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() {
      _nearbyUsers = _generateNearbyUsers();
      _suggestedUsers = _generateSuggestedUsers();
      _globalUsers = _generateGlobalUsers();
    });
  }

  List<User> _generateNearbyUsers() {
    return [
      User(
        id: 'nearby_1',
        virtualNumber: '555-901-2345',
        handle: 'alex_nyc',
        fullName: 'Alex Johnson',
        bio: 'Online now • 0.2 km away',
        isDiscoverable: true,
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
        updatedAt: DateTime.now(),
        status: UserStatus.online,
      ),
      User(
        id: 'nearby_2',
        virtualNumber: '555-902-3456',
        handle: 'sarah_coffee',
        fullName: 'Sarah Wilson',
        bio: 'Active 2m ago • 0.5 km away',
        isDiscoverable: true,
        createdAt: DateTime.now().subtract(const Duration(days: 15)),
        updatedAt: DateTime.now(),
        status: UserStatus.offline,
      ),
      User(
        id: 'nearby_3',
        virtualNumber: '555-903-4567',
        handle: 'mike_tech',
        fullName: 'Mike Chen',
        bio: 'Online now • 1.2 km away',
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
        virtualNumber: '555-801-2345',
        handle: 'emma_artist',
        fullName: 'Emma Davis',
        bio: 'Artist from London, UK 🎨',
        isDiscoverable: true,
        createdAt: DateTime.now().subtract(const Duration(days: 45)),
        updatedAt: DateTime.now(),
        status: UserStatus.offline,
      ),
      User(
        id: 'suggested_2',
        virtualNumber: '555-802-3456',
        handle: 'james_music',
        fullName: 'James Brown',
        bio: 'Music producer from Tokyo 🎵',
        isDiscoverable: true,
        createdAt: DateTime.now().subtract(const Duration(days: 20)),
        updatedAt: DateTime.now(),
        status: UserStatus.online,
      ),
      User(
        id: 'suggested_3',
        virtualNumber: '555-803-4567',
        handle: 'lisa_travel',
        fullName: 'Lisa Garcia',
        bio: 'Travel blogger from Paris ✈️',
        isDiscoverable: true,
        createdAt: DateTime.now().subtract(const Duration(days: 60)),
        updatedAt: DateTime.now(),
        status: UserStatus.online,
      ),
    ];
  }

  List<User> _generateGlobalUsers() {
    return [
      User(
        id: 'global_1',
        handle: 'carlos_brazil',
        fullName: 'Carlos Silva',
        virtualNumber: '555-701-2345',
        bio: 'São Paulo, Brazil',
        isDiscoverable: true,
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
        updatedAt: DateTime.now(),
        status: UserStatus.online,
      ),
      User(
        id: 'global_2',
        handle: 'priya_india',
        fullName: 'Priya Sharma',
        virtualNumber: '555-702-3456',
        bio: 'Mumbai, India',
        isDiscoverable: true,
        createdAt: DateTime.now().subtract(const Duration(days: 45)),
        updatedAt: DateTime.now(),
        status: UserStatus.offline,
      ),
      User(
        id: 'global_3',
        handle: 'ahmed_egypt',
        fullName: 'Ahmed Hassan',
        virtualNumber: '555-703-4567',
        bio: 'Cairo, Egypt',
        isDiscoverable: true,
        createdAt: DateTime.now().subtract(const Duration(days: 20)),
        updatedAt: DateTime.now(),
        status: UserStatus.online,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UsernameProvider>(
      builder: (context, usernameProvider, child) {
        return Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User Profile Card
                _currentUser != null 
                    ? (_currentUser!.id == 'demo_user' || _currentUser!.id == 'fallback_user')
                        ? _buildSetupProfileCard()
                        : HeroUserProfileCard(
                            user: _currentUser!,
                            onTap: () {
                              Navigator.pushNamed(context, '/profile');
                            },
                            additionalInfo: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.public, color: Colors.white, size: 16),
                                    SizedBox(width: 8),
                                    Text(
                                      'Discoverable worldwide',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                    : _buildSetupProfileCard(), // Fallback to setup card if user is null
                
                const SizedBox(height: 24),

                // Discovery Actions
                _buildDiscoveryActions(),
            
            const SizedBox(height: 24),

            // Quick Stats
            _buildQuickStats(),
            
            const SizedBox(height: 24),

            // Nearby Users
            if (_nearbyUsers.isNotEmpty) ...[
              _buildSectionHeader('People Nearby', Icons.location_on, 
                subtitle: 'Connect with people around you'),
              const SizedBox(height: 12),
              _buildUsersGrid(_nearbyUsers),
              const SizedBox(height: 24),
            ],

            // Suggested Users
            if (_suggestedUsers.isNotEmpty) ...[
              _buildSectionHeader('Suggested for You', Icons.people_outline,
                subtitle: 'People you might want to connect with'),
              const SizedBox(height: 12),
              _buildUsersGrid(_suggestedUsers),
              const SizedBox(height: 24),
            ],

            // Global Users
            if (_globalUsers.isNotEmpty) ...[
              _buildSectionHeader('Around the World', Icons.public,
                subtitle: 'Connect with people globally'),
              const SizedBox(height: 12),
              _buildGlobalUsersList(_globalUsers),
              const SizedBox(height: 24),
            ],

            // Features
            _buildSectionHeader('Why Boofer?', Icons.star_outline),
            const SizedBox(height: 12),
            _buildFeatureCard(
              icon: Icons.public,
              title: 'Connect Globally',
              description: 'Find and chat with people from around the world using virtual numbers and usernames.',
            ),
            const SizedBox(height: 12),
            _buildFeatureCard(
              icon: Icons.security,
              title: 'Privacy First',
              description: 'No personal information required. Your real identity stays completely private.',
            ),
            const SizedBox(height: 12),
            _buildFeatureCard(
              icon: Icons.flash_on,
              title: 'Instant Connection',
              description: 'Start chatting immediately with anyone, anywhere in the world.',
            ),
          ],
        ),
      ),
    );
      },
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(20),
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
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
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
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon, 
              color: Theme.of(context).colorScheme.primary, 
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingProfileCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary.withOpacity(0.7),
            Theme.of(context).colorScheme.secondary.withOpacity(0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Column(
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 16),
          Text(
            'Loading profile...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSetupProfileCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.secondary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Avatar placeholder
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 3,
              ),
            ),
            child: const CircleAvatar(
              radius: 40,
              backgroundColor: Colors.white24,
              child: Icon(
                Icons.person_add,
                size: 32,
                color: Colors.white,
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Welcome text
          const Text(
            'Welcome to Boofer!',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 8),
          
          // Description
          const Text(
            'Complete your profile setup to start connecting with people worldwide',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 20),
          
          // Setup button
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pushNamed(context, '/onboarding');
            },
            icon: const Icon(Icons.settings, size: 20),
            label: const Text('Complete Setup'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Theme.of(context).colorScheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscoveryActions() {
    return Row(
      children: [
        Expanded(
          child: _buildActionCard(
            icon: Icons.search,
            title: 'Find People',
            subtitle: 'Search globally',
            color: Theme.of(context).colorScheme.primary,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SearchScreen(),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildActionCard(
            icon: Icons.location_on,
            title: 'Nearby',
            subtitle: 'People around you',
            color: const Color(0xFF34B7F1),
            onTap: () {
              _showNearbyUsers();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStats() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Boofer Stats',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  icon: Icons.people,
                  label: 'Connections',
                  value: '${_nearbyUsers.length + _suggestedUsers.length}',
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  icon: Icons.location_on,
                  label: 'Nearby',
                  value: '${_nearbyUsers.length}',
                  color: const Color(0xFF34B7F1),
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  icon: Icons.public,
                  label: 'Global',
                  value: '${_globalUsers.length}',
                  color: const Color(0xFF9C27B0),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, {String? subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              color: Theme.of(context).colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildUsersGrid(List<User> users) {
    return SizedBox(
      height: 240, // Increased height to accommodate all content
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: users.length,
        itemBuilder: (context, index) {
          final user = users[index];
          return Container(
            width: 160,
            margin: const EdgeInsets.only(right: 12),
            child: EnhancedUserProfileCard(
              user: user,
              style: ProfileCardStyle.grid,
              onTap: () => _showUserProfile(user),
              onStatusChanged: () {
                // Handle status change
              },
              showFollowButton: true,
            ),
          );
        },
      ),
    );
  }

  void _showUserProfile(User user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.8,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // User profile
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Column(
                    children: [
                      // Large avatar
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        child: Text(
                          user.initials,
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Name and handle
                      Text(
                        user.displayName,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      
                      const SizedBox(height: 4),
                      
                      Text(
                        user.formattedHandle,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Bio
                      if (user.bio.isNotEmpty) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            user.bio,
                            style: Theme.of(context).textTheme.bodyLarge,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                      
                      // Action button
                      SizedBox(
                        width: double.infinity,
                        child: GridUserProfileCard(
                          user: user,
                          showBio: false,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showNearbyUsers() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Header
              Row(
                children: [
                  const Icon(Icons.location_on, color: Color(0xFF34B7F1)),
                  const SizedBox(width: 8),
                  Text(
                    'People Nearby',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // Nearby users list
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: _nearbyUsers.length,
                  itemBuilder: (context, index) {
                    final user = _nearbyUsers[index];
                    return _buildNearbyUserTile(user);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlobalUsersList(List<User> users) {
    return Column(
      children: users.map((user) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: _buildGlobalUserTile(user),
      )).toList(),
    );
  }

  Widget _buildGlobalUserTile(User user) {
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
          Stack(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                child: Text(
                  user.initials,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              if (user.status == UserStatus.online)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        width: 2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user.bio.isNotEmpty ? user.bio : user.formattedHandle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => _connectWithGlobalUser(user),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text('Follow'),
          ),
        ],
      ),
    );
  }

  Widget _buildNearbyUserTile(User user) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
          Stack(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                child: Text(
                  user.initials,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              if (user.status == UserStatus.online)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        width: 2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user.bio.isNotEmpty ? user.bio : user.formattedHandle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => _connectWithNearbyUser(user),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text('Follow'),
          ),
        ],
      ),
    );
  }

  void _connectWithNearbyUser(User user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Connect with ${user.displayName}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Username: ${user.formattedHandle}'),
            Text('Virtual Number: ${user.virtualNumber}'),
            const SizedBox(height: 16),
            const Text(
              'Send a connection request to start chatting?',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _sendConnectionRequestToUser(user);
            },
            child: const Text('Follow'),
          ),
        ],
      ),
    );
  }

  void _sendConnectionRequestToUser(User user) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Follow request sent to ${user.displayName}'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _connectWithGlobalUser(User user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Connect with ${user.displayName}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Username: ${user.formattedHandle}'),
            Text('Virtual Number: ${user.virtualNumber}'),
            const SizedBox(height: 16),
            const Text(
              'Send a connection request to start chatting?',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _sendConnectionRequestToGlobalUser(user);
            },
            child: const Text('Follow'),
          ),
        ],
      ),
    );
  }

  void _sendConnectionRequestToGlobalUser(User user) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Follow request sent to ${user.displayName}'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}