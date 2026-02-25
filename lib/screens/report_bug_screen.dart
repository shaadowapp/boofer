import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

class ReportBugScreen extends StatefulWidget {
  const ReportBugScreen({super.key});

  @override
  State<ReportBugScreen> createState() => _ReportBugScreenState();
}

class _ReportBugScreenState extends State<ReportBugScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _stepsController = TextEditingController();
  final _expectedController = TextEditingController();
  final _actualController = TextEditingController();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool _isSubmitting = false;
  bool _submitted = false;
  String _selectedSeverity = 'Medium';
  String _deviceInfo = 'Loading device info...';
  String _appVersion = '...';

  final List<Map<String, dynamic>> _severities = [
    {
      'label': 'Low',
      'icon': Icons.arrow_downward_rounded,
      'color': const Color(0xFF20C997),
    },
    {
      'label': 'Medium',
      'icon': Icons.remove_rounded,
      'color': const Color(0xFFFF9F43),
    },
    {
      'label': 'High',
      'icon': Icons.arrow_upward_rounded,
      'color': const Color(0xFFFF6B6B),
    },
    {
      'label': 'Critical',
      'icon': Icons.whatshot_rounded,
      'color': const Color(0xFFFF4757),
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadDeviceInfo();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
        );
    _animationController.forward();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _stepsController.dispose();
    _expectedController.dispose();
    _actualController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadDeviceInfo() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      final packageInfo = await PackageInfo.fromPlatform();
      String deviceDetails = '';
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceDetails =
            'Android ${androidInfo.version.release} (SDK ${androidInfo.version.sdkInt}) • '
            '${androidInfo.manufacturer} ${androidInfo.model}';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceDetails = 'iOS ${iosInfo.systemVersion} • ${iosInfo.model}';
      }
      if (mounted) {
        setState(() {
          _deviceInfo = deviceDetails.isEmpty
              ? 'Unknown device'
              : deviceDetails;
          _appVersion = '${packageInfo.version} (${packageInfo.buildNumber})';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _deviceInfo = 'Unable to load device info';
          _appVersion = 'Unknown';
        });
      }
    }
  }

  Future<void> _submitBugReport() async {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.mediumImpact();
    setState(() => _isSubmitting = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final bugReportData = {
        'id': const Uuid().v4(),
        'user_id': userId,
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'steps_to_reproduce': _stepsController.text.trim().isEmpty
            ? null
            : _stepsController.text.trim(),
        'expected_behavior': _expectedController.text.trim().isEmpty
            ? null
            : _expectedController.text.trim(),
        'actual_behavior': _actualController.text.trim().isEmpty
            ? null
            : _actualController.text.trim(),
        'device_info': _deviceInfo,
        'app_version': _appVersion,
        'severity': _selectedSeverity.toLowerCase(),
        'created_at': DateTime.now().toIso8601String(),
        'status': 'open',
      };

      await Supabase.instance.client.from('bug_reports').insert(bugReportData);

      if (mounted) {
        HapticFeedback.heavyImpact();
        setState(() => _submitted = true);
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.of(context).pop();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text('Failed to submit: ${e.toString()}')),
              ],
            ),
            backgroundColor: const Color(0xFFFF4757),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0D0D1A) : const Color(0xFFF5F5FA);

    return Scaffold(
      backgroundColor: bg,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.arrow_back_ios_new,
              size: 16,
              color: theme.colorScheme.onSurface,
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _submitted ? _buildSuccessState(theme) : _buildForm(theme, isDark),
    );
  }

  Widget _buildSuccessState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFFFF6B6B), Color(0xFFFF9F43)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF6B6B).withOpacity(0.4),
                  blurRadius: 24,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: const Icon(
              Icons.bug_report_rounded,
              color: Colors.white,
              size: 48,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Report Received! 🐞',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We\'ll squash it as soon as possible.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(ThemeData theme, bool isDark) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + kToolbarHeight + 8,
            left: 20,
            right: 20,
            bottom: 32,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                const Text(
                  'Report a\nbug 🐞',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Help us make Boofer better by reporting issues.',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.45),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 28),

                // Severity selector
                _buildLabel('Severity'),
                const SizedBox(height: 12),
                Row(
                  children: _severities.map((s) {
                    final isSelected = _selectedSeverity == s['label'];
                    final color = s['color'] as Color;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedSeverity = s['label']);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: EdgeInsets.only(
                            right: s['label'] == 'Critical' ? 0 : 8,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? color.withOpacity(0.15)
                                : theme.colorScheme.onSurface.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? color : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                s['icon'] as IconData,
                                size: 16,
                                color: isSelected
                                    ? color
                                    : theme.colorScheme.onSurface.withOpacity(
                                        0.35,
                                      ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                s['label'],
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected
                                      ? color
                                      : theme.colorScheme.onSurface.withOpacity(
                                          0.4,
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 28),

                // Title
                _buildLabel('Bug title *'),
                const SizedBox(height: 12),
                _buildTextField(
                  controller: _titleController,
                  hint: 'e.g. Crash when opening profile',
                  theme: theme,
                  isDark: isDark,
                  prefixIcon: Icons.title_rounded,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty)
                      return 'Please enter a title';
                    if (v.trim().length < 5) return 'Title is too short';
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Description
                _buildLabel('Description *'),
                const SizedBox(height: 12),
                _buildTextField(
                  controller: _descriptionController,
                  hint: 'What exactly happened? Be as detailed as possible...',
                  maxLines: 5,
                  maxLength: 2000,
                  theme: theme,
                  isDark: isDark,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty)
                      return 'Please describe the bug';
                    if (v.trim().length < 20) {
                      return 'Please provide at least 20 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Steps to reproduce
                _buildLabel('Steps to reproduce  (optional)'),
                const SizedBox(height: 12),
                _buildTextField(
                  controller: _stepsController,
                  hint: '1. Open the app\n2. Go to...\n3. Tap on...',
                  maxLines: 4,
                  theme: theme,
                  isDark: isDark,
                ),
                const SizedBox(height: 24),

                // Expected vs Actual
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('Expected'),
                          const SizedBox(height: 12),
                          _buildTextField(
                            controller: _expectedController,
                            hint: 'What should happen?',
                            maxLines: 3,
                            theme: theme,
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('Actual'),
                          const SizedBox(height: 12),
                          _buildTextField(
                            controller: _actualController,
                            hint: 'What actually happened?',
                            maxLines: 3,
                            theme: theme,
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Device info card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.onSurface.withOpacity(0.07),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.phone_android_rounded,
                        size: 18,
                        color: theme.colorScheme.onSurface.withOpacity(0.4),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Auto-detected device info',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.onSurface.withOpacity(
                                  0.4,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _deviceInfo,
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurface.withOpacity(
                                  0.6,
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'App v$_appVersion',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurface.withOpacity(
                                  0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 36),

                // Submit button
                _buildSubmitButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.4,
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required ThemeData theme,
    required bool isDark,
    int? maxLines,
    int? maxLength,
    TextInputType? keyboardType,
    IconData? prefixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines ?? 1,
      maxLength: maxLength,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: prefixIcon != null
            ? Icon(
                prefixIcon,
                size: 18,
                color: theme.colorScheme.onSurface.withOpacity(0.4),
              )
            : null,
        hintStyle: TextStyle(
          color: theme.colorScheme.onSurface.withOpacity(0.3),
        ),
        filled: true,
        fillColor: theme.colorScheme.onSurface.withOpacity(
          isDark ? 0.06 : 0.04,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: theme.colorScheme.onSurface.withOpacity(0.07),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: const Color(0xFFFF6B6B).withOpacity(0.6),
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFFF4757)),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        counterStyle: TextStyle(
          color: theme.colorScheme.onSurface.withOpacity(0.3),
          fontSize: 11,
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildSubmitButton() {
    return GestureDetector(
      onTap: _isSubmitting ? null : _submitBugReport,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 56,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF6B6B), Color(0xFFFF9F43)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: _isSubmitting
              ? []
              : [
                  BoxShadow(
                    color: const Color(0xFFFF6B6B).withOpacity(0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
        ),
        child: Center(
          child: _isSubmitting
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.bug_report_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Submit Bug Report',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
