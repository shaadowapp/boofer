import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';
import '../services/follow_service.dart';
import '../widgets/unified_friend_card.dart';
import 'friend_chat_screen.dart';
import '../services/chat_cache_service.dart';

class StartNewChatScreen extends StatefulWidget {
  const StartNewChatScreen({super.key});

  @override
  State<StartNewChatScreen> createState() => _StartNewChatScreenState();
}

class _StartNewChatScreenState extends State<StartNewChatScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<User> _allUsers = [];
  List<User> _filteredUsers = [];
  User? _currentUser;
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    if (!mounted) return;

    final cacheService = ChatCacheService.instance;
    _currentUser = await UserService.getCurrentUser();

    if (_currentUser == null) return;

    // STEP 1: Load from cache first (instant UI)
    final cachedData = await cacheService.getCachedStartChatUsers(
      _currentUser!.id,
    );
    if (cachedData.isNotEmpty && mounted) {
      setState(() {
        _allUsers = cachedData.map((json) {
          return User(
            id: json['profile_id'],
            email: '',
            handle: json['handle'],
            fullName: json['name'],
            bio: json['bio'] ?? '',
            avatar: json['avatar'],
            virtualNumber: json['virtual_number'],
            status: json['status'] == 'online'
                ? UserStatus.online
                : UserStatus.offline,
            isDiscoverable: true,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
        }).toList();
        _filterUsers(_searchQuery);
        _isLoading = false;
      });
      print('✅ Loaded ${_allUsers.length} users from Start Chat cache');
    }

    // STEP 2: Check Throttling/Validity
    if (!forceRefresh) {
      final isCacheValid = await cacheService.isStartChatCacheValid();
      if (isCacheValid && _allUsers.isNotEmpty) {
        print('✅ Start Chat cache is fresh, skipping network call');
        return;
      }
    } else {
      final isThrottled = await cacheService.isStartChatRefreshThrottled();
      if (isThrottled) {
        print('⏳ Start Chat refresh throttled.');
        return;
      }
    }

    // STEP 3: Fetch from network
    if (_allUsers.isEmpty) {
      setState(() => _isLoading = true);
    }

    try {
      final followService = FollowService.instance;

      // Fetch both followers and following
      final results = await Future.wait([
        followService.getFollowing(userId: _currentUser!.id, limit: 1000),
        followService.getFollowers(userId: _currentUser!.id, limit: 1000),
      ]);

      final following = results[0];
      final followers = results[1];

      // Combine into a unique list of users (friends = union of following + followers)
      final Map<String, User> uniqueUsers = {};
      for (var user in following) uniqueUsers[user.id] = user;
      for (var user in followers) uniqueUsers[user.id] = user;

      _allUsers = uniqueUsers.values.toList();

      // Sort alphabetically
      _allUsers.sort(
        (a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
      );

      // Update cache
      await cacheService.cacheStartChatUsers(
        _currentUser!.id,
        _allUsers
            .map(
              (u) => {
                'id': u.id,
                'full_name': u.fullName,
                'handle': u.handle,
                'bio': u.bio,
                'profile_picture': u.profilePicture,
                'avatar': u.avatar,
                'virtual_number': u.virtualNumber,
                'status': u.status == UserStatus.online ? 'online' : 'offline',
              },
            )
            .toList(),
      );

      if (mounted) {
        setState(() {
          _filterUsers(_searchQuery);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading users for new chat: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _filterUsers(query);
    });
  }

  void _filterUsers(String query) {
    if (query.isEmpty) {
      _filteredUsers = List.from(_allUsers);
    } else {
      final q = query.toLowerCase();
      _filteredUsers = _allUsers.where((user) {
        return user.fullName.toLowerCase().contains(q) ||
            user.handle.toLowerCase().contains(q) ||
            (user.virtualNumber?.toLowerCase().contains(q) ?? false);
      }).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Start New Chat',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search friends, handle or number...',
                prefixIcon: const Icon(Icons.search, size: 22),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.4),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _loadData(forceRefresh: true),
              child: ListView.builder(
                itemCount:
                    (_searchQuery.isEmpty ? 1 : 0) + _filteredUsers.length,
                itemBuilder: (context, index) {
                  if (_searchQuery.isEmpty && index == 0) {
                    return _buildYouItem();
                  }

                  final userIndex = _searchQuery.isEmpty ? index - 1 : index;
                  final user = _filteredUsers[userIndex];

                  return UnifiedFriendCard(
                    user: user,
                    showMessageButton: true,
                    showBio: true,
                    onTap: () => _startChat(user),
                  );
                },
              ),
            ),
    );
  }

  Widget _buildYouItem() {
    if (_currentUser == null) return const SizedBox.shrink();

    // Create a special self-user for "You"
    final youUser = User(
      id: _currentUser!.id,
      email: _currentUser!.email,
      handle: _currentUser!.handle,
      fullName: 'You (${_currentUser!.fullName})',
      bio: 'Message yourself',
      avatar: _currentUser!.avatar,
      profilePicture: _currentUser!.profilePicture,
      isDiscoverable: true,
      createdAt: _currentUser!.createdAt,
      updatedAt: _currentUser!.updatedAt,
      status: UserStatus.online,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UnifiedFriendCard(
          user: youUser,
          showMessageButton: true,
          showBio: true,
          showHandle: false,
          onTap: () => _startChat(youUser),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'CONTACTS ON BOOFER',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ],
    );
  }

  void _startChat(User user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FriendChatScreen(
          recipientId: user.id,
          recipientName: user.id == _currentUser?.id
              ? user.fullName
              : user.displayName,
          recipientHandle: user.handle,
          recipientAvatar: user.profilePicture ?? user.avatar ?? '',
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
