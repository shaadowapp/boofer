import 'dart:ui';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';
import '../services/user_profile_sync_service.dart';
import '../services/virtual_number_service.dart';
import '../services/local_storage_service.dart';

class ProfileCompletionModal extends StatefulWidget {
  final User initialUser;
  final VoidCallback onCompleted;

  const ProfileCompletionModal({
    super.key,
    required this.initialUser,
    required this.onCompleted,
  });

  @override
  State<ProfileCompletionModal> createState() => _ProfileCompletionModalState();
}

class _ProfileCompletionModalState extends State<ProfileCompletionModal>
    with TickerProviderStateMixin {
  late TextEditingController _nameController;
  late TextEditingController _usernameController;
  late TextEditingController _bioController;

  bool _isLoading = false;
  String? _usernameError;
  bool _isCheckingUsername = false;

  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize controllers with current user data
    _nameController = TextEditingController(text: widget.initialUser.fullName);
    _usernameController = TextEditingController(
      text: widget.initialUser.handle,
    );
    _bioController = TextEditingController(text: widget.initialUser.bio);

    // Setup animations
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));

    // Start animations
    _fadeController.forward();
    _slideController.forward();

    // Listen to username changes for validation
    _usernameController.addListener(_validateUsername);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    _slideController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _validateUsername() async {
    final username = _usernameController.text.trim();

    if (username.isEmpty) {
      setState(() {
        _usernameError = null;
        _isCheckingUsername = false;
      });
      return;
    }

    // Basic validation
    if (username.length < 3) {
      setState(() {
        _usernameError = 'Username must be at least 3 characters';
        _isCheckingUsername = false;
      });
      return;
    }

    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username)) {
      setState(() {
        _usernameError =
            'Username can only contain letters, numbers, and underscores';
        _isCheckingUsername = false;
      });
      return;
    }

    // Skip availability check if it's the same as current username
    if (username == widget.initialUser.handle) {
      setState(() {
        _usernameError = null;
        _isCheckingUsername = false;
      });
      return;
    }

    // Check availability
    setState(() {
      _isCheckingUsername = true;
      _usernameError = null;
    });

    try {
      final isAvailable = await UserService.instance.isHandleAvailable(
        username,
      );
      if (mounted) {
        setState(() {
          _usernameError = isAvailable ? null : 'Username is already taken';
          _isCheckingUsername = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _usernameError = 'Error checking username availability';
          _isCheckingUsername = false;
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    if (_isLoading) return;

    final name = _nameController.text.trim();
    final username = _usernameController.text.trim();
    final bio = _bioController.text.trim();

    // Validation
    if (name.isEmpty) {
      _showError('Please enter your name');
      return;
    }

    if (username.isEmpty) {
      _showError('Please enter a username');
      return;
    }

    if (_usernameError != null) {
      _showError('Please fix the username error');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      debugPrint('🔄 Saving comprehensive profile data...');

      // Generate virtual number for the user
      final virtualNumberService = VirtualNumberService();
      debugPrint(
        '🔄 Attempting to generate virtual number for user: ${widget.initialUser.id}',
      );

      final virtualNumber = await virtualNumberService
          .generateAndAssignVirtualNumber(widget.initialUser.id);

      if (virtualNumber == null) {
        debugPrint('❌ Virtual number generation failed');
        _showError('Failed to generate virtual number. Please try again.');
        return;
      }

      debugPrint('✅ Virtual number generated successfully: $virtualNumber');

      // Update user profile with all details including virtual number
      final updatedUser = widget.initialUser.copyWith(
        fullName: name,
        handle: username,
        bio: bio.isEmpty ? 'Hey there! I\'m using Boofer 👋' : bio,
        virtualNumber: virtualNumber,
        updatedAt: DateTime.now(),
      );

      // Use comprehensive sync service
      final syncService = UserProfileSyncService();

      // Sync profile with completion metadata and virtual number
      final success = await syncService.syncUserProfile(
        updatedUser,
        additionalData: {
          'profileCompleted': true,
          'profileCompletedAt': DateTime.now().toIso8601String(),
          'virtualNumber': virtualNumber,
          'virtualNumberAssignedAt': DateTime.now().toIso8601String(),
          'virtualNumberMetadata': {
            'assignedAt': DateTime.now().toIso8601String(),
            'assignedFrom': 'profile_completion',
            'format': '123-456-7890',
            'isActive': true,
          },
          'completionMetadata': {
            'completedFrom': 'mobile_app',
            'completionMethod': 'profile_modal',
            'fieldsCompleted': ['fullName', 'handle', 'bio', 'virtualNumber'],
            'completedAt': DateTime.now().toIso8601String(),
            'virtualNumberGenerated': true,
          },
        },
      );

      if (success && mounted) {
        // Save profile completion status to local storage
        try {
          await LocalStorageService.setString('profile_completed', 'true');
          await LocalStorageService.setString('user_type', 'completed_user');
          debugPrint('✅ Profile completion status saved to local storage');
        } catch (e) {
          debugPrint(
            '⚠️ Warning: Could not save profile completion to local storage: $e',
          );
          // Continue anyway - this is not critical
        }

        // Show success message with virtual number
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Profile completed successfully! 🎉'),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Your Boofer ID: $virtualNumber',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.trustBlue,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Close modal with animation
        await _slideController.reverse();
        await _fadeController.reverse();

        // Set timestamp to prevent showing modal again soon
        await LocalStorageService.setString(
          'profile_modal_last_dismissed',
          DateTime.now().toIso8601String(),
        );

        widget.onCompleted();
      } else {
        _showError('Failed to update profile. Please try again.');
      }
    } catch (e) {
      _showError('Error updating profile: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.danger,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return WillPopScope(
      onWillPop: () async => false, // Prevent dismissal
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            // Blurred background
            FadeTransition(
              opacity: _fadeAnimation,
              child: Container(
                width: double.infinity,
                height: double.infinity,
                color: Colors.black.withOpacity(0.7),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(color: Colors.black.withOpacity(0.2)),
                ),
              ),
            ),

            // Modal content
            Center(
              child: SlideTransition(
                position: _slideAnimation,
                child: Container(
                  margin: const EdgeInsets.all(24),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.scaffoldBackground(isDark),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header
                        Row(
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.trustBlue,
                                    AppColors.loveRose,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: const Icon(
                                Icons.person_add,
                                size: 30,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Complete Your Profile',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primaryText(isDark),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Let\'s set up your Boofer profile',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: AppColors.lightSecondaryText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 32),

                        // Profile picture placeholder
                        Center(
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 50,
                                backgroundColor: AppColors.trustBlue
                                    .withOpacity(0.1),
                                backgroundImage:
                                    widget.initialUser.profilePicture != null &&
                                        widget.initialUser.profilePicture!
                                            .startsWith('http')
                                    ? NetworkImage(
                                        widget.initialUser.profilePicture!,
                                      )
                                    : null,
                                child:
                                    widget.initialUser.avatar != null &&
                                        widget.initialUser.avatar!.isNotEmpty
                                    ? Text(
                                        widget.initialUser.avatar!,
                                        style: const TextStyle(fontSize: 40),
                                      )
                                    : (widget.initialUser.profilePicture ==
                                                  null ||
                                              !widget
                                                  .initialUser
                                                  .profilePicture!
                                                  .startsWith('http')
                                          ? Text(
                                              widget.initialUser.fullName
                                                  .split(' ')
                                                  .map(
                                                    (e) => e.isNotEmpty
                                                        ? e[0]
                                                        : '',
                                                  )
                                                  .take(2)
                                                  .join()
                                                  .toUpperCase(),
                                              style: const TextStyle(
                                                fontSize: 24,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.trustBlue,
                                              ),
                                            )
                                          : null),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: AppColors.trustBlue,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.scaffoldBackground(
                                        isDark,
                                      ),
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Name field
                        _buildTextField(
                          controller: _nameController,
                          label: 'Full Name',
                          hint: 'Enter your full name',
                          icon: Icons.person,
                        ),

                        const SizedBox(height: 16),

                        // Username field
                        _buildTextField(
                          controller: _usernameController,
                          label: 'Username',
                          hint: 'Choose a unique username',
                          icon: Icons.alternate_email,
                          errorText: _usernameError,
                          suffix: _isCheckingUsername
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppColors.trustBlue,
                                    ),
                                  ),
                                )
                              : _usernameError == null &&
                                    _usernameController.text.isNotEmpty
                              ? const Icon(
                                  Icons.check_circle,
                                  color: AppColors.trustBlue,
                                  size: 20,
                                )
                              : null,
                        ),

                        const SizedBox(height: 16),

                        // Bio field
                        _buildTextField(
                          controller: _bioController,
                          label: 'Bio (Optional)',
                          hint: 'Tell us about yourself...',
                          icon: Icons.info,
                          maxLines: 3,
                        ),

                        const SizedBox(height: 24),

                        // Features info
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.loveRose.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.loveRose.withOpacity(0.2),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'What you get when completing your profile:',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryText(isDark),
                                ),
                              ),
                              const SizedBox(height: 8),
                              _buildFeatureItem(
                                '🆔',
                                'Unique Boofer ID (Virtual Number)',
                              ),
                              _buildFeatureItem(
                                '👥',
                                'Connect with friends easily',
                              ),
                              _buildFeatureItem(
                                '🔍',
                                'Be discoverable by others',
                              ),
                              _buildFeatureItem(
                                '💬',
                                'Start chatting immediately',
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Save button
                        ElevatedButton(
                          onPressed: _isLoading ? null : _saveProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.trustBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Text('Generating Boofer ID...'),
                                  ],
                                )
                              : const Text(
                                  'Complete Profile',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),

                        const SizedBox(height: 16),

                        // Skip button (subtle)
                        TextButton(
                          onPressed: _isLoading
                              ? null
                              : () async {
                                  // Set timestamp to prevent showing modal again soon
                                  await LocalStorageService.setString(
                                    'profile_modal_last_dismissed',
                                    DateTime.now().toIso8601String(),
                                  );
                                  widget.onCompleted();
                                },
                          child: const Text(
                            'Skip for now',
                            style: TextStyle(
                              color: AppColors.lightSecondaryText,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildFeatureItem(String emoji, String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.primaryText(isDark),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? errorText,
    Widget? suffix,
    int maxLines = 1,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.primaryText(isDark),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.lightSecondaryText),
            prefixIcon: Icon(icon, color: AppColors.lightSecondaryText),
            suffixIcon: suffix,
            errorText: errorText,
            filled: true,
            fillColor: AppColors.trustBlue.withOpacity(0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppColors.trustBlue.withOpacity(0.2),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppColors.trustBlue.withOpacity(0.2),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppColors.trustBlue,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.danger),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: maxLines > 1 ? 16 : 12,
            ),
          ),
          style: TextStyle(color: AppColors.primaryText(isDark)),
        ),
      ],
    );
  }
}
