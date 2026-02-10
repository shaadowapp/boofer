import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../services/user_service.dart';
import '../services/local_storage_service.dart';
import '../services/profile_picture_service.dart';
import '../models/user_model.dart';
import 'settings_screen.dart';
import 'archived_chats_screen.dart';
import 'help_screen.dart';
import 'friends_screen.dart';
import 'user_search_screen.dart';
import 'appearance_settings_screen.dart';

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
  StreamSubscription<String?>? _profilePictureSubscription;

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
    
    // Listen to profile picture updates
    _profilePictureSubscription = ProfilePictureService.instance.profilePictureStream.listen((url) {
      if (mounted && _currentUser != null && url != _currentUser!.profilePicture) {
        print('📸 Profile screen received update: $url');
        setState(() {
          _currentUser = _currentUser!.copyWith(profilePicture: url);
        });
      }
    });
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _handleController.dispose();
    _bioController.dispose();
    _profilePictureSubscription?.cancel();
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
            print('📸 Loaded user from Firestore - Profile picture: ${user.profilePicture}');
          }
        }
      } else {
        // Refresh from Firestore to get latest data
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.id)
            .get();
        
        if (doc.exists) {
          final freshUser = User.fromJson(doc.data()!);
          await UserService.setCurrentUser(freshUser);
          user = freshUser;
          print('📸 Refreshed user from Firestore - Profile picture: ${user.profilePicture}');
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
      
      print('✅ Profile loaded - Name: ${user?.fullName}, Picture: ${user?.profilePicture}');
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

      // Update local storage and broadcast profile picture change
      await UserService.setCurrentUser(updatedUser);
      
      // Also update ProfilePictureService to broadcast the change
      // Note: ProfilePictureService stores the profilePicture URL, not avatar emoji
      // But we still need to trigger a refresh for the UI
      await ProfilePictureService.instance.updateProfilePicture(updatedUser.profilePicture);
      
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
      builder: (context) => _buildAvatarPickerSheet(),
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
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const SettingsScreen()),
                    );
                    break;
                  case 'archive':
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ArchivedChatsScreen()),
                    );
                    break;
                  case 'help':
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const HelpScreen()),
                    );
                    break;
                  case 'friends':
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const FriendsScreen()),
                    );
                    break;
                  case 'discover':
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const UserSearchScreen()),
                    );
                    break;
                  case 'appearance':
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AppearanceSettingsScreen()),
                    );
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'friends',
                  child: Row(
                    children: [
                      Icon(Icons.people_outline),
                      SizedBox(width: 12),
                      Text('Friends'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'discover',
                  child: Row(
                    children: [
                      Icon(Icons.explore_outlined),
                      SizedBox(width: 12),
                      Text('Discover Users'),
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
                  value: 'appearance',
                  child: Row(
                    children: [
                      Icon(Icons.palette_outlined),
                      SizedBox(width: 12),
                      Text('Appearance'),
                    ],
                  ),
                ),
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
          : RefreshIndicator(
              onRefresh: _loadUserData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
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
          ),
    );
  }

  Widget _buildProfileHeader(ThemeData theme) {
    return Column(
      children: [
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
                    Icons.edit,
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
    
    // Check if profile picture is a real uploaded image (not UI-avatars generated)
    final hasRealProfilePicture = _currentUser?.profilePicture != null && 
        _currentUser!.profilePicture!.isNotEmpty &&
        !_currentUser!.profilePicture!.contains('ui-avatars.com');
    
    // First priority: Show actual uploaded profile picture
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
            _currentUser!.profilePicture!,
            key: ValueKey(_currentUser!.profilePicture), // Force rebuild on URL change
            width: size,
            height: size,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                      : null,
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              print('❌ Error loading profile picture: $error');
              // Fallback to emoji avatar if image fails to load
              return _buildEmojiOrInitialsAvatar(size, theme);
            },
          ),
        ),
      );
    }
    
    // Second priority: Show emoji avatar or initials
    return _buildEmojiOrInitialsAvatar(size, theme);
  }

  Widget _buildEmojiOrInitialsAvatar(double size, ThemeData theme) {
    // Show emoji avatar if selected
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
    
    // Fallback: Show initials
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
          
          const SizedBox(height: 12),
          
          // Bio (removed handle from here since it's in navbar)
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
      child: ElevatedButton.icon(
        onPressed: () => setState(() => _isEditing = true),
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

  Widget _buildAvatarPickerSheet() {
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
                              onTap: () async {
                                final selectedEmoji = avatar['emoji'] as String;
                                setState(() {
                                  _selectedAvatar = selectedEmoji;
                                });
                                
                                // Close the bottom sheet first
                                if (mounted) {
                                  Navigator.pop(context);
                                }
                                
                                // Save immediately to Firestore
                                if (_currentUser != null) {
                                  try {
                                    final selectedEmoji = avatar['emoji'] as String;
                                    final selectedColor = (avatar['color'] as Color).value.toRadixString(16).padLeft(8, '0');
                                    
                                    print('📸 Saving emoji avatar: $selectedEmoji with color: $selectedColor');
                                    
                                    await FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(_currentUser!.id)
                                        .update({
                                      'avatar': selectedEmoji,
                                      'avatarColor': selectedColor,
                                      'updatedAt': DateTime.now().toIso8601String(),
                                    });
                                    
                                    final updatedUser = _currentUser!.copyWith(
                                      avatar: selectedEmoji,
                                      updatedAt: DateTime.now(),
                                    );
                                    
                                    await UserService.setCurrentUser(updatedUser);
                                    
                                    if (mounted) {
                                      setState(() {
                                        _currentUser = updatedUser;
                                      });
                                      
                                      print('✅ Emoji avatar saved with color!');
                                      
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Avatar updated!'),
                                          backgroundColor: Colors.green,
                                          duration: Duration(seconds: 1),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    print('❌ Error saving avatar: $e');
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Error: $e')),
                                      );
                                    }
                                  }
                                }
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
