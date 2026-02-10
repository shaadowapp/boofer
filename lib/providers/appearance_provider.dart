import 'package:flutter/material.dart';
import '../services/unified_storage_service.dart';
import 'theme_provider.dart';
import 'dart:async';

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
