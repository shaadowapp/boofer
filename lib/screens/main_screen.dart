import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
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
import 'write_post_screen.dart';
import '../providers/theme_provider.dart';
import '../providers/auth_state_provider.dart';
import '../providers/firestore_user_provider.dart';
import '../services/user_service.dart';
import '../services/local_storage_service.dart';
import '../models/user_model.dart';
import '../providers/chat_provider.dart';
import '../providers/archive_settings_provider.dart';
import '../providers/username_provider.dart';
import '../models/friend_model.dart';
import '../services/connection_service.dart';
import '../services/friendship_service.dart';
import '../services/google_auth_service.dart';
import '../utils/svg_icons.dart';
import '../services/notification_service.dart';
import '../widgets/profile_completion_modal.dart';
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
  List<User> _filteredUsers = [];
  List<User> _allUsers = [];
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

    // Check if we need to show profile completion modal
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowProfileCompletion();
    });
  }

  Future<void> _checkAndShowProfileCompletion() async {
    try {
      // Check if profile completion modal was recently dismissed
      final lastDismissed = await LocalStorageService.getString('profile_modal_last_dismissed');
      if (lastDismissed != null) {
        final dismissedTime = DateTime.tryParse(lastDismissed);
        if (dismissedTime != null) {
          final timeSinceDismissed = DateTime.now().difference(dismissedTime);
          if (timeSinceDismissed.inHours < 24) {
            print('ℹ️ Profile completion modal was dismissed recently, skipping');
            return;
          }
        }
      }

      // Check if user just signed in and needs profile completion
      final authProvider = context.read<AuthStateProvider>();
      if (authProvider.isAuthenticated) {
        final currentUser = authProvider.currentUser;
        if (currentUser != null) {
          // Get user profile and type from local storage
          final userType = await LocalStorageService.getString('user_type');
          final profileCompleted = await LocalStorageService.getString('profile_completed');
          
          print('👤 User type: $userType');
          print('✅ Profile completed: $profileCompleted');
          
          // Get user profile using UserService (which handles custom IDs)
          final userProfile = await UserService.getCurrentUser();
          
          if (userProfile != null && mounted) {
            print('✅ User profile found: ${userProfile.fullName} (ID: ${userProfile.id})');
            
            // Check if profile needs completion
            final needsCompletion = _shouldShowProfileCompletion(
              userType: userType,
              profileCompleted: profileCompleted == 'true',
              userProfile: userProfile,
            );
            
            // If profile appears complete but isn't marked as such, mark it automatically
            if (!needsCompletion && profileCompleted != 'true' && _isProfileActuallyComplete(userProfile)) {
              print('✅ Profile appears complete, marking as completed automatically');
              await LocalStorageService.setString('profile_completed', 'true');
              await LocalStorageService.setString('user_type', 'completed_user');
            }
            
            if (needsCompletion) {
              // Show profile completion modal after a short delay
              Future.delayed(Duration(milliseconds: 800), () {
                if (mounted) {
                  _showProfileCompletionModal(userProfile);
                }
              });
            } else {
              print('ℹ️ Profile completion not needed for this user');
            }
          } else {
            print('❌ No user profile found - user may need to sign in again');
            
            // If no user profile exists but user is authenticated,
            // they may need to complete the signup process
            if (userType == 'new_signup' || userType == null) {
              print('🔄 Attempting to create user profile from Firebase auth...');
              await _handleMissingUserProfile(currentUser);
            }
          }
        }
      }
    } catch (e) {
      print('❌ Error checking profile completion: $e');
      // Continue silently
    }
  }

  /// Handle case where user is authenticated but has no profile data
  Future<void> _handleMissingUserProfile(firebase_auth.User firebaseUser) async {
    try {
      print('🔄 Creating missing user profile...');
      
      final googleAuthService = GoogleAuthService();
      
      // Try to restore user session or create new profile
      final restoredUser = await googleAuthService.restoreUserSession();
      
      if (restoredUser != null) {
        print('✅ User session restored: ${restoredUser.fullName}');
        
        // Check if profile completion is needed
        final needsCompletion = _shouldShowProfileCompletion(
          userType: 'restored_user',
          profileCompleted: false,
          userProfile: restoredUser,
        );
        
        if (needsCompletion && mounted) {
          Future.delayed(Duration(milliseconds: 800), () {
            if (mounted) {
              _showProfileCompletionModal(restoredUser);
            }
          });
        }
      } else {
        print('❌ Could not restore user session - user may need to sign in again');
      }
    } catch (e) {
      print('❌ Error handling missing user profile: $e');
    }
  }

  /// Determine if profile completion modal should be shown
  bool _shouldShowProfileCompletion({
    String? userType,
    bool profileCompleted = false,
    required User userProfile,
  }) {
    // Never show for completed profiles
    if (profileCompleted) {
      print('✅ Profile already completed - skipping modal');
      return false;
    }

    // Always show for new signups
    if (userType == 'new_signup') {
      print('🆕 New signup detected - showing profile completion');
      return true;
    }
    
    // For existing users, only show if profile is genuinely incomplete
    // Check multiple indicators to avoid false positives
    
    int incompleteCount = 0;
    
    // Check if user has auto-generated handle (heuristic for incomplete profile)
    if (userProfile.handle.contains('_') && userProfile.handle.length > 15) {
      incompleteCount++;
      print('🔧 Auto-generated handle detected');
    }
    
    // Check if user has default bio
    if (userProfile.bio == 'Hey there! I\'m using Boofer 👋') {
      incompleteCount++;
      print('📝 Default bio detected');
    }
    
    // Check if user doesn't have virtual number
    if (userProfile.virtualNumber == null || userProfile.virtualNumber!.isEmpty) {
      incompleteCount++;
      print('🆔 No virtual number detected');
    }
    
    // Check if full name is very short or looks auto-generated
    if (userProfile.fullName.length < 3 || userProfile.fullName.contains('User')) {
      incompleteCount++;
      print('👤 Incomplete full name detected');
    }
    
    // Only show modal if multiple indicators suggest incomplete profile
    final shouldShow = incompleteCount >= 2;
    
    if (shouldShow) {
      print('📝 Profile appears incomplete ($incompleteCount indicators) - showing completion modal');
    } else {
      print('✅ Profile appears complete enough - skipping modal');
    }
    
    return shouldShow;
  }

  /// Check if profile is actually complete (has all required fields properly filled)
  bool _isProfileActuallyComplete(User userProfile) {
    // Check if all essential fields are properly filled
    final hasProperName = userProfile.fullName.isNotEmpty && 
                         userProfile.fullName.length >= 3 && 
                         !userProfile.fullName.contains('User');
    
    final hasProperHandle = userProfile.handle.isNotEmpty && 
                           !userProfile.handle.contains('_') && 
                           userProfile.handle.length < 15;
    
    final hasCustomBio = userProfile.bio.isNotEmpty && 
                        userProfile.bio != 'Hey there! I\'m using Boofer 👋';
    
    final hasVirtualNumber = userProfile.virtualNumber != null && 
                            userProfile.virtualNumber!.isNotEmpty;
    
    return hasProperName && hasProperHandle && hasCustomBio && hasVirtualNumber;
  }

  void _showProfileCompletionModal(User userProfile) {
    showDialog(
      context: context,
      barrierDismissible: false, // Cannot be dismissed
      barrierColor: Colors.transparent, // We handle the blur in the modal
      builder: (context) => ProfileCompletionModal(
        initialUser: userProfile,
        onCompleted: () {
          Navigator.of(context).pop(); // Close the modal
        },
      ),
    );
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
        _filteredUsers = _allUsers;
      } else {
        _filteredUsers = _allUsers.where((user) {
          return user.fullName.toLowerCase().contains(trimmedQuery) ||
                 user.handle.toLowerCase().contains(trimmedQuery) ||
                 (user.virtualNumber?.toLowerCase().contains(trimmedQuery) ?? false);
        }).toList();
      }
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _isSearching = false;
      _filteredUsers = _allUsers;
    });
  }

  void _onAddPressed() async {
    String action = '';
    switch (_currentIndex) {
      case 0:
        // Home tab - open write post screen
        try {
          final userProvider = context.read<FirestoreUserProvider>();
          final currentUser = userProvider.currentUser;
          
          if (currentUser != null && mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => WritePostScreen(currentUser: currentUser),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Please complete your profile first'),
              ),
            );
          }
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to open post creator. Please try again.'),
            ),
          );
        }
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
        return 'Search Boofer...';
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
    if (_filteredUsers.isEmpty) {
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
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _filteredUsers.length,
      itemBuilder: (context, index) {
        final user = _filteredUsers[index];
        return _buildUserTile(user);
      },
    );
  }

  Widget _buildUserTile(User user) {
    return InkWell(
      onTap: () => _onUserTap(user),
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
                  backgroundImage: user.profilePicture != null
                      ? NetworkImage(user.profilePicture!)
                      : null,
                  child: user.profilePicture == null
                      ? Text(
                          user.fullName.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase(),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        )
                      : null,
                ),
                if (user.status == UserStatus.online)
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
            
            // User Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          user.fullName,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_currentIndex == 1) // Chat tab
                        Text(
                          _formatTime(user.lastSeen ?? user.updatedAt),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
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
                              ? '@${user.handle}'
                              : user.virtualNumber ?? '@${user.handle}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
                              onPressed: () => _makeCall(user, false),
                            ),
                            IconButton(
                              icon: SvgIcons.sized(
                                SvgIcons.videoCall, 
                                20,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              onPressed: () => _makeCall(user, true),
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

  void _onUserTap(User user) {
    // Clear search first
    _clearSearch();
    
    if (_currentIndex == 1) { // Chat tab
      // Navigate to chat screen with user
      Navigator.pushNamed(context, '/chat', arguments: user);
    } else if (_currentIndex == 2) { // Calls tab
      // Show call options
      _showCallOptions(user);
    }
  }

  void _showCallOptions(User user) {
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
            // User info
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  backgroundImage: user.profilePicture != null
                      ? NetworkImage(user.profilePicture!)
                      : null,
                  child: user.profilePicture == null
                      ? Text(
                          user.fullName.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase(),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary,
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
                        user.fullName,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        user.virtualNumber ?? '@${user.handle}',
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
                      _makeCall(user, false);
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
                      _makeCall(user, true);
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

  void _makeCall(User user, bool isVideo) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${isVideo ? 'Video' : 'Voice'} calling ${user.fullName}...'),
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
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        automaticallyImplyLeading: false, // Remove default back button
        title: Align(
          alignment: Alignment.centerLeft,
          child: SvgPicture.asset(
            'assets/images/logo/boofer-logo.svg', // Your SVG logo file
            height: 40, // Increased from 32 to 40
            width: 150, // Increased from 120 to 150
            // Removed colorFilter to show original logo colors
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
                  icon: SvgPicture.asset(
                    'assets/icons/find_users.svg',
                    width: 24,
                    height: 24,
                    colorFilter: ColorFilter.mode(
                      Theme.of(context).appBarTheme.foregroundColor ?? Colors.white,
                      BlendMode.srcIn,
                    ),
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
            color: Theme.of(context).appBarTheme.backgroundColor,
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
                : Consumer<FirestoreUserProvider>(
                    builder: (context, userProvider, child) {
                      // Update local users list when Firestore data changes
                      _allUsers = userProvider.allUsers;
                      _filteredUsers = _allUsers;
                      
                      return _screens[_currentIndex];
                    },
                  )
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