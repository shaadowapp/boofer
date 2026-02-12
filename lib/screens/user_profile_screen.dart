import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/user_service.dart';
import '../services/friend_request_service.dart';
import '../services/supabase_service.dart';
import '../models/user_model.dart';
import 'friend_chat_screen.dart';

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
  final FriendRequestService _friendRequestService =
      FriendRequestService.instance;
  final SupabaseService _supabaseService = SupabaseService.instance;

  User? _profileUser;
  User? _currentUser;
  bool _isLoading = true;
  bool _isOwnProfile = false;
  String _relationshipStatus = 'none';
  String? _requestId;
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

      // Load friendship status if viewing another user
      if (!_isOwnProfile && _currentUser != null && _profileUser != null) {
        final relationData = await _friendRequestService.getRelationshipStatus(
          _currentUser!.id,
          _profileUser!.id,
        );

        _relationshipStatus = relationData['status'] as String;
        _requestId = relationData['requestId'] as String?;
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
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
    final theme = Theme.of(context);

    // Check if profile picture exists
    final hasRealProfilePicture =
        _profileUser?.profilePicture != null &&
        _profileUser!.profilePicture!.isNotEmpty &&
        !_profileUser!.profilePicture!.contains('ui-avatars.com');

    if (hasRealProfilePicture) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: theme.colorScheme.outline.withOpacity(0.2),
            width: 2,
          ),
        ),
        child: ClipOval(
          child: Image.network(
            _profileUser!.profilePicture!,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return _buildInitialsAvatar(size, theme);
            },
          ),
        ),
      );
    }

    return _buildInitialsAvatar(size, theme);
  }

  Widget _buildInitialsAvatar(double size, ThemeData theme) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
          width: 2,
        ),
      ),
      child: Center(
        child: Text(
          _profileUser?.initials ?? '?',
          style: TextStyle(
            fontSize: size * 0.4,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
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
              const SizedBox(width: 6),
              Icon(Icons.verified, size: 20, color: theme.colorScheme.primary),
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
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
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

    final isFriend = _relationshipStatus == 'friends';

    return Row(
      children: [
        // Follow/Following/Requested button
        Expanded(flex: isFriend ? 1 : 2, child: _buildFollowButton(theme)),

        // Message button (only if friends)
        if (isFriend) ...[
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _openChat,
              icon: const Icon(Icons.message_outlined, size: 18),
              label: const Text('Message'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 24,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30), // Pill shape
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFollowButton(ThemeData theme) {
    switch (_relationshipStatus) {
      case 'none':
        return ElevatedButton(
          onPressed: _sendFollowRequest,
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30), // Pill shape
            ),
          ),
          child: const Text('Follow'),
        );

      case 'request_sent':
        return OutlinedButton(
          onPressed: null,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30), // Pill shape
            ),
          ),
          child: const Text('Requested'),
        );

      case 'request_received':
        return ElevatedButton(
          onPressed: _acceptRequest,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade600,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30), // Pill shape
            ),
          ),
          child: const Text('Accept Request'),
        );

      case 'friends':
        return OutlinedButton(
          onPressed: null,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.green.shade700,
            side: BorderSide(color: Colors.green.shade300),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30), // Pill shape
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check, size: 18, color: Colors.green.shade700),
              const SizedBox(width: 4),
              const Text('Following'),
            ],
          ),
        );

      default:
        return ElevatedButton(
          onPressed: _sendFollowRequest,
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30), // Pill shape
            ),
          ),
          child: const Text('Follow'),
        );
    }
  }

  Widget _buildStatsRow(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              '${_profileUser?.friendsCount ?? 0}',
              'Friends',
              Icons.people_outline,
              theme,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              '${_profileUser?.followerCount ?? 0}',
              'Followers',
              Icons.person_add_outlined,
              theme,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              '${_profileUser?.followingCount ?? 0}',
              'Following',
              Icons.person_outline,
              theme,
            ),
          ),
        ],
      ),
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
  Future<void> _sendFollowRequest() async {
    if (_currentUser == null || _profileUser == null) return;

    setState(() => _loadingAction = true);

    final success = await _friendRequestService.sendFriendRequest(
      fromUserId: _currentUser!.id,
      toUserId: _profileUser!.id,
      message: 'Hi! I\'d like to connect with you.',
    );

    if (mounted) {
      if (success) {
        await _loadProfile();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Follow request sent to ${_profileUser!.displayName}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
      setState(() => _loadingAction = false);
    }
  }

  Future<void> _acceptRequest() async {
    if (_currentUser == null || _requestId == null) return;

    setState(() => _loadingAction = true);

    final success = await _friendRequestService.acceptFriendRequest(
      requestId: _requestId!,
      userId: _currentUser!.id,
    );

    if (mounted) {
      if (success) {
        await _loadProfile();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'You are now friends with ${_profileUser!.displayName}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
      setState(() => _loadingAction = false);
    }
  }

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
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement block functionality
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('User blocked')));
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
