import 'dart:math' show pi;
import 'package:flutter/material.dart';
import '../services/multi_account_storage_service.dart';
import 'signup_steps_screen.dart';
import 'auth/login_screen.dart';

/// Attractive landing page that shows when no active session exists.
/// Handles the Sign Up → multi-step wizard OR Login → account picker flow.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  late final PageController _pageController;
  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;

  int _currentPage = 0;
  bool _hasSavedAccounts = false;
  bool _loading = true;

  // Slide content
  static const _slides = [
    _SlideData(
      emoji: '🔥',
      title: 'Meet your\nnext spark',
      subtitle:
          'Anonymous. Exciting. Real connections — without giving away who you are.',
      color: Color(0xFFFF6B6B),
    ),
    _SlideData(
      emoji: '🎭',
      title: 'Be whoever\nyou want',
      subtitle:
          'Create your persona, choose your vibe. No names. No numbers. Just you.',
      color: Color(0xFF845EF7),
    ),
    _SlideData(
      emoji: '💬',
      title: 'Chat. Flirt.\nConnect.',
      subtitle:
          'End-to-end encrypted. Your conversations stay between you and your match.',
      color: Color(0xFF20C997),
    ),
    _SlideData(
      emoji: '🌍',
      title: 'Your world,\nyour circle',
      subtitle:
          'Discover people near you or across the globe. Build your private social world.',
      color: Color(0xFFFF922B),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _checkSavedAccounts();
  }

  Future<void> _checkSavedAccounts() async {
    final accounts = await MultiAccountStorageService.getSavedAccounts();
    if (mounted) {
      setState(() {
        _hasSavedAccounts = accounts.isNotEmpty;
        _loading = false;
      });
      _animController.forward();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _goToSignup() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SignupStepsScreen()),
    );
  }

  void _goToLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F0F1A),
        body: Center(child: CircularProgressIndicator(color: Colors.white30)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: Stack(
        children: [
          // Animated background blobs
          const _BackgroundBlobs(),

          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Column(
                children: [
                  // Top logo row
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF845EF7), Color(0xFFFF6B6B)],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.chat_bubble_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Boofer',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Feature slides
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      onPageChanged: (i) => setState(() => _currentPage = i),
                      itemCount: _slides.length,
                      itemBuilder: (_, i) => _SlideWidget(slide: _slides[i]),
                    ),
                  ),

                  // Page indicator dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _slides.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == i ? 20 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: _currentPage == i
                              ? _slides[_currentPage].color
                              : Colors.white24,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // CTAs
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        // Primary button: Create Account
                        _GradientButton(
                          onTap: _goToSignup,
                          label: 'Create Account',
                          icon: Icons.auto_awesome_rounded,
                          gradient: LinearGradient(
                            colors: [
                              _slides[_currentPage].color,
                              _slides[_currentPage].color.withOpacity(0.7),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Login button
                        if (_hasSavedAccounts) ...[
                          _OutlineButton(
                            onTap: _goToLogin,
                            label: 'Switch Account',
                            icon: Icons.phone_android_rounded,
                          ),
                        ] else ...[
                          _OutlineButton(
                            onTap: _goToLogin,
                            label: 'I already have an account',
                            icon: Icons.login_rounded,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Footer note
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      'By continuing you agree to our Terms & Privacy Policy',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.3),
                        fontSize: 11,
                      ),
                      textAlign: TextAlign.center,
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

// ─── Data class for slides ────────────────────────────────────────────────────

class _SlideData {
  final String emoji;
  final String title;
  final String subtitle;
  final Color color;
  const _SlideData({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.color,
  });
}

// ─── Individual slide widget ──────────────────────────────────────────────────

class _SlideWidget extends StatefulWidget {
  final _SlideData slide;
  const _SlideWidget({required this.slide});

  @override
  State<_SlideWidget> createState() => _SlideWidgetState();
}

class _SlideWidgetState extends State<_SlideWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Glow emoji
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.slide.color.withOpacity(0.15),
                  boxShadow: [
                    BoxShadow(
                      color: widget.slide.color.withOpacity(0.3),
                      blurRadius: 40,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    widget.slide.emoji,
                    style: const TextStyle(fontSize: 52),
                  ),
                ),
              ),
              const SizedBox(height: 36),
              Text(
                widget.slide.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  height: 1.15,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                widget.slide.subtitle,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.55),
                  fontSize: 15,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Animated gradient background ────────────────────────────────────────────

class _BackgroundBlobs extends StatefulWidget {
  const _BackgroundBlobs();

  @override
  State<_BackgroundBlobs> createState() => _BackgroundBlobsState();
}

class _BackgroundBlobsState extends State<_BackgroundBlobs>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = _ctrl.value * 2 * pi;
        return CustomPaint(painter: _BlobPainter(t), size: Size.infinite);
      },
    );
  }
}

class _BlobPainter extends CustomPainter {
  final double t;
  _BlobPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..blendMode = BlendMode.screen;

    // blob 1 - purple top-left
    paint.shader =
        RadialGradient(
          colors: [
            const Color(0xFF845EF7).withOpacity(0.35),
            Colors.transparent,
          ],
        ).createShader(
          Rect.fromCircle(
            center: Offset(
              size.width * 0.15 + 40 * (1 + _sin(t * 0.7)),
              size.height * 0.15 + 30 * _sin(t * 0.5),
            ),
            radius: 220,
          ),
        );
    canvas.drawCircle(
      Offset(
        size.width * 0.15 + 40 * (1 + _sin(t * 0.7)),
        size.height * 0.15 + 30 * _sin(t * 0.5),
      ),
      220,
      paint,
    );

    // blob 2 - pink bottom-right
    paint.shader =
        RadialGradient(
          colors: [
            const Color(0xFFFF6B6B).withOpacity(0.28),
            Colors.transparent,
          ],
        ).createShader(
          Rect.fromCircle(
            center: Offset(
              size.width * 0.85 + 30 * _sin(t * 0.6),
              size.height * 0.75 + 40 * _sin(t * 0.8),
            ),
            radius: 200,
          ),
        );
    canvas.drawCircle(
      Offset(
        size.width * 0.85 + 30 * _sin(t * 0.6),
        size.height * 0.75 + 40 * _sin(t * 0.8),
      ),
      200,
      paint,
    );
  }

  double _sin(double v) => (v % (2 * pi)) < pi
      ? ((v % (2 * pi)) / pi) * 2 - 1
      : 1 - (((v % (2 * pi)) - pi) / pi) * 2;

  @override
  bool shouldRepaint(_BlobPainter old) => old.t != t;
}

// ─── Reusable buttons ─────────────────────────────────────────────────────────

class _GradientButton extends StatelessWidget {
  final VoidCallback onTap;
  final String label;
  final IconData icon;
  final Gradient gradient;

  const _GradientButton({
    required this.onTap,
    required this.label,
    required this.icon,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 56,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  final VoidCallback onTap;
  final String label;
  final IconData icon;

  const _OutlineButton({
    required this.onTap,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white24),
          borderRadius: BorderRadius.circular(16),
          color: Colors.white.withOpacity(0.05),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white70, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
