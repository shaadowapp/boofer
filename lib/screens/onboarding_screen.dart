import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/anonymous_auth_service.dart';
import '../providers/auth_state_provider.dart';
import '../providers/firestore_user_provider.dart';

/// Privacy-focused onboarding screen with one-click anonymous signup
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool _isCreatingProfile = false;
  String _statusMessage = '';

  Future<void> _createAnonymousProfile() async {
    setState(() {
      _isCreatingProfile = true;
      _statusMessage = 'Checking internet connection...';
    });

    try {
      final authService = AnonymousAuthService();

      setState(() {
        _statusMessage = 'Creating virtual identity...';
      });

      final user = await authService.createAnonymousUser();

      if (user != null) {
        setState(() {
          _statusMessage = 'Profile created successfully!';
        });

        // Update auth state
        final authProvider = context.read<AuthStateProvider>();
        await authProvider.checkAuthState();

        // Initialize user provider
        final userProvider = context.read<FirestoreUserProvider>();
        await userProvider.initialize();

        await Future.delayed(const Duration(milliseconds: 500));

        if (mounted) {
          Navigator.pushReplacementNamed(context, '/legal-acceptance');
        }
      } else {
        setState(() {
          _statusMessage =
              'Failed to create profile. Please check your internet connection and try again.';
          _isCreatingProfile = false;
        });

        // Show error dialog
        if (mounted) {
          _showErrorDialog(
            'Signup Failed',
            'Unable to create your profile. Please ensure you have an active internet connection and try again.',
          );
        }
      }
    } catch (e) {
      final errorMessage = e.toString().replaceAll('Exception: ', '');
      setState(() {
        _statusMessage = errorMessage;
        _isCreatingProfile = false;
      });

      // Show error dialog
      if (mounted) {
        _showErrorDialog('Signup Failed', errorMessage);
      }
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6), Color(0xFF60A5FA)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),

                // App Icon
                const Icon(
                  Icons.chat_bubble_rounded,
                  size: 100,
                  color: Colors.white,
                ),

                const SizedBox(height: 24),

                // App Name
                const Text(
                  'Boofer',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 1,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 12),

                // Tagline
                const Text(
                  'Privacy-first messaging',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white70,
                    fontWeight: FontWeight.w400,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 48),

                // Privacy Features
                _buildFeatureItem(
                  icon: Icons.shield_outlined,
                  title: 'No Email Required',
                  description: 'Your privacy is our priority',
                ),

                const SizedBox(height: 16),

                _buildFeatureItem(
                  icon: Icons.phone_android_outlined,
                  title: 'Virtual Phone Number',
                  description: 'Auto-generated for your safety',
                ),

                const SizedBox(height: 16),

                _buildFeatureItem(
                  icon: Icons.person_outline,
                  title: 'Anonymous Identity',
                  description: 'Random username and profile',
                ),

                const Spacer(),

                // Status Message
                if (_statusMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Text(
                      _statusMessage,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ),

                // Create Profile Button
                ElevatedButton(
                  onPressed: _isCreatingProfile
                      ? null
                      : _createAnonymousProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF1E3A8A),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                  ),
                  child: _isCreatingProfile
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFF1E3A8A),
                            ),
                          ),
                        )
                      : const Text(
                          'Create Anonymous Profile',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),

                const SizedBox(height: 16),

                // Privacy Note
                const Text(
                  'No personal information required.\nYour data stays private.',
                  style: TextStyle(fontSize: 12, color: Colors.white60),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
