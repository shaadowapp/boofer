import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'welcome_screen.dart';
import 'terms_of_service_screen.dart';
import 'privacy_policy_screen.dart';
import '../utils/random_data_generator.dart';
import '../core/constants.dart';

/// Multi-step onboarding wizard: Age/Gender → Interests → Hobbies → Looking For → Terms.
/// All profile steps (except Terms) are skippable.
class SignupStepsScreen extends StatefulWidget {
  final String? guardianId;
  const SignupStepsScreen({super.key, this.guardianId});

  @override
  State<SignupStepsScreen> createState() => _SignupStepsScreenState();
}

class _SignupStepsScreenState extends State<SignupStepsScreen>
    with TickerProviderStateMixin {
  // Wizard state
  int _step = 0;

  // Step 1 – Age & Gender (important)
  int _age = 21;
  String? _gender;

  // Step 2 – Interests (optional)
  final Set<String> _interests = {};

  // Step 3 – Hobbies (optional)
  final Set<String> _hobbies = {};

  // Step 4 – Looking for (optional)
  String? _lookingFor;

  bool _isCreating = false;
  String? _errorMsg;

  // Total steps (0–4): age/gender, interests, hobbies, lookingFor, terms
  static const int _totalSteps = 5;

  late final AnimationController _slideController;
  late Animation<Offset> _slideIn;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _updateSlideAnimation();
    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  void _updateSlideAnimation() {
    _slideIn = Tween<Offset>(
      begin: const Offset(1.0, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
  }

  void _nextStep() {
    if (_step < _totalSteps - 1) {
      _slideController.reset();
      setState(() => _step++);
      _slideController.forward();
    }
  }

  void _prevStep() {
    if (_step > 0) {
      _slideController.reset();
      setState(() => _step--);
      _slideController.forward();
    }
  }

  Future<void> _finishAndCreate() async {
    // Generate draft profile data for the Welcome Screen 'gate'
    final fullName = RandomDataGenerator.generateFullName();
    final handle = RandomDataGenerator.generateHandle(fullName);
    final bio = RandomDataGenerator.generateBio();
    final virtualNumber = RandomDataGenerator.generateVirtualNumber();
    final avatar = RandomDataGenerator.generateAvatar();

    // Navigate to welcome screen as a gate
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => WelcomeScreen(
          draftData: {
            'fullName': fullName,
            'handle': handle,
            'bio': bio,
            'virtualNumber': virtualNumber,
            'avatar': avatar,
            'age': _age,
            'gender': _gender,
            'interests': _interests.toList(),
            'hobbies': _hobbies.toList(),
            'lookingFor': _lookingFor,
            'guardianId': widget.guardianId,
          },
        ),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                // Progress indicator with breathing room
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: SizedBox(
                      height: 3,
                      child: LinearProgressIndicator(
                        value: (_step + 1) / _totalSteps,
                        backgroundColor: Colors.white.withOpacity(0.08),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF845EF7),
                        ),
                      ),
                    ),
                  ),
                ),
                // const SizedBox(height: 4), // Replaced by padding above
                // Back button + Step indicator
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      if (_step > 0)
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back_ios_rounded,
                            color: Colors.white70,
                            size: 20,
                          ),
                          onPressed: _prevStep,
                        )
                      else
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white54),
                          onPressed: () => Navigator.pop(context),
                        ),
                      const Spacer(),
                      Text(
                        'Step ${_step + 1} of $_totalSteps',
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),

                // Scrollable step content
                Expanded(
                  child: SlideTransition(
                    position: _slideIn,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _buildStep(),
                    ),
                  ),
                ),

                // Error message
                if (_errorMsg != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.withOpacity(0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.red,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMsg!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Bottom action buttons
                _buildBottomBar(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _buildAgeGenderStep();
      case 1:
        return _buildInterestsStep();
      case 2:
        return _buildHobbiesStep();
      case 3:
        return _buildLookingForStep();
      case 4:
        return _buildTermsStep();
      default:
        return const SizedBox();
    }
  }

  Widget _buildBottomBar() {
    final isTermsStep = _step == _totalSteps - 1;
    final canSkip = _step > 0 && _step < _totalSteps - 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        children: [
          if (isTermsStep)
            _PrimaryButton(
              onTap: _isCreating ? null : _finishAndCreate,
              label: _isCreating
                  ? 'Creating your world...'
                  : 'Agree & Create Profile',
              isLoading: _isCreating,
              gradient: const LinearGradient(
                colors: [Color(0xFF845EF7), Color(0xFF20C997)],
              ),
            )
          else
            _PrimaryButton(
              onTap: _nextStep,
              label: _step == 0 ? 'Continue →' : 'Next →',
              gradient: const LinearGradient(
                colors: [Color(0xFF845EF7), Color(0xFFFF6B6B)],
              ),
            ),
          if (canSkip && !isTermsStep) ...[
            const SizedBox(height: 10),
            TextButton(
              onPressed: _nextStep,
              child: Text(
                'Skip for now',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Step 1: Age & Gender ──────────────────────────────────────────────────

  Widget _buildAgeGenderStep() {
    final genders = [
      ('Male', '♂️', 'male'),
      ('Female', '♀️', 'female'),
      ('Non-binary', '⚧', 'non_binary'),
      ('Prefer not to say', '🙈', 'undisclosed'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const Text(
          'Tell us about\nyourself',
          style: TextStyle(
            color: Colors.white,
            fontSize: 34,
            fontWeight: FontWeight.w900,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'This helps us show you the right people. Required for a safer community.',
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 14,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 32),

        // Age slider
        _SectionLabel(label: 'Your Age', emoji: '🎂'),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            children: [
              Container(
                height: 150,
                child: ListWheelScrollView.useDelegate(
                  itemExtent: 50,
                  perspective: 0.005,
                  diameterRatio: 1.2,
                  physics: const FixedExtentScrollPhysics(),
                  controller: FixedExtentScrollController(
                    initialItem: _age - 18,
                  ),
                  onSelectedItemChanged: (index) {
                    setState(() => _age = index + 18);
                    HapticFeedback.selectionClick();
                  },
                  childDelegate: ListWheelChildBuilderDelegate(
                    builder: (context, index) {
                      final age = index + 18;
                      if (age > 100) return null;
                      return Center(
                        child: Text(
                          '$age',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: _age == age
                                ? const Color(0xFF845EF7)
                                : Colors.white38,
                          ),
                        ),
                      );
                    },
                    childCount: 83, // 18 to 100
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '18',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    '18',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    '100',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        // Gender chips
        _SectionLabel(label: 'Your Gender', emoji: '✨'),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: genders.map((g) {
            final selected = _gender == g.$3;
            return GestureDetector(
              onTap: () => setState(() => _gender = selected ? null : g.$3),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  gradient: selected
                      ? const LinearGradient(
                          colors: [Color(0xFF845EF7), Color(0xFFFF6B6B)],
                        )
                      : null,
                  color: selected ? null : Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(
                    color: selected
                        ? Colors.transparent
                        : Colors.white.withOpacity(0.15),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(g.$2, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Text(
                      g.$1,
                      style: TextStyle(
                        color: selected ? Colors.white : Colors.white70,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ── Step 2: Interests ─────────────────────────────────────────────────────

  Widget _buildInterestsStep() {
    return _buildChipSelector(
      title: 'Your interests',
      subtitle: 'Pick what you love — we\'ll help you meet matching souls.',
      items: AppConstants.interestOptions,
      selected: _interests,
      maxSelect: 5,
    );
  }

  // ── Step 3: Hobbies ───────────────────────────────────────────────────────

  Widget _buildHobbiesStep() {
    return _buildChipSelector(
      title: 'Your hobbies',
      subtitle: 'What do you do for fun? Let your matches know!',
      items: AppConstants.hobbyOptions,
      selected: _hobbies,
      maxSelect: 5,
    );
  }

  Widget _buildChipSelector({
    required String title,
    required String subtitle,
    required List<(String, String)> items,
    required Set<String> selected,
    required int maxSelect,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 34,
            fontWeight: FontWeight.w900,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 14,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Pick up to $maxSelect — tap to select (or skip)',
          style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 8,
          runSpacing: 10,
          children: items.map((item) {
            final isSelected = selected.contains(item.$2);
            return GestureDetector(
              onTap: () => setState(() {
                if (isSelected) {
                  selected.remove(item.$2);
                } else if (selected.length < maxSelect) {
                  selected.add(item.$2);
                } else {
                  // Optional: Show a subtle feedback if limit reached
                  HapticFeedback.vibrate();
                }
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? const LinearGradient(
                          colors: [Color(0xFF845EF7), Color(0xFFFF6B6B)],
                        )
                      : null,
                  color: isSelected ? null : Colors.white.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(
                    color: isSelected
                        ? Colors.transparent
                        : Colors.white.withOpacity(0.12),
                  ),
                ),
                child: Text(
                  item.$1,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white60,
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ── Step 4: Looking for ───────────────────────────────────────────────────

  Widget _buildLookingForStep() {
    final opts = [
      ('Looking for men', '♂️', 'male'),
      ('Looking for women', '♀️', 'female'),
      ('Open to everyone', '💫', 'everyone'),
      ('Just friends & chat', '🤝', 'friends'),
      ('Skip for now', '🙊', null),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const Text(
          'Who are you\nlooking for?',
          style: TextStyle(
            color: Colors.white,
            fontSize: 34,
            fontWeight: FontWeight.w900,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Totally optional — we\'ll suggest connections based on your answer.',
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 14,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 28),
        ...opts.map((o) {
          final isSelected = _lookingFor == o.$3;
          return GestureDetector(
            onTap: () => setState(() => _lookingFor = isSelected ? null : o.$3),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? const LinearGradient(
                        colors: [Color(0xFF845EF7), Color(0xFFFF6B6B)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      )
                    : null,
                color: isSelected ? null : Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? Colors.transparent
                      : Colors.white.withOpacity(0.12),
                ),
              ),
              child: Row(
                children: [
                  Text(o.$2, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 14),
                  Text(
                    o.$1,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontSize: 15,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
                  ),
                  if (isSelected) ...[
                    const Spacer(),
                    const Icon(
                      Icons.check_circle,
                      color: Colors.white,
                      size: 20,
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 24),
      ],
    );
  }

  // ── Step 5: Terms ─────────────────────────────────────────────────────────

  Widget _buildTermsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const Text(
          'Almost there! 🎉',
          style: TextStyle(
            color: Colors.white,
            fontSize: 34,
            fontWeight: FontWeight.w900,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'A few important ground rules to keep Boofer safe for everyone.',
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 14,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 28),

        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            children: [
              _GuidelineCard(
                icon: Icons.person_off_outlined,
                iconColor: const Color(0xFF845EF7),
                title: 'Your identity, protected',
                desc:
                    'Your real identity is never exposed. You control what you share.',
              ),
              _GuidelineCard(
                icon: Icons.lock_outline_rounded,
                iconColor: const Color(0xFF20C997),
                title: 'End-to-end encrypted',
                desc:
                    'All conversations are encrypted. Not even we can read them.',
              ),
              _GuidelineCard(
                icon: Icons.volunteer_activism_outlined,
                iconColor: const Color(0xFFFF922B),
                title: 'Respect everyone',
                desc: 'You are responsible for your interactions. Be kind.',
              ),
              _GuidelineCard(
                icon: Icons.block_outlined,
                iconColor: const Color(0xFFFF6B6B),
                title: 'Zero tolerance',
                desc:
                    'Harassment, illegal content, and hate speech result in permanent ban.',
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Legal links
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TermsOfServiceScreen()),
              ),
              child: const Text(
                'Terms of Service',
                style: TextStyle(
                  color: Color(0xFF845EF7),
                  fontSize: 13,
                  decoration: TextDecoration.underline,
                  decorationColor: Color(0xFF845EF7),
                ),
              ),
            ),
            Text(
              '&',
              style: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: 13,
              ),
            ),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
              ),
              child: const Text(
                'Privacy Policy',
                style: TextStyle(
                  color: Color(0xFF845EF7),
                  fontSize: 13,
                  decoration: TextDecoration.underline,
                  decorationColor: Color(0xFF845EF7),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ─── Supporting widgets ───────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final String emoji;
  const _SectionLabel({required this.label, required this.emoji});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _GuidelineCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String desc;

  const _GuidelineCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.45),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final VoidCallback? onTap;
  final String label;
  final Gradient gradient;
  final bool isLoading;

  const _PrimaryButton({
    required this.onTap,
    required this.label,
    required this.gradient,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 56,
        decoration: BoxDecoration(
          gradient: onTap == null ? null : gradient,
          color: onTap == null ? Colors.white12 : null,
          borderRadius: BorderRadius.circular(16),
          boxShadow: onTap == null
              ? null
              : [
                  BoxShadow(
                    color: const Color(0xFF845EF7).withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : Text(
                  label,
                  style: TextStyle(
                    color: onTap == null ? Colors.white38 : Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
        ),
      ),
    );
  }
}
