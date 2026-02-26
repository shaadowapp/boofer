import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_state_provider.dart';
import '../../services/multi_account_storage_service.dart';
import '../../services/local_storage_service.dart';
import '../main_screen.dart';

/// Login screen shown when user taps "I already have an account".
/// Lists all saved accounts on this device → auto-login on tap.
/// Falls back gracefully if Supabase session is expired (re-shows onboarding).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late Future<List<Map<String, dynamic>>> _accountsFuture;
  String? _loadingAccountId;
  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _accountsFuture = MultiAccountStorageService.getSavedAccounts();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _loginAs(Map<String, dynamic> account) async {
    setState(() => _loadingAccountId = account['id'] as String);
    try {
      final auth = context.read<AuthStateProvider>();
      // Use switchAccount instead of checkAuthState to recover the saved session
      await auth.switchAccount(account['id'] as String);

      if (!mounted) return;

      if (auth.isAuthenticated) {
        // Check if terms have been accepted for this account
        final hasTerms = await LocalStorageService.hasAcceptedTerms(
          account['id'] as String,
        );

        if (!mounted) return;

        if (hasTerms) {
          _showWelcomeToast(account['fullName'] as String? ?? 'Welcome back!');
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const MainScreen()),
            (route) => false,
          );
        } else {
          Navigator.pushReplacementNamed(context, '/legal-acceptance');
        }
      } else {
        // This part should technically be unreachable if switchAccount succeeds,
        // but keeping it as a fallback in case switchAccount sets unauthenticated state.
        if (mounted) {
          _showSessionExpiredDialog(account);
        }
      }
    } catch (e) {
      if (mounted) {
        _showSessionExpiredDialog(account);
      }
    } finally {
      if (mounted) setState(() => _loadingAccountId = null);
    }
  }

  void _showWelcomeToast(String name) {
    final greetings = [
      'Welcome back, $name! 👋',
      'Hey $name! Ready to connect? 🔥',
      'Good to see you again, $name! 💫',
      '$name is back! Let\'s go! 🚀',
    ];
    final msg = greetings[DateTime.now().second % greetings.length];

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

  void _showSessionExpiredDialog(Map<String, dynamic> account) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Session Expired',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Your session for @${account['handle']} has expired. Please create a new account to continue.',
          style: const TextStyle(color: Colors.white60),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await MultiAccountStorageService.removeAccount(
                account['id'] as String,
              );
              setState(() {
                _accountsFuture = MultiAccountStorageService.getSavedAccounts();
              });
              if (mounted) Navigator.pop(context);
            },
            child: const Text(
              'Remove Account',
              style: TextStyle(color: Color(0xFFFF6B6B)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: Color(0xFF845EF7))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_rounded,
                        color: Colors.white70,
                        size: 20,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Welcome\nback 💫',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Select your account to continue',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.45),
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Account list
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _accountsFuture,
                  builder: (_, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF845EF7),
                        ),
                      );
                    }

                    final accounts = snapshot.data ?? [];

                    if (accounts.isEmpty) {
                      return _buildNoAccounts();
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: accounts.length,
                      itemBuilder: (_, i) => _buildAccountTile(accounts[i]),
                    );
                  },
                ),
              ),

              // Bottom: New account CTA
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Divider(color: Colors.white12),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        // OnboardingScreen handles navigation to SignupStepsScreen
                      },
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white12),
                          borderRadius: BorderRadius.circular(16),
                          color: Colors.white.withOpacity(0.04),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_circle_outline,
                              color: Colors.white54,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Add another account',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountTile(Map<String, dynamic> account) {
    final id = account['id'] as String;
    final fullName = (account['fullName'] as String?) ?? 'Boofer User';
    final handle = (account['handle'] as String?) ?? '';
    final avatar = account['avatar'] as String?;
    final isLoading = _loadingAccountId == id;

    return GestureDetector(
      onTap: isLoading ? null : () => _loginAs(account),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isLoading
              ? const Color(0xFF845EF7).withOpacity(0.15)
              : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isLoading
                ? const Color(0xFF845EF7).withOpacity(0.5)
                : Colors.white.withOpacity(0.08),
          ),
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF845EF7), Color(0xFFFF6B6B)],
                ),
              ),
              child: Center(
                child: Text(
                  avatar != null
                      ? avatar
                      : (fullName.isNotEmpty
                            ? fullName.substring(0, 1).toUpperCase()
                            : '?'),
                  style: TextStyle(
                    fontSize: avatar != null ? 24 : 20,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Name & handle
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
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            // Loading or arrow
            if (isLoading)
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Color(0xFF845EF7),
                ),
              )
            else
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white30,
                size: 16,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoAccounts() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF845EF7).withOpacity(0.15),
            ),
            child: const Center(
              child: Text('🔍', style: TextStyle(fontSize: 36)),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No saved accounts',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No previous accounts found on this device. Go back and create a new account to get started!',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 14,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
