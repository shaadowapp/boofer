import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_state_provider.dart';
import '../services/local_storage_service.dart';
import '../services/user_service.dart';
import 'main_screen.dart';
import '../models/user_model.dart';
import '../widgets/boofer_identity_card.dart';

/// Animated welcome screen shown as a 'gate' after data collection.
/// Users see their draft profile (Aadhaar style) and can edit it
/// or confirm to finally insert data into the database.
class WelcomeScreen extends StatefulWidget {
  final Map<String, dynamic> draftData;
  const WelcomeScreen({super.key, required this.draftData});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late Map<String, dynamic> _localData;
  late final AnimationController _ctrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _cardSlideAnim;

  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _localData = Map<String, dynamic>.from(widget.draftData);

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _cardSlideAnim = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutQuart));

    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _handleConfirm() async {
    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final authProvider = context.read<AuthStateProvider>();
      await authProvider.createAnonymousUser(
        fullName: _localData['fullName'],
        handle: _localData['handle'],
        bio: _localData['bio'],
        avatar: _localData['avatar'],
        age: _localData['age'],
        gender: _localData['gender'],
        lookingFor: _localData['lookingFor'],
        interests: _localData['interests'],
        hobbies: _localData['hobbies'],
        guardianId: _localData['guardianId'],
      );

      if (!mounted) return;

      if (authProvider.isAuthenticated) {
        // Accept terms
        final user = await UserService.getCurrentUser();
        if (user != null) {
          await LocalStorageService.setTermsAccepted(user.id, true);
        }

        // Final transition to app
        Navigator.pushAndRemoveUntil(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const MainScreen(),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
            transitionDuration: const Duration(milliseconds: 800),
          ),
          (route) => false,
        );
      } else {
        setState(() {
          _error = authProvider.errorMessage ?? 'Signup failed';
          _isSaving = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isSaving = false;
      });
    }
  }

  void _showEditSheet() {
    final nameCtrl = TextEditingController(text: _localData['fullName']);
    final handleCtrl = TextEditingController(text: _localData['handle']);
    final bioCtrl = TextEditingController(text: _localData['bio']);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 32,
          top: 32,
          left: 24,
          right: 24,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A2E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Customize your identity',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 24),
            _buildEditField('Full Name', nameCtrl, Icons.person_outline),
            const SizedBox(height: 16),
            _buildEditField('Handle', handleCtrl, Icons.alternate_email),
            const SizedBox(height: 16),
            _buildEditField('Bio', bioCtrl, Icons.info_outline, maxLines: 2),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: () {
                setState(() {
                  _localData['fullName'] = nameCtrl.text;
                  _localData['handle'] = handleCtrl.text;
                  _localData['bio'] = bioCtrl.text;
                });
                Navigator.pop(ctx);
              },
              child: Container(
                height: 56,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF845EF7), Color(0xFF5C7CFA)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Text(
                    'Save Changes',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
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

  Widget _buildEditField(
    String label,
    TextEditingController ctrl,
    IconData icon, {
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: Colors.white30, size: 20),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: Stack(
        children: [
          // Background accents
          Positioned(
            top: -100,
            right: -100,
            child: _GlowCircle(
              color: const Color(0xFF845EF7).withOpacity(0.15),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: _GlowCircle(color: const Color(0xFFFF6B6B).withOpacity(0.1)),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  FadeTransition(
                    opacity: _fadeAnim,
                    child: Column(
                      children: [
                        const Text(
                          '🎉 Identity Secured!',
                          style: TextStyle(
                            color: Color(0xFF845EF7),
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Your Digital Boofer Card',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'This is how others will see you in the world.',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // THE PROFILE CARD (Aadhaar Style Inspired)
                  SlideTransition(
                    position: _cardSlideAnim,
                    child: FadeTransition(
                      opacity: _fadeAnim,
                      child: BooferIdentityCard(
                        user: User(
                          id: 'draft',
                          email: '',
                          handle: _localData['handle'],
                          fullName: _localData['fullName'],
                          bio: _localData['bio'] ?? '',
                          isDiscoverable: true,
                          createdAt: DateTime.now(),
                          updatedAt: DateTime.now(),
                          avatar: _localData['avatar'],
                          virtualNumber: _localData['virtualNumber'],
                        ),
                        onCopyNumber: () {
                          Clipboard.setData(
                            ClipboardData(text: _localData['virtualNumber']),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Virtual Number copied!'),
                              duration: Duration(seconds: 1),
                              backgroundColor: Color(0xFF845EF7),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],

                  const Spacer(),

                  // Action Buttons
                  FadeTransition(
                    opacity: _fadeAnim,
                    child: Column(
                      children: [
                        _GateButton(
                          onTap: _isSaving ? null : _handleConfirm,
                          label: 'Get into Boofer world',
                          isLoading: _isSaving,
                          isPrimary: true,
                        ),
                        const SizedBox(height: 16),
                        _GateButton(
                          onTap: _isSaving ? null : _showEditSheet,
                          label: 'Edit My Profile',
                          isPrimary: false,
                        ),
                        const SizedBox(height: 32),
                      ],
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

class _GateButton extends StatelessWidget {
  final VoidCallback? onTap;
  final String label;
  final bool isLoading;
  final bool isPrimary;

  const _GateButton({
    required this.onTap,
    required this.label,
    this.isLoading = false,
    required this.isPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 60,
        width: double.infinity,
        decoration: BoxDecoration(
          color: isPrimary ? null : Colors.transparent,
          gradient: isPrimary && onTap != null
              ? const LinearGradient(
                  colors: [Color(0xFF845EF7), Color(0xFF5C7CFA)],
                )
              : null,
          borderRadius: BorderRadius.circular(18),
          border: isPrimary ? null : Border.all(color: Colors.white10),
          boxShadow: isPrimary && onTap != null
              ? [
                  BoxShadow(
                    color: const Color(0xFF845EF7).withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  label,
                  style: TextStyle(
                    color: isPrimary ? Colors.white : Colors.white70,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
        ),
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  final Color color;
  const _GlowCircle({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      height: 300,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color, blurRadius: 100, spreadRadius: 20)],
      ),
    );
  }
}
