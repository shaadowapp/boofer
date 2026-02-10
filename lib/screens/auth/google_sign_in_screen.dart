import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../providers/auth_state_provider.dart';
import '../../services/google_auth_service.dart';
import '../../widgets/custom_button.dart';

class GoogleSignInScreen extends StatefulWidget {
  const GoogleSignInScreen({super.key});

  @override
  State<GoogleSignInScreen> createState() => _GoogleSignInScreenState();
}

class _GoogleSignInScreenState extends State<GoogleSignInScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    // Start animations
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleSignIn() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final googleAuthService = GoogleAuthService();
      final user = await googleAuthService.signInWithGoogle();
      
      if (mounted && user != null) {
        // Update auth state
        final authProvider = context.read<AuthStateProvider>();
        await authProvider.checkAuthState();
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Welcome to Boofer! 🎉'),
              ],
            ),
            backgroundColor: AppColors.trustBlue,
            duration: Duration(seconds: 2),
          ),
        );
        
        // Navigate to main screen (chats tab) - user profile is automatically completed
        Navigator.of(context).pushReplacementNamed('/main');
      } else if (mounted) {
        // Sign-in was cancelled or failed silently
        _showErrorDialog(
          'Sign In Cancelled',
          'You cancelled the sign-in process. Please try again to continue.',
          showRetry: true,
        );
      }
    } catch (e) {
      if (mounted) {
        String errorTitle = 'Sign In Failed';
        String errorMessage = 'An unexpected error occurred. Please try again.';
        bool showNetworkHelp = false;

        // Parse error and provide user-friendly messages
        final errorString = e.toString().toLowerCase();
        
        if (errorString.contains('network_error') || 
            errorString.contains('apiexception: 7')) {
          errorTitle = 'No Internet Connection';
          errorMessage = 'Unable to connect to Google services. Please check your internet connection and try again.';
          showNetworkHelp = true;
        } else if (errorString.contains('sign_in_cancelled') || 
                   errorString.contains('cancelled')) {
          errorTitle = 'Sign In Cancelled';
          errorMessage = 'You cancelled the sign-in process.';
        } else if (errorString.contains('sign_in_failed')) {
          errorTitle = 'Sign In Failed';
          errorMessage = 'Unable to sign in with Google. Please try again.';
        } else if (errorString.contains('account_exists')) {
          errorTitle = 'Account Already Exists';
          errorMessage = 'An account with this email already exists. Please sign in instead.';
        }

        _showErrorDialog(errorTitle, errorMessage, 
          showRetry: true, 
          showNetworkHelp: showNetworkHelp,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showErrorDialog(String title, String message, {
    bool showRetry = false,
    bool showNetworkHelp = false,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              showNetworkHelp ? Icons.wifi_off : Icons.error_outline,
              color: AppColors.danger,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            if (showNetworkHelp) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.trustBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.trustBlue.withOpacity(0.3),
                  ),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, 
                          size: 16, 
                          color: AppColors.trustBlue,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Troubleshooting Tips:',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      '• Check your Wi-Fi or mobile data\n'
                      '• Try turning airplane mode off\n'
                      '• Restart your device if needed\n'
                      '• Make sure Google services are accessible',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          if (showRetry)
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _handleGoogleSignIn();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.trustBlue,
              ),
              child: const Text('Try Again'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground(isDark),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo/Icon section
                  Container(
                    height: 120,
                    width: 120,
                    margin: const EdgeInsets.only(bottom: 32),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [
                          AppColors.trustBlue,
                          AppColors.loveRose,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.trustBlue.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.chat_bubble_rounded,
                      size: 60,
                      color: Colors.white,
                    ),
                  ),

                  // Welcome text
                  Text(
                    'Welcome to Boofer',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryText(isDark),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 12),
                  
                  const Text(
                    'Connect with your loved ones in a secure, private space',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.lightSecondaryText,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 48),

                  // Google Sign In Button
                  Consumer<AuthStateProvider>(
                    builder: (context, authProvider, child) {
                      return CustomButton(
                        text: _isLoading ? 'Signing in...' : 'Continue with Google',
                        onPressed: _isLoading ? null : _handleGoogleSignIn,
                        isLoading: _isLoading,
                        icon: !_isLoading ? Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Center(
                            child: Text(
                              'G',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.trustBlue,
                              ),
                            ),
                          ),
                        ) : null,
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // Privacy notice
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.trustBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.trustBlue.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.security,
                          color: AppColors.trustBlue,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Your privacy is our priority. All messages are end-to-end encrypted.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.primaryText(isDark),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Features list
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
                          'What you get with Boofer:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryText(isDark),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildFeatureItem('🔒', 'End-to-end encrypted messages'),
                        _buildFeatureItem('🌐', 'Works online and offline'),
                        _buildFeatureItem('👥', 'Connect with friends securely'),
                        _buildFeatureItem('🎨', 'Beautiful, customizable themes'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
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
}