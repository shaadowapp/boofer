import 'package:flutter/material.dart';
import '../models/friend_model.dart';
import '../utils/svg_icons.dart';
import '../widgets/user_profile_card.dart';

class SearchScreen extends StatefulWidget {
  final SearchType searchType;
  final List<Friend> friends;

  const SearchScreen({
    super.key,
    required this.searchType,
    required this.friends,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Friend> _filteredFriends = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _filteredFriends = widget.friends;
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    // Don't perform search automatically - wait for user to press Enter
    setState(() {
      _isSearching = _searchController.text.trim().isNotEmpty;
    });
  }

  void _performSearch() {
    final query = _searchController.text.toLowerCase().trim();
    
    setState(() {
      _isSearching = query.isNotEmpty;
      
      if (query.isEmpty) {
        _filteredFriends = widget.friends;
      } else {
        _filteredFriends = widget.friends.where((friend) {
          return friend.name.toLowerCase().contains(query) ||
                 friend.virtualNumber.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  void _onFriendTap(Friend friend) {
    Navigator.pop(context);
    
    if (widget.searchType == SearchType.chat) {
      // Navigate to chat screen
      Navigator.pushNamed(context, '/chat', arguments: friend);
    } else if (widget.searchType == SearchType.call) {
      // Show call options
      _showCallOptions(friend);
    }
  }

  void _showCallOptions(Friend friend) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            // Friend info
            Row(
              children: [
                UserProfileCard(
                  user: friend.toUser(),
                  isCurrentUser: false,
                  showVirtualNumber: true,
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Call options
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _makeCall(friend, false);
                    },
                    icon: SvgIcons.sized(
                      SvgIcons.voiceCall, 
                      20,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                    label: const Text('Voice Call'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _makeCall(friend, true);
                    },
                    icon: SvgIcons.sized(
                      SvgIcons.videoCall, 
                      20,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                    label: const Text('Video Call'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _makeCall(Friend friend, bool isVideo) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${isVideo ? 'Video' : 'Voice'} calling ${friend.name}...'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return 'now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else {
      return '${time.day}/${time.month}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: TextField(
          controller: _searchController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: widget.searchType == SearchType.chat 
                ? 'Search friends to chat...' 
                : 'Search friends to call...',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
            border: InputBorder.none,
            suffixIcon: _isSearching
                ? IconButton(
                    icon: SvgIcons.sized(SvgIcons.clear, 24, color: Colors.white),
                    onPressed: () {
                      _searchController.clear();
                      _performSearch();
                    },
                  )
                : null,
          ),
          onSubmitted: (value) {
            _performSearch();
          },
        ),
      ),
      body: _filteredFriends.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SvgIcons.sized(
                    _isSearching ? SvgIcons.searchOff : SvgIcons.peopleOutline,
                    64,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isSearching ? 'No friends found' : 'Type and press Enter to search friends',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _filteredFriends.length,
              itemBuilder: (context, index) {
                final friend = _filteredFriends[index];
                return _buildFriendTile(friend);
              },
            ),
    );
  }

  Widget _buildFriendTile(Friend friend) {
    return InkWell(
      onTap: () => _onFriendTap(friend),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context).dividerColor.withOpacity(0.3),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            // Avatar
            UserProfileCard(
              user: friend.toUser(),
              isCurrentUser: false,
              showVirtualNumber: false,
              compact: true,
            ),
            
            const SizedBox(width: 16),
            
            // Friend Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        friend.fullName,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (widget.searchType == SearchType.chat)
                        Text(
                          _formatTime(friend.lastMessageTime),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: friend.unreadCount > 0
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                            fontWeight: friend.unreadCount > 0
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          widget.searchType == SearchType.chat
                              ? friend.lastMessage
                              : friend.virtualNumber,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (widget.searchType == SearchType.chat && friend.unreadCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            friend.unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (widget.searchType == SearchType.call)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: SvgIcons.sized(
                                SvgIcons.voiceCall, 
                                20,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              onPressed: () => _makeCall(friend, false),
                            ),
                            IconButton(
                              icon: SvgIcons.sized(
                                SvgIcons.videoCall, 
                                20,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              onPressed: () => _makeCall(friend, true),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum SearchType { chat, call }