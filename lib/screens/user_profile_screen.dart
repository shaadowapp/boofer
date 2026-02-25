import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import 'share_profile_screen.dart';
import '../services/supabase_service.dart';
import '../services/user_service.dart';
import '../providers/follow_provider.dart';
import '../widgets/follow_button.dart';
import '../core/constants.dart';
import 'friend_chat_screen.dart';
import '../widgets/profile_share_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;

  const UserProfileScreen({super.key, required this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final SupabaseService _supabaseService = SupabaseService.instance;
  User? _profileUser;
  bool _isLoading = true;
  bool _isOwnProfile = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final currentUser = await UserService.getCurrentUser();
      final currentUserId = currentUser?.id ?? '';

      // Use the new SQL join method to get profile + relationship
      final userData = await _supabaseService.getUserAndRelationship(
        currentUserId: currentUserId,
        profileUserId: widget.userId,
      );

      if (userData != null && mounted) {
        final profileUser = User.fromJson(userData);

        // Update FollowProvider with the real relationship status from SQL join
        final followProvider = context.read<FollowProvider>();
        followProvider.setLocalFollowingStatus(
          widget.userId,
          userData['is_following'] ?? false,
        );

        // Also update counts in provider to ensure accuracy
        // We can't set stats directly but we can trigger a load if needed,
        // or just let the provider do its thing.
        // But the user said counts are inaccurate, so let's push the truth.

        setState(() {
          _profileUser = profileUser;
          _isOwnProfile = currentUserId == widget.userId;
          _isLoading = false;
        });

        // Trigger background stats load to be sure
        followProvider.loadFollowStats(widget.userId, refresh: true);
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _shareProfile() {
    if (_profileUser == null) return;

    if (_isOwnProfile) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ShareProfileScreen(user: _profileUser!),
        ),
      );
    } else {
      ProfileShareSheet.show(context, profile: _profileUser!);
    }
  }

  void _showBlockConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Block User?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'You will no longer see their messages or profile.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Block', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showReportDialog() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Report submitted. Thank you for keeping Boofer safe!'),
      ),
    );
  }

  Future<void> _openChat() async {
    if (_profileUser == null) return;
    final currentUser = await UserService.getCurrentUser();
    if (currentUser == null) return;

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FriendChatScreen(
            recipientId: widget.userId,
            recipientName: _profileUser!.fullName,
            recipientHandle: _profileUser!.handle,
            recipientAvatar: _profileUser!.avatar,
            recipientProfilePicture: _profileUser!.profilePicture,
            virtualNumber: _profileUser!.virtualNumber,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Center(
          child: CircularProgressIndicator(color: theme.colorScheme.primary),
        ),
      );
    }

    if (_profileUser == null) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
        body: _buildErrorState(),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: theme.colorScheme.onSurface,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            onPressed: _shareProfile,
            icon: Icon(
              Icons.share_outlined,
              color: theme.colorScheme.onSurface,
            ),
          ),
          if (!_isOwnProfile)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: theme.colorScheme.onSurface),
              onSelected: (value) {
                if (value == 'block') _showBlockConfirmation();
                if (value == 'report') _showReportDialog();
              },
              itemBuilder: (context) => [
                if (widget.userId != AppConstants.booferId &&
                    _profileUser?.handle != 'boofer')
                  const PopupMenuItem(
                    value: 'block',
                    child: Row(
                      children: [
                        Icon(Icons.block, color: Colors.red, size: 20),
                        SizedBox(width: 12),
                        Text('Block User', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                const PopupMenuItem(
                  value: 'report',
                  child: Row(
                    children: [
                      Icon(Icons.report_outlined, size: 20),
                      SizedBox(width: 12),
                      Text('Report'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Stack(
        children: [
          // Background Glows (Subtle)
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
            onRefresh: _loadProfile,
            color: theme.colorScheme.primary,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  const SizedBox(height: 110),

                  // THE BOOFER CARD
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _ProfileHeroCard(
                      user: _profileUser!,
                      onCopyNumber: () {
                        Clipboard.setData(
                          ClipboardData(
                            text: _profileUser!.virtualNumber ?? '',
                          ),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Virtual Number copied!'),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Stats & Quick Actions
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildActionRow(),
                        const SizedBox(height: 32),

                        if (!_profileUser!.isCompany) ...[
                          if (_profileUser!.interests.isNotEmpty) ...[
                            _buildSectionTitle('Interests'),
                            const SizedBox(height: 12),
                            _buildChipCloud(
                              _profileUser!.interests,
                              const Color(0xFF845EF7),
                            ),
                            const SizedBox(height: 24),
                          ],

                          if (_profileUser!.hobbies.isNotEmpty) ...[
                            _buildSectionTitle('Hobbies'),
                            const SizedBox(height: 12),
                            _buildChipCloud(
                              _profileUser!.hobbies,
                              const Color(0xFFFF6B6B),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ],

                        if (_profileUser!.id != AppConstants.booferId) ...[
                          _buildSectionTitle('Network Stats'),
                          const SizedBox(height: 16),
                          _buildStatsGrid(),
                          const SizedBox(height: 40),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_off_rounded,
            size: 64,
            color: Colors.white.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          const Text(
            'Identity Not Found',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'The requested persona has vanished into the shadows.',
            style: TextStyle(color: Colors.white24, fontSize: 14),
          ),
          const SizedBox(height: 24),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Return',
              style: TextStyle(color: Color(0xFF845EF7)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
        fontSize: 12,
        fontWeight: FontWeight.w900,
        letterSpacing: 2,
      ),
    );
  }

  Widget _buildChipCloud(List<String> items, Color color) {
    return Wrap(
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
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActionRow() {
    if (_isOwnProfile) {
      return GestureDetector(
        onTap: _showEditProfileSheet,
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

    return Consumer<FollowProvider>(
      builder: (context, provider, child) {
        final isFriend = provider.isFriends(widget.userId);
        final theme = Theme.of(context);
        return Row(
          children: [
            if (widget.userId != AppConstants.booferId)
              Expanded(child: FollowButton(user: _profileUser!)),
            if (isFriend || widget.userId == AppConstants.booferId) ...[
              if (widget.userId != AppConstants.booferId)
                const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: _openChat,
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.colorScheme.onSurface.withOpacity(0.1),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'Secure Message',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildStatsGrid() {
    return Consumer<FollowProvider>(
      builder: (context, provider, child) {
        final stats = provider.getFollowStats(widget.userId);
        final followers =
            stats?.followersCount ?? _profileUser?.followerCount ?? 0;
        final following =
            stats?.followingCount ?? _profileUser?.followingCount ?? 0;

        return Row(
          children: [
            Expanded(
              child: _StatBox(
                label: 'Followers',
                value: '$followers',
                icon: Icons.people_outline,
              ),
            ),
            if (!(_profileUser?.isCompany ?? false)) ...[
              const SizedBox(width: 12),
              Expanded(
                child: _StatBox(
                  label: 'Following',
                  value: '$following',
                  icon: Icons.person_add_alt_1_outlined,
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  void _showEditProfileSheet() {
    final nameCtrl = TextEditingController(text: _profileUser?.fullName);
    final handleCtrl = TextEditingController(text: _profileUser?.handle);
    final bioCtrl = TextEditingController(text: _profileUser?.bio);
    final ageCtrl = TextEditingController(
      text: _profileUser?.age?.toString() ?? '',
    );
    Set<String> selectedInterests = Set.from(_profileUser?.interests ?? []);
    Set<String> selectedHobbies = Set.from(_profileUser?.hobbies ?? []);
    String selectedAvatar = _profileUser?.avatar ?? '👤';

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
                // Drag Handle
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
                        'Refine Your Profile',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'System generated data like Virtual Number cannot be changed.',
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

                // Save Button
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

                      // Check handle availability if changed
                      if (handleCtrl.text != _profileUser?.handle) {
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
                      final oldAge = _profileUser?.age;

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
        prefs.getStringList('age_updates_${_profileUser?.id}') ?? [];
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
    final key = 'age_updates_${_profileUser?.id}';
    final updates = prefs.getStringList(key) ?? [];
    updates.add(DateTime.now().toIso8601String());
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 15,
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(
              icon,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
              size: 20,
            ),
            filled: true,
            fillColor: Theme.of(
              context,
            ).colorScheme.onSurface.withOpacity(0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? color.withOpacity(0.2)
                  : Theme.of(context).colorScheme.onSurface.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
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
                fontSize: 13,
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
    required String bio,
    String? avatar,
    int? age,
    required List<String> interests,
    required List<String> hobbies,
  }) async {
    setState(() => _isLoading = true);
    try {
      final updatedUser = _profileUser!.copyWith(
        fullName: name,
        handle: handle,
        bio: bio,
        avatar: avatar,
        age: age,
        interests: interests,
        hobbies: hobbies,
      );

      // 1. Update Supabase
      await _supabaseService.updateUserProfile(
        userId: widget.userId,
        fullName: name,
        handle: handle,
        bio: bio,
        avatar: avatar,
        age: age,
        interests: interests,
        hobbies: hobbies,
      );

      // 2. Update Local
      await UserService.updateUser(updatedUser);

      // 3. Reload
      await _loadProfile();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile identity successfully secured!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update: $e')));
        setState(() => _isLoading = false);
      }
    }
  }
}

class _ProfileHeroCard extends StatelessWidget {
  final User user;
  final VoidCallback onCopyNumber;

  const _ProfileHeroCard({required this.user, required this.onCopyNumber});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E30) : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.onSurface.withOpacity(0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 10,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF845EF7), Color(0xFFFF6B6B)],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 85,
                          height: 105,
                          decoration: BoxDecoration(
                            color: user.isCompany
                                ? const Color(0xFFFFD700).withOpacity(0.08)
                                : theme.colorScheme.onSurface.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: user.isCompany
                                  ? const Color(0xFFFFD700).withOpacity(0.35)
                                  : theme.colorScheme.onSurface.withOpacity(
                                      0.1,
                                    ),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              user.isCompany ? '🏢' : (user.avatar ?? '👤'),
                              style: const TextStyle(fontSize: 44),
                            ),
                          ),
                        ),
                        if (user.isCompany)
                          Positioned(
                            right: 4,
                            bottom: 4,
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF845EF7,
                                ), // deep purple — contrasts with gold crown
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: theme.colorScheme.surface,
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF845EF7,
                                    ).withOpacity(0.5),
                                    blurRadius: 6,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Text(
                                  '👑',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.isCompany
                                ? 'OFFICIAL BOOFER ENTITY'
                                : 'BOOFER IDENTITY',
                            style: TextStyle(
                              color: user.isCompany
                                  ? const Color(0xFF20C997)
                                  : const Color(0xFF845EF7),
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            user.fullName,
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Row(
                            children: [
                              Text(
                                '@${user.handle}',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.4),
                                  fontSize: 13,
                                ),
                              ),
                              if (!user.isCompany && user.age != null) ...[
                                Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  width: 4,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                Text(
                                  '${user.age} yrs',
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.4),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            user.bio.isNotEmpty
                                ? user.bio
                                : 'No bio identity established yet.',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.6,
                              ),
                              fontSize: 12,
                              height: 1.4,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  height: 1,
                  color: theme.colorScheme.onSurface.withOpacity(0.05),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'VIRTUAL NUMBER',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withOpacity(0.3),
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user.formattedVirtualNumber,
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: onCopyNumber,
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF845EF7).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.copy_rounded,
                          color: Color(0xFF845EF7),
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            width: double.infinity,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.05),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(24),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.policy_rounded,
                  color: theme.colorScheme.primary.withOpacity(0.5),
                  size: 14,
                ),
                const SizedBox(width: 8),
                Text(
                  'GOVERNMENT OF BOOFER',
                  style: TextStyle(
                    color: theme.colorScheme.primary.withOpacity(0.7),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
