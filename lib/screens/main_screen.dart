import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'lobby_screen.dart';
import 'calls_screen.dart';
import 'home_screen.dart';
import 'dialpad_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'archived_chats_screen.dart';
import 'connection_requests_screen.dart';
import 'friends_screen.dart';
import 'friend_requests_screen.dart';
import 'user_search_screen.dart';
import '../providers/theme_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/archive_settings_provider.dart';
import '../providers/username_provider.dart';
import '../models/friend_model.dart';
import '../services/connection_service.dart';
import '../services/friendship_service.dart';
import '../utils/svg_icons.dart';
import '../services/notification_service.dart';
import '../l10n/app_localizations.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 1; // Start with chat (middle tab)
  bool _hasCheckedNotifications = false;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  List<Friend> _filteredFriends = [];
  List<Friend> _allFriends = [];
  final ConnectionService _connectionService = ConnectionService.instance;
  final FriendshipService _friendshipService = FriendshipService.instance;
  int _pendingRequestsCount = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const LobbyScreen(), // This is the chat screen
    const CallsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _allFriends = Friend.getDemoFriends();
    _filteredFriends = _allFriends;
    _initializeMainScreen();
    _loadPendingRequests();
    _initializeProviders();
    
    // Listen to connection request updates
    _connectionService.connectionRequestsStream.listen((requests) {
      if (mounted) {
        setState(() {
          _pendingRequestsCount = _connectionService.getPendingRequests().length;
        });
      }
    });
  }

  void _loadPendingRequests() {
    setState(() {
      _pendingRequestsCount = _connectionService.getPendingRequests().length;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initializeMainScreen() async {
    // Optimize initialization - remove delays and make it faster
    if (mounted && !_hasCheckedNotifications) {
      // Check notifications in background without blocking UI
      _checkNotificationPermissions();
    }
  }

  Future<void> _checkNotificationPermissions() async {
    try {
      _hasCheckedNotifications = true;
      
      final notificationService = NotificationService.instance;
      await notificationService.initialize();
      
      // Only show dialog if permission is not granted and not permanently denied
      if (await notificationService.shouldRequestPermission()) {
        if (mounted) {
          await notificationService.showPermissionDialog(context);
        }
      } else if (await notificationService.isPermanentlyDenied()) {
        // Show a subtle snackbar for permanently denied
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.white, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Enable notifications in Settings for the best experience',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
              action: SnackBarAction(
                label: 'Settings',
                textColor: Colors.white,
                onPressed: () => notificationService.openAppSettings(),
              ),
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error checking notification permissions: $e');
      // Continue silently - don't disrupt user experience
    }
  }

  Future<void> _initializeProviders() async {
    try {
      // Force reload the username provider to ensure it has the latest data
      final usernameProvider = Provider.of<UsernameProvider>(context, listen: false);
      await usernameProvider.reloadHandle();
    } catch (e) {
      debugPrint('Error initializing providers: $e');
    }
  }

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Consumer2<ChatProvider, ArchiveSettingsProvider>(
        builder: (context, chatProvider, archiveSettings, child) {
          return Container(
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
                
                // Archive option (if configured to show in top navbar)
                if (chatProvider.archivedChats.isNotEmpty && 
                    archiveSettings.archiveButtonPosition == ArchiveButtonPosition.topNavbarMoreOptions)
                  ListTile(
                    leading: Icon(Icons.archive, color: Theme.of(context).colorScheme.onSurface),
                    title: Text('Archived (${chatProvider.archivedChats.length})'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ArchivedChatsScreen(),
                        ),
                      );
                    },
                  ),
                
                // Theme toggle switch
                Consumer<ThemeProvider>(
                  builder: (context, themeProvider, child) {
                    return ListTile(
                      leading: SvgIcons.theme(
                        isDark: themeProvider.isDarkMode,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      title: Text(AppLocalizations.of(context)!.darkMode),
                      trailing: Switch(
                        value: themeProvider.isDarkMode,
                        onChanged: (value) => themeProvider.toggleTheme(),
                      ),
                    );
                  },
                ),
                // Profile button
                ListTile(
                  leading: SvgIcons.medium(SvgIcons.profile, color: Theme.of(context).colorScheme.onSurface),
                  title: const Text('Profile'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ProfileScreen(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: SvgIcons.medium(SvgIcons.settings, color: Theme.of(context).colorScheme.onSurface),
                  title: const Text('Settings'),
                  onTap: () {
                    Navigator.pop(context);
                    _showSettingsMenu();
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _performSearch(String query) {
    final trimmedQuery = query.toLowerCase().trim();
    
    setState(() {
      _isSearching = trimmedQuery.isNotEmpty;
      
      if (trimmedQuery.isEmpty) {
        _filteredFriends = _allFriends;
      } else {
        _filteredFriends = _allFriends.where((friend) {
          return friend.name.toLowerCase().contains(trimmedQuery) ||
                 friend.virtualNumber.toLowerCase().contains(trimmedQuery);
        }).toList();
      }
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _isSearching = false;
      _filteredFriends = _allFriends;
    });
  }

  void _onAddPressed() {
    String action = '';
    switch (_currentIndex) {
      case 0:
        action = 'Add new contact';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$action functionality coming soon!')),
        );
        break;
      case 1:
        action = 'Start new chat';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$action functionality coming soon!')),
        );
        break;
      case 2:
        // For calls tab, show dialpad
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const DialpadScreen(),
          ),
        );
        break;
    }
  }

  void _onDialpadPressed() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const DialpadScreen(),
      ),
    );
  }

  void _showSettingsMenu() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SettingsScreen(),
      ),
    );
  }

  String _getSearchPlaceholder() {
    switch (_currentIndex) {
      case 0:
        return 'Search...';
      case 1:
        return 'Search chats...';
      case 2:
        return 'Search contacts...';
      default:
        return 'Search...';
    }
  }

  bool _checkArchiveTrigger(String searchText) {
    final archiveSettings = Provider.of<ArchiveSettingsProvider>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    
    // Only check trigger if archive button is hidden and there are archived chats
    if (archiveSettings.archiveButtonPosition == ArchiveButtonPosition.hidden &&
        chatProvider.archivedChats.isNotEmpty &&
        searchText.trim().toLowerCase() == archiveSettings.archiveSearchTrigger.trim().toLowerCase()) {
      
      // Clear search field and navigate to archived chats
      _searchController.clear();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const ArchivedChatsScreen(),
        ),
      );
      return true;
    }
    return false;
  }

  Widget _buildSearchResults() {
    if (_filteredFriends.isEmpty) {
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
              'No friends found',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _filteredFriends.length,
      itemBuilder: (context, index) {
        final friend = _filteredFriends[index];
        return _buildFriendTile(friend);
      },
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
            Stack(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  child: friend.avatar != null
                      ? ClipOval(
                          child: Image.network(
                            friend.avatar!,
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Text(
                          friend.name.split(' ').map((e) => e[0]).take(2).join(),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                ),
                if (friend.isOnline)
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: Container(
                      width: 14,
                      height: 14,
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
            
            // Friend Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        friend.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_currentIndex == 1) // Chat tab
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
                          _currentIndex == 1 // Chat tab
                              ? friend.lastMessage
                              : friend.virtualNumber,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_currentIndex == 1 && friend.unreadCount > 0) // Chat tab with unread
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
                      if (_currentIndex == 2) // Calls tab
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

  void _onFriendTap(Friend friend) {
    // Clear search first
    _clearSearch();
    
    if (_currentIndex == 1) { // Chat tab
      // Navigate to chat screen
      Navigator.pushNamed(context, '/chat', arguments: friend);
    } else if (_currentIndex == 2) { // Calls tab
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
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  child: Text(
                    friend.name.split(' ').map((e) => e[0]).take(2).join(),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        friend.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        friend.virtualNumber,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
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
        elevation: 0,
        automaticallyImplyLeading: false, // Remove default back button
        title: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Boofer',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).brightness == Brightness.light 
                  ? Theme.of(context).colorScheme.primary 
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        titleSpacing: 16, // Add some padding from the left edge
        actions: [
          // Friends button - combines all friend-related functionality
          Container(
            width: 48,
            height: 48,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            child: Stack(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.people,
                    color: Theme.of(context).appBarTheme.foregroundColor ?? Colors.white,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const UserSearchScreen(),
                      ),
                    );
                  },
                  tooltip: 'Find friends',
                ),
                if (_pendingRequestsCount > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        '$_pendingRequestsCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // More options button
          Container(
            width: 48,
            height: 48,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            child: IconButton(
              icon: SvgIcons.more(
                horizontal: false,
                color: Theme.of(context).appBarTheme.foregroundColor ?? Colors.white,
              ),
              onPressed: _showMoreOptions,
              tooltip: 'More options',
            ),
          ),
          const SizedBox(width: 4), // Reduced padding from the right edge
        ],
      ),
      body: Column(
        children: [
          // Search bar below navbar
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).appBarTheme.backgroundColor ?? Theme.of(context).colorScheme.primary,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: _getSearchPlaceholder(),
                hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                prefixIcon: Icon(Icons.search, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                        onPressed: _clearSearch,
                      )
                    : null,
                filled: true,
                fillColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              onChanged: (value) {
                setState(() {});
                // Don't perform search automatically - only show/hide clear button
              },
              onSubmitted: (value) {
                if (value.isNotEmpty) {
                  // Check for archive trigger first
                  if (_checkArchiveTrigger(value)) {
                    return; // Archive screen opened, don't proceed with normal search
                  }
                  // Perform contact search
                  _performSearch(value);
                }
              },
            ),
          ),
          // Main content
          Expanded(
            child: _isSearching 
                ? _buildSearchResults() 
                : _screens[_currentIndex]
          ),
        ],
      ),
      bottomNavigationBar: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            type: BottomNavigationBarType.fixed,
            selectedItemColor: Theme.of(context).colorScheme.primary,
            unselectedItemColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            items: [
              BottomNavigationBarItem(
                icon: SvgIcons.home(
                  filled: false,
                  context: context,
                  color: _currentIndex == 0 
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                activeIcon: SvgIcons.home(
                  filled: true,
                  context: context,
                  color: Theme.of(context).colorScheme.primary,
                ),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: SvgIcons.chat(
                  filled: false,
                  context: context,
                  color: _currentIndex == 1 
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                activeIcon: SvgIcons.chat(
                  filled: true,
                  context: context,
                  color: Theme.of(context).colorScheme.primary,
                ),
                label: 'Chats',
              ),
              BottomNavigationBarItem(
                icon: SvgIcons.call(
                  filled: false,
                  context: context,
                  color: _currentIndex == 2 
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                activeIcon: SvgIcons.call(
                  filled: true,
                  context: context,
                  color: Theme.of(context).colorScheme.primary,
                ),
                label: 'Calls',
              ),
            ],
          );
        },
      ),
      floatingActionButton: _currentIndex == 2 
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Dialpad FAB (smaller)
                FloatingActionButton.small(
                  onPressed: _onDialpadPressed,
                  heroTag: 'dialpad',
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  child: SvgIcons.sized(SvgIcons.dialpad, 20, color: Colors.white),
                ),
                const SizedBox(height: 16),
                // Main FAB (same size as other tabs)
                FloatingActionButton(
                  onPressed: _onAddPressed,
                  heroTag: 'add',
                  child: SvgIcons.sized(SvgIcons.addCall, 24, color: Colors.white),
                ),
              ],
            )
          : FloatingActionButton(
              onPressed: _onAddPressed,
              child: _currentIndex == 1 
                  ? SvgIcons.sized(SvgIcons.addChat, 24, color: Colors.white)
                  : SvgIcons.sized(SvgIcons.add, 24, color: Colors.white),
            ),
    );
  }
}