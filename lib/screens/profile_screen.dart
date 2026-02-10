import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/user_service.dart';
import '../services/local_storage_service.dart';
import '../models/user_model.dart';
import '../utils/svg_icons.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _handleController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  bool _isEditing = false;
  bool _isLoading = false;
  User? _currentUser;
  String _selectedAvatar = '';

  // Modern diverse avatar options - gender inclusive
  final List<Map<String, dynamic>> _avatarOptions = [
    // People - Diverse skin tones and genders
    {'emoji': '👨', 'color': const Color(0xFFFFE5B4), 'category': 'People'},
    {'emoji': '👩', 'color': const Color(0xFFFFB4E5), 'category': 'People'},
    {'emoji': '🧑', 'color': const Color(0xFFB4E5FF), 'category': 'People'},
    {'emoji': '👨🏻', 'color': const Color(0xFFFFE5D4), 'category': 'People'},
    {'emoji': '👩🏻', 'color': const Color(0xFFFFD4E5), 'category': 'People'},
    {'emoji': '👨🏼', 'color': const Color(0xFFFFE5C4), 'category': 'People'},
    {'emoji': '👩🏼', 'color': const Color(0xFFFFD4D4), 'category': 'People'},
    {'emoji': '👨🏽', 'color': const Color(0xFFE5D4B4), 'category': 'People'},
    {'emoji': '👩🏽', 'color': const Color(0xFFFFD4C4), 'category': 'People'},
    {'emoji': '👨🏾', 'color': const Color(0xFFD4C4B4), 'category': 'People'},
    {'emoji': '👩🏾', 'color': const Color(0xFFE5C4D4), 'category': 'People'},
    {'emoji': '👨🏿', 'color': const Color(0xFFC4B4A4), 'category': 'People'},
    {'emoji': '👩🏿', 'color': const Color(0xFFD4B4C4), 'category': 'People'},
    {'emoji': '🧔', 'color': const Color(0xFFB4D4FF), 'category': 'People'},
    {'emoji': '👱‍♀️', 'color': const Color(0xFFFFE4B4), 'category': 'People'},
    {'emoji': '👱‍♂️', 'color': const Color(0xFFB4FFE4), 'category': 'People'},
    {'emoji': '🧑‍🦱', 'color': const Color(0xFFE4B4FF), 'category': 'People'},
    {'emoji': '👨‍🦱', 'color': const Color(0xFFFFB4D4), 'category': 'People'},
    {'emoji': '👩‍🦱', 'color': const Color(0xFFD4FFB4), 'category': 'People'},
    {'emoji': '🧑‍🦰', 'color': const Color(0xFFFFD4B4), 'category': 'People'},
    {'emoji': '👨‍🦰', 'color': const Color(0xFFB4FFD4), 'category': 'People'},
    {'emoji': '👩‍🦰', 'color': const Color(0xFFD4B4FF), 'category': 'People'},
    {'emoji': '👴', 'color': const Color(0xFFE5E5E5), 'category': 'People'},
    {'emoji': '👵', 'color': const Color(0xFFFFE5E5), 'category': 'People'},
    {'emoji': '🧓', 'color': const Color(0xFFE5FFE5), 'category': 'People'},
    
    // Expressions
    {'emoji': '😊', 'color': const Color(0xFFFFE5B4), 'category': 'Expressions'},
    {'emoji': '😎', 'color': const Color(0xFFB4E5FF), 'category': 'Expressions'},
    {'emoji': '🤩', 'color': const Color(0xFFFFB4E5), 'category': 'Expressions'},
    {'emoji': '🥳', 'color': const Color(0xFFE5FFB4), 'category': 'Expressions'},
    {'emoji': '😇', 'color': const Color(0xFFFFD4B4), 'category': 'Expressions'},
    {'emoji': '🤗', 'color': const Color(0xFFD4B4FF), 'category': 'Expressions'},
    {'emoji': '🧐', 'color': const Color(0xFFB4FFD4), 'category': 'Expressions'},
    {'emoji': '🤓', 'color': const Color(0xFFFFB4D4), 'category': 'Expressions'},
    {'emoji': '😴', 'color': const Color(0xFFD4E5FF), 'category': 'Expressions'},
    {'emoji': '🤔', 'color': const Color(0xFFFFE4D4), 'category': 'Expressions'},
    {'emoji': '😌', 'color': const Color(0xFFE4FFD4), 'category': 'Expressions'},
    {'emoji': '🥰', 'color': const Color(0xFFFFD4E4), 'category': 'Expressions'},
    
    // Animals
    {'emoji': '😺', 'color': const Color(0xFFD4FFB4), 'category': 'Animals'},
    {'emoji': '🐶', 'color': const Color(0xFFB4D4FF), 'category': 'Animals'},
    {'emoji': '🦊', 'color': const Color(0xFFFFD4D4), 'category': 'Animals'},
    {'emoji': '🐼', 'color': const Color(0xFFD4FFD4), 'category': 'Animals'},
    {'emoji': '🦁', 'color': const Color(0xFFFFE4B4), 'category': 'Animals'},
    {'emoji': '🐯', 'color': const Color(0xFFE4B4FF), 'category': 'Animals'},
    {'emoji': '🦄', 'color': const Color(0xFFFFB4E4), 'category': 'Animals'},
    {'emoji': '🐨', 'color': const Color(0xFFB4FFE4), 'category': 'Animals'},
    {'emoji': '🐻', 'color': const Color(0xFFE4D4B4), 'category': 'Animals'},
    {'emoji': '🐰', 'color': const Color(0xFFFFE4E4), 'category': 'Animals'},
    {'emoji': '🦝', 'color': const Color(0xFFD4D4E4), 'category': 'Animals'},
    {'emoji': '🐸', 'color': const Color(0xFFD4FFD4), 'category': 'Animals'},
    
    // Fantasy & Fun
    {'emoji': '👽', 'color': const Color(0xFFB4FFB4), 'category': 'Fantasy'},
    {'emoji': '🤖', 'color': const Color(0xFFB4D4E5), 'category': 'Fantasy'},
    {'emoji': '👻', 'color': const Color(0xFFE5E5FF), 'category': 'Fantasy'},
    {'emoji': '🎭', 'color': const Color(0xFFFFE5FF), 'category': 'Fantasy'},
    {'emoji': '🎨', 'color': const Color(0xFFFFD4FF), 'category': 'Fantasy'},
    {'emoji': '🎮', 'color': const Color(0xFFD4E5FF), 'category': 'Fantasy'},
    {'emoji': '🎵', 'color': const Color(0xFFFFE4FF), 'category': 'Fantasy'},
    {'emoji': '⚡', 'color': const Color(0xFFFFFFB4), 'category': 'Fantasy'},
    {'emoji': '🌟', 'color': const Color(0xFFFFFFD4), 'category': 'Fantasy'},
    {'emoji': '💎', 'color': const Color(0xFFD4E5FF), 'category': 'Fantasy'},
    {'emoji': '🔥', 'color': const Color(0xFFFFD4B4), 'category': 'Fantasy'},
    {'emoji': '🌈', 'color': const Color(0xFFFFE5E5), 'category': 'Fantasy'},
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _handleController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      User? user = await UserService.getCurrentUser();
      
      if (user == null) {
        final customUserId = await LocalStorageService.getString('custom_user_id');
        
        if (customUserId != null) {
          final doc = await FirebaseFirestore.instance
              .collection('users')
              .doc(customUserId)
              .get();
          
          if (doc.exists) {
            user = User.fromJson(doc.data()!);
            await UserService.setCurrentUser(user);
          }
        }
      } else {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.id)
            .get();
        
        if (doc.exists) {
          final freshUser = User.fromJson(doc.data()!);
          await UserService.setCurrentUser(freshUser);
          user = freshUser;
        }
      }
      
      setState(() {
        _currentUser = user;
        _fullNameController.text = user?.fullName ?? '';
        _handleController.text = user?.handle ?? '';
        _bioController.text = user?.bio ?? 'Hey there! I\'m using Boofer 👋';
        _selectedAvatar = user?.avatar ?? '';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile: $e')),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (_currentUser == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final updatedUser = _currentUser!.copyWith(
        fullName: _fullNameController.text.trim(),
        handle: _handleController.text.trim(),
        bio: _bioController.text.trim(),
        avatar: _selectedAvatar,
        updatedAt: DateTime.now(),
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(updatedUser.id)
          .update({
        'fullName': updatedUser.fullName,
        'handle': updatedUser.handle,
        'bio': updatedUser.bio,
        'avatar': updatedUser.avatar,
        'updatedAt': updatedUser.updatedAt.toIso8601String(),
      });

      await UserService.updateUser(updatedUser);
      
      setState(() {
        _currentUser = updatedUser;
        _isEditing = false;
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving profile: $e')),
        );
      }
    }
  }

  void _cancelEditing() {
    setState(() {
      _fullNameController.text = _currentUser?.fullName ?? '';
      _handleController.text = _currentUser?.handle ?? '';
      _bioController.text = _currentUser?.bio ?? '';
      _selectedAvatar = _currentUser?.avatar ?? '';
      _isEditing = false;
    });
  }

  void _showAvatarPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildAvatarPicker(),
    );
  }

  void _shareProfile() {
    if (_currentUser == null) return;

    final profileText = '''
Check out my Boofer profile!

Name: ${_currentUser!.fullName.isNotEmpty ? _currentUser!.fullName : _currentUser!.formattedHandle}
Handle: ${_currentUser!.formattedHandle}
Bio: ${_currentUser!.bio}

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        title: Text(
          _currentUser?.formattedHandle ?? 'Profile',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          if (_isEditing) ...[
            TextButton(
              onPressed: _isLoading ? null : _cancelEditing,
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: _isLoading ? null : _saveProfile,
              child: _isLoading 
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ] else ...[
            IconButton(
              onPressed: _shareProfile,
              icon: const Icon(Icons.share_outlined),
              tooltip: 'Share Profile',
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                switch (value) {
                  case 'settings':
                    Navigator.pushNamed(context, '/settings');
                    break;
                  case 'archive':
                    Navigator.pushNamed(context, '/archived-chats');
                    break;
                  case 'help':
                    Navigator.pushNamed(context, '/help');
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'settings',
                  child: Row(
                    children: [
                      Icon(Icons.settings_outlined),
                      SizedBox(width: 12),
                      Text('Settings'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'archive',
                  child: Row(
                    children: [
                      Icon(Icons.archive_outlined),
                      SizedBox(width: 12),
                      Text('Archived Chats'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'help',
                  child: Row(
                    children: [
                      Icon(Icons.help_outline),
                      SizedBox(width: 12),
                      Text('Help & Support'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      body: _isLoading && !_isEditing
          ? const Center(child: CircularProgressIndicator())
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
                  
                  // Action Buttons
                  _buildActionButtons(theme),
                  
                  const SizedBox(height: 24),
                  
                  // Stats Row (Instagram style)
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

  Widget _buildProfileHeader(ThemeData theme) {
    return Column(
      children: [
        // Avatar with direct tap to change
        GestureDetector(
          onTap: _showAvatarPicker,
          child: Stack(
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
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.colorScheme.surface,
                      width: 3,
                    ),
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAvatar({double size = 90}) {
    final theme = Theme.of(context);
    
    if (_selectedAvatar.isNotEmpty) {
      final avatarData = _avatarOptions.firstWhere(
        (a) => a['emoji'] == _selectedAvatar,
        orElse: () => _avatarOptions[0],
      );
      
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [
              avatarData['color'] as Color,
              (avatarData['color'] as Color).withOpacity(0.7),
            ],
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
            _selectedAvatar,
            style: TextStyle(fontSize: size * 0.5),
          ),
        ),
      );
    }
    
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.secondary,
          ],
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
          _currentUser?.initials ?? '?',
          style: TextStyle(
            fontSize: size * 0.4,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildStatColumn(String value, String label, ThemeData theme) {
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildNameBioSection(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Name with verification badge
          if (!_isEditing)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    _currentUser?.fullName ?? '',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.verified,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
              ],
            ),
          
          if (_isEditing)
            TextField(
              controller: _fullNameController,
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          
          const SizedBox(height: 8),
          
          // Handle
          if (!_isEditing)
            Text(
              _currentUser?.formattedHandle ?? '',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
          
          const SizedBox(height: 12),
          
          // Bio
          if (!_isEditing)
            Text(
              _currentUser?.bio ?? '',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          
          if (_isEditing)
            TextField(
              controller: _bioController,
              maxLines: 3,
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                labelText: 'Bio',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(ThemeData theme) {
    if (_isEditing) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: ElevatedButton.icon(
              onPressed: () => setState(() => _isEditing = true),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Edit Profile'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: OutlinedButton.icon(
              onPressed: _shareProfile,
              icon: const Icon(Icons.share_outlined, size: 18),
              label: const Text('Share'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(child: _buildStatCard(
            '${_currentUser?.friendsCount ?? 0}', 
            'Friends', 
            Icons.people_outline, 
            theme
          )),
          const SizedBox(width: 12),
          Expanded(child: _buildStatCard(
            '${_currentUser?.followerCount ?? 0}', 
            'Followers', 
            Icons.person_add_outlined, 
            theme
          )),
          const SizedBox(width: 12),
          Expanded(child: _buildStatCard(
            '${_currentUser?.followingCount ?? 0}', 
            'Following', 
            Icons.person_outline, 
            theme
          )),
        ],
      ),
    );
  }

  Widget _buildStatCard(String value, String label, IconData icon, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.1),
        ),
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
            icon: Icons.location_on_outlined,
            title: 'Location',
            value: _currentUser?.location ?? 'Not specified',
            color: Colors.red,
          ),
          const SizedBox(height: 12),
          _buildInfoCard(
            theme,
            icon: Icons.calendar_today_outlined,
            title: 'Joined',
            value: _formatDate(_currentUser?.createdAt),
            color: Colors.blue,
          ),
          const SizedBox(height: 12),
          _buildInfoCard(
            theme,
            icon: Icons.phone_outlined,
            title: 'Virtual Number',
            value: _currentUser?.virtualNumber ?? 'Not assigned',
            color: Colors.green,
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
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
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
                  style: theme.textTheme.bodyLarge?.copyWith(
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
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.year}';
  }

  Widget _buildAvatarPicker() {
    final theme = Theme.of(context);
    final categories = ['People', 'Expressions', 'Animals', 'Fantasy'];
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Choose Avatar',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_avatarOptions.length} diverse options',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: DefaultTabController(
              length: categories.length,
              child: Column(
                children: [
                  TabBar(
                    isScrollable: true,
                    labelColor: theme.colorScheme.primary,
                    unselectedLabelColor: theme.colorScheme.onSurface.withOpacity(0.6),
                    indicatorColor: theme.colorScheme.primary,
                    tabs: categories.map((cat) => Tab(text: cat)).toList(),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: categories.map((category) {
                        final categoryAvatars = _avatarOptions
                            .where((a) => a['category'] == category)
                            .toList();
                        
                        return GridView.builder(
                          padding: const EdgeInsets.all(24),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                          itemCount: categoryAvatars.length,
                          itemBuilder: (context, index) {
                            final avatar = categoryAvatars[index];
                            final isSelected = _selectedAvatar == avatar['emoji'];
                            
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedAvatar = avatar['emoji'] as String;
                                });
                                Navigator.pop(context);
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [
                                      avatar['color'] as Color,
                                      (avatar['color'] as Color).withOpacity(0.7),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  border: Border.all(
                                    color: isSelected
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.outline.withOpacity(0.2),
                                    width: isSelected ? 3 : 2,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: theme.colorScheme.primary.withOpacity(0.3),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Center(
                                  child: Text(
                                    avatar['emoji'] as String,
                                    style: const TextStyle(fontSize: 36),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      }).toList(),
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
}
