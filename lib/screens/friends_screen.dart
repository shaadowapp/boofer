import 'dart:async';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/friend_request_service.dart';
import '../services/user_service.dart';
import '../widgets/enhanced_user_profile_card.dart';
import 'friend_chat_screen.dart';
import 'user_search_screen.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final FriendRequestService _friendRequestService =
      FriendRequestService.instance;
  List<User> _friends = [];
  bool _loading = true;
  String? _currentUserId;
  late StreamSubscription<List<User>> _friendsSubscription;

  @override
  void initState() {
    super.initState();
    _loadFriends();

    // Listen to friends updates
    _friendsSubscription = _friendRequestService.friendsStream.listen((
      friends,
    ) {
      if (mounted) {
        setState(() {
          _friends = friends;
          _loading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _friendsSubscription.cancel();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    final currentUser = await UserService.getCurrentUser();
    if (currentUser == null) return;

    setState(() {
      _currentUserId = currentUser.id;
      _loading = true;
    });

    _friendRequestService.listenToFriends(currentUser.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Friends (${_friends.length})'),
        elevation: 0,
        actions: [
          IconButton(onPressed: _loadFriends, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_friends.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No friends yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Search for users and send friend requests to start chatting',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                // Navigate to search screen
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const UserSearchScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.search),
              label: const Text('Discover'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFriends,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _friends.length,
        itemBuilder: (context, index) {
          final friend = _friends[index];
          return _buildFriendTile(friend);
        },
      ),
    );
  }

  Widget _buildFriendTile(User friend) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          // Using the enhanced profile card in list style
          EnhancedUserProfileCard(
            user: friend,
            style: ProfileCardStyle.list,
            onTap: () => _openChat(friend),
            showFollowButton: true,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openChat(friend),
                  icon: const Icon(Icons.chat, size: 18),
                  label: const Text('Message'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _startCall(friend),
                  icon: const Icon(Icons.call, size: 18),
                  label: const Text('Call'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openChat(User friend) {
    if (_currentUserId == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FriendChatScreen(
          recipientId: friend.id,
          recipientName: friend.displayName,
        ),
      ),
    );
  }

  void _startCall(User friend) {
    // Implement call functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Calling ${friend.displayName}...'),
        backgroundColor: Colors.green,
      ),
    );
  }
}
