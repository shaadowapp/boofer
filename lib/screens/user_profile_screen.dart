import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/user_service.dart';
import '../services/supabase_service.dart';
import '../models/user_model.dart';
import '../providers/chat_provider.dart';
import '../providers/follow_provider.dart';
import '../widgets/follow_button.dart';
import 'package:provider/provider.dart';
import 'friend_chat_screen.dart';
import '../widgets/user_avatar.dart';
import '../core/constants.dart';

/// Dynamic user profile screen (like Instagram)
/// - If viewing own profile: Shows "Edit Profile" button
/// - If viewing other user: Shows "Follow/Following/Message" buttons
class UserProfileScreen extends StatefulWidget {
  final String userId; // User ID to display

  const UserProfileScreen({super.key, required this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  // Removed FriendRequestService
  final SupabaseService _supabaseService = SupabaseService.instance;

  User? _profileUser;
  User? _currentUser;
  bool _isLoading = true;
  bool _isOwnProfile = false;
  bool _loadingAction = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);

    try {
      // Load current user
      _currentUser = await UserService.getCurrentUser();

      // Check if viewing own profile
      _isOwnProfile = _currentUser?.id == widget.userId;

      // Load profile user data
      if (_isOwnProfile) {
        _profileUser = _currentUser;
      } else {
        _profileUser = await _supabaseService.getUserProfile(widget.userId);
      }

      // Load follow stats if viewing another user
      if (!_isOwnProfile && _currentUser != null && _profileUser != null) {
        final followProvider = context.read<FollowProvider>();
        await followProvider.loadFollowStats(widget.userId);
        await followProvider.checkFriendshipStatus(widget.userId);
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading profile: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        title: Text(
          _profileUser?.formattedHandle ?? 'Profile',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          // Share button for all profiles
          IconButton(
            onPressed: _shareProfile,
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share Profile',
          ),
          if (!_isOwnProfile && _profileUser != null)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                switch (value) {
                  case 'block':
                    _showBlockConfirmation();
                    break;
                  case 'report':
                    _showReportDialog();
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'block',
                  child: Row(
                    children: [
                      Icon(Icons.block, color: Colors.red),
                      SizedBox(width: 12),
                      Text('Block User', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'report',
                  child: Row(
                    children: [
                      Icon(Icons.report_outlined),
                      SizedBox(width: 12),
                      Text('Report'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _profileUser == null
          ? _buildErrorState()
          : SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 24),

                  // Profile Header with Avatar
                  _buildProfileHeader(theme),

                  const SizedBox(height: 16),

                  // Name and Bio Section
                  _buildNameBioSection(theme),

                  const SizedBox(height: 20),

                  // Action Buttons (Edit Profile OR Follow/Message)
                  _buildActionButtons(theme),

                  const SizedBox(height: 24),

                  // Stats Row
                  _buildStatsRow(theme),
                  const SizedBox(height: 24),

                  // Additional Info Cards
                  _buildInfoCards(theme),

                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_off_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'User not found',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(ThemeData theme) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: _buildAvatar(size: 120),
        ),
      ],
    );
  }

  Widget _buildAvatar({double size = 90}) {
    return UserAvatar(
      profilePicture: _profileUser?.profilePicture,
      avatar: _profileUser?.avatar,
      name: _profileUser?.fullName ?? _profileUser?.handle,
      radius: size / 2,
      fontSize: size * 0.5,
    );
  }

  Widget _buildNameBioSection(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Name with verification badge
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  _profileUser?.fullName ?? '',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 8),
              if (_profileUser?.isVerified ?? false) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.verified,
                  size: 20,
                  color: _profileUser?.id == AppConstants.booferId
                      ? Colors.green
                      : theme.colorScheme.primary,
                ),
              ],
            ],
          ),

          const SizedBox(height: 12),

          // Bio (removed handle from here)
          Text(
            _profileUser?.bio ?? '',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: _isOwnProfile
          ? _buildOwnProfileButtons(theme)
          : _buildOtherUserButtons(theme),
    );
  }

  Widget _buildOwnProfileButtons(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              // Navigate back to the main profile screen which has edit functionality
              Navigator.pop(context);
              // Or you can navigate to a dedicated edit screen if you create one
            },
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Edit Profile'),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              minimumSize: const Size.fromHeight(44), // Consistent height
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30), // Pill shape
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOtherUserButtons(ThemeData theme) {
    if (_loadingAction) {
      return const Center(child: CircularProgressIndicator());
    }

    return Consumer<FollowProvider>(
      builder: (context, provider, child) {
        final isFriend = provider.isFriends(widget.userId);

        return Row(
          children: [
            // Follow/Following button - Hide for Boofer
            if (widget.userId != AppConstants.booferId)
              Expanded(child: _buildFollowButton(theme)),

            if (isFriend || widget.userId == AppConstants.booferId) ...[
              if (widget.userId != AppConstants.booferId)
                const SizedBox(width: 12),

              // Message button - only shown if friends (or Boofer)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _openChat,
                  icon: const Icon(Icons.message_outlined, size: 18),
                  label: const Text('Message'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44), // Consistent height
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30), // Pill shape
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

  Widget _buildFollowButton(ThemeData theme) {
    if (_profileUser == null) return const SizedBox.shrink();
    return FollowButton(user: _profileUser!);
  }

  Widget _buildStatsRow(ThemeData theme) {
    if (_profileUser == null) return const SizedBox.shrink();

    return Consumer<FollowProvider>(
      builder: (context, followProvider, child) {
        final stats = followProvider.getFollowStats(_profileUser!.id);
        final isBoofer = _profileUser!.id == AppConstants.booferId;

        // Special layout for Boofer
        if (isBoofer) {
          return Center(
            child: Column(
              children: [
                Text(
                  '${stats?.followersCount ?? 0}',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                Text(
                  'Followers',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  '${stats?.followersCount ?? 0}',
                  'Followers',
                  Icons.people_outline,
                  theme,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  '${stats?.followingCount ?? 0}',
                  'Following',
                  Icons.person_outline,
                  theme,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(
    String value,
    String label,
    IconData icon,
    ThemeData theme,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Icon(icon, color: theme.colorScheme.primary, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCards(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          _buildInfoCard(
            theme,
            icon: Icons.phone_outlined,
            title: 'Virtual Number',
            value: _profileUser?.virtualNumber ?? 'Not set',
          ),
          const SizedBox(height: 12),
          _buildInfoCard(
            theme,
            icon: Icons.calendar_today_outlined,
            title: 'Joined',
            value: _formatDate(_profileUser?.createdAt),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown';
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  // Actions

  void _openChat() {
    if (_profileUser == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FriendChatScreen(
          recipientId: _profileUser!.id,
          recipientName: _profileUser!.displayName,
          recipientHandle: _profileUser!.handle,
          recipientAvatar: _profileUser!.profilePicture ?? '',
        ),
      ),
    );
  }

  void _shareProfile() {
    if (_profileUser == null) return;

    final profileText =
        '''
Check out ${_isOwnProfile ? 'my' : '${_profileUser!.displayName}\'s'} Boofer profile!

Name: ${_profileUser!.fullName.isNotEmpty ? _profileUser!.fullName : _profileUser!.formattedHandle}
Handle: ${_profileUser!.formattedHandle}
Bio: ${_profileUser!.bio}

Download Boofer for secure messaging!
''';

    Clipboard.setData(ClipboardData(text: profileText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile copied to clipboard - Share it anywhere!'),
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _showBlockConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block User'),
        content: Text(
          'Are you sure you want to block ${_profileUser?.displayName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              if (_profileUser == null) return;

              // Show loading Snackbar
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Blocking user...')));

              try {
                // Call ChatProvider to block
                await context.read<ChatProvider>().blockUser(_profileUser!.id);

                if (!context.mounted) return;

                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Blocked ${_profileUser!.displayName}'),
                    action: SnackBarAction(
                      label: 'Undo',
                      onPressed: () async {
                        // Undo block logic if needed, or just info
                        try {
                          await context.read<ChatProvider>().unblockUser(
                            _profileUser!.id,
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('User unblocked')),
                            );
                          }
                        } catch (e) {
                          // ignore
                        }
                      },
                    ),
                  ),
                );

                // Pop back to previous screen as we typically don't view blocked profiles
                Navigator.of(context).pop();
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error blocking user: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Block'),
          ),
        ],
      ),
    );
  }

  void _showReportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report User'),
        content: const Text('Please select a reason for reporting this user.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement report functionality
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Report submitted')));
            },
            child: const Text('Report'),
          ),
        ],
      ),
    );
  }
}
