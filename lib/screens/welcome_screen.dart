import 'package:flutter/material.dart';
import 'main_screen.dart';

/// Animated welcome screen shown once after a successful signup.
/// Automatically advances to MainScreen after the animation plays.
class WelcomeScreen extends StatefulWidget {
  final String? displayName;
  const WelcomeScreen({super.key, this.displayName});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _scaleAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _ctrl,
            curve: const Interval(0.3, 0.9, curve: Curves.easeOut),
          ),
        );

    _ctrl.forward();

    // Auto-navigate after animation + pause
    Future.delayed(const Duration(milliseconds: 3000), () {
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const MainScreen(),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
            transitionDuration: const Duration(milliseconds: 600),
          ),
          (route) => false,
        );
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _getWelcomeEmoji() {
    final emojis = ['🎉', '🚀', '✨', '🔥', '💫', '🌟'];
    return emojis[DateTime.now().second % emojis.length];
  }

  String _getWelcomeMessage(String name) {
    final msgs = [
      'Your world just got\na whole lot bigger.',
      'A new identity,\nendless possibilities.',
      'Your adventure\nstarts now.',
      'Zero limits.\nJust you and your vibe.',
    ];
    return msgs[DateTime.now().second % msgs.length];
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.displayName ?? 'Hey you';
    final emoji = _getWelcomeEmoji();
    final msg = _getWelcomeMessage(name);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: Stack(
        children: [
          // Animated background
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) {
                return CustomPaint(painter: _WelcomeBgPainter(_ctrl.value));
              },
            ),
          ),

          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Big emoji + scale animation
                    ScaleTransition(
                      scale: _scaleAnim,
                      child: FadeTransition(
                        opacity: _fadeAnim,
                        child: Container(
                          width: 130,
                          height: 130,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF845EF7), Color(0xFFFF6B6B)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF845EF7).withOpacity(0.5),
                                blurRadius: 40,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              emoji,
                              style: const TextStyle(fontSize: 56),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Name greeting
                    SlideTransition(
                      position: _slideAnim,
                      child: FadeTransition(
                        opacity: _fadeAnim,
                        child: Column(
                          children: [
                            Text(
                              'Welcome,',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 20,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 38,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            Text(
                              msg,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.45),
                                fontSize: 16,
                                height: 1.6,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 60),

                    // Progress dots
                    FadeTransition(
                      opacity: _fadeAnim,
                      child: AnimatedBuilder(
                        animation: _ctrl,
                        builder: (_, __) {
                          final progress = _ctrl.value;
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(3, (i) {
                              final dotProgress = ((progress * 3) - i).clamp(
                                0.0,
                                1.0,
                              );
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                width: 8 + dotProgress * 16,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: Color.lerp(
                                    Colors.white24,
                                    const Color(0xFF845EF7),
                                    dotProgress,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              );
                            }),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomeBgPainter extends CustomPainter {
  final double t;
  _WelcomeBgPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..blendMode = BlendMode.screen;

    // Center glow
    paint.shader =
        RadialGradient(
          colors: [
            const Color(0xFF845EF7).withOpacity(0.3 * t),
            Colors.transparent,
          ],
        ).createShader(
          Rect.fromCircle(
            center: Offset(size.width / 2, size.height * 0.4),
            radius: 300 * t,
          ),
        );
    canvas.drawCircle(
      Offset(size.width / 2, size.height * 0.4),
      300 * t,
      paint,
    );

    // Bottom accent
    paint.shader =
        RadialGradient(
          colors: [
            const Color(0xFFFF6B6B).withOpacity(0.2 * t),
            Colors.transparent,
          ],
        ).createShader(
          Rect.fromCircle(
            center: Offset(size.width * 0.7, size.height * 0.85),
            radius: 180 * t,
          ),
        );
    canvas.drawCircle(
      Offset(size.width * 0.7, size.height * 0.85),
      180 * t,
      paint,
    );
  }

  @override
  bool shouldRepaint(_WelcomeBgPainter old) => old.t != t;
}
