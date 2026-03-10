import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'lobby_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'archived_chats_screen.dart';
import 'discover_screen.dart';
import 'support_chat_screen.dart';
import '../providers/appearance_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/auth_state_provider.dart';
import '../providers/follow_provider.dart';
import '../services/user_service.dart';
import '../services/profile_picture_service.dart';
import '../providers/chat_provider.dart';
import '../providers/archive_settings_provider.dart';
import '../providers/username_provider.dart';
import '../utils/svg_icons.dart';
import '../services/notification_service.dart';
import '../services/follow_service.dart';
import '../l10n/app_localizations.dart';
import '../services/receive_share_service.dart';
import '../main.dart';
import '../services/multi_account_storage_service.dart';
import '../widgets/user_avatar.dart';
import 'learn_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _hasCheckedNotifications = false;
  StreamSubscription<String?>? _profilePictureSubscription;
  bool _isGridView = false;

  List<Widget> get _screens {
    final authProvider = context.read<AuthStateProvider>();
    final userId = authProvider.currentUserId ?? 'guest';
    
    return [
      DiscoverScreen(
        key: ValueKey('discover_$userId'),
        showAppBar: false,
        showManageFriendsButton: true,
        isGridView: _isGridView,
        onToggleGridView: () {
          setState(() => _isGridView = !_isGridView);
          HapticFeedback.lightImpact();
        },
      ), // Home
      LobbyScreen(key: ValueKey('lobby_$userId')), // Chats
      ProfileScreen(key: ValueKey('profile_$userId')), // You
    ];
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: 0);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        HapticFeedback.selectionClick();
      } else {
        if (mounted) setState(() {});
      }
    });

    // Listen to auth state changes to force rebuild and tab reset
    context.read<AuthStateProvider>().addListener(_handleAuthChange);

    _initializeMainScreen();
    _initializeProviders();
    _loadGridPreference(); // Load saved grid/list preference

    _profilePictureSubscription =
        ProfilePictureService.instance.profilePictureStream.listen((_) {
      if (mounted) setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeUserData();
      ReceiveShareService.instance.init(BooferApp.navigatorKey);
    });
  }

  @override
  void dispose() {
    context.read<AuthStateProvider>().removeListener(_handleAuthChange);
    _tabController.dispose();
    _profilePictureSubscription?.cancel();
    super.dispose();
  }

  void _handleAuthChange() {
    if (mounted) {
      setState(() {
        // This will force re-generation of _screens with new keys
      });
    }
  }

  Future<void> _loadGridPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getBool('discover_grid_view') ?? false;
      if (mounted && saved != _isGridView) {
        setState(() => _isGridView = saved);
      }
    } catch (_) {}
  }

  Future<void> _saveGridPreference(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('discover_grid_view', value);
    } catch (_) {}
  }

  Future<void> _initializeUserData() async {
    try {
      final authProvider = context.read<AuthStateProvider>();
      if (authProvider.isAuthenticated) {
        final userProfile = await UserService.getCurrentUser();
        if (userProfile != null) {
          FollowService.instance.ensureFollowingBoofer(userProfile.id);
          if (!mounted) return;
          context.read<FollowProvider>().initialize(userProfile.id);
        }
      }
    } catch (e) {
      debugPrint('Error initializing user data: $e');
    }
  }

  Future<void> _initializeMainScreen() async {
    if (mounted && !_hasCheckedNotifications) {
      _checkNotificationPermissions();
    }
  }

  Future<void> _checkNotificationPermissions() async {
    try {
      _hasCheckedNotifications = true;
      final notificationService = NotificationService.instance;
      await notificationService.initialize();
      if (await notificationService.shouldRequestPermission()) {
        if (mounted) await notificationService.showPermissionDialog(context);
      }
    } catch (e) {
      debugPrint('Error checking notification permissions: $e');
    }
  }

  Future<void> _initializeProviders() async {
    try {
      await Provider.of<UsernameProvider>(context, listen: false)
          .reloadHandle();
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
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                if (chatProvider.archivedChats.isNotEmpty &&
                    archiveSettings.archiveButtonPosition ==
                        ArchiveButtonPosition.topNavbarMoreOptions)
                  ListTile(
                    leading: Icon(Icons.archive,
                        color: Theme.of(context).colorScheme.onSurface),
                    title:
                        Text('Archived (${chatProvider.archivedChats.length})'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  const ArchivedChatsScreen()));
                    },
                  ),
                // Boofer support — always visible
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Text('🛣️', style: TextStyle(fontSize: 20)),
                    ),
                  ),
                  title: const Text('Boofer'),
                  subtitle: const Text('Open Support'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SupportChatScreen(),
                      ),
                    );
                  },
                ),
                Consumer<ThemeProvider>(
                  builder: (context, themeProvider, child) {
                    return ListTile(
                      leading: SvgIcons.theme(
                          isDark: themeProvider.isDarkMode,
                          color: Theme.of(context).colorScheme.onSurface),
                      title: Text(AppLocalizations.of(context)!.darkMode),
                      trailing: Switch(
                          value: themeProvider.isDarkMode,
                          onChanged: (value) => themeProvider.toggleTheme()),
                    );
                  },
                ),
                ListTile(
                  leading: SvgIcons.medium(SvgIcons.settings,
                      color: Theme.of(context).colorScheme.onSurface),
                  title: const Text('Settings'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const SettingsScreen()));
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appearance = Provider.of<AppearanceProvider>(context);

    return Scaffold(
      appBar: _tabController.index == 2
          ? null // Hide AppBar on Profile tab
          : AppBar(
        title: SvgPicture.asset(
          'assets/images/logo/boofer-logo.svg',
          height: 36,
          alignment: Alignment.centerLeft,
        ),
        actions: [
          // Show grid/list toggle only on Home tab
          if (_tabController.index == 0)
            IconButton(
              onPressed: () {
                final next = !_isGridView;
                setState(() => _isGridView = next);
                _saveGridPreference(next);
                HapticFeedback.lightImpact();
              },
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (child, anim) => ScaleTransition(
                  scale: anim,
                  child: child,
                ),
                child: Icon(
                  _isGridView
                      ? Icons.table_rows_rounded   // grid → switch to list
                      : Icons.apps_rounded,        // list → switch to grid
                  key: ValueKey(_isGridView),
                  color: theme.appBarTheme.foregroundColor ?? Colors.white,
                  size: 22,
                ),
              ),
              tooltip: _isGridView ? 'Switch to List' : 'Switch to Grid',
            ),
          // Show Learn button only on Chats tab (index 1)
          if (_tabController.index == 1)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LearnScreen(),
                    ),
                  );
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.25),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_stories_rounded,
                        size: 15,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Learn',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          IconButton(
            icon: SvgIcons.more(
              horizontal: false,
              color: theme.appBarTheme.foregroundColor ?? Colors.white,
            ),
            onPressed: _showMoreOptions,
            tooltip: 'More options',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: _screens,
      ),
      bottomNavigationBar: _buildNavBar(context, appearance),
    );
  }

  Widget _buildNavBar(BuildContext context, AppearanceProvider appearance) {
    switch (appearance.navBarStyle) {
      case NavBarStyle.simple:
        return _buildSimpleNavBar(context);
      case NavBarStyle.modern:
        return _buildModernNavBar(context);
      case NavBarStyle.ios:
        return _buildIOSNavBar(context);
      case NavBarStyle.bubble:
        return _buildBubbleNavBar(context);
      case NavBarStyle.liquid:
        return _buildLiquidNavBar(context);
      case NavBarStyle.genz:
        return _buildGenZNavBar(context);
    }
  }

  Widget _buildSimpleNavBar(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.1),
            width: 0.5,
          ),
        ),
      ),
      child: BottomNavigationBar(
        currentIndex: _tabController.index,
        onTap: (index) => _tabController.animateTo(index),
        selectedItemColor: theme.colorScheme.primary,
        unselectedItemColor: theme.colorScheme.onSurface.withValues(alpha: 0.6),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        items: [
          BottomNavigationBarItem(
            icon: SvgIcons.home(filled: false, context: context),
            activeIcon: SvgIcons.home(filled: true, context: context),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: SvgIcons.chat(filled: false, context: context),
            activeIcon: SvgIcons.chat(filled: true, context: context),
            label: 'Chats',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'You',
          ),
        ],
      ),
    );
  }

  Widget _buildModernNavBar(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.1),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavBarItem(context, 0, 'Home', NavBarStyle.modern),
          _buildNavBarItem(context, 1, 'Chats', NavBarStyle.modern),
          _buildNavBarItem(context, 2, 'You', NavBarStyle.modern),
        ],
      ),
    );
  }

  Widget _buildIOSNavBar(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 90,
      padding: const EdgeInsets.only(bottom: 20, left: 16, right: 16),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNavBarItem(context, 0, 'Home', NavBarStyle.ios),
            _buildNavBarItem(context, 1, 'Chats', NavBarStyle.ios),
            _buildNavBarItem(context, 2, 'You', NavBarStyle.ios),
          ],
        ),
      ),
    );
  }

  Widget _buildBubbleNavBar(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavBarItem(context, 0, 'Home', NavBarStyle.bubble),
          _buildNavBarItem(context, 1, 'Chats', NavBarStyle.bubble),
          _buildNavBarItem(context, 2, 'You', NavBarStyle.bubble),
        ],
      ),
    );
  }

  Widget _buildLiquidNavBar(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 80,
      color: theme.colorScheme.surface,
      child: Stack(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavBarItem(context, 0, 'Home', NavBarStyle.liquid),
              _buildNavBarItem(context, 1, 'Chats', NavBarStyle.liquid),
              _buildNavBarItem(context, 2, 'You', NavBarStyle.liquid),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGenZNavBar(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.1),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavBarItem(context, 0, 'Home', NavBarStyle.genz),
          _buildNavBarItem(context, 1, 'Chats', NavBarStyle.genz),
          _buildNavBarItem(context, 2, 'You', NavBarStyle.genz),
        ],
      ),
    );
  }

  Widget _buildNavBarItem(
      BuildContext context, int index, String label, NavBarStyle style) {
    final theme = Theme.of(context);
    final isSelected = _tabController.index == index;
    final color = isSelected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;

    Widget icon;
    switch (index) {
      case 0:
        icon =
            SvgIcons.home(filled: isSelected, context: context, color: color);
        break;
      case 1:
        icon =
            SvgIcons.chat(filled: isSelected, context: context, color: color);
        break;
      case 2:
      default:
        icon = Icon(isSelected ? Icons.person : Icons.person_outline,
            color: color);
        break;
    }

    return GestureDetector(
      onTap: () {
        _tabController.animateTo(index);
        setState(() {}); // Trigger rebuild to update selected state
      },
      onLongPress: index == 2
          ? () => _showProfileSwitcher(context)
          : null,
      child: _buildStyleWrapper(context, icon, label, isSelected, style),
    );
  }

  Widget _buildStyleWrapper(BuildContext context, Widget icon, String label,
      bool isSelected, NavBarStyle style) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    switch (style) {
      case NavBarStyle.modern:
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? primary.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
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
                      color: primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                ),
              ],
            ],
          ),
        );
      case NavBarStyle.ios:
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected ? primary : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: isSelected
              ? IconTheme(
                  data: const IconThemeData(color: Colors.white), child: icon)
              : icon,
        );
      case NavBarStyle.bubble:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? primary.withValues(alpha: 0.15)
                    : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: icon,
            ),
            if (isSelected)
              Text(
                label,
                style: TextStyle(
                    color: primary, fontWeight: FontWeight.bold, fontSize: 11),
              ),
          ],
        );
      case NavBarStyle.liquid:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              transform: isSelected
                  ? Matrix4.translationValues(0, -5, 0)
                  : Matrix4.identity(),
              child: icon,
            ),
            if (isSelected)
              Container(
                width: 4,
                height: 4,
                decoration:
                    BoxDecoration(color: primary, shape: BoxShape.circle),
              ),
          ],
        );
      case NavBarStyle.genz:
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: isSelected
              ? BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primary, theme.colorScheme.secondary],
                  ),
                  borderRadius: BorderRadius.circular(16),
                )
              : null,
          child: isSelected
              ? IconTheme(
                  data: const IconThemeData(color: Colors.white), child: icon)
              : icon,
        );
      default:
        return icon;
    }
  }
  Future<void> _showProfileSwitcher(BuildContext context) async {
    final accounts = await MultiAccountStorageService.getSavedAccounts();
    if (accounts.length <= 1) return;

    if (!context.mounted) return;
    final currentUserId = context.read<AuthStateProvider>().currentUserId;

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;

        return Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pull handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              const Text(
                'IDENTITY SWITCHER',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 2,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 24),

              // List of accounts
              ...accounts.map((acc) {
                final isCurrent = acc['id'] == currentUserId;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: isCurrent
                        ? colorScheme.primary.withValues(alpha: 0.08)
                        : colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      onTap: () async {
                        Navigator.pop(context);
                        if (!isCurrent) {
                          final navigator = Navigator.of(context, rootNavigator: true);
                          await context
                              .read<AuthStateProvider>()
                              .switchAccount(acc['id']);

                          if (context.mounted) {
                            // 1. Force refresh of providers
                            context.read<ChatProvider>().refreshFriends();
                            context.read<FollowProvider>().initialize(acc['id']);

                            // 2. Perform a "hard reset" of the UI by re-pushing the main route.
                            navigator.pushNamedAndRemoveUntil(
                              '/main',
                              (route) => false,
                            );
                          }
                        }
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isCurrent
                                ? colorScheme.primary.withValues(alpha: 0.3)
                                : colorScheme.onSurface.withValues(alpha: 0.05),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            UserAvatar(
                              avatar: acc['avatar'] ?? '👤',
                              name: acc['fullName'] ?? 'User',
                              radius: 24,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    acc['fullName'] ?? 'User',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                  Text(
                                    '@${acc['handle']}',
                                    style: TextStyle(
                                      color: colorScheme.onSurface
                                          .withValues(alpha: 0.5),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isCurrent)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  'ACTIVE',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

