import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../providers/theme_provider.dart';
import '../providers/appearance_provider.dart';

class AppearanceSettingsScreen extends StatefulWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  State<AppearanceSettingsScreen> createState() => _AppearanceSettingsScreenState();
}

class _AppearanceSettingsScreenState extends State<AppearanceSettingsScreen> {
  final List<Color> _brandColors = [
    const Color(0xFF3B82F6), // Blue
    const Color(0xFF10B981), // Green
    const Color(0xFFEF4444), // Red
    const Color(0xFFF59E0B), // Orange
    const Color(0xFF8B5CF6), // Purple
    const Color(0xFFEC4899), // Pink
    const Color(0xFF06B6D4), // Cyan
    const Color(0xFF14B8A6), // Teal
  ];

  final List<Map<String, dynamic>> _wallpapers = [
    {'id': 'none', 'name': 'None', 'type': 'none'},
    // Doodles
    {'id': 'doodle1', 'name': 'Doodle 1', 'type': 'doodle', 'color': const Color(0xFFF3F4F6)},
    {'id': 'doodle2', 'name': 'Doodle 2', 'type': 'doodle', 'color': const Color(0xFFDCFCE7)},
    {'id': 'doodle3', 'name': 'Doodle 3', 'type': 'doodle', 'color': const Color(0xFFDEEDFF)},
    {'id': 'doodle4', 'name': 'Doodle 4', 'type': 'doodle', 'color': const Color(0xFFFFF4E6)},
    {'id': 'doodle5', 'name': 'Doodle 5', 'type': 'doodle', 'color': const Color(0xFFF3E5F5)},
    {'id': 'doodle6', 'name': 'Doodle 6', 'type': 'doodle', 'color': const Color(0xFFFFEBEE)},
    // Solid colors
    {'id': 'solid1', 'name': 'Soft White', 'type': 'solid', 'color': const Color(0xFFF5F5F5)},
    {'id': 'solid2', 'name': 'Soft Green', 'type': 'solid', 'color': const Color(0xFFE8F5E9)},
    {'id': 'solid3', 'name': 'Soft Blue', 'type': 'solid', 'color': const Color(0xFFE3F2FD)},
    {'id': 'solid4', 'name': 'Soft Orange', 'type': 'solid', 'color': const Color(0xFFFFF3E0)},
    {'id': 'solid5', 'name': 'Soft Purple', 'type': 'solid', 'color': const Color(0xFFF3E5F5)},
    {'id': 'solid6', 'name': 'Soft Pink', 'type': 'solid', 'color': const Color(0xFFFCE4EC)},
    // Modern gradients
    {'id': 'gradient1', 'name': 'Warm Yellow', 'type': 'gradient'},
    {'id': 'gradient2', 'name': 'Soft Pink', 'type': 'gradient'},
    {'id': 'gradient3', 'name': 'Peach', 'type': 'gradient'},
    {'id': 'gradient4', 'name': 'Sky Blue', 'type': 'gradient'},
    {'id': 'gradient5', 'name': 'Mint Green', 'type': 'gradient'},
    {'id': 'gradient6', 'name': 'Lavender', 'type': 'gradient'},
    {'id': 'gradient7', 'name': 'Coral Sunset', 'type': 'gradient'},
    {'id': 'gradient8', 'name': 'Purple Dream', 'type': 'gradient'},
    {'id': 'gradient9', 'name': 'Fire', 'type': 'gradient'},
    {'id': 'gradient10', 'name': 'Ocean Blue', 'type': 'gradient'},
    {'id': 'gradient11', 'name': 'Sunset', 'type': 'gradient'},
    {'id': 'gradient12', 'name': 'Cotton Candy', 'type': 'gradient'},
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final appearanceProvider = Provider.of<AppearanceProvider>(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        title: const Text('Appearance'),
      ),
      body: ListView(
        children: [
          // Theme Section
          _buildSection(
            context,
            title: 'THEME',
            children: [
              ListTile(
                leading: Icon(
                  themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                  color: theme.colorScheme.onSurface,
                ),
                title: const Text('Theme Mode'),
                subtitle: Text(themeProvider.themeModeString),
                trailing: Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                ),
                onTap: () => _showThemeDialog(context, themeProvider),
              ),
            ],
          ),

          // Brand Color Section
          _buildSection(
            context,
            title: 'ACCENT COLOR',
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Choose your accent color',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: _brandColors.map((color) {
                        final isSelected = appearanceProvider.accentColor.value == color.value;
                        return GestureDetector(
                          onTap: () => appearanceProvider.setAccentColor(color),
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: isSelected
                                  ? Border.all(
                                      color: theme.colorScheme.onSurface,
                                      width: 3,
                                    )
                                  : null,
                              boxShadow: [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: isSelected
                                ? const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 28,
                                  )
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Font Size Section
          _buildSection(
            context,
            title: 'FONT SIZE',
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Adjust text size across the entire app',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Text(
                          'A',
                          style: TextStyle(
                            fontSize: 14,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 4.0,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8.0),
                              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16.0),
                            ),
                            child: Slider(
                              value: appearanceProvider.fontSize,
                              min: 14.0,
                              max: 20.0,
                              divisions: 3,
                              label: _getFontSizeLabel(appearanceProvider.fontSize),
                              onChanged: (value) {
                                appearanceProvider.setFontSize(value);
                              },
                            ),
                          ),
                        ),
                        Text(
                          'A',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        style: TextStyle(
                          fontSize: appearanceProvider.fontSize,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.primary,
                        ),
                        child: Text(
                          'Preview: ${_getFontSizeLabel(appearanceProvider.fontSize)}',
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        style: TextStyle(
                          fontSize: appearanceProvider.fontSize,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                        child: const Text(
                          'The quick brown fox jumps over the lazy dog',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Chat Wallpaper Section
          _buildSection(
            context,
            title: 'CHAT WALLPAPER',
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Choose a background for your chats',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 16),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.8,
                      ),
                      itemCount: _wallpapers.length,
                      itemBuilder: (context, index) {
                        final wallpaper = _wallpapers[index];
                        final isSelected = appearanceProvider.selectedWallpaper == wallpaper['id'];
                        final type = wallpaper['type'] as String;

                        return GestureDetector(
                          onTap: () => appearanceProvider.setWallpaper(wallpaper['id']),
                          child: Container(
                            decoration: BoxDecoration(
                              color: type == 'solid' ? wallpaper['color'] as Color? : null,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.outline.withValues(alpha: 0.2),
                                width: isSelected ? 3 : 1,
                              ),
                            ),
                            child: Stack(
                              children: [
                                if (wallpaper['id'] != 'none')
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: _buildWallpaperPreview(wallpaper['id']),
                                  ),
                                if (wallpaper['id'] == 'none')
                                  const Center(
                                    child: Icon(Icons.block, size: 32),
                                  ),
                                if (isSelected)
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                Positioned(
                                  bottom: 8,
                                  left: 8,
                                  right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.6),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      wallpaper['name'],
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildWallpaperPreview(String wallpaperId) {
    final wallpaper = _wallpapers.firstWhere((w) => w['id'] == wallpaperId);
    final type = wallpaper['type'] as String;

    if (type == 'doodle') {
      return SizedBox.expand(
        child: CustomPaint(
          painter: DoodlePainter(wallpaperId),
        ),
      );
    }

    if (type == 'solid') {
      return Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: wallpaper['color'] as Color,
        ),
      );
    }

    // Gradient
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _getGradientColors(wallpaperId),
        ),
      ),
    );
  }

  List<Color> _getGradientColors(String wallpaperId) {
    switch (wallpaperId) {
      case 'gradient1':
        return [const Color(0xFFFEF3C7), const Color(0xFFFDE68A)];
      case 'gradient2':
        return [const Color(0xFFFCE7F3), const Color(0xFFFBCFE8)];
      case 'gradient3':
        return [const Color(0xFFFFE5B4), const Color(0xFFFFD4A3)];
      case 'gradient4':
        return [const Color(0xFFE0F2FE), const Color(0xFFBAE6FD)];
      case 'gradient5':
        return [const Color(0xFFDCFCE7), const Color(0xFFBBF7D0)];
      case 'gradient6':
        return [const Color(0xFFE9D5FF), const Color(0xFFD8B4FE)];
      case 'gradient7':
        return [const Color(0xFFFF9A9E), const Color(0xFFFAD0C4)];
      case 'gradient8':
        return [const Color(0xFFA18CD1), const Color(0xFFFBC2EB)];
      case 'gradient9':
        return [const Color(0xFFFAD961), const Color(0xFFF76B1C)];
      case 'gradient10':
        return [const Color(0xFF89F7FE), const Color(0xFF66A6FF)];
      case 'gradient11':
        return [const Color(0xFFFFD89B), const Color(0xFF19547B)];
      case 'gradient12':
        return [const Color(0xFFFF6E7F), const Color(0xFFBFE9FF)];
      default:
        return [Colors.grey.shade200, Colors.grey.shade300];
    }
  }

  String _getFontSizeLabel(double fontSize) {
    if (fontSize <= 14.0) return 'Small';
    if (fontSize <= 16.0) return 'Medium';
    if (fontSize <= 18.0) return 'Large';
    return 'Extra Large';
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        ...children,
      ],
    );
  }

  void _showThemeDialog(BuildContext context, ThemeProvider themeProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<AppThemeMode>(
              title: const Text('Light'),
              value: AppThemeMode.light,
              groupValue: themeProvider.themeMode,
              onChanged: (value) {
                if (value != null) {
                  themeProvider.setThemeMode(value);
                  Navigator.pop(context);
                }
              },
            ),
            RadioListTile<AppThemeMode>(
              title: const Text('Dark'),
              value: AppThemeMode.dark,
              groupValue: themeProvider.themeMode,
              onChanged: (value) {
                if (value != null) {
                  themeProvider.setThemeMode(value);
                  Navigator.pop(context);
                }
              },
            ),
            RadioListTile<AppThemeMode>(
              title: const Text('System Default'),
              value: AppThemeMode.system,
              groupValue: themeProvider.themeMode,
              onChanged: (value) {
                if (value != null) {
                  themeProvider.setThemeMode(value);
                  Navigator.pop(context);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

// Custom painter for doodle patterns
class DoodlePainter extends CustomPainter {
  final String doodleId;

  DoodlePainter(this.doodleId);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.15)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    switch (doodleId) {
      case 'doodle1':
        // Circles pattern - Light gray background
        _drawCirclesPattern(canvas, size, paint);
        break;
      case 'doodle2':
        // Waves pattern - Light green background
        _drawWavesPattern(canvas, size, paint);
        break;
      case 'doodle3':
        // Stars pattern - Light blue background
        _drawStarsPattern(canvas, size, paint);
        break;
      case 'doodle4':
        // Dots pattern - Light orange background
        _drawDotsPattern(canvas, size, paint);
        break;
      case 'doodle5':
        // Hearts pattern - Light purple background
        _drawHeartsPattern(canvas, size, paint);
        break;
      case 'doodle6':
        // Zigzag pattern - Light pink background
        _drawZigzagPattern(canvas, size, paint);
        break;
    }
  }

  void _drawCirclesPattern(Canvas canvas, Size size, Paint paint) {
    for (var i = 0; i < 4; i++) {
      for (var j = 0; j < 4; j++) {
        canvas.drawCircle(
          Offset(size.width * (i / 4) + size.width / 8, size.height * (j / 4) + size.height / 8),
          size.width / 12,
          paint,
        );
      }
    }
  }

  void _drawWavesPattern(Canvas canvas, Size size, Paint paint) {
    for (var row = 0; row < 4; row++) {
      final path = Path();
      final y = size.height * (row / 4) + size.height / 8;
      path.moveTo(0, y);
      for (var i = 0; i < size.width; i += 20) {
        path.quadraticBezierTo(
          i + 10,
          y - 10,
          i + 20,
          y,
        );
      }
      canvas.drawPath(path, paint);
    }
  }

  void _drawStarsPattern(Canvas canvas, Size size, Paint paint) {
    for (var i = 0; i < 3; i++) {
      for (var j = 0; j < 3; j++) {
        _drawStar(
          canvas,
          paint,
          Offset(size.width * (i / 3) + size.width / 6, size.height * (j / 3) + size.height / 6),
          size.width / 15,
        );
      }
    }
  }

  void _drawDotsPattern(Canvas canvas, Size size, Paint paint) {
    paint.style = PaintingStyle.fill;
    for (var i = 0; i < 6; i++) {
      for (var j = 0; j < 6; j++) {
        canvas.drawCircle(
          Offset(size.width * (i / 6) + size.width / 12, size.height * (j / 6) + size.height / 12),
          3,
          paint,
        );
      }
    }
  }

  void _drawHeartsPattern(Canvas canvas, Size size, Paint paint) {
    paint.style = PaintingStyle.fill;
    for (var i = 0; i < 3; i++) {
      for (var j = 0; j < 3; j++) {
        _drawHeart(
          canvas,
          paint,
          Offset(size.width * (i / 3) + size.width / 6, size.height * (j / 3) + size.height / 6),
          size.width / 20,
        );
      }
    }
  }

  void _drawZigzagPattern(Canvas canvas, Size size, Paint paint) {
    for (var row = 0; row < 5; row++) {
      final path = Path();
      final y = size.height * (row / 5);
      path.moveTo(0, y);
      for (var i = 0; i < size.width; i += 15) {
        path.lineTo(i + 7.5, y + (i % 30 == 0 ? 10 : -10));
        path.lineTo(i + 15, y);
      }
      canvas.drawPath(path, paint);
    }
  }

  void _drawStar(Canvas canvas, Paint paint, Offset center, double radius) {
    final path = Path();
    for (var i = 0; i < 5; i++) {
      final angle = (i * 4 * math.pi) / 5 - math.pi / 2;
      final x = center.dx + radius * (i % 2 == 0 ? 1 : 0.5) * math.cos(angle);
      final y = center.dy + radius * (i % 2 == 0 ? 1 : 0.5) * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawHeart(Canvas canvas, Paint paint, Offset center, double size) {
    final path = Path();
    path.moveTo(center.dx, center.dy + size);
    path.cubicTo(
      center.dx - size * 2, center.dy - size,
      center.dx - size, center.dy - size * 1.5,
      center.dx, center.dy - size * 0.5,
    );
    path.cubicTo(
      center.dx + size, center.dy - size * 1.5,
      center.dx + size * 2, center.dy - size,
      center.dx, center.dy + size,
    );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
