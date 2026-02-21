import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../models/user_model.dart';
import '../widgets/boofer_identity_card.dart';
import 'qr_scanner_screen.dart';

class ShareProfileScreen extends StatefulWidget {
  final User user;
  const ShareProfileScreen({super.key, required this.user});

  @override
  State<ShareProfileScreen> createState() => _ShareProfileScreenState();
}

class _ShareProfileScreenState extends State<ShareProfileScreen> {
  final ScreenshotController _screenshotController = ScreenshotController();
  bool _isQrMode = false;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _copyHandle() async {
    await Clipboard.setData(ClipboardData(text: '@${widget.user.handle}'));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Handle copied to clipboard!'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    HapticFeedback.lightImpact();
  }

  Future<void> _shareIdentity() async {
    try {
      final image = await _screenshotController.capture();
      if (image != null) {
        final directory = await getTemporaryDirectory();
        final path = '${directory.path}/boofer_share_${widget.user.handle}.png';
        final file = File(path);
        await file.writeAsBytes(image);

        await Share.shareXFiles([
          XFile(path),
        ], text: 'Join me on Boofer! My handle is @${widget.user.handle}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to share: $e')));
      }
    }
  }

  Future<void> _downloadIdentity() async {
    try {
      final image = await _screenshotController.capture();
      if (image != null) {
        // Since we don't have a gallery saver 100% confirmed, we'll save to documents
        // and notify user. Sharing is often preferred on mobile anyway.
        final directory = await getApplicationDocumentsDirectory();
        final fileName =
            'boofer_${widget.user.handle}_${DateTime.now().millisecondsSinceEpoch}.png';
        final path = '${directory.path}/$fileName';
        final file = File(path);
        await file.writeAsBytes(image);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Identity saved as $fileName'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'SHARE IDENTITY',
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w900,
            fontSize: 14,
            letterSpacing: 2,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const QrScannerScreen(),
                ),
              );
            },
            icon: Icon(
              Icons.qr_code_scanner_rounded,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 20),
              // Card/QR Mode Switcher
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildModeTab('Boofer Card', !_isQrMode, () {
                        _pageController.animateToPage(
                          0,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                        setState(() => _isQrMode = false);
                      }),
                    ),
                    Expanded(
                      child: _buildModeTab('QR Code', _isQrMode, () {
                        _pageController.animateToPage(
                          1,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                        setState(() => _isQrMode = true);
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // The Visual Part
              Screenshot(
                controller: _screenshotController,
                child: SizedBox(
                  height: 480,
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() => _isQrMode = index == 1);
                      HapticFeedback.mediumImpact();
                    },
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Center(child: _buildBooferCard(theme, isDark)),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Center(child: _buildQrCard(theme, isDark)),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 60),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildActionButton(
                    'Copy',
                    Icons.copy_rounded,
                    _copyHandle,
                    theme,
                  ),
                  _buildActionButton(
                    'Share',
                    Icons.share_rounded,
                    _shareIdentity,
                    theme,
                  ),
                  _buildActionButton(
                    'Save',
                    Icons.download_rounded,
                    _downloadIdentity,
                    theme,
                  ),
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeTab(String title, bool isSelected, VoidCallback onTap) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              color: isSelected
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurface.withOpacity(0.4),
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBooferCard(ThemeData theme, bool isDark) {
    return BooferIdentityCard(
      user: widget.user,
      onCopyNumber: _copyHandle,
      showQrInsteadOfCopy: true,
    );
  }

  Widget _buildQrCard(ThemeData theme, bool isDark) {
    return Container(
      key: const ValueKey('qr_card'),
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 320, minHeight: 420),

      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E30) : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: theme.colorScheme.onSurface.withOpacity(0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: IntrinsicHeight(
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              Container(
                height: 10,
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF845EF7), Color(0xFFFF6B6B)],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 260,
                      width: 260,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: QrImageView(
                          data: 'boofer://profile/@${widget.user.handle}',
                          version: QrVersions.auto,
                          size: 260.0,
                          gapless: true,
                          padding: const EdgeInsets.all(0),
                          eyeStyle: const QrEyeStyle(
                            eyeShape: QrEyeShape.circle,
                            color: Colors.black,
                          ),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.circle,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '@${widget.user.handle.toUpperCase()}',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'SCAN TO CONNECT',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.3),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.05),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(32),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.policy_rounded,
                      color: theme.colorScheme.primary.withOpacity(0.5),
                      size: 14,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'GOVERNMENT OF BOOFER',
                      style: TextStyle(
                        color: theme.colorScheme.primary.withOpacity(0.7),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3,
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

  Widget _buildActionButton(
    String label,
    IconData icon,
    VoidCallback onTap,
    ThemeData theme,
  ) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withOpacity(0.05),
              shape: BoxShape.circle,
              border: Border.all(
                color: theme.colorScheme.onSurface.withOpacity(0.1),
              ),
            ),
            child: Icon(icon, color: theme.colorScheme.onSurface, size: 24),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: TextStyle(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
