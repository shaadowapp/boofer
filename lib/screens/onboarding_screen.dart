import 'dart:async' show Timer;
import 'dart:math' show pi, sin;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/multi_account_storage_service.dart';
import '../services/local_storage_service.dart';
import '../providers/auth_state_provider.dart';
import 'signup_steps_screen.dart';
import 'main_screen.dart';
import 'legal_acceptance_screen.dart';
import 'terms_of_service_screen.dart';
import 'privacy_policy_screen.dart';
import '../services/receive_share_service.dart';
import '../main.dart';

/// Smart auth gateway — shown only when:
///   • 0 saved accounts  → signup flow (slides + swipe-to-start)
///   • 2+ saved accounts → account picker (cards + swipe to login selected)
///
/// Single account is handled in main.dart (direct /main route).
class OnboardingScreen extends StatefulWidget {
  final List<Map<String, dynamic>>? initialAccounts;

  const OnboardingScreen({super.key, this.initialAccounts});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  // ── State ──
  List<Map<String, dynamic>> _accounts = [];
  bool _loading = true;

  // For multi-account picker
  int _selectedIndex = 0;
  bool _isLoggingIn = false;
  String? _loginError;

  // Slides page controller
  late final PageController _pageController;
  int _currentSlide = 0;
  int _virtualPage = 1000;

  // Animations
  late final AnimationController _entranceCtrl;
  late final Animation<double> _fadeAnim;

  // Auto-advance slides
  Timer? _timer;
  bool _isInteracting = false;

  // ── Slide definitions ──
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
    _SlideData(
      emoji: '⚡',
      title: 'Fast name,\nFaster chats',
      subtitle:
          'It\'s called Boofer, but your connections won\'t be "buffery". Everything is built for speed and instant discovery.',
      color: Color(0xFFFCC419),
    ),
  ];

  @override
  void initState() {
    super.initState();

    _pageController = PageController(
      initialPage: 1000,
    ); // High base for infinite scroll

    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOut);

    _init();

    // Process any pending share intent captured during splash
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ReceiveShareService.instance.init(BooferApp.navigatorKey);
    });
  }

  Future<void> _init() async {
    final accounts =
        widget.initialAccounts ??
        await MultiAccountStorageService.getSavedAccounts();
    if (!mounted) return;

    setState(() {
      _accounts = accounts;
      _loading = false;
    });

    _entranceCtrl.forward();

    if (accounts.isEmpty) {
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 6), (t) {
      if (!mounted ||
          _accounts.isNotEmpty ||
          _isInteracting ||
          !_pageController.hasClients) {
        return;
      }

      // Increment virtual page and animate to it
      _virtualPage++;
      _pageController.animateToPage(
        _virtualPage,
        duration: const Duration(milliseconds: 1200), // Balanced smooth scroll
        curve: Curves.easeInOutQuart,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    _entranceCtrl.dispose();
    super.dispose();
  }

  // ── Navigation actions ─────────────────────────────────────────────────────

  void _goToSignup() {
    HapticFeedback.mediumImpact();
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const SignupStepsScreen(),
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 420),
      ),
    );
  }

  Future<void> _loginAs(Map<String, dynamic> account) async {
    if (_isLoggingIn) return;
    setState(() {
      _isLoggingIn = true;
      _loginError = null;
    });

    try {
      final auth = context.read<AuthStateProvider>();
      // Use switchAccount instead of checkAuthState to recover the saved session
      await auth.switchAccount(account['id'] as String);

      if (!mounted) return;

      if (auth.isAuthenticated) {
        final hasTerms = await LocalStorageService.hasAcceptedTerms(
          account['id'] as String,
        );
        await MultiAccountStorageService.setLastActiveAccountId(
          account['id'] as String,
        );

        if (!mounted) return;

        if (hasTerms) {
          _showWelcomeToast(account['fullName'] as String? ?? 'Welcome back!');
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const MainScreen()),
            (_) => false,
          );
        } else {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const LegalAcceptanceScreen()),
            (_) => false,
          );
        }
      } else {
        setState(() {
          _loginError =
              'Session expired. Please pick your account again or login with a different one.';
          _isLoggingIn = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loginError = 'Session expired. Redirecting...';
          _isLoggingIn = false;
        });
      }
    }
  }

  void _showWelcomeToast(String name) {
    final msgs = [
      'Hey $name! 👋 Welcome back!',
      'Good to see you, $name! 🔥',
      '$name is back! Let\'s go 🚀',
      'Welcome back, $name 💫',
    ];
    final msg = msgs[DateTime.now().second % msgs.length];
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Text('✨', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF845EF7),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: Center(child: CircularProgressIndicator(color: Colors.white24)),
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F0F1A),
        body: Stack(
          children: [
            const RepaintBoundary(child: _AuroraBackground()),
            SafeArea(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: _accounts.isEmpty
                    ? _buildSignupView()
                    : _buildAccountPickerView(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── View A: No accounts → Signup ──────────────────────────────────────────

  Widget _buildSignupView() {
    return Column(
      children: [
        // Logo
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: Row(children: [_BooferLogo()]),
        ),

        // Slides
        Expanded(
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (_) {
              setState(() => _isInteracting = true);
              if (_pageController.hasClients) {
                // STOP the auto-animation immediately on touch
                _pageController.jumpTo(_pageController.offset);
              }
            },
            onPointerUp: (_) {
              // Wait 5 seconds after interaction ends before resuming
              Future.delayed(const Duration(seconds: 5), () {
                if (mounted) setState(() => _isInteracting = false);
              });
            },
            child: PageView.builder(
              controller: _pageController,
              physics: const BouncingScrollPhysics(),
              onPageChanged: (i) {
                // Sync the virtual page tracker with real manual swipes
                _virtualPage = i;
                final realIndex = i % _slides.length;
                if (_currentSlide != realIndex) {
                  setState(() => _currentSlide = realIndex);
                }
              },
              // Infinite scrolling enabled
              itemBuilder: (_, i) => _SlideWidget(
                key: ValueKey('slide_${i % _slides.length}'),
                slide: _slides[i % _slides.length],
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Isolated footer for high-performance scrolling
        RepaintBoundary(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SliderDots(count: _slides.length, current: _currentSlide),
              const SizedBox(height: 32),
              _SwipeBar(
                key: const ValueKey('signup_swipe'),
                accentColor: const Color(0xFF845EF7),
                label: 'swipe me to get started',
                onActivated: _goToSignup,
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.only(bottom: 20, left: 24, right: 24),
                child: _LegalFooter(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── View B: Multiple accounts → Picker ───────────────────────────────────

  Widget _buildAccountPickerView() {
    final selected = _accounts[_selectedIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          child: Row(children: [_BooferLogo()]),
        ),

        const SizedBox(height: 32),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Welcome\nback 💫',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Choose your account to continue',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        // Account cards list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _accounts.length,
            itemBuilder: (_, i) {
              final acc = _accounts[i];
              final isSelected = i == _selectedIndex;
              return _AccountCard(
                account: acc,
                isSelected: isSelected,
                onTap: () => setState(() => _selectedIndex = i),
              );
            },
          ),
        ),

        // Error
        if (_loginError != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.red,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _loginError!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Swipe to login as selected
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _isLoggingIn
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Column(
                      children: [
                        const CircularProgressIndicator(
                          color: Color(0xFF845EF7),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Logging you in...',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.54),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : _SwipeBar(
                  key: ValueKey(_selectedIndex),
                  accentColor: const Color(0xFF845EF7),
                  label:
                      'Swipe to continue as ${(selected['fullName'] as String?)?.split(' ').first ?? 'you'}',
                  onActivated: () => _loginAs(selected),
                ),
        ),

        const SizedBox(height: 20),

        // Footer
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Center(
            child: Text(
              'Add more accounts via Settings',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.2),
                fontSize: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Shared logo widget ───────────────────────────────────────────────────────

class _BooferLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/images/logo/boofer-logo.svg',
      height: 28,
      // Show white version on dark background
      colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
    );
  }
}

// ─── Legal footer (tappable terms + privacy) ─────────────────────────────────

class _LegalFooter extends StatefulWidget {
  @override
  State<_LegalFooter> createState() => _LegalFooterState();
}

class _LegalFooterState extends State<_LegalFooter> {
  late final TapGestureRecognizer _termsRec;
  late final TapGestureRecognizer _privacyRec;

  @override
  void initState() {
    super.initState();
    _termsRec = TapGestureRecognizer()
      ..onTap = () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const TermsOfServiceScreen()),
      );

    _privacyRec = TapGestureRecognizer()
      ..onTap = () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
      );
  }

  @override
  void dispose() {
    _termsRec.dispose();
    _privacyRec.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.28),
          fontSize: 11,
          height: 1.5,
        ),
        children: [
          const TextSpan(text: 'By continuing you agree to our '),
          TextSpan(
            text: 'Terms of Service',
            recognizer: _termsRec,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              decoration: TextDecoration.underline,
              decorationColor: Colors.white.withValues(alpha: 0.35),
              fontWeight: FontWeight.w500,
            ),
          ),
          const TextSpan(text: ' & '),
          TextSpan(
            text: 'Privacy Policy',
            recognizer: _privacyRec,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              decoration: TextDecoration.underline,
              decorationColor: Colors.white.withValues(alpha: 0.35),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Account card ─────────────────────────────────────────────────────────────

class _AccountCard extends StatelessWidget {
  final Map<String, dynamic> account;
  final bool isSelected;
  final VoidCallback onTap;

  const _AccountCard({
    required this.account,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fullName = (account['fullName'] as String?) ?? 'Boofer User';
    final handle = (account['handle'] as String?) ?? '';
    final avatar = account['avatar'] as String?;
    final initial = fullName.isNotEmpty
        ? fullName.substring(0, 1).toUpperCase()
        : '?';

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFF845EF7), Color(0xFF6A4BD4)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected ? null : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : Colors.white.withValues(alpha: 0.09),
            width: isSelected ? 0 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF845EF7).withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            // Avatar circle
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.2)
                    : const Color(0xFF845EF7).withValues(alpha: 0.25),
              ),
              child: Center(
                child: Text(
                  avatar ?? initial,
                  style: TextStyle(
                    fontSize: avatar != null ? 22 : 18,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Name + handle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fullName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '@$handle',
                    style: TextStyle(
                      color: Colors.white.withValues(
                        alpha: isSelected ? 0.7 : 0.38,
                      ),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            // Selected check
            AnimatedScale(
              scale: isSelected ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.25),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Slide dots ───────────────────────────────────────────────────────────────

class _SliderDots extends StatelessWidget {
  final int count;
  final int current;
  const _SliderDots({required this.count, required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        count,
        (i) => AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: current == i ? 22 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: current == i
                ? Colors.white.withValues(alpha: 0.70)
                : Colors.white.withValues(alpha: 0.20),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }
}

// ─── Slide data & widget ──────────────────────────────────────────────────────

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

class _SlideWidget extends StatefulWidget {
  final _SlideData slide;
  const _SlideWidget({super.key, required this.slide});

  @override
  State<_SlideWidget> createState() => _SlideWidgetState();
}

class _SlideWidgetState extends State<_SlideWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
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
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.slide.color.withValues(alpha: 0.12),
                  boxShadow: [
                    BoxShadow(
                      color: widget.slide.color.withValues(alpha: 0.28),
                      blurRadius: 50,
                      spreadRadius: 8,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    widget.slide.emoji,
                    style: const TextStyle(fontSize: 48),
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
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 15,
                  height: 1.65,
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

// ─── Swipe bar (shared between signup & login) ─────────────────────────────────

class _SwipeBar extends StatefulWidget {
  final Color accentColor;
  final String label;
  final VoidCallback onActivated;

  const _SwipeBar({
    super.key,
    required this.accentColor,
    required this.label,
    required this.onActivated,
  });

  @override
  State<_SwipeBar> createState() => _SwipeBarState();
}

class _SwipeBarState extends State<_SwipeBar>
    with SingleTickerProviderStateMixin {
  double _progress = 0.0;
  double _trackWidth = 0;
  bool _activated = false;

  static const double _knobSize = 56.0;
  static const double _trackH = 64.0;
  static const double _pad = 4.0;

  late final AnimationController _snapCtrl;
  late Animation<double> _snapAnim;

  @override
  void initState() {
    super.initState();
    _snapCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void dispose() {
    _snapCtrl.dispose();
    super.dispose();
  }

  double get _maxTravel => _trackWidth - _knobSize - _pad * 2;
  double get _knobLeft => _pad + _progress * _maxTravel;

  void _onDragUpdate(DragUpdateDetails d) {
    if (_activated || _trackWidth == 0) return;
    setState(() {
      _progress = (_progress + d.delta.dx / _maxTravel).clamp(0.0, 1.0);
    });
  }

  void _onDragEnd(DragEndDetails _) {
    if (_activated) return;
    if (_progress >= 0.86) {
      HapticFeedback.heavyImpact();
      setState(() {
        _progress = 1.0;
        _activated = true;
      });
      Future.delayed(const Duration(milliseconds: 300), widget.onActivated);
    } else {
      _snapAnim = Tween<double>(begin: _progress, end: 0.0).animate(
        CurvedAnimation(parent: _snapCtrl, curve: Curves.elasticOut),
      )..addListener(() => setState(() => _progress = _snapAnim.value));
      _snapCtrl
        ..reset()
        ..forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: LayoutBuilder(
        builder: (_, box) {
          _trackWidth = box.maxWidth;
          return GestureDetector(
            onHorizontalDragUpdate: _onDragUpdate,
            onHorizontalDragEnd: _onDragEnd,
            child: SizedBox(
              height: _trackH,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(_trackH / 2),
                child: Stack(
                  children: [
                    // Track background
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(_trackH / 2),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.09),
                          ),
                        ),
                      ),
                    ),

                    // Progress trail
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: (_knobLeft + _knobSize / 2).clamp(
                          0.0,
                          _trackWidth,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              widget.accentColor.withValues(alpha: 0.55),
                              widget.accentColor.withValues(alpha: 0.0),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(_trackH / 2),
                        ),
                      ),
                    ),

                    // Label
                    Positioned.fill(
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: _knobSize + _pad * 2 + 8,
                          right: 16,
                        ),
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 150),
                          opacity: (1.0 - _progress * 2.2).clamp(0.0, 1.0),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Text(
                                    widget.label,
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.54,
                                      ),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.3,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  color: Colors.white.withValues(alpha: 0.30),
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Knob
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 10),
                      left: _knobLeft,
                      top: _pad,
                      child: _activated
                          ? _CheckKnob(color: widget.accentColor)
                          : _DragKnob(
                              color: widget.accentColor,
                              progress: _progress,
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Knob variants ────────────────────────────────────────────────────────────

class _DragKnob extends StatelessWidget {
  final Color color;
  final double progress;

  const _DragKnob({required this.color, required this.progress});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _SwipeBarState._knobSize,
      height: _SwipeBarState._knobSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.45 + progress * 0.2),
            blurRadius: 14 + progress * 10,
            spreadRadius: progress * 3,
          ),
        ],
      ),
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: progress > 0.5
              ? const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 24,
                  key: ValueKey('fwd'),
                )
              : const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white,
                  size: 28,
                  key: ValueKey('crt'),
                ),
        ),
      ),
    );
  }
}

class _CheckKnob extends StatefulWidget {
  final Color color;
  const _CheckKnob({required this.color});

  @override
  State<_CheckKnob> createState() => _CheckKnobState();
}

class _CheckKnobState extends State<_CheckKnob>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    )..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(
        begin: 0.4,
        end: 1.0,
      ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut)),
      child: Container(
        width: _SwipeBarState._knobSize,
        height: _SwipeBarState._knobSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF20C997),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF20C997).withValues(alpha: 0.55),
              blurRadius: 24,
              spreadRadius: 4,
            ),
          ],
        ),
        child: const Center(
          child: Icon(Icons.check_rounded, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}

// ─── Aurora animated background ───────────────────────────────────────────────

class _AuroraBackground extends StatefulWidget {
  const _AuroraBackground();

  @override
  State<_AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<_AuroraBackground>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12), // Slower is more efficient
    )..repeat();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _ctrl.repeat();
    } else {
      _ctrl.stop(); // Zero CPU usage when app is backgrounded
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(
        painter: _AuroraPainter(_ctrl.value),
        size: MediaQuery.of(context).size,
      ),
    );
  }
}

class _AuroraPainter extends CustomPainter {
  final double t;
  _AuroraPainter(this.t);

  static double _s(double v) => sin(v * 2 * pi);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..blendMode = BlendMode.screen;

    void drawBlob(Color c, double cx, double cy, double r, double alpha) {
      // Cull blobs that are completely off-screen to save GPU
      if (cx + r < 0 ||
          cx - r > size.width ||
          cy + r < 0 ||
          cy - r > size.height) {
        return;
      }

      paint.shader = RadialGradient(
        colors: [
          c.withValues(alpha: alpha),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r));
      canvas.drawCircle(Offset(cx, cy), r, paint);
    }

    drawBlob(
      const Color(0xFF845EF7),
      size.width * 0.18 + 50 * _s(t * 0.6),
      size.height * 0.2 + 40 * _s(t * 0.4),
      230,
      0.30,
    );
    drawBlob(
      const Color(0xFFFF6B6B),
      size.width * 0.82 + 40 * _s(t * 0.55 + 0.3),
      size.height * 0.72 + 50 * _s(t * 0.7 + 0.2),
      210,
      0.22,
    );
    drawBlob(
      const Color(0xFF20C997),
      size.width * 0.5 + 30 * _s(t * 0.8 + 0.5),
      size.height * 0.5 + 30 * _s(t * 0.5 + 0.8),
      180,
      0.13,
    );
  }

  @override
  bool shouldRepaint(_AuroraPainter old) => old.t != t;
}
