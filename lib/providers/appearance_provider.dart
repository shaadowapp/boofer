import 'package:flutter/material.dart';
import '../services/unified_storage_service.dart';
import 'theme_provider.dart';
import 'dart:async';
import 'dart:math' as math;

class AppearanceProvider extends ChangeNotifier {
  Color _accentColor = const Color(0xFF3B82F6);
  String _selectedWallpaper = 'none';
  double _fontSize = 16.0; // Default font size
  bool _isInitialized = false;
  ThemeProvider? _themeProvider;
  Timer? _fontSizeDebounce;

  Color get accentColor => _accentColor;
  String get selectedWallpaper => _selectedWallpaper;
  double get fontSize => _fontSize;
  bool get isInitialized => _isInitialized;

  // Font size presets
  static const double fontSizeSmall = 14.0;
  static const double fontSizeMedium = 16.0;
  static const double fontSizeLarge = 18.0;
  static const double fontSizeExtraLarge = 20.0;

  // Set theme provider reference
  void setThemeProvider(ThemeProvider themeProvider) {
    _themeProvider = themeProvider;
  }

  // Initialize from storage
  Future<void> initialize() async {
    if (_isInitialized) return;

    final accentColorValue = await UnifiedStorageService.getInt('accent_color');
    final wallpaper = await UnifiedStorageService.getString('chat_wallpaper');
    final fontSizeValue = await UnifiedStorageService.getDouble('font_size');

    _accentColor = Color(accentColorValue ?? 0xFF3B82F6);
    _selectedWallpaper = wallpaper ?? 'none';
    _fontSize = fontSizeValue ?? 16.0;
    _isInitialized = true;

    // Update theme provider with loaded accent color and font size
    _themeProvider?.updateAccentColor(_accentColor);
    _themeProvider?.updateFontSize(_fontSize);

    notifyListeners();
  }

  // Update accent color
  Future<void> setAccentColor(Color color) async {
    _accentColor = color;
    await UnifiedStorageService.setInt('accent_color', color.value);
    
    // Update theme provider to rebuild entire app theme
    _themeProvider?.updateAccentColor(color);
    
    notifyListeners();
  }

  // Update wallpaper
  Future<void> setWallpaper(String wallpaperId) async {
    _selectedWallpaper = wallpaperId;
    await UnifiedStorageService.setString('chat_wallpaper', wallpaperId);
    notifyListeners();
  }

  // Update font size with debouncing for smooth updates
  Future<void> setFontSize(double size) async {
    _fontSize = size;
    
    // Cancel previous debounce timer
    _fontSizeDebounce?.cancel();
    
    // Notify listeners immediately for smooth slider movement
    notifyListeners();
    
    // Debounce the theme provider update and storage save
    _fontSizeDebounce = Timer(const Duration(milliseconds: 300), () async {
      await UnifiedStorageService.setDouble('font_size', size);
      _themeProvider?.updateFontSize(size);
    });
  }

  @override
  void dispose() {
    _fontSizeDebounce?.cancel();
    super.dispose();
  }

  // Get wallpaper decoration
  BoxDecoration? getWallpaperDecoration() {
    if (_selectedWallpaper == 'none') return null;

    if (_selectedWallpaper.startsWith('doodle')) {
      // For doodles, we only return the background color
      // The pattern will be drawn by CustomPaint in getWallpaperWidget
      return BoxDecoration(
        color: _getWallpaperColor(_selectedWallpaper),
      );
    }

    if (_selectedWallpaper.startsWith('solid')) {
      return BoxDecoration(
        color: _getSolidColor(_selectedWallpaper),
      );
    }

    // Gradient wallpapers
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: _getGradientColors(_selectedWallpaper),
      ),
    );
  }

  // Get wallpaper widget (for doodle patterns that need CustomPaint)
  Widget? getWallpaperWidget({required Widget child}) {
    if (_selectedWallpaper == 'none') {
      return child;
    }

    if (_selectedWallpaper.startsWith('doodle')) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        color: _getWallpaperColor(_selectedWallpaper),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Doodle pattern - fills entire space
            CustomPaint(
              painter: _DoodlePainter(_selectedWallpaper),
              size: Size.infinite,
            ),
            // Content on top
            child,
          ],
        ),
      );
    }

    // For solid and gradient, just use decoration
    return Container(
      decoration: getWallpaperDecoration(),
      child: child,
    );
  }

  Color _getWallpaperColor(String wallpaperId) {
    switch (wallpaperId) {
      case 'doodle1':
        return const Color(0xFFF3F4F6); // Light gray
      case 'doodle2':
        return const Color(0xFFDCFCE7); // Light green
      case 'doodle3':
        return const Color(0xFFDEEDFF); // Light blue
      case 'doodle4':
        return const Color(0xFFFFF4E6); // Light orange
      case 'doodle5':
        return const Color(0xFFF3E5F5); // Light purple
      case 'doodle6':
        return const Color(0xFFFFEBEE); // Light pink
      case 'doodle7':
        return const Color(0xFFE8F5E9); // Light green
      case 'doodle8':
        return const Color(0xFFFFF9C4); // Light yellow
      default:
        return Colors.transparent;
    }
  }

  Color _getSolidColor(String wallpaperId) {
    switch (wallpaperId) {
      case 'solid1':
        return const Color(0xFFF5F5F5); // Soft white
      case 'solid2':
        return const Color(0xFFE8F5E9); // Soft green
      case 'solid3':
        return const Color(0xFFE3F2FD); // Soft blue
      case 'solid4':
        return const Color(0xFFFFF3E0); // Soft orange
      case 'solid5':
        return const Color(0xFFF3E5F5); // Soft purple
      case 'solid6':
        return const Color(0xFFFCE4EC); // Soft pink
      case 'solid7':
        return const Color(0xFFFFFDE7); // Soft yellow
      case 'solid8':
        return const Color(0xFFE0F2F1); // Soft teal
      case 'solid9':
        return const Color(0xFFE8EAF6); // Soft indigo
      case 'solid10':
        return const Color(0xFFFFF8E1); // Soft amber
      default:
        return const Color(0xFFF5F5F5);
    }
  }

  List<Color> _getGradientColors(String wallpaperId) {
    switch (wallpaperId) {
      // Warm gradients
      case 'gradient1':
        return [const Color(0xFFFEF3C7), const Color(0xFFFDE68A)]; // Warm yellow
      case 'gradient2':
        return [const Color(0xFFFCE7F3), const Color(0xFFFBCFE8)]; // Soft pink
      case 'gradient3':
        return [const Color(0xFFFFE5B4), const Color(0xFFFFD4A3)]; // Peach
      // Cool gradients
      case 'gradient4':
        return [const Color(0xFFE0F2FE), const Color(0xFFBAE6FD)]; // Sky blue
      case 'gradient5':
        return [const Color(0xFFDCFCE7), const Color(0xFFBBF7D0)]; // Mint green
      case 'gradient6':
        return [const Color(0xFFE9D5FF), const Color(0xFFD8B4FE)]; // Lavender
      // Modern gradients
      case 'gradient7':
        return [const Color(0xFFFF9A9E), const Color(0xFFFAD0C4)]; // Coral sunset
      case 'gradient8':
        return [const Color(0xFFA18CD1), const Color(0xFFFBC2EB)]; // Purple dream
      case 'gradient9':
        return [const Color(0xFFFAD961), const Color(0xFFF76B1C)]; // Fire
      case 'gradient10':
        return [const Color(0xFF89F7FE), const Color(0xFF66A6FF)]; // Ocean blue
      case 'gradient11':
        return [const Color(0xFFFFD89B), const Color(0xFF19547B)]; // Sunset
      case 'gradient12':
        return [const Color(0xFFFF6E7F), const Color(0xFFBFE9FF)]; // Cotton candy
      case 'gradient13':
        return [const Color(0xFF134E5E), const Color(0xFF71B280)]; // Forest
      case 'gradient14':
        return [const Color(0xFFEEA4CE), const Color(0xFFC58BF2)]; // Rose gold
      case 'gradient15':
        return [const Color(0xFF00C9FF), const Color(0xFF92FE9D)]; // Northern lights
      default:
        return [Colors.grey.shade200, Colors.grey.shade300];
    }
  }

  // Reset to defaults
  Future<void> resetToDefaults() async {
    _accentColor = const Color(0xFF3B82F6);
    _selectedWallpaper = 'none';
    _fontSize = 16.0;

    await UnifiedStorageService.setInt('accent_color', 0xFF3B82F6);
    await UnifiedStorageService.setString('chat_wallpaper', 'none');
    await UnifiedStorageService.setDouble('font_size', 16.0);

    _themeProvider?.updateAccentColor(_accentColor);
    _themeProvider?.updateFontSize(_fontSize);

    notifyListeners();
  }
}

// Custom painter for doodle patterns (same as in appearance_settings_screen.dart)
class _DoodlePainter extends CustomPainter {
  final String doodleId;

  _DoodlePainter(this.doodleId);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.12)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    switch (doodleId) {
      case 'doodle1':
        _drawGeometricPattern(canvas, size, paint);
        break;
      case 'doodle2':
        _drawLeavesPattern(canvas, size, paint);
        break;
      case 'doodle3':
        _drawStarsPattern(canvas, size, paint);
        break;
      case 'doodle4':
        _drawCurvesPattern(canvas, size, paint);
        break;
      case 'doodle5':
        _drawHeartsPattern(canvas, size, paint);
        break;
      case 'doodle6':
        _drawWavesPattern(canvas, size, paint);
        break;
      case 'doodle7':
        _drawSimpleDotsPattern(canvas, size, paint);
        break;
      case 'doodle8':
        _drawDiagonalLinesPattern(canvas, size, paint);
        break;
    }
  }

  void _drawGeometricPattern(Canvas canvas, Size size, Paint paint) {
    final spacing = size.width / 5;
    final rows = (size.height / spacing).ceil() + 1;
    
    for (var i = 0; i < 5; i++) {
      for (var j = 0; j < rows; j++) {
        final x = i * spacing + spacing / 2;
        final y = j * spacing + spacing / 2;
        
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
        
        _drawStar(canvas, paint, Offset(x, y), spacing / 4, 4);
        
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
        
        _drawHeart(canvas, paint, Offset(x, y), spacing / 5);
        
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
    
    path.cubicTo(
      center.dx - size * 2, center.dy - size * 0.5,
      center.dx - size, center.dy - size * 1.2,
      center.dx, center.dy - size * 0.3,
    );
    
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
