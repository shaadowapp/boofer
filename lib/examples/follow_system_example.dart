import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/follow_provider.dart';
import '../models/user_model.dart';
import '../widgets/follow_button.dart';
import '../widgets/user_profile_card.dart';
import '../screens/followers_screen.dart';
import '../screens/following_screen.dart';
import '../screens/discover_users_screen.dart';

/// Example implementation showing how to integrate the follow system
class FollowSystemExample extends StatefulWidget {
  final User currentUser;

  const FollowSystemExample({
    super.key,
    required this.currentUser,
  });

  @override
  State<FollowSystemExample> createState() => _FollowSystemExampleState();
}

class _FollowSystemExampleState extends State<FollowSystemExample> {
  @override
  void initState() {
    super.initState();
    
    // Initialize follow provider with current user
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FollowProvider>().initialize(widget.currentUser.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Follow System Demo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DiscoverUsersScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer<FollowProvider>(
        builder: (context, followProvider, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Current user profile section
                _buildCurrentUserSection(context, followProvider),
                
                const SizedBox(height: 24),
                
                // Suggested users section
                _buildSuggestedUsersSection(context, followProvider),
                
                const SizedBox(height: 24),
                
                // Quick actions section
                _buildQuickActionsSection(context, followProvider),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCurrentUserSection(BuildContext context, FollowProvider followProvider) {
    final stats = followProvider.getFollowStats(widget.currentUser.id);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your Profile',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundImage: widget.currentUser.profilePicture != null
                      ? NetworkImage(widget.currentUser.profilePicture!)
                      : null,
                  child: widget.currentUser.profilePicture == null
                      ? Text(
                          widget.currentUser.initials,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.currentUser.displayName,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        widget.currentUser.formattedHandle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (widget.currentUser.bio.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          widget.currentUser.bio,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Follow stats
            if (stats != null) ...[
              Row(
                children: [
                  _buildStatButton(
                    context,
                    count: stats.followersCount,
                    label: 'Followers',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FollowersScreen(
                            userId: widget.currentUser.id,
                            userName: widget.currentUser.displayName,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 24),
                  _buildStatButton(
                    context,
                    count: stats.followingCount,
                    label: 'Following',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FollowingScreen(
                            userId: widget.currentUser.id,
                            userName: widget.currentUser.displayName,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestedUsersSection(BuildContext context, FollowProvider followProvider) {
    final suggestedUsers = followProvider.getSuggestedUsers();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Suggested for You',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DiscoverUsersScreen(),
                  ),
                );
              },
              child: const Text('See All'),
            ),
          ],
        ),
        
        const SizedBox(height: 12),
        
        if (suggestedUsers.isEmpty) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 48,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No suggestions available',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Follow some people to get personalized suggestions',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DiscoverUsersScreen(),
                        ),
                      );
                    },
                    child: const Text('Discover People'),
                  ),
                ],
              ),
            ),
          ),
        ] else ...[
          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: suggestedUsers.length,
              itemBuilder: (context, index) {
                final user = suggestedUsers[index];
                return Container(
                  width: 160,
                  margin: const EdgeInsets.only(right: 12),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundImage: user.profilePicture != null
                                ? NetworkImage(user.profilePicture!)
                                : null,
                            child: user.profilePicture == null
                                ? Text(
                                    user.initials,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            user.displayName,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            user.formattedHandle,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Spacer(),
                          SizedBox(
                            width: double.infinity,
                            child: FollowButton(
                              user: user,
                              onFollowChanged: () {
                                // Refresh suggestions after following
                                followProvider.loadSuggestedUsers(refresh: true);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildQuickActionsSection(BuildContext context, FollowProvider followProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.search),
                title: const Text('Discover People'),
                subtitle: const Text('Find new people to follow'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DiscoverUsersScreen(),
                    ),
                  );
                },
              ),
              
              const Divider(height: 1),
              
              ListTile(
                leading: const Icon(Icons.people),
                title: const Text('My Followers'),
                subtitle: Text('${followProvider.getFollowStats(widget.currentUser.id)?.followersCount ?? 0} followers'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FollowersScreen(
                        userId: widget.currentUser.id,
                        userName: widget.currentUser.displayName,
                      ),
                    ),
                  );
                },
              ),
              
              const Divider(height: 1),
              
              ListTile(
                leading: const Icon(Icons.person_add),
                title: const Text('Following'),
                subtitle: Text('${followProvider.getFollowStats(widget.currentUser.id)?.followingCount ?? 0} following'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FollowingScreen(
                        userId: widget.currentUser.id,
                        userName: widget.currentUser.displayName,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatButton(
    BuildContext context, {
    required int count,
    required String label,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Text(
              _formatCount(count),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCount(int count) {
    if (count < 1000) {
      return count.toString();
    } else if (count < 1000000) {
      final k = count / 1000;
      return k % 1 == 0 ? '${k.toInt()}K' : '${k.toStringAsFixed(1)}K';
    } else {
      final m = count / 1000000;
      return m % 1 == 0 ? '${m.toInt()}M' : '${m.toStringAsFixed(1)}M';
    }
  }
}

/// Example of how to integrate the follow system in your main app
class FollowSystemIntegrationExample extends StatelessWidget {
  const FollowSystemIntegrationExample({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Add FollowProvider to your existing providers
        ChangeNotifierProvider(create: (_) => FollowProvider()),
        // ... other providers
      ],
      child: MaterialApp(
        title: 'Follow System Demo',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
        ),
        home: const FollowSystemDemoHome(),
        routes: {
          '/discover': (context) => const DiscoverUsersScreen(),
        },
      ),
    );
  }
}

class FollowSystemDemoHome extends StatelessWidget {
  const FollowSystemDemoHome({super.key});

  @override
  Widget build(BuildContext context) {
    // Example current user - replace with your actual user data
    final currentUser = User(
      id: 'current_user_id',
      email: 'user@example.com',
      handle: 'current_user',
      fullName: 'Current User',
      bio: 'This is the current user\'s bio',
      isDiscoverable: true,
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
      updatedAt: DateTime.now(),
      followerCount: 150,
      followingCount: 75,
    );

    return FollowSystemExample(currentUser: currentUser);
  }
}