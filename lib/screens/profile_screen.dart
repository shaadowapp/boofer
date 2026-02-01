import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/user_service.dart';
import '../services/local_storage_service.dart';
import '../services/google_auth_service.dart';
import '../models/user_model.dart';
import '../utils/svg_icons.dart';
import 'debug_user_data_screen.dart';

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
  List<String> _linkTreeUrls = [];

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
      print('🔄 Loading user data...');
      
      // First try to get user from local storage
      User? user = await UserService.getCurrentUser();
      print('📱 Local user: ${user?.id} - ${user?.fullName}');
      
      // If no local user or we want fresh data, fetch from Firestore
      if (user == null) {
        print('❌ No local user found, checking custom user ID...');
        
        // Try to get custom user ID from local storage
        final customUserId = await LocalStorageService.getString('custom_user_id');
        print('🆔 Custom user ID from storage: $customUserId');
        
        if (customUserId != null) {
          print('🔄 Fetching user from Firestore with custom ID: $customUserId');
          
          // Fetch user from Firestore using custom ID
          final doc = await FirebaseFirestore.instance
              .collection('users')
              .doc(customUserId)
              .get();
          
          if (doc.exists) {
            print('✅ User document found in Firestore');
            final userData = doc.data()!;
            print('📄 User data: $userData');
            
            user = User.fromJson(userData);
            // Update local storage with fresh data
            await UserService.setCurrentUser(user);
            print('✅ User data updated in local storage');
          } else {
            print('❌ User document not found in Firestore');
          }
        } else {
          print('❌ No custom user ID found in local storage');
        }
      } else {
        print('✅ Local user found, refreshing from Firestore...');
        
        // Refresh user data from Firestore to ensure it's up to date
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.id)
            .get();
        
        if (doc.exists) {
          print('✅ Fresh user data fetched from Firestore');
          final freshUser = User.fromJson(doc.data()!);
          // Update local storage with fresh data
          await UserService.setCurrentUser(freshUser);
          user = freshUser;
        } else {
          print('⚠️ User document not found in Firestore, using local data');
        }
      }
      
      setState(() {
        _currentUser = user;
        _fullNameController.text = user?.fullName ?? '';
        _handleController.text = user?.handle ?? '';
        _bioController.text = user?.bio ?? 'Hey there! I\'m using Boofer 👋';
        _linkTreeUrls = []; // Load saved links in real app
        _isLoading = false;
      });
      
      if (user != null) {
        print('✅ User data loaded successfully:');
        print('   - Name: ${user.fullName}');
        print('   - ID: ${user.id}');
        print('   - Handle: ${user.handle}');
        print('   - Virtual Number: ${user.virtualNumber}');
        print('   - Email: ${user.email}');
      } else {
        print('❌ No user data available');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('❌ Error loading profile: $e');
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
        updatedAt: DateTime.now(),
      );

      // Update in Firestore first using the custom user ID
      await FirebaseFirestore.instance
          .collection('users')
          .doc(updatedUser.id) // This is the custom user ID
          .update({
        'fullName': updatedUser.fullName,
        'handle': updatedUser.handle,
        'bio': updatedUser.bio,
        'updatedAt': updatedUser.updatedAt.toIso8601String(),
      });

      // Then update locally
      await UserService.updateUser(updatedUser);
      
      setState(() {
        _currentUser = updatedUser;
        _isEditing = false;
        _isLoading = false;
      });

      print('✅ Profile updated successfully');
      print('📄 Updated user: ${updatedUser.fullName} (${updatedUser.handle})');
      print('🆔 Custom User ID: ${updatedUser.id}');

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
      print('❌ Error saving profile: $e');
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
      _isEditing = false;
    });
  }

  void _copyNumber() {
    if (_currentUser?.virtualNumber != null) {
      Clipboard.setData(ClipboardData(text: _currentUser!.virtualNumber ?? ''));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Virtual number copied to clipboard'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _copyHandle() {
    if (_currentUser?.handle != null) {
      Clipboard.setData(ClipboardData(text: _currentUser!.formattedHandle));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Handle copied to clipboard'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _shareProfile() {
    if (_currentUser == null) return;

    final profileText = '''
Check out my Boofer profile!

Name: ${_currentUser!.fullName.isNotEmpty ? _currentUser!.fullName : _currentUser!.formattedHandle}
Handle: ${_currentUser!.formattedHandle}
Bio: ${_currentUser!.bio}
Virtual Number: ${_currentUser!.virtualNumber}

${_linkTreeUrls.isNotEmpty ? 'Links:\n${_linkTreeUrls.join('\n')}' : ''}

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

  void _showLinkTreeDialog() {
    showDialog(
      context: context,
      builder: (context) => LinkTreeDialog(
        currentLinks: _linkTreeUrls,
        onSave: (links) {
          setState(() {
            _linkTreeUrls = links;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Links updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        },
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout? You will need to sign in again.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _logout();
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    try {
      print('🔄 Starting logout process...');
      
      // Clear user data from UserService
      await UserService.clearUserData();
      print('✅ UserService data cleared');
      
      // Sign out from Google Auth and Firebase
      final googleAuthService = GoogleAuthService();
      await googleAuthService.signOut();
      print('✅ Google Auth and Firebase sign out completed');
      
      // Clear additional local storage
      await LocalStorageService.remove('custom_user_id');
      await LocalStorageService.remove('firebase_to_custom_id');
      await LocalStorageService.remove('firebase_uid');
      await LocalStorageService.remove('user_email');
      await LocalStorageService.remove('user_type');
      await LocalStorageService.remove('profile_completed');
      await LocalStorageService.remove('registered_emails'); // Clear stored emails
      print('✅ Local storage cleared');
      
      if (mounted) {
        // Navigate to onboarding screen (which is now an alias to Google sign-in)
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/onboarding',
          (route) => false,
        );
        print('✅ Navigated to onboarding screen');
      }
    } catch (e) {
      print('❌ Error during logout: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error during logout: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        title: const Text('Profile'),
        centerTitle: true,
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
              icon: const Icon(Icons.share),
              tooltip: 'Share profile',
            ),
            IconButton(
              onPressed: _loadUserData,
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh profile data',
            ),
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DebugUserDataScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.bug_report),
              tooltip: 'Debug user data',
            ),
            IconButton(
              onPressed: () => setState(() => _isEditing = true),
              icon: SvgIcons.sized(
                SvgIcons.edit,
                24,
                color: theme.colorScheme.onSurface,
              ),
              tooltip: 'Edit profile',
            ),
          ],
        ],
      ),
      body: _isLoading && !_isEditing
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Profile Header Section
                  _buildProfileHeader(),
                  const SizedBox(height: 32),
                  
                  // Profile Info Section
                  _buildProfileInfoSection(),
                  const SizedBox(height: 24),
                  
                  // Boofer Stats Section
                  _buildBooferStatsSection(),
                  const SizedBox(height: 24),
                  
                  // Account Details Section
                  _buildAccountDetailsSection(),
                  const SizedBox(height: 24),
                  
                  // Link Tree Section
                  _buildLinkTreeSection(),
                  const SizedBox(height: 32),
                  
                  // Logout Button
                  _buildLogoutButton(),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileHeader() {
    final theme = Theme.of(context);
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.secondary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 3,
                  ),
                ),
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  child: Text(
                    _currentUser?.initials ?? '?',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Photo upload feature coming soon!'),
                        ),
                      );
                    },
                    icon: Icon(
                      Icons.camera_alt,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                  ),
                ),
              ),
              // Online status indicator
              if (_currentUser?.status == UserStatus.online)
                Positioned(
                  top: 5,
                  right: 5,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            _currentUser?.displayName ?? 'Loading...',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _copyHandle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _currentUser?.formattedHandle ?? '@loading',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.copy,
                    color: Colors.white,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _currentUser?.bio ?? 'Hey there! I\'m using Boofer 👋',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.9),
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _currentUser?.status == UserStatus.online 
                      ? Icons.circle 
                      : Icons.circle_outlined,
                  color: _currentUser?.status == UserStatus.online 
                      ? Colors.green 
                      : Colors.white.withOpacity(0.7),
                  size: 12,
                ),
                const SizedBox(width: 8),
                Text(
                  _currentUser?.statusText ?? 'Offline',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileInfoSection() {
    final theme = Theme.of(context);
    
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.person,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Profile Information',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Full Name Field
            _buildInfoField(
              label: 'Full Name',
              controller: _fullNameController,
              enabled: _isEditing,
              icon: Icons.person_outline,
              hint: 'Enter your full name',
            ),
            const SizedBox(height: 16),
            
            // Handle Field
            _buildInfoField(
              label: 'Handle (@username)',
              controller: _handleController,
              enabled: _isEditing,
              icon: Icons.alternate_email,
              hint: 'Enter your handle',
              prefix: '@',
            ),
            const SizedBox(height: 16),
            
            // Bio Field
            _buildInfoField(
              label: 'Bio',
              controller: _bioController,
              enabled: _isEditing,
              icon: Icons.info_outline,
              maxLines: 3,
              hint: 'Tell people about yourself',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBooferStatsSection() {
    final theme = Theme.of(context);
    
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.analytics_outlined,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Your Boofer Stats',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.people,
                    label: 'Connections',
                    value: '24',
                    color: theme.colorScheme.primary,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.location_on,
                    label: 'Nearby',
                    value: '8',
                    color: const Color(0xFF34B7F1),
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.public,
                    label: 'Global',
                    value: '16',
                    color: const Color(0xFF9C27B0),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildAccountDetailsSection() {
    final theme = Theme.of(context);
    
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.account_circle,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Account Details',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // User ID
            _buildInfoTile(
              label: 'User ID',
              value: _currentUser?.id ?? 'Not available',
              icon: Icons.fingerprint,
              onTap: () {
                if (_currentUser?.id != null) {
                  Clipboard.setData(ClipboardData(text: _currentUser!.id));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('User ID copied to clipboard')),
                  );
                }
              },
              trailing: _currentUser?.id != null ? Icon(
                Icons.copy,
                size: 18,
                color: theme.colorScheme.primary,
              ) : null,
            ),
            const SizedBox(height: 12),
            
            // Virtual Number
            _buildInfoTile(
              label: 'Virtual Number',
              value: _currentUser?.virtualNumber ?? 'Not assigned',
              icon: Icons.phone,
              onTap: _currentUser?.virtualNumber != null ? _copyNumber : null,
              trailing: _currentUser?.virtualNumber != null ? Icon(
                Icons.copy,
                size: 18,
                color: theme.colorScheme.primary,
              ) : null,
            ),
            const SizedBox(height: 12),
            
            // Account Created
            _buildInfoTile(
              label: 'Account Created',
              value: _currentUser?.createdAt != null 
                  ? _formatDate(_currentUser!.createdAt)
                  : 'Loading...',
              icon: Icons.calendar_today,
            ),
            const SizedBox(height: 12),
            
            // Last Updated
            _buildInfoTile(
              label: 'Last Updated',
              value: _currentUser?.updatedAt != null 
                  ? _formatDate(_currentUser!.updatedAt)
                  : 'Loading...',
              icon: Icons.update,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()} weeks ago';
    } else if (difference.inDays < 365) {
      return '${(difference.inDays / 30).floor()} months ago';
    } else {
      return '${(difference.inDays / 365).floor()} years ago';
    }
  }

  Widget _buildInfoField({
    required String label,
    required TextEditingController controller,
    required bool enabled,
    required IconData icon,
    int maxLines = 1,
    String? hint,
    String? prefix,
  }) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.7),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          enabled: enabled,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            prefixText: prefix,
            prefixIcon: Padding(
              padding: const EdgeInsets.all(12),
              child: Icon(
                icon,
                size: 20,
                color: enabled 
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: theme.colorScheme.outline.withOpacity(0.3),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: theme.colorScheme.outline.withOpacity(0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: theme.colorScheme.primary,
                width: 2,
              ),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: theme.colorScheme.outline.withOpacity(0.2),
              ),
            ),
            filled: true,
            fillColor: enabled 
                ? theme.colorScheme.surface
                : theme.colorScheme.surfaceVariant.withOpacity(0.3),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoTile({
    required String label,
    required String value,
    required IconData icon,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    final theme = Theme.of(context);
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: theme.colorScheme.outline.withOpacity(0.2),
          ),
          borderRadius: BorderRadius.circular(12),
          color: theme.colorScheme.surface.withOpacity(0.5),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  Widget _buildLinkTreeSection() {
    final theme = Theme.of(context);
    
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Link Tree',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextButton.icon(
                  onPressed: _showLinkTreeDialog,
                  icon: Icon(
                    _linkTreeUrls.isEmpty ? Icons.add : Icons.edit,
                    size: 18,
                  ),
                  label: Text(_linkTreeUrls.isEmpty ? 'Add Links' : 'Edit'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Share your products, services, or social media links',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 16),
            
            if (_linkTreeUrls.isEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: theme.colorScheme.outline.withOpacity(0.3),
                    style: BorderStyle.solid,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.link,
                      size: 48,
                      color: theme.colorScheme.onSurface.withOpacity(0.3),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No links added yet',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add links to your website, social media, or products',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.4),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ] else ...[
              ...(_linkTreeUrls.asMap().entries.map((entry) {
                final index = entry.key;
                final url = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildLinkTile(url, index),
                );
              }).toList()),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLinkTile(String url, int index) {
    final theme = Theme.of(context);
    final displayUrl = url.length > 40 ? '${url.substring(0, 37)}...' : url;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.3),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              Icons.link,
              size: 16,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              displayUrl,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.primary,
                decoration: TextDecoration.underline,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: url));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Link copied to clipboard'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            icon: Icon(
              Icons.copy,
              size: 18,
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
            tooltip: 'Copy link',
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _showLogoutDialog,
        icon: const Icon(
          Icons.logout,
          color: Colors.red,
        ),
        label: const Text(
          'Logout',
          style: TextStyle(
            color: Colors.red,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.red),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}

// Link Tree Dialog for managing external links
class LinkTreeDialog extends StatefulWidget {
  final List<String> currentLinks;
  final Function(List<String>) onSave;

  const LinkTreeDialog({
    super.key,
    required this.currentLinks,
    required this.onSave,
  });

  @override
  State<LinkTreeDialog> createState() => _LinkTreeDialogState();
}

class _LinkTreeDialogState extends State<LinkTreeDialog> {
  late List<TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = widget.currentLinks
        .map((link) => TextEditingController(text: link))
        .toList();
    
    // Add empty controller if no links exist
    if (_controllers.isEmpty) {
      _controllers.add(TextEditingController());
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addLink() {
    setState(() {
      _controllers.add(TextEditingController());
    });
  }

  void _removeLink(int index) {
    setState(() {
      _controllers[index].dispose();
      _controllers.removeAt(index);
    });
  }

  void _saveLinks() {
    final links = _controllers
        .map((controller) => controller.text.trim())
        .where((link) => link.isNotEmpty)
        .toList();
    
    widget.onSave(links);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxHeight: 600),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Manage Links',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Add links to your website, social media, products, or services',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 24),
            
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    ...(_controllers.asMap().entries.map((entry) {
                      final index = entry.key;
                      final controller = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _buildLinkField(controller, index),
                      );
                    }).toList()),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _controllers.length < 10 ? _addLink : null,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Link'),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _saveLinks,
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLinkField(TextEditingController controller, int index) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: 'Link ${index + 1}',
              hintText: 'https://example.com',
              prefixIcon: const Icon(Icons.link),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              suffixIcon: _controllers.length > 1
                  ? IconButton(
                      onPressed: () => _removeLink(index),
                      icon: Icon(
                        Icons.remove_circle_outline,
                        color: Colors.red.shade400,
                      ),
                    )
                  : null,
            ),
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.next,
          ),
        ),
      ],
    );
  }
}