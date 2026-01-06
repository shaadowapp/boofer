import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/onboarding_controller.dart';
import '../constants/app_colors.dart';

class OnboardingStep3 extends StatefulWidget {
  final VoidCallback? onComplete;

  const OnboardingStep3({
    super.key,
    this.onComplete,
  });

  @override
  State<OnboardingStep3> createState() => _OnboardingStep3State();
}

class _OnboardingStep3State extends State<OnboardingStep3>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _numberAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _numberScaleAnimation;
  late Animation<double> _numberFadeAnimation;

  bool _contactsRequested = false;
  bool _inviteSent = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializeStep();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _numberAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _numberScaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _numberAnimationController,
      curve: Curves.elasticOut,
    ));

    _numberFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _numberAnimationController,
      curve: Curves.easeIn,
    ));

    _animationController.forward();
    
    // Delay number animation
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        _numberAnimationController.forward();
      }
    });
  }

  void _initializeStep() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final controller = context.read<OnboardingController>();
        // Generate virtual number if not already generated
        if (controller.virtualNumber.isEmpty) {
          controller.generateVirtualNumber();
        }
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _numberAnimationController.dispose();
    super.dispose();
  }

  void _copyNumberToClipboard(String number) {
    Clipboard.setData(ClipboardData(text: number));
    HapticFeedback.lightImpact();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Text('Virtual number copied: $number'),
          ],
        ),
        backgroundColor: AppColors.brandAccent,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _handleInviteFriends() {
    setState(() {
      _inviteSent = true;
    });

    HapticFeedback.lightImpact();
    
    // Simulate invite functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.share, color: Colors.white),
            SizedBox(width: 8),
            Text('Invite feature will be available soon!'),
          ],
        ),
        backgroundColor: AppColors.info,
        duration: Duration(seconds: 2),
      ),
    );

    // Reset state after animation
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _inviteSent = false;
        });
      }
    });
  }

  void _handleContactAccess() {
    setState(() {
      _contactsRequested = true;
    });

    HapticFeedback.lightImpact();
    
    // Simulate contact access request
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.contacts, color: Colors.white),
            SizedBox(width: 8),
            Text('Contact access feature will be available soon!'),
          ],
        ),
        backgroundColor: AppColors.electricOrchid,
        duration: Duration(seconds: 2),
      ),
    );

    // Reset state after animation
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _contactsRequested = false;
        });
      }
    });
  }

  void _handleContinue() async {
    final controller = context.read<OnboardingController>();
    
    // Validate that we have all required data
    if (controller.virtualNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Virtual number is not ready. Please wait...'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    if (controller.userName.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User name is missing. Please go back and complete registration.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    if (!controller.termsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Terms must be accepted to complete setup.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    try {
      // Show completion feedback
      HapticFeedback.lightImpact();
      
      // Complete onboarding through the callback
      widget.onComplete?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to complete setup: $e'),
            backgroundColor: AppColors.danger,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _handleContinue(),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<OnboardingController>(
      builder: (context, controller, child) {
        // Handle controller errors
        if (controller.errorMessage != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(controller.errorMessage!),
                  backgroundColor: AppColors.danger,
                  action: SnackBarAction(
                    label: 'Dismiss',
                    textColor: Colors.white,
                    onPressed: () {
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    },
                  ),
                ),
              );
            }
          });
        }

        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  // Header Section
                  Expanded(
                    flex: 2,
                    child: _buildHeaderSection(),
                  ),

                  // Virtual Number Display Section
                  Expanded(
                    flex: 3,
                    child: _buildVirtualNumberSection(controller),
                  ),

                  // Optional Actions Section
                  Expanded(
                    flex: 2,
                    child: _buildOptionalActionsSection(),
                  ),

                  // Action Section
                  _buildActionSection(controller),

                  // Progress Indicator
                  _buildProgressIndicator(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderSection() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 600),
            tween: Tween(begin: 0.0, end: 1.0),
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.fingerprint,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          const Text(
            'Your Digital Identity',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your unique virtual number is ready',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.9),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildVirtualNumberSection(OnboardingController controller) {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Virtual Number Display
          FadeTransition(
            opacity: _numberFadeAnimation,
            child: ScaleTransition(
              scale: _numberScaleAnimation,
              child: GestureDetector(
                onTap: controller.virtualNumber.isNotEmpty 
                    ? () => _copyNumberToClipboard(controller.virtualNumber)
                    : null,
                child: TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 300),
                  tween: Tween(begin: 1.0, end: controller.virtualNumber.isNotEmpty ? 1.0 : 0.95),
                  builder: (context, scale, child) {
                    return Transform.scale(
                      scale: scale,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                            if (controller.virtualNumber.isNotEmpty)
                              BoxShadow(
                                color: Colors.white.withOpacity(0.1),
                                blurRadius: 20,
                                offset: const Offset(0, 0),
                              ),
                          ],
                        ),
                        child: Column(
                          children: [
                            TweenAnimationBuilder<double>(
                              duration: const Duration(milliseconds: 500),
                              tween: Tween(begin: 0.0, end: 1.0),
                              builder: (context, iconValue, child) {
                                return Transform.rotate(
                                  angle: iconValue * 0.1,
                                  child: Icon(
                                    Icons.phone_android,
                                    color: Colors.white.withOpacity(0.9 + (iconValue * 0.1)),
                                    size: 28,
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 500),
                              child: Text(
                                controller.virtualNumber.isNotEmpty 
                                    ? controller.virtualNumber 
                                    : 'Generating...',
                                key: ValueKey(controller.virtualNumber),
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: controller.virtualNumber.isNotEmpty ? 2 : 1,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (controller.virtualNumber.isNotEmpty)
                              TweenAnimationBuilder<double>(
                                duration: const Duration(milliseconds: 400),
                                tween: Tween(begin: 0.0, end: 1.0),
                                builder: (context, copyValue, child) {
                                  return Transform.scale(
                                    scale: copyValue,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.3),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.copy,
                                            color: Colors.white,
                                            size: 14,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Tap to copy',
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(0.9),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Identity Explanation
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This number serves as your identity',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Use this virtual number to connect with others while keeping your real number private.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.8),
                    height: 1.3,
                  ),
                  textAlign: TextAlign.left,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionalActionsSection() {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Optional Actions',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 12),
          
          Row(
            children: [
              // Invite Friends Button
              Expanded(
                child: _buildOptionalActionButton(
                  icon: _inviteSent ? Icons.check : Icons.share,
                  label: _inviteSent ? 'Invited!' : 'Invite Friends',
                  onTap: _inviteSent ? null : _handleInviteFriends,
                  color: AppColors.info,
                  isActive: _inviteSent,
                ),
              ),
              
              const SizedBox(width: 12),
              
              // Contact Access Button
              Expanded(
                child: _buildOptionalActionButton(
                  icon: _contactsRequested ? Icons.check : Icons.contacts,
                  label: _contactsRequested ? 'Requested!' : 'Contact Access',
                  onTap: _contactsRequested ? null : _handleContactAccess,
                  color: AppColors.electricOrchid,
                  isActive: _contactsRequested,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          Text(
            'These features can be enabled later in settings',
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withOpacity(0.6),
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildOptionalActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    required Color color,
    bool isActive = false,
  }) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 300),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.8 + (value * 0.2),
          child: GestureDetector(
            onTap: onTap,
            onTapDown: (_) {
              HapticFeedback.selectionClick();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              decoration: BoxDecoration(
                color: isActive 
                    ? color.withOpacity(0.3) 
                    : Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isActive 
                      ? color 
                      : Colors.white.withOpacity(0.3),
                  width: isActive ? 2 : 1,
                ),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: color.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : [],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, animation) {
                      return ScaleTransition(
                        scale: animation,
                        child: RotationTransition(
                          turns: animation,
                          child: child,
                        ),
                      );
                    },
                    child: Icon(
                      icon,
                      key: ValueKey(icon),
                      color: isActive ? color : Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 6),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 300),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isActive ? color : Colors.white,
                    ),
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionSection(OnboardingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: controller.virtualNumber.isNotEmpty ? _handleContinue : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF1E3A8A),
            disabledBackgroundColor: Colors.white.withOpacity(0.3),
            disabledForegroundColor: Colors.white.withOpacity(0.5),
            elevation: controller.virtualNumber.isNotEmpty ? 4 : 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: controller.isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1E3A8A)),
                  ),
                )
              : const Text(
                  'Complete Setup',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildProgressDot(true), // Step 1 - completed
          _buildProgressLine(true),
          _buildProgressDot(true), // Step 2 - completed
          _buildProgressLine(true),
          _buildProgressDot(true), // Step 3 - active
        ],
      ),
    );
  }

  Widget _buildProgressDot(bool isActive) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? Colors.white : Colors.white.withOpacity(0.3),
      ),
    );
  }

  Widget _buildProgressLine(bool isCompleted) {
    return Container(
      width: 40,
      height: 2,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: isCompleted ? Colors.white : Colors.white.withOpacity(0.3),
    );
  }
}