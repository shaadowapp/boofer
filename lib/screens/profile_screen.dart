import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../services/supabase_service.dart';
import '../services/user_service.dart';
import '../services/local_storage_service.dart';
import '../services/profile_picture_service.dart';
import '../models/user_model.dart';
import '../widgets/boofer_identity_card.dart';

import '../core/constants.dart';
import 'settings_screen.dart';
import 'archived_chats_screen.dart';
import 'help_screen.dart';
import 'user_search_screen.dart';
import 'appearance_settings_screen.dart';
import 'followers_screen.dart';
import 'following_screen.dart';
import 'share_profile_screen.dart';
import '../providers/follow_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/skeleton_profile_header.dart';
import '../utils/screenshot_mode.dart';
import '../widgets/smart_maintenance.dart';
import '../models/system_status_model.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = false;
  User? _currentUser;
  StreamSubscription<String?>? _profilePictureSubscription;

  @override
  void initState() {
    super.initState();
    _loadUserData();

    _profilePictureSubscription =
        ProfilePictureService.instance.profilePictureStream.listen((url) {
      if (mounted &&
          _currentUser != null &&
          url != _currentUser!.profilePicture) {
        setState(() {
          _currentUser = _currentUser!.copyWith(profilePicture: url);
        });
      }
    });
  }

  @override
  void dispose() {
    _profilePictureSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);

    if (ScreenshotMode.isEnabled) {
      if (mounted) {
        setState(() {
          _currentUser = ScreenshotMode.dummyCurrentProfile;
          _isLoading = false;
        });
      }
      return;
    }

    try {
      User? user = await UserService.getCurrentUser();
      if (user == null) {
        final customUserId = await LocalStorageService.getString(
          'custom_user_id',
        );
        if (customUserId != null) {
          final freshUser = await SupabaseService.instance.getUserProfile(
            customUserId,
          );
          if (freshUser != null) {
            user = freshUser;
            await UserService.setCurrentUser(user);
          }
        }
      } else {
        final freshUser = await SupabaseService.instance.getUserProfile(
          user.id,
        );
        if (freshUser != null) {
          await UserService.setCurrentUser(freshUser);
          user = freshUser;
        }
      }

      if (user != null) {
        final followProvider = context.read<FollowProvider>();
        await followProvider.loadFollowStats(user.id, refresh: true);
      }

      setState(() {
        _currentUser = user;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading profile: $e')));
      }
    }
  }

  void _shareProfile() {
    if (_currentUser == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ShareProfileScreen(user: _currentUser!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading && _currentUser == null) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          systemOverlayStyle:
              isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
          title: Text(
            'MY IDENTITY',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w900,
              fontSize: 13,
              letterSpacing: 2,
            ),
          ),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 110),
              const SkeletonProfileHeader(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      );
    }

    if (_currentUser == null) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Identity Not Found',
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withOpacity(0.4),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loadUserData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle:
            isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        title: Text(
          'MY IDENTITY',
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w900,
            fontSize: 13,
            letterSpacing: 2,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _shareProfile,
            icon: Icon(
              Icons.share_outlined,
              color: theme.colorScheme.onSurface,
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: theme.colorScheme.onSurface),
            onSelected: (value) {
              switch (value) {
                case 'settings':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  );
                  break;
                case 'appearance':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AppearanceSettingsScreen(),
                    ),
                  );
                  break;
                case 'help':
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const HelpScreen()),
                  );
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'appearance',
                child: Text('Appearance'),
              ),
              const PopupMenuItem(value: 'settings', child: Text('Settings')),
              const PopupMenuItem(value: 'help', child: Text('Help & Support')),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned(
            top: -100,
            right: -100,
            child: _GlowCircle(
              color: theme.colorScheme.primary.withOpacity(isDark ? 0.1 : 0.05),
            ),
          ),
          Positioned(
            bottom: 100,
            left: -50,
            child: _GlowCircle(
              color: const Color(0xFFFF6B6B).withOpacity(isDark ? 0.05 : 0.02),
            ),
          ),
          RefreshIndicator(
            onRefresh: _loadUserData,
            color: theme.colorScheme.primary,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  const SizedBox(height: 110),
                  BooferIdentityCard(
                    user: _currentUser!,
                    onCopyNumber: () {
                      Clipboard.setData(
                        ClipboardData(text: _currentUser!.virtualNumber ?? ''),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Virtual Number copied!')),
                      );
                    },
                  ),

                  const SizedBox(height: 32),
                  _buildActionRow(),
                  const SizedBox(height: 32),

                  if (!_currentUser!.isCompany) ...[
                    if (_currentUser!.interests.isNotEmpty) ...[
                      _buildSectionTitle('Interests'),
                      const SizedBox(height: 12),
                      _buildChipCloud(
                        _currentUser!.interests,
                        const Color(0xFF845EF7),
                      ),
                      const SizedBox(height: 24),
                    ],
                    if (_currentUser!.hobbies.isNotEmpty) ...[
                      _buildSectionTitle('Hobbies'),
                      const SizedBox(height: 12),
                      _buildChipCloud(
                        _currentUser!.hobbies,
                        const Color(0xFFFF6B6B),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ],

                  _buildSectionTitle('Network Stats'),
                  const SizedBox(height: 16),
                  _buildStatsGrid(),
                  const SizedBox(height: 40),

                  // Tools Section
                  _buildSectionTitle('Identity Tools'),
                  const SizedBox(height: 16),
                  _buildToolItem(
                    Icons.explore_outlined,
                    'Discover Users',
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const UserSearchScreen(),
                      ),
                    ),
                  ),
                  _buildToolItem(
                    Icons.archive_outlined,
                    'Archived Chats',
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ArchivedChatsScreen(),
                      ),
                    ),
                  ),
                  _buildToolItem(
                    Icons.people_outline,
                    'Followers',
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FollowersScreen(
                          userId: _currentUser!.id,
                          userName: _currentUser!.fullName,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow() {
    return GestureDetector(
      onTap: () {
        if (!SupabaseService.instance.currentStatus.isProfileUpdatesActive) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  SupabaseService.instance.currentStatus.maintenanceMessage),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }
        _showEditProfileSheet();
      },
      child: Container(
        height: 56,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF845EF7), Color(0xFF5C7CFA)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF845EF7).withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: const Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.edit_note_rounded, color: Colors.white),
              SizedBox(width: 10),
              Text(
                'Customize My Identity',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 2,
        ),
      ),
    );
  }

  Widget _buildChipCloud(List<String> items, Color color) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: items.map((item) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Text(
              item,
              style: TextStyle(
                color: color.withOpacity(0.9),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatsGrid() {
    return Consumer<FollowProvider>(
      builder: (context, provider, child) {
        final stats = provider.getFollowStats(_currentUser!.id);
        return Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FollowersScreen(
                      userId: _currentUser!.id,
                      userName: _currentUser!.fullName,
                    ),
                  ),
                ),
                child: _StatBox(
                  label: 'Followers',
                  value: '${stats?.followersCount ?? 0}',
                  icon: Icons.people_outline,
                ),
              ),
            ),
            if (!_currentUser!.isCompany) ...[
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FollowingScreen(
                        userId: _currentUser!.id,
                        userName: _currentUser!.fullName,
                      ),
                    ),
                  ),
                  child: _StatBox(
                    label: 'Following',
                    value: '${stats?.followingCount ?? 0}',
                    icon: Icons.person_add_alt_1_outlined,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildToolItem(IconData icon, String title, VoidCallback onTap) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: theme.colorScheme.onSurface.withOpacity(0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.onSurface.withOpacity(0.05),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: theme.colorScheme.onSurface.withOpacity(0.3),
              size: 20,
            ),
            const SizedBox(width: 16),
            Text(
              title,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.arrow_forward_ios,
              color: theme.colorScheme.onSurface.withOpacity(0.1),
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

  void _showEditProfileSheet() {
    final nameCtrl = TextEditingController(text: _currentUser?.fullName);
    final handleCtrl = TextEditingController(text: _currentUser?.handle);
    final bioCtrl = TextEditingController(text: _currentUser?.bio);
    final ageCtrl = TextEditingController(
      text: _currentUser?.age?.toString() ?? '',
    );
    Set<String> selectedInterests = Set.from(_currentUser?.interests ?? []);
    Set<String> selectedHobbies = Set.from(_currentUser?.hobbies ?? []);
    String selectedAvatar = _currentUser?.avatar ?? '👤';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final theme = Theme.of(ctx);
          final isDark = theme.brightness == Brightness.dark;

          return Container(
            height: MediaQuery.of(ctx).size.height * 0.85,
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1A1A2E)
                  : theme.scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
              boxShadow: [
                if (!isDark)
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      Text(
                        'Refine Your Identity',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Choose how the world sees you. System data remains immutable.',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.4),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 32),
                      _buildModalSectionTitle(
                        'Identity Persona',
                        theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: Stack(
                          children: [
                            GestureDetector(
                              onTap: () => _showAvatarPicker(
                                ctx,
                                selectedAvatar,
                                (avatar) {
                                  setModalState(() => selectedAvatar = avatar);
                                },
                              ),
                              child: Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withOpacity(
                                    0.1,
                                  ),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: theme.colorScheme.primary
                                        .withOpacity(0.2),
                                    width: 2,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    selectedAvatar,
                                    style: const TextStyle(fontSize: 50),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: () => _showAvatarPicker(
                                  ctx,
                                  selectedAvatar,
                                  (avatar) {
                                    setModalState(
                                      () => selectedAvatar = avatar,
                                    );
                                  },
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.edit_rounded,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      _buildEditTextField(
                        'Full Name',
                        nameCtrl,
                        Icons.person_outline,
                      ),
                      const SizedBox(height: 20),
                      _buildEditTextField(
                        'Handle',
                        handleCtrl,
                        Icons.alternate_email,
                      ),
                      const SizedBox(height: 20),
                      _buildEditTextField(
                        'Bio',
                        bioCtrl,
                        Icons.info_outline,
                        maxLines: 3,
                      ),
                      const SizedBox(height: 20),
                      _buildModalSectionTitle(
                        'Age Selection',
                        const Color(0xFF20C997),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        height: 150,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onSurface.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: theme.colorScheme.onSurface.withOpacity(0.1),
                          ),
                        ),
                        child: ListWheelScrollView.useDelegate(
                          itemExtent: 50,
                          perspective: 0.005,
                          diameterRatio: 1.2,
                          physics: const FixedExtentScrollPhysics(),
                          controller: FixedExtentScrollController(
                            initialItem:
                                (int.tryParse(ageCtrl.text) ?? 21) - 18,
                          ),
                          onSelectedItemChanged: (index) {
                            ageCtrl.text = (index + 18).toString();
                            HapticFeedback.selectionClick();
                          },
                          childDelegate: ListWheelChildBuilderDelegate(
                            builder: (context, index) {
                              final age = index + 18;
                              if (age > 100) return null;
                              return Center(
                                child: Text(
                                  '$age',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              );
                            },
                            childCount: 83, // 18 to 100
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      _buildModalSectionTitle(
                        'Interests (Max 5)',
                        const Color(0xFF845EF7),
                      ),
                      const SizedBox(height: 12),
                      _buildSelectorGrid(
                        AppConstants.interestOptions.map((e) => e.$1).toList(),
                        AppConstants.interestOptions.map((e) => e.$2).toList(),
                        selectedInterests,
                        const Color(0xFF845EF7),
                        setModalState,
                      ),
                      const SizedBox(height: 32),
                      _buildModalSectionTitle(
                        'Hobbies (Max 5)',
                        const Color(0xFFFF6B6B),
                      ),
                      const SizedBox(height: 12),
                      _buildSelectorGrid(
                        AppConstants.hobbyOptions.map((e) => e.$1).toList(),
                        AppConstants.hobbyOptions.map((e) => e.$2).toList(),
                        selectedHobbies,
                        const Color(0xFFFF6B6B),
                        setModalState,
                      ),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1A1A2E)
                        : theme.scaffoldBackgroundColor,
                    border: Border(
                      top: BorderSide(
                        color: theme.colorScheme.onSurface.withOpacity(0.05),
                      ),
                    ),
                  ),
                  child: GestureDetector(
                    onTap: () async {
                      if (nameCtrl.text.isEmpty || handleCtrl.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Name and Handle are required'),
                          ),
                        );
                        return;
                      }
                      if (handleCtrl.text != _currentUser?.handle) {
                        final isAvailable = await UserService.instance
                            .isHandleAvailable(handleCtrl.text);
                        if (!isAvailable) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('This handle is already taken'),
                            ),
                          );
                          return;
                        }
                      }

                      final newAge = int.tryParse(ageCtrl.text);
                      final oldAge = _currentUser?.age;

                      if (newAge != oldAge) {
                        final canUpdate = await _canUpdateAge();
                        if (!canUpdate) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Age update limit reached (3 per month)',
                                ),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          }
                          return;
                        }
                        await _recordAgeUpdate();
                      }

                      Navigator.pop(ctx);
                      _updateProfile(
                        name: nameCtrl.text,
                        handle: handleCtrl.text,
                        bio: bioCtrl.text,
                        avatar: selectedAvatar,
                        age: newAge,
                        interests: selectedInterests.toList(),
                        hobbies: selectedHobbies.toList(),
                      );
                    },
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF845EF7), Color(0xFF5C7CFA)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: Text(
                          'Save Identity',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showAvatarPicker(
    BuildContext context,
    String currentAvatar,
    Function(String) onSelected,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.5,
        decoration: BoxDecoration(
          color: Theme.of(ctx).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.all(12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'Choose Your Avatar',
                style: TextStyle(
                  color: Theme.of(ctx).colorScheme.onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(24),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 20,
                  crossAxisSpacing: 20,
                ),
                itemCount: AppConstants.avatarOptions.length,
                itemBuilder: (ctx, index) {
                  final avatar = AppConstants.avatarOptions[index];
                  final isSelected = avatar == currentAvatar;
                  return GestureDetector(
                    onTap: () {
                      onSelected(avatar);
                      Navigator.pop(ctx);
                      HapticFeedback.lightImpact();
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Theme.of(ctx).colorScheme.primary.withOpacity(0.1)
                            : Theme.of(
                                ctx,
                              ).colorScheme.onSurface.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? Theme.of(ctx).colorScheme.primary
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          avatar,
                          style: const TextStyle(fontSize: 32),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModalSectionTitle(String title, Color accent) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
      ],
    );
  }

  Future<bool> _canUpdateAge() async {
    final prefs = await SharedPreferences.getInstance();
    final updates =
        prefs.getStringList('age_updates_${_currentUser?.id}') ?? [];
    final now = DateTime.now();
    final oneMonthAgo = now.subtract(const Duration(days: 30));

    final recentUpdates = updates.where((s) {
      final date = DateTime.parse(s);
      return date.isAfter(oneMonthAgo);
    }).toList();

    return recentUpdates.length < 3;
  }

  Future<void> _recordAgeUpdate() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'age_updates_${_currentUser?.id}';
    final updates = prefs.getStringList(key) ?? [];
    updates.add(DateTime.now().toIso8601String());
    // Keep only last 3 to save space
    if (updates.length > 3) updates.removeAt(0);
    await prefs.setStringList(key, updates);
  }

  Widget _buildEditTextField(
    String label,
    TextEditingController ctrl,
    IconData icon, {
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: theme.colorScheme.onSurface.withOpacity(0.4),
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14),
          decoration: InputDecoration(
            prefixIcon: Icon(
              icon,
              color: theme.colorScheme.primary.withOpacity(0.5),
              size: 20,
            ),
            filled: true,
            fillColor: Theme.of(
              context,
            ).colorScheme.onSurface.withOpacity(0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectorGrid(
    List<String> labels,
    List<String> values,
    Set<String> selected,
    Color color,
    StateSetter setModalState,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(labels.length, (index) {
        final label = labels[index];
        final value = values[index];
        final isSelected = selected.contains(value);
        return GestureDetector(
          onTap: () {
            setModalState(() {
              if (isSelected) {
                selected.remove(value);
              } else if (selected.length < 5) {
                selected.add(value);
                HapticFeedback.selectionClick();
              } else {
                HapticFeedback.vibrate();
              }
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? color.withOpacity(0.2)
                  : Theme.of(context).colorScheme.onSurface.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? color.withOpacity(0.5)
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? color
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        );
      }),
    );
  }

  Future<void> _updateProfile({
    required String name,
    required String handle,
    String? bio,
    String? avatar,
    int? age,
    required List<String> interests,
    required List<String> hobbies,
  }) async {
    setState(() => _isLoading = true);
    try {
      final updatedUser = _currentUser!.copyWith(
        fullName: name,
        handle: handle,
        bio: bio,
        avatar: avatar,
        age: age,
        interests: interests,
        hobbies: hobbies,
      );
      await SupabaseService.instance.updateUserProfile(
        userId: updatedUser.id,
        fullName: name,
        handle: handle,
        bio: bio,
        avatar: avatar,
        age: age,
        interests: interests,
        hobbies: hobbies,
      );
      await UserService.updateUser(updatedUser);
      await UserService.setCurrentUser(updatedUser);
      setState(() {
        _currentUser = updatedUser;
        _isLoading = false;
      });
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Identity secured.'),
            backgroundColor: Colors.green,
          ),
        );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed: $e')));
        setState(() => _isLoading = false);
      }
    }
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _StatBox({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.onSurface.withOpacity(0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: theme.colorScheme.onSurface.withOpacity(0.2),
            size: 20,
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: theme.colorScheme.onSurface.withOpacity(0.4),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  final Color color;
  const _GlowCircle({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 400,
      height: 400,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color, blurRadius: 100, spreadRadius: 20)],
      ),
    );
  }
}
