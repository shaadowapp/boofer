import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/onboarding_controller.dart';

class OnboardingStep2 extends StatefulWidget {
  final VoidCallback? onNext;
  final VoidCallback? onSkip;

  const OnboardingStep2({
    super.key,
    this.onNext,
    this.onSkip,
  });

  @override
  State<OnboardingStep2> createState() => _OnboardingStep2State();
}

class _OnboardingStep2State extends State<OnboardingStep2>
    with TickerProviderStateMixin {
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  final _pinFocusNode = FocusNode();
  final _confirmPinFocusNode = FocusNode();
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late AnimationController _shakeController;
  late Animation<Offset> _shakeAnimation;

  bool _isPinVisible = false;
  bool _isConfirmPinVisible = false;
  bool _isProcessing = false;
  String _pin = '';
  String _confirmPin = '';

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializeForm();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
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

    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _shakeAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0.1, 0),
    ).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.elasticIn,
    ));

    _animationController.forward();
  }

  void _initializeForm() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final controller = context.read<OnboardingController>();
        if (controller.userPin != null) {
          _pin = controller.userPin!;
          _confirmPin = controller.userPin!;
          _pinController.text = _pin;
          _confirmPinController.text = _confirmPin;
        }
      }
    });
  }

  @override
  void dispose() {
    _pinController.dispose();
    _confirmPinController.dispose();
    _pinFocusNode.dispose();
    _confirmPinFocusNode.dispose();
    _animationController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _onPinChanged(String value) async {
    setState(() {
      _pin = value;
      _isProcessing = true;
    });
    
    try {
      final controller = context.read<OnboardingController>();
      if (value.length == 4) {
        await controller.setUserPin(value);
        // Auto-focus to confirmation field
        if (mounted) {
          _confirmPinFocusNode.requestFocus();
        }
      } else {
        await controller.setUserPin(null);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save PIN: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _onConfirmPinChanged(String value) {
    setState(() {
      _confirmPin = value;
    });

    if (value.length == 4) {
      _validatePins();
    }
  }

  void _validatePins() async {
    if (_pin.length == 4 && _confirmPin.length == 4) {
      if (_pin == _confirmPin) {
        final controller = context.read<OnboardingController>();
        await controller.setUserPin(_pin);
        
        // Show success feedback
        HapticFeedback.lightImpact();
      } else {
        // Show error feedback
        _shakeController.forward().then((_) {
          _shakeController.reverse();
        });
        HapticFeedback.heavyImpact();
        
        // Clear confirmation field
        _confirmPinController.clear();
        _confirmPin = '';
        
        // Show error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PINs do not match. Please try again.'),
              backgroundColor: Colors.redAccent,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    }
  }

  void _handleContinue() async {
    if (_isProcessing) return;
    
    final controller = context.read<OnboardingController>();
    
    if (_pin.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a 4-digit PIN or skip this step'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_pin.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PIN must be exactly 4 digits'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_pin != _confirmPin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PINs do not match'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // Save PIN securely
      await controller.setUserPin(_pin);
      
      // Proceed to next step
      if (mounted) {
        widget.onNext?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save PIN: $e'),
            backgroundColor: Colors.redAccent,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _handleContinue(),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _handleSkip() async {
    if (_isProcessing) return;
    
    setState(() {
      _isProcessing = true;
    });

    try {
      final controller = context.read<OnboardingController>();
      await controller.skipPinSetup();
      if (mounted) {
        widget.onSkip?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to skip PIN setup: $e'),
            backgroundColor: Colors.redAccent,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _handleSkip(),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
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
                  backgroundColor: Colors.redAccent,
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

                  // PIN Setup Section
                  Expanded(
                    flex: 4,
                    child: _buildPinSetupSection(),
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
                    Icons.security,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          const Text(
            'Secure Your Account',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Set up a 4-digit PIN for added security',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.9),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'This step is optional and can be skipped',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.7),
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPinSetupSection() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // PIN Entry
        SlideTransition(
          position: _shakeAnimation,
          child: _buildPinInputField(
            controller: _pinController,
            focusNode: _pinFocusNode,
            label: 'Enter 4-digit PIN',
            isVisible: _isPinVisible,
            onChanged: _onPinChanged,
            onVisibilityToggle: () {
              setState(() {
                _isPinVisible = !_isPinVisible;
              });
            },
          ),
        ),

        const SizedBox(height: 24),

        // PIN Confirmation
        SlideTransition(
          position: _shakeAnimation,
          child: _buildPinInputField(
            controller: _confirmPinController,
            focusNode: _confirmPinFocusNode,
            label: 'Confirm PIN',
            isVisible: _isConfirmPinVisible,
            onChanged: _onConfirmPinChanged,
            onVisibilityToggle: () {
              setState(() {
                _isConfirmPinVisible = !_isConfirmPinVisible;
              });
            },
          ),
        ),

        const SizedBox(height: 24),

        // PIN Match Indicator
        _buildPinMatchIndicator(),
      ],
    );
  }

  Widget _buildPinInputField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required bool isVisible,
    required Function(String) onChanged,
    required VoidCallback onVisibilityToggle,
  }) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 300),
      tween: Tween(begin: 0.0, end: focusNode.hasFocus ? 1.0 : 0.0),
      builder: (context, focusValue, child) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: Matrix4.identity()..scale(1.0 + (focusValue * 0.02)),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: focusNode.hasFocus
                  ? [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : [],
            ),
            child: TextFormField(
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              obscureText: !isVisible,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 4,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w600,
                letterSpacing: 8,
              ),
              decoration: InputDecoration(
                labelText: label,
                counterText: '',
                suffixIcon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: IconButton(
                    key: ValueKey(isVisible),
                    icon: Icon(
                      isVisible ? Icons.visibility_off : Icons.visibility,
                      color: Colors.white.withOpacity(0.7),
                    ),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      onVisibilityToggle();
                    },
                  ),
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1 + (focusValue * 0.05)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Colors.white,
                    width: 2,
                  ),
                ),
                labelStyle: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 16 + (focusValue * 2),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPinMatchIndicator() {
    if (_pin.isEmpty || _confirmPin.isEmpty) {
      return const SizedBox.shrink();
    }

    final bool isMatch = _pin == _confirmPin && _pin.length == 4;
    final bool showIndicator = _pin.length == 4 && _confirmPin.isNotEmpty;

    if (!showIndicator) {
      return const SizedBox.shrink();
    }

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 400),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isMatch 
                  ? Colors.green.withOpacity(0.2) 
                  : Colors.red.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isMatch ? Colors.green : Colors.red,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isMatch ? Colors.green : Colors.red).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 300),
                  tween: Tween(begin: 0.0, end: 1.0),
                  builder: (context, iconValue, child) {
                    return Transform.scale(
                      scale: iconValue,
                      child: Icon(
                        isMatch ? Icons.check_circle : Icons.error,
                        color: isMatch ? Colors.green : Colors.red,
                        size: 24,
                      ),
                    );
                  },
                ),
                const SizedBox(width: 12),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 300),
                  style: TextStyle(
                    color: isMatch ? Colors.green : Colors.red,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                  child: Text(isMatch ? 'PINs match!' : 'PINs do not match'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionSection(OnboardingController controller) {
    final bool canContinue = _pin.length == 4 && _pin == _confirmPin && !_isProcessing;
    final bool canSkip = !_isProcessing;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        children: [
          // Skip Button
          Expanded(
            child: OutlinedButton(
              onPressed: canSkip ? _handleSkip : null,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white.withOpacity(0.5),
                side: BorderSide(
                  color: canSkip ? Colors.white : Colors.white.withOpacity(0.3),
                  width: 1,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Skip',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),

          const SizedBox(width: 16),

          // Continue Button
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: canContinue ? _handleContinue : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF1E3A8A),
                disabledBackgroundColor: Colors.white.withOpacity(0.3),
                disabledForegroundColor: Colors.white.withOpacity(0.5),
                elevation: canContinue ? 4 : 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: (_isProcessing || controller.isLoading)
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1E3A8A)),
                      ),
                    )
                  : const Text(
                      'Continue',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
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
          _buildProgressDot(true), // Step 2 - active
          _buildProgressLine(false),
          _buildProgressDot(false), // Step 3
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