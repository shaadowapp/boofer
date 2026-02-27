import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'lobby_screen.dart';
import 'calls_screen.dart';
// import 'home_screen.dart';
import 'dialpad_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'archived_chats_screen.dart';
import 'user_search_screen.dart';
import '../providers/theme_provider.dart';
import '../providers/appearance_provider.dart';

import '../providers/auth_state_provider.dart';
import '../providers/follow_provider.dart';
import '../services/user_service.dart';
import '../services/local_storage_service.dart';
import '../services/profile_picture_service.dart';
import '../models/user_model.dart';
import '../providers/chat_provider.dart';
import '../providers/archive_settings_provider.dart';
import '../providers/username_provider.dart';
import '../utils/svg_icons.dart';
import '../services/notification_service.dart';
import '../services/follow_service.dart';
import '../l10n/app_localizations.dart';
import '../services/receive_share_service.dart';
import '../main.dart';
import '../widgets/fast_profile_switcher.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 1; // Start with chat (middle tab)
  bool _hasCheckedNotifications = false;
  StreamSubscription<String?>? _profilePictureSubscription; // Listen to profile picture changes
  String? _currentAvatar; // Store emoji avatar
  String? _currentAvatarColor; // Store emoji avatar color
  final int _baseIndex = 999999;
  late final PageController _pageController = PageController(
    initialPage: _baseIndex + _currentIndex,
  );
  Timer? _holdTimer;

  final List<Widget> _screens = [
    const ProfileScreen(), // Index 0
    const LobbyScreen(), // Index 1
  ];

  @override
  void initState() {
    super.initState();
    _initializeMainScreen();
    _initializeProviders();

    // Listen to profile picture updates (broadcast)
    _profilePictureSubscription = ProfilePictureService
        .instance
        .profilePictureStream
        .listen((profilePictureUrl) {
          if (mounted) {
            setState(() {});
          }
        });

    // Listen for current user updates from local storage/UserService
    UserService.getCurrentUser().then((user) {
      if (user != null && mounted) {
        setState(() {
          _currentAvatar = user.avatar;
        });
      }
    });

    // Initialize providers and load data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeUserData();
      // Process any pending share intent captured during splash
      ReceiveShareService.instance.init(BooferApp.navigatorKey);
    });
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _pageController.dispose();
    _profilePictureSubscription?.cancel();
    super.dispose();
  }

  void _onPageChanged(int index) {
    int navbarIndex = (index - _baseIndex) % _screens.length;
    if (_currentIndex != navbarIndex) {
      setState(() {
        _currentIndex = navbarIndex;
      });
      HapticFeedback.selectionClick();
    }
  }

  void _startHoldTimer() {
    _holdTimer?.cancel();
    _holdTimer = Timer(const Duration(seconds: 1), () {
      HapticFeedback.vibrate();
      FastProfileSwitcher.show(context, showAddButton: false);
    });
  }

  void _cancelHoldTimer() {
    _holdTimer?.cancel();
  }

  void _onTabTapped(int index) {
    if (_currentIndex == index) return;

    int currentPage =
        _pageController.page?.round() ?? (_baseIndex + _currentIndex);
    int currentOffset = (currentPage - _baseIndex) % _screens.length;
    int targetOffset = index;

    int diff = targetOffset - currentOffset;
    int totalScreens = _screens.length;
    if (diff > 1) diff -= totalScreens;
    if (diff < -1) diff += totalScreens;

    _pageController.animateToPage(
      currentPage + diff,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOutQuart,
    );
  }

  Future<void> _initializeUserData() async {
    try {
      // Get current user data
      final authProvider = context.read<AuthStateProvider>();
      if (authProvider.isAuthenticated) {
        final userProfile = await UserService.getCurrentUser();

        if (mounted && userProfile != null) {
          setState(() {
            _currentAvatar = userProfile.avatar;
          });

          // Ensure following Boofer Official
          FollowService.instance.ensureFollowingBoofer(userProfile.id);

          // Load avatar color from local storage
          final storedUserData = await LocalStorageService.getString(
            'current_user',
          );
          if (storedUserData != null) {
            try {
              final userJson = jsonDecode(storedUserData);
              final avatarColor = userJson['avatarColor'] as String?;
              if (mounted && avatarColor != null) {
                setState(() {
                  _currentAvatarColor = avatarColor;
                });
              }
            } catch (e) {
              // Error handled silently
            }
          }
        }

        // Initialize FollowProvider
        if (userProfile != null) {
          final followProvider = context.read<FollowProvider>();
          followProvider.initialize(userProfile.id);
        }
      }
    } catch (e) {
      // Error handled silently
    }
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
      final usernameProvider = Provider.of<UsernameProvider>(
        context,
        listen: false,
      );
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
                    archiveSettings.archiveButtonPosition ==
                        ArchiveButtonPosition.topNavbarMoreOptions)
                  ListTile(
                    leading: Icon(
                      Icons.archive,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    title: Text(
                      'Archived (${chatProvider.archivedChats.length})',
                    ),
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
                // Settings button
                ListTile(
                  leading: SvgIcons.medium(
                    SvgIcons.settings,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
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

  void _onAddPressed() async {
    switch (_currentIndex) {
      case 0:
        // Profile tab - No action
        break;
      case 1:
        // Lobby tab - Find new people
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const UserSearchScreen()),
        );
        break;
      case 2:
        // For calls tab, show dialpad
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const DialpadScreen()),
        );
        break;
    }
  }

  void _onDialpadPressed() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DialpadScreen()),
    );
  }

  void _showSettingsMenu() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }


  Widget _buildProfileIcon(bool isActive, String? profilePictureUrl) {
    const size = 24.0;
    final borderWidth = isActive ? 2.0 : 0.0;

    // Check if it's a real uploaded image (not UI-avatars generated)
    final hasRealProfilePicture =
        profilePictureUrl != null &&
        profilePictureUrl.isNotEmpty &&
        !profilePictureUrl.contains('ui-avatars.com');

    // Check if we have an emoji avatar
    final hasEmojiAvatar = _currentAvatar != null && _currentAvatar!.isNotEmpty;

    // Parse avatar color
    Color avatarBgColor = Theme.of(
      context,
    ).colorScheme.primary.withOpacity(0.2);
    if (_currentAvatarColor != null && _currentAvatarColor!.isNotEmpty) {
      try {
        avatarBgColor = Color(int.parse(_currentAvatarColor!, radix: 16));
      } catch (e) {
        // Error handled silently
      }
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: isActive
            ? Border.all(
                color: Theme.of(context).colorScheme.primary,
                width: borderWidth,
              )
            : null,
      ),
      child: ClipOval(
        child: hasRealProfilePicture && profilePictureUrl.startsWith('http')
            ? Image.network(
                profilePictureUrl,
                key: ValueKey(profilePictureUrl),
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildDefaultProfileIcon(isActive, size);
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return _buildDefaultProfileIcon(isActive, size);
                },
              )
            : hasEmojiAvatar
            ? Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [avatarBgColor, avatarBgColor.withOpacity(0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Text(
                    _currentAvatar!,
                    style: const TextStyle(fontSize: size * 0.5),
                  ),
                ),
              )
            : _buildDefaultProfileIcon(isActive, size),
      ),
    );
  }

  Widget _buildDefaultProfileIcon(bool isActive, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)
            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
      ),
      child: Icon(
        Icons.person,
        size: size * 0.6,
        color: isActive
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final navBarStyle = context.watch<AppearanceProvider>().navBarStyle;
    final extendBody =
        navBarStyle == NavBarStyle.ios ||
        navBarStyle == NavBarStyle.liquid ||
        navBarStyle == NavBarStyle.modern;

    return Scaffold(
      extendBody: extendBody,
      appBar: _currentIndex == 0
          ? null
          : PreferredSize(
              preferredSize: const Size.fromHeight(kToolbarHeight),
              child: Container(
                color: Theme.of(context).appBarTheme.backgroundColor,
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── Title row (WhatsApp-style) ──
                      SizedBox(
                        height: kToolbarHeight,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              Expanded(
                                child: SvgPicture.asset(
                                  'assets/images/logo/boofer-logo.svg',
                                  height: 36,
                                  alignment: Alignment.centerLeft,
                                ),
                              ),
                              // Discover
                              IconButton(
                                icon: SvgPicture.asset(
                                  'assets/icons/find_users.svg',
                                  width: 22,
                                  height: 22,
                                  colorFilter: ColorFilter.mode(
                                    Theme.of(
                                          context,
                                        ).appBarTheme.foregroundColor ??
                                        Colors.white,
                                    BlendMode.srcIn,
                                  ),
                                ),
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const UserSearchScreen(),
                                  ),
                                ),
                                tooltip: 'Discover',
                                padding: const EdgeInsets.all(8),
                                constraints: const BoxConstraints(),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: SvgIcons.more(
                                  horizontal: false,
                                  color:
                                      Theme.of(
                                        context,
                                      ).appBarTheme.foregroundColor ??
                                      Colors.white,
                                ),
                                onPressed: _showMoreOptions,
                                tooltip: 'More options',
                                padding: const EdgeInsets.all(8),
                                constraints: const BoxConstraints(),
                              ),
                              const SizedBox(width: 4),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
      body: PageView.builder(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              dragStartBehavior: DragStartBehavior.down,
              itemBuilder: (context, index) {
                int screenIndex = (index - _baseIndex) % _screens.length;
                return _screens[screenIndex];
              },
            ),
      bottomNavigationBar: Consumer<AppearanceProvider>(
        builder: (context, appearance, child) {
          return _buildNavBar(context, appearance.navBarStyle);
        },
      ),
      floatingActionButton: null,
    );
  }

  Widget _buildNavBar(BuildContext context, NavBarStyle style) {
    switch (style) {
      case NavBarStyle.simple:
        return _buildSimpleNavBar();
      case NavBarStyle.modern:
        return _buildModernNavBar();
      case NavBarStyle.ios:
        return _buildIOSNavBar();
      case NavBarStyle.bubble:
        return _buildBubbleNavBar();
      case NavBarStyle.liquid:
        return _buildLiquidNavBar();
      case NavBarStyle.genz:
        return _buildGenZNavBar();
    }
  }

  Widget _buildSimpleNavBar() {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: _onTabTapped,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Theme.of(context).colorScheme.primary,
      unselectedItemColor: Theme.of(
        context,
      ).colorScheme.onSurface.withValues(alpha: 0.6),
      elevation: 8,
      backgroundColor: Theme.of(context).colorScheme.surface,
      items: [
        BottomNavigationBarItem(
          icon: StreamBuilder<String?>(
            stream: ProfilePictureService.instance.profilePictureStream,
            initialData: ProfilePictureService.instance.currentProfilePicture,
            builder: (context, snapshot) =>
                _buildProfileIcon(false, snapshot.data),
          ),
          activeIcon: StreamBuilder<String?>(
            stream: ProfilePictureService.instance.profilePictureStream,
            initialData: ProfilePictureService.instance.currentProfilePicture,
            builder: (context, snapshot) => GestureDetector(
              onPanDown: (_) => _startHoldTimer(),
              onPanCancel: _cancelHoldTimer,
              onPanEnd: (_) => _cancelHoldTimer(),
              child: _buildProfileIcon(true, snapshot.data),
            ),
          ),
          label: 'You',
        ),
        BottomNavigationBarItem(
          icon: _buildChatIcon(
            false,
            Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          activeIcon: _buildChatIcon(
            true,
            Theme.of(context).colorScheme.primary,
          ),
          label: 'Chats',
        ),
      ],
    );
  }

  Widget _buildModernNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          height: 70,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildModernNavItem(
                index: 0,
                icon: GestureDetector(
                  onSecondaryTap: () {},
                  onPanDown: (_) => _startHoldTimer(),
                  onPanCancel: _cancelHoldTimer,
                  onPanEnd: (_) => _cancelHoldTimer(),
                  child: StreamBuilder<String?>(
                    stream: ProfilePictureService.instance.profilePictureStream,
                    initialData:
                        ProfilePictureService.instance.currentProfilePicture,
                    builder: (context, snapshot) {
                      return _buildProfileIcon(
                        _currentIndex == 0,
                        snapshot.data,
                      );
                    },
                  ),
                ),
                label: 'You',
                isProfile: true,
              ),
              _buildModernNavItem(
                index: 1,
                icon: _buildChatIcon(
                  _currentIndex == 1,
                  _currentIndex == 1
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                label: 'Chats',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIOSNavBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 16,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildIOSNavItem(0, 'You', isProfile: true),
                _buildIOSNavItem(1, 'Chats'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIOSNavItem(int index, String label, {bool isProfile = false}) {
    final isSelected = _currentIndex == index;
    Widget icon;

    if (isProfile) {
      icon = StreamBuilder<String?>(
        stream: ProfilePictureService.instance.profilePictureStream,
        initialData: ProfilePictureService.instance.currentProfilePicture,
        builder: (context, snapshot) => GestureDetector(
          onPanDown: (_) => _startHoldTimer(),
          onPanCancel: _cancelHoldTimer,
          onPanEnd: (_) => _cancelHoldTimer(),
          child: _buildProfileIcon(false, snapshot.data),
        ),
      );
    } else {
      final color = isSelected
          ? Colors.white
          : Theme.of(context).colorScheme.onSurface;
      switch (label) {
        case 'Chats':
          icon = _buildChatIcon(isSelected, color);
          break;
        case 'Calls':
          icon = SvgIcons.call(
            filled: isSelected,
            context: context,
            color: color,
          );
          break;
        default:
          icon = const SizedBox();
      }
    }

    return GestureDetector(
      onTap: () => _onTabTapped(index),
      onPanDown: isProfile ? (_) => _startHoldTimer() : null,
      onPanCancel: isProfile ? _cancelHoldTimer : null,
      onPanEnd: isProfile ? (_) => _cancelHoldTimer() : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
          shape: BoxShape.circle,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: icon,
      ),
    );
  }

  Widget _buildLiquidNavBar() {
    final theme = Theme.of(context);
    final width = MediaQuery.of(context).size.width;
    final itemWidth = width / 2;

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _pageController,
        builder: (context, child) {
          final double page = _pageController.hasClients
              ? (_pageController.page ?? _baseIndex.toDouble())
              : (_baseIndex + _currentIndex).toDouble();
          final double normalizedPage = page % 2;

          return Container(
            height: 80,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  left: itemWidth * normalizedPage + (itemWidth - 56) / 2,
                  top: 12,
                  width: 56,
                  height: 56,
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                Row(
                  children: [
                    _buildLiquidNavItem(0, 'You', isProfile: true),
                    _buildLiquidNavItem(1, 'Chats'),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLiquidNavItem(
    int index,
    String label, {
    bool isProfile = false,
  }) {
    final isSelected = _currentIndex == index;
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;

    final double page = _pageController.hasClients
        ? (_pageController.page ?? _baseIndex.toDouble())
        : (_baseIndex + _currentIndex).toDouble();
    final double normalizedPage = page % 3;
    double distance = (index - normalizedPage).abs();

    // Handle wrap-around distance
    if (distance > 1.5) distance = (3 - distance).abs();

    // Scale and opacity could be used for animation effects
    // final double selectionFactor = (1.0 - distance.clamp(0.0, 1.0));
    // final double scale = 1.0 + (0.2 * selectionFactor);
    // final double opacity = isSelected ? 1.0 : selectionFactor;

    return Expanded(
      child: GestureDetector(
        onTap: () => _onTabTapped(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutBack,
              transform: isSelected
                  ? Matrix4.translationValues(0, -6, 0)
                  : Matrix4.identity(),
              child: isProfile
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: StreamBuilder<String?>(
                        stream:
                            ProfilePictureService.instance.profilePictureStream,
                        initialData: ProfilePictureService
                            .instance
                            .currentProfilePicture,
                        builder: (context, snapshot) =>
                            _buildProfileIcon(isSelected, snapshot.data),
                      ),
                    )
                  : label == 'Chats'
                  ? _buildChatIcon(isSelected, color)
                  : _getSvgIcon(label, isSelected, color),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: isSelected ? 16 : 0,
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: isSelected ? 1.0 : 0.0,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      label,
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _getSvgIcon(String label, bool isSelected, Color color) {
    switch (label) {
      case 'Chats':
        return SvgIcons.chat(
          filled: isSelected,
          context: context,
          color: color,
        );
      case 'Calls':
        return SvgIcons.call(
          filled: isSelected,
          context: context,
          color: color,
        );
      default:
        return const SizedBox();
    }
  }

  Widget _buildBubbleNavBar() {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _pageController,
        builder: (context, child) {
          return Container(
            color: Theme.of(context).colorScheme.surface,
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: SafeArea(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildBubbleNavItem(0, 'You', isProfile: true),
                  _buildBubbleNavItem(1, 'Chats'),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBubbleNavItem(
    int index,
    String label, {
    bool isProfile = false,
  }) {
    final isSelected = _currentIndex == index;
    final color = Theme.of(context).colorScheme.primary;

    // Calculate individual item scale based on distance to current scroll position
    final double page = _pageController.hasClients
        ? (_pageController.page ?? _baseIndex.toDouble())
        : (_baseIndex + _currentIndex).toDouble();
    final double normalizedPage = page % 3;
    double distance = (index - normalizedPage).abs();
    // Handle wrapping distance for Profile <-> Home
    if (distance > 1.5) distance = (3 - distance).abs();

    final double selectionFactor = (1.0 - distance.clamp(0.0, 1.0));
    final double scale = 1.0 + (0.2 * selectionFactor);
    final double opacity = isSelected ? 1.0 : selectionFactor;

    return GestureDetector(
      onTap: () => _onTabTapped(index),
      onLongPressStart: isProfile ? (_) => _startHoldTimer() : null,
      onLongPressEnd: isProfile ? (_) => _cancelHoldTimer() : null,
      // Also use Pan events for more reliable hold detection in nested scrolls
      onPanDown: isProfile ? (_) => _startHoldTimer() : null,
      onPanCancel: isProfile ? _cancelHoldTimer : null,
      onPanEnd: isProfile ? (_) => _cancelHoldTimer() : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15 * selectionFactor),
              shape: BoxShape.circle,
            ),
            child: Transform.scale(
              scale: scale,
              child: isProfile
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: StreamBuilder<String?>(
                        stream:
                            ProfilePictureService.instance.profilePictureStream,
                        initialData: ProfilePictureService
                            .instance
                            .currentProfilePicture,
                        builder: (context, snapshot) =>
                            _buildProfileIcon(isSelected, snapshot.data),
                      ),
                    )
                  : label == 'Chats'
                  ? _buildChatIcon(
                      isSelected,
                      Color.lerp(
                            Theme.of(context).colorScheme.onSurfaceVariant,
                            color,
                            selectionFactor,
                          ) ??
                          color,
                    )
                  : _getSvgIcon(
                      label,
                      isSelected,
                      Color.lerp(
                            Theme.of(context).colorScheme.onSurfaceVariant,
                            color,
                            selectionFactor,
                          ) ??
                          color,
                    ),
            ),
          ),
          ClipRect(
            child: Align(
              heightFactor: selectionFactor,
              child: Opacity(
                opacity: opacity.clamp(0.0, 1.0),
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernNavItem({
    required int index,
    required Widget icon,
    required String label,
    bool isProfile = false,
  }) {
    final isSelected = _currentIndex == index;
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onPanDown: isProfile ? (_) => _startHoldTimer() : null,
      onPanCancel: isProfile ? _cancelHoldTimer : null,
      onPanEnd: isProfile ? (_) => _cancelHoldTimer() : null,
      child: InkWell(
        onTap: () => _onTabTapped(index),
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(
            horizontal: isSelected ? 16 : 12,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primaryContainer.withValues(alpha: 0.4)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              icon,
              if (isSelected) ...[
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGenZNavBar() {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withOpacity(0.15),
            theme.colorScheme.secondary.withOpacity(0.15),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildGenZNavItem(0, 'You', isProfile: true),
          _buildGenZNavItem(1, 'Chats'),
        ],
      ),
    );
  }

  Widget _buildGenZNavItem(int index, String label, {bool isProfile = false}) {
    final theme = Theme.of(context);
    final isSelected = _currentIndex == index;

    Widget icon;
    if (isProfile) {
      icon = SizedBox(
        width: 24,
        height: 24,
        child: StreamBuilder<String?>(
          stream: ProfilePictureService.instance.profilePictureStream,
          initialData: ProfilePictureService.instance.currentProfilePicture,
          builder: (context, snapshot) => GestureDetector(
            onPanDown: (_) => _startHoldTimer(),
            onPanCancel: _cancelHoldTimer,
            onPanEnd: (_) => _cancelHoldTimer(),
            child: _buildProfileIcon(isSelected, snapshot.data),
          ),
        ),
      );
    } else if (label == 'Chats') {
      icon = _buildChatIcon(
        isSelected,
        isSelected ? Colors.white : theme.colorScheme.onSurfaceVariant,
      );
    } else if (label == 'Calls') {
      icon = SvgIcons.call(
        filled: isSelected,
        context: context,
        color: isSelected ? Colors.white : theme.colorScheme.onSurfaceVariant,
      );
    } else {
      icon = Icon(
        isSelected ? Icons.person : Icons.person_outline,
        color: isSelected ? Colors.white : theme.colorScheme.onSurfaceVariant,
        size: 24,
      );
    }

    return GestureDetector(
      onTap: () => _onTabTapped(index),
      onPanDown: isProfile ? (_) => _startHoldTimer() : null,
      onPanCancel: isProfile ? _cancelHoldTimer : null,
      onPanEnd: isProfile ? (_) => _cancelHoldTimer() : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: isSelected
            ? BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.secondary,
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              )
            : null,
        child: icon,
      ),
    );
  }

  Widget _getFloatingActionButton() {
    if (_currentIndex == 2) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            onPressed: _onDialpadPressed,
            heroTag: 'dialpad',
            backgroundColor: Theme.of(context).colorScheme.secondary,
            child: SvgIcons.sized(SvgIcons.dialpad, 20, color: Colors.white),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            onPressed: _onAddPressed,
            heroTag: 'add',
            child: SvgIcons.sized(SvgIcons.addCall, 24, color: Colors.white),
          ),
        ],
      );
    }

    return Container();
  }

  Widget _buildChatIcon(bool isSelected, Color color) {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, child) {
        return Badge(
          isLabelVisible: chatProvider.hasUnreadMessages,
          child: SvgIcons.chat(
            filled: isSelected,
            context: context,
            color: color,
          ),
        );
      },
    );
  }
}
