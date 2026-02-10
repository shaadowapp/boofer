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
    // Doodles - inspired by Telegram/WhatsApp patterns
    {'id': 'doodle1', 'name': 'Geometric', 'type': 'doodle', 'color': const Color(0xFFF3F4F6)},
    {'id': 'doodle2', 'name': 'Leaves', 'type': 'doodle', 'color': const Color(0xFFDCFCE7)},
    {'id': 'doodle3', 'name': 'Stars', 'type': 'doodle', 'color': const Color(0xFFDEEDFF)},
    {'id': 'doodle4', 'name': 'Curves', 'type': 'doodle', 'color': const Color(0xFFFFF4E6)},
    {'id': 'doodle5', 'name': 'Hearts', 'type': 'doodle', 'color': const Color(0xFFF3E5F5)},
    {'id': 'doodle6', 'name': 'Waves', 'type': 'doodle', 'color': const Color(0xFFFFEBEE)},
    {'id': 'doodle7', 'name': 'Dots', 'type': 'doodle', 'color': const Color(0xFFE8F5E9)},
    {'id': 'doodle8', 'name': 'Lines', 'type': 'doodle', 'color': const Color(0xFFFFF9C4)},
    // Solid colors
    {'id': 'solid1', 'name': 'Soft White', 'type': 'solid', 'color': const Color(0xFFF5F5F5)},
    {'id': 'solid2', 'name': 'Soft Green', 'type': 'solid', 'color': const Color(0xFFE8F5E9)},
    {'id': 'solid3', 'name': 'Soft Blue', 'type': 'solid', 'color': const Color(0xFFE3F2FD)},
    {'id': 'solid4', 'name': 'Soft Orange', 'type': 'solid', 'color': const Color(0xFFFFF3E0)},
    {'id': 'solid5', 'name': 'Soft Purple', 'type': 'solid', 'color': const Color(0xFFF3E5F5)},
    {'id': 'solid6', 'name': 'Soft Pink', 'type': 'solid', 'color': const Color(0xFFFCE4EC)},
    {'id': 'solid7', 'name': 'Soft Yellow', 'type': 'solid', 'color': const Color(0xFFFFFDE7)},
    {'id': 'solid8', 'name': 'Soft Teal', 'type': 'solid', 'color': const Color(0xFFE0F2F1)},
    {'id': 'solid9', 'name': 'Soft Indigo', 'type': 'solid', 'color': const Color(0xFFE8EAF6)},
    {'id': 'solid10', 'name': 'Soft Amber', 'type': 'solid', 'color': const Color(0xFFFFF8E1)},
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
    {'id': 'gradient13', 'name': 'Forest', 'type': 'gradient'},
    {'id': 'gradient14', 'name': 'Rose Gold', 'type': 'gradient'},
    {'id': 'gradient15', 'name': 'Northern Lights', 'type': 'gradient'},
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
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  'Choose a background for your chats',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
              
              // None option
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: _buildWallpaperOption(
                  context,
                  'none',
                  'None',
                  appearanceProvider,
                  theme,
                ),
              ),
              
              // Doodles Section
              _buildWallpaperSubSection(
                context,
                title: 'Doodles',
                wallpapers: _wallpapers.where((w) => w['type'] == 'doodle').toList(),
                appearanceProvider: appearanceProvider,
                theme: theme,
              ),
              
              // Solid Colors Section
              _buildWallpaperSubSection(
                context,
                title: 'Solid Colors',
                wallpapers: _wallpapers.where((w) => w['type'] == 'solid').toList(),
                appearanceProvider: appearanceProvider,
                theme: theme,
              ),
              
              // Gradients Section
              _buildWallpaperSubSection(
                context,
                title: 'Gradients',
                wallpapers: _wallpapers.where((w) => w['type'] == 'gradient').toList(),
                appearanceProvider: appearanceProvider,
                theme: theme,
              ),
            ],
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // Build wallpaper subsection with horizontal scroll
  Widget _buildWallpaperSubSection(
    BuildContext context, {
    required String title,
    required List<Map<String, dynamic>> wallpapers,
    required AppearanceProvider appearanceProvider,
    required ThemeData theme,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: wallpapers.length,
            itemBuilder: (context, index) {
              final wallpaper = wallpapers[index];
              return Padding(
                padding: EdgeInsets.only(right: index < wallpapers.length - 1 ? 12 : 0),
                child: _buildWallpaperOption(
                  context,
                  wallpaper['id'],
                  wallpaper['name'],
                  appearanceProvider,
                  theme,
                  width: 100,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // Build individual wallpaper option
  Widget _buildWallpaperOption(
    BuildContext context,
    String id,
    String name,
    AppearanceProvider appearanceProvider,
    ThemeData theme, {
    double? width,
  }) {
    final isSelected = appearanceProvider.selectedWallpaper == id;
    
    return GestureDetector(
      onTap: () => appearanceProvider.setWallpaper(id),
      child: Container(
        width: width,
        decoration: BoxDecoration(
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
            if (id != 'none')
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _buildWallpaperPreview(id),
              ),
            if (id == 'none')
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.block,
                      size: 32,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      name,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
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
            if (id != 'none')
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
                    name,
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
  }

  Widget _buildWallpaperPreview(String wallpaperId) {
    final wallpaper = _wallpapers.firstWhere((w) => w['id'] == wallpaperId);
    final type = wallpaper['type'] as String;

    if (type == 'doodle') {
      return Container(
        width: double.infinity,
        height: double.infinity,
        color: wallpaper['color'] as Color,
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
      case 'gradient13':
        return [const Color(0xFF134E5E), const Color(0xFF71B280)];
      case 'gradient14':
        return [const Color(0xFFEEA4CE), const Color(0xFFC58BF2)];
      case 'gradient15':
        return [const Color(0xFF00C9FF), const Color(0xFF92FE9D)];
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

// Custom painter for doodle patterns inspired by Telegram/WhatsApp
class DoodlePainter extends CustomPainter {
  final String doodleId;

  DoodlePainter(this.doodleId);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.12)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    switch (doodleId) {
      case 'doodle1':
        // Geometric circles and dots pattern
        _drawGeometricPattern(canvas, size, paint);
        break;
      case 'doodle2':
        // Nature-inspired leaves pattern
        _drawLeavesPattern(canvas, size, paint);
        break;
      case 'doodle3':
        // Stars and sparkles pattern
        _drawStarsPattern(canvas, size, paint);
        break;
      case 'doodle4':
        // Abstract curves pattern
        _drawCurvesPattern(canvas, size, paint);
        break;
      case 'doodle5':
        // Hearts and flowers pattern
        _drawHeartsPattern(canvas, size, paint);
        break;
      case 'doodle6':
        // Waves and lines pattern
        _drawWavesPattern(canvas, size, paint);
        break;
      case 'doodle7':
        // Simple dots pattern
        _drawSimpleDotsPattern(canvas, size, paint);
        break;
      case 'doodle8':
        // Diagonal lines pattern
        _drawDiagonalLinesPattern(canvas, size, paint);
        break;
    }
  }

  void _drawGeometricPattern(Canvas canvas, Size size, Paint paint) {
    final spacing = size.width / 5;
    final rows = (size.height / spacing).ceil() + 1;
    
    // Draw circles
    for (var i = 0; i < 5; i++) {
      for (var j = 0; j < rows; j++) {
        final x = i * spacing + spacing / 2;
        final y = j * spacing + spacing / 2;
        
        // Alternating circles and dots
        if ((i + j) % 2 == 0) {
          canvas.drawCircle(Offset(x, y), spacing / 4, paint);
        } else {
          paint.style = PaintingStyle.fill;
          canvas.drawCircle(Offset(x, y), 2, paint);
          paint.style = PaintingStyle.stroke;
        }
      }
    }
  }

  void _drawLeavesPattern(Canvas canvas, Size size, Paint paint) {
    final spacing = size.width / 4;
    final rows = (size.height / spacing).ceil() + 1;
    
    for (var i = 0; i < 4; i++) {
      for (var j = 0; j < rows; j++) {
        final x = i * spacing + spacing / 2;
        final y = j * spacing + spacing / 2;
        
        // Draw leaf shape
        final path = Path();
        path.moveTo(x, y - spacing / 3);
        path.quadraticBezierTo(
          x + spacing / 4, y - spacing / 6,
          x, y + spacing / 3,
        );
        path.quadraticBezierTo(
          x - spacing / 4, y - spacing / 6,
          x, y - spacing / 3,
        );
        canvas.drawPath(path, paint);
        
        // Add vein
        canvas.drawLine(
          Offset(x, y - spacing / 3),
          Offset(x, y + spacing / 3),
          paint,
        );
      }
    }
  }

  void _drawStarsPattern(Canvas canvas, Size size, Paint paint) {
    final spacing = size.width / 4;
    final rows = (size.height / spacing).ceil() + 1;
    
    for (var i = 0; i < 4; i++) {
      for (var j = 0; j < rows; j++) {
        final x = i * spacing + spacing / 2;
        final y = j * spacing + spacing / 2;
        
        // Draw 4-point star
        _drawStar(canvas, paint, Offset(x, y), spacing / 4, 4);
        
        // Add small sparkles
        if ((i + j) % 2 == 0) {
          paint.style = PaintingStyle.fill;
          canvas.drawCircle(Offset(x + spacing / 3, y - spacing / 4), 1.5, paint);
          canvas.drawCircle(Offset(x - spacing / 3, y + spacing / 4), 1.5, paint);
          paint.style = PaintingStyle.stroke;
        }
      }
    }
  }

  void _drawCurvesPattern(Canvas canvas, Size size, Paint paint) {
    final spacing = size.width / 5;
    final rows = (size.height / spacing).ceil() + 1;
    
    for (var i = 0; i < 5; i++) {
      for (var j = 0; j < rows; j++) {
        final x = i * spacing + spacing / 2;
        final y = j * spacing + spacing / 2;
        
        // Draw curved lines
        final path = Path();
        path.moveTo(x - spacing / 3, y);
        path.quadraticBezierTo(
          x, y - spacing / 3,
          x + spacing / 3, y,
        );
        path.quadraticBezierTo(
          x, y + spacing / 3,
          x - spacing / 3, y,
        );
        canvas.drawPath(path, paint);
      }
    }
  }

  void _drawHeartsPattern(Canvas canvas, Size size, Paint paint) {
    final spacing = size.width / 4;
    final rows = (size.height / spacing).ceil() + 1;
    
    for (var i = 0; i < 4; i++) {
      for (var j = 0; j < rows; j++) {
        final x = i * spacing + spacing / 2;
        final y = j * spacing + spacing / 2;
        
        // Draw heart
        _drawHeart(canvas, paint, Offset(x, y), spacing / 5);
        
        // Add small dots around
        if ((i + j) % 2 == 0) {
          paint.style = PaintingStyle.fill;
          canvas.drawCircle(Offset(x + spacing / 3, y), 1.5, paint);
          canvas.drawCircle(Offset(x - spacing / 3, y), 1.5, paint);
          paint.style = PaintingStyle.stroke;
        }
      }
    }
  }

  void _drawWavesPattern(Canvas canvas, Size size, Paint paint) {
    final spacing = size.height / 8;
    final rows = (size.height / spacing).ceil() + 1;
    
    for (var row = 0; row < rows; row++) {
      final path = Path();
      final y = row * spacing;
      path.moveTo(0, y);
      
      for (var i = 0.0; i < size.width + spacing; i += spacing) {
        path.quadraticBezierTo(
          i + spacing / 2, y + spacing / 3,
          i + spacing, y,
        );
      }
      canvas.drawPath(path, paint);
      
      // Add dots between waves
      if (row % 2 == 0) {
        paint.style = PaintingStyle.fill;
        for (var i = spacing / 2; i < size.width; i += spacing) {
          canvas.drawCircle(Offset(i, y + spacing / 2), 1.5, paint);
        }
        paint.style = PaintingStyle.stroke;
      }
    }
  }

  void _drawSimpleDotsPattern(Canvas canvas, Size size, Paint paint) {
    final spacing = size.width / 8;
    final rows = (size.height / spacing).ceil() + 1;
    
    paint.style = PaintingStyle.fill;
    for (var i = 0; i < 8; i++) {
      for (var j = 0; j < rows; j++) {
        final x = i * spacing + spacing / 2;
        final y = j * spacing + spacing / 2;
        canvas.drawCircle(Offset(x, y), 2.5, paint);
      }
    }
    paint.style = PaintingStyle.stroke;
  }

  void _drawDiagonalLinesPattern(Canvas canvas, Size size, Paint paint) {
    const spacing = 20.0;
    
    for (var i = -size.height; i < size.width + size.height; i += spacing) {
      canvas.drawLine(
        Offset(i.toDouble(), 0),
        Offset(i + size.height, size.height),
        paint,
      );
    }
  }

  void _drawStar(Canvas canvas, Paint paint, Offset center, double radius, int points) {
    final path = Path();
    final angleStep = (2 * math.pi) / points;
    
    for (var i = 0; i < points; i++) {
      final angle = i * angleStep - math.pi / 2;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      
      // Add inner point
      final innerAngle = angle + angleStep / 2;
      final innerX = center.dx + (radius * 0.4) * math.cos(innerAngle);
      final innerY = center.dy + (radius * 0.4) * math.sin(innerAngle);
      path.lineTo(innerX, innerY);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawHeart(Canvas canvas, Paint paint, Offset center, double size) {
    final path = Path();
    path.moveTo(center.dx, center.dy + size);
    
    // Left curve
    path.cubicTo(
      center.dx - size * 2, center.dy - size * 0.5,
      center.dx - size, center.dy - size * 1.2,
      center.dx, center.dy - size * 0.3,
    );
    
    // Right curve
    path.cubicTo(
      center.dx + size, center.dy - size * 1.2,
      center.dx + size * 2, center.dy - size * 0.5,
      center.dx, center.dy + size,
    );
    
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
