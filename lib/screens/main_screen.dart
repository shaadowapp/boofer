import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'lobby_screen.dart';
import 'calls_screen.dart';
import 'home_screen.dart';
import 'search_screen.dart';
import 'dialpad_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'help_screen.dart';
import 'about_screen.dart';
import '../providers/theme_provider.dart';
import '../models/friend_model.dart';
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

  final List<Widget> _screens = [
    const HomeScreen(),
    const LobbyScreen(), // This is the chat screen
    const CallsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _initializeMainScreen();
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

  void _showMoreOptions() {
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
            // Theme toggle switch
            Consumer<ThemeProvider>(
              builder: (context, themeProvider, child) {
                return ListTile(
                  leading: SvgIcons.theme(
                    isDark: themeProvider.isDarkMode,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  title: Text(AppLocalizations.of(context)!.themeToggle),
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
            ListTile(
              leading: SvgIcons.medium(SvgIcons.help, color: Theme.of(context).colorScheme.onSurface),
              title: const Text('Help'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const HelpScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: SvgIcons.medium(SvgIcons.info, color: Theme.of(context).colorScheme.onSurface),
              title: const Text('About'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AboutScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _onSearchPressed() {
    final friends = Friend.getDemoFriends();
    SearchType searchType;
    
    switch (_currentIndex) {
      case 0:
        // Home screen - general search
        searchType = SearchType.chat;
        break;
      case 1:
        // Chat screen - search for friends to chat
        searchType = SearchType.chat;
        break;
      case 2:
        // Calls screen - search for friends to call
        searchType = SearchType.call;
        break;
      default:
        searchType = SearchType.chat;
    }
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SearchScreen(
          searchType: searchType,
          friends: friends,
        ),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false, // Remove default back button
        title: const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Boofer',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        titleSpacing: 16, // Add some padding from the left edge
        actions: [
          // More options button
          Container(
            width: 48,
            height: 48,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            child: IconButton(
              icon: SvgIcons.more(
                horizontal: false,
                color: Colors.white,
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
            color: Theme.of(context).colorScheme.primary,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search...',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                prefixIcon: Icon(Icons.search, color: Colors.white.withValues(alpha: 0.7)),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: Colors.white.withValues(alpha: 0.7)),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              style: const TextStyle(color: Colors.white),
              onChanged: (value) {
                setState(() {});
              },
              onSubmitted: (value) {
                if (value.isNotEmpty) {
                  _onSearchPressed();
                }
              },
            ),
          ),
          // Main content
          Expanded(child: _screens[_currentIndex]),
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
                label: 'Chat',
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