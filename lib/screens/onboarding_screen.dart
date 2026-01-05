import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/onboarding_controller.dart';
import '../widgets/onboarding_step1.dart';
import '../widgets/onboarding_step2.dart';
import '../widgets/onboarding_step3.dart';
import 'main_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _progressAnimationController;
  late AnimationController _backgroundAnimationController;
  late AnimationController _pulseAnimationController;
  late Animation<double> _progressAnimation;
  late Animation<double> _backgroundAnimation;
  late Animation<double> _pulseAnimation;
  
  @override
  void initState() {
    super.initState();
    _setupControllers();
    _initializeOnboarding();
  }

  void _setupControllers() {
    _pageController = PageController();
    _progressAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _backgroundAnimationController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    );
    _pulseAnimationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressAnimationController,
      curve: Curves.easeInOut,
    ));
    
    _backgroundAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _backgroundAnimationController,
      curve: Curves.linear,
    ));
    
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseAnimationController,
      curve: Curves.easeInOut,
    ));
    
    // Start background animation
    _backgroundAnimationController.repeat();
    
    // Start pulse animation
    _pulseAnimationController.repeat(reverse: true);
  }

  void _initializeOnboarding() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = context.read<OnboardingController>();
      controller.initialize();
      _updateProgressAnimation(controller.currentStep);
    });
  }

  void _updateProgressAnimation(int step) {
    final progress = (step - 1) / 2; // 3 steps total, so step 1 = 0, step 2 = 0.5, step 3 = 1.0
    _progressAnimationController.animateTo(
      progress,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _progressAnimationController.dispose();
    _backgroundAnimationController.dispose();
    _pulseAnimationController.dispose();
    super.dispose();
  }

  void _handleNextStep() async {
    final controller = context.read<OnboardingController>();
    
    // Add haptic feedback
    HapticFeedback.lightImpact();
    
    if (controller.currentStep < 3) {
      // Move to next step in controller
      await controller.nextStep();
      
      // Animate to next page
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
      
      // Update progress animation
      _updateProgressAnimation(controller.currentStep);
    } else {
      // Complete onboarding
      await _completeOnboarding();
    }
  }

  void _handlePreviousStep() async {
    final controller = context.read<OnboardingController>();
    
    // Add haptic feedback
    HapticFeedback.lightImpact();
    
    if (controller.currentStep > 1) {
      // Move to previous step in controller
      controller.previousStep();
      
      // Animate to previous page
      await _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
      
      // Update progress animation
      _updateProgressAnimation(controller.currentStep);
    }
  }

  Future<void> _completeOnboarding() async {
    final controller = context.read<OnboardingController>();
    
    try {
      await controller.completeOnboarding();
      
      if (mounted) {
        // Navigate to main screen
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const MainScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 600),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to complete onboarding: $e'),
            backgroundColor: Colors.redAccent,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _completeOnboarding(),
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
        return Scaffold(
          body: AnimatedBuilder(
            animation: _backgroundAnimation,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.lerp(
                        const Color(0xFF1E3A8A),
                        const Color(0xFF3730A3),
                        _backgroundAnimation.value,
                      )!,
                      Color.lerp(
                        const Color(0xFF3B82F6),
                        const Color(0xFF6366F1),
                        _backgroundAnimation.value,
                      )!,
                      Color.lerp(
                        const Color(0xFF60A5FA),
                        const Color(0xFF8B5CF6),
                        _backgroundAnimation.value,
                      )!,
                    ],
                    stops: const [0.0, 0.6, 1.0],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    children: [
                      // Header with back button and progress
                      _buildHeader(controller),
                      
                      // Main content area
                      Expanded(
                        child: PageView.builder(
                          controller: _pageController,
                          physics: const NeverScrollableScrollPhysics(), // Disable swipe navigation
                          itemCount: 3,
                          onPageChanged: (index) {
                            // Sync controller step with page index
                            final targetStep = index + 1;
                            if (controller.currentStep != targetStep) {
                              controller.goToStep(targetStep);
                              _updateProgressAnimation(targetStep);
                            }
                          },
                          itemBuilder: (context, index) {
                            return AnimatedBuilder(
                              animation: _pageController,
                              builder: (context, child) {
                                double value = 1.0;
                                if (_pageController.position.haveDimensions) {
                                  value = _pageController.page! - index;
                                  value = (1 - (value.abs() * 0.3)).clamp(0.0, 1.0);
                                }
                                
                                return Transform.scale(
                                  scale: Curves.easeOut.transform(value),
                                  child: Opacity(
                                    opacity: value,
                                    child: _buildStepWidget(index),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildHeader(OnboardingController controller) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          // Top row with back button and step indicator
          Row(
            children: [
              // Back button (only show if not on first step)
              if (controller.currentStep > 1)
                AnimatedScale(
                  scale: controller.currentStep > 1 ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: IconButton(
                    onPressed: _handlePreviousStep,
                    icon: const Icon(
                      Icons.arrow_back_ios,
                      color: Colors.white,
                      size: 20,
                    ),
                    tooltip: 'Previous step',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                )
              else
                const SizedBox(width: 48), // Maintain spacing
              
              // Step indicator with animation
              Expanded(
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.3),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: Text(
                      'Step ${controller.currentStep} of 3',
                      key: ValueKey(controller.currentStep),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
              
              // Skip button (only show on steps 1 and 2)
              if (controller.currentStep < 3)
                AnimatedScale(
                  scale: controller.currentStep < 3 ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: TextButton(
                    onPressed: () => _showSkipDialog(),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Skip',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                )
              else
                const SizedBox(width: 48), // Maintain spacing
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Progress bar
          _buildProgressBar(controller),
        ],
      ),
    );
  }

  Widget _buildProgressBar(OnboardingController controller) {
    return Container(
      height: 8,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Stack(
        children: [
          // Background track with subtle animation
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Container(
                width: double.infinity,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1 * _pulseAnimation.value),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            },
          ),
          // Animated progress with enhanced visuals
          AnimatedBuilder(
            animation: _progressAnimation,
            builder: (context, child) {
              return FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: _progressAnimation.value,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.7),
                        Colors.white,
                        Colors.white.withOpacity(0.9),
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.5),
                        blurRadius: 12,
                        offset: const Offset(0, 2),
                      ),
                      BoxShadow(
                        color: Colors.white.withOpacity(0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          // Enhanced progress dots with micro-animations
          Positioned.fill(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(3, (index) {
                final isActive = controller.currentStep > index;
                final isCurrent = controller.currentStep == index + 1;
                return AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    final scale = isCurrent ? _pulseAnimation.value : 1.0;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOutCubic,
                      width: (isCurrent ? 16 : 10) * scale,
                      height: (isCurrent ? 16 : 10) * scale,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isActive || isCurrent 
                            ? Colors.white 
                            : Colors.white.withOpacity(0.4),
                        boxShadow: isActive || isCurrent ? [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.4),
                            blurRadius: 8 * scale,
                            offset: const Offset(0, 2),
                          ),
                          if (isCurrent) BoxShadow(
                            color: Colors.white.withOpacity(0.6),
                            blurRadius: 16 * scale,
                            offset: const Offset(0, 0),
                          ),
                        ] : null,
                      ),
                      child: isCurrent ? Center(
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF1E3A8A),
                          ),
                        ),
                      ) : null,
                    );
                  },
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  void _showSkipDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Skip Onboarding?'),
          content: const Text(
            'You can complete the setup later in Settings. Are you sure you want to skip?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _skipToMainScreen();
              },
              child: const Text('Skip'),
            ),
          ],
        );
      },
    );
  }

  void _skipToMainScreen() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const MainScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  Widget _buildStepWidget(int index) {
    switch (index) {
      case 0:
        return Consumer<OnboardingController>(
          builder: (context, controller, child) => OnboardingStep1(
            controller: controller,
            onNext: _handleNextStep,
          ),
        );
      case 1:
        return OnboardingStep2(
          onNext: _handleNextStep,
          onSkip: _handleNextStep, // Skip also moves to next step
        );
      case 2:
        return OnboardingStep3(onComplete: _completeOnboarding);
      default:
        return const SizedBox.shrink();
    }
  }
}