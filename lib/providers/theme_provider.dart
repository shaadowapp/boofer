import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_colors.dart';

enum AppThemeMode { light, dark, system }

class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'theme_mode';
  AppThemeMode _themeMode = AppThemeMode.dark;
  bool _isSystemDarkMode = false;
  Color _accentColor = AppColors.loveRose;
  double _fontSizeScale = 1.0; // Font size multiplier (16.0 / 16.0 = 1.0)
  double _cornerRadius = 16.0; // Corner radius for UI elements

  AppThemeMode get themeMode => _themeMode;
  bool get isDarkMode =>
      _themeMode == AppThemeMode.dark ||
      (_themeMode == AppThemeMode.system && _isSystemDarkMode);
  Color get accentColor => _accentColor;
  double get fontSizeScale => _fontSizeScale;
  double get cornerRadius => _cornerRadius;

  String get themeModeString {
    switch (_themeMode) {
      case AppThemeMode.light:
        return 'Light';
      case AppThemeMode.dark:
        return 'Dark';
      case AppThemeMode.system:
        return 'System Default';
    }
  }

  ThemeProvider() {
    _loadTheme();
    _detectSystemTheme();
  }

  // Update accent color and rebuild theme
  void updateAccentColor(Color color) {
    if (_accentColor != color) {
      _accentColor = color;
      notifyListeners();
    }
  }

  // Update font size and rebuild theme smoothly
  void updateFontSize(double fontSize) {
    final newScale = fontSize / 16.0; // 16.0 is the base font size
    if ((_fontSizeScale - newScale).abs() > 0.01) {
      // Only update if change is significant
      _fontSizeScale = newScale;
      notifyListeners();
    }
  }

  // Update corner radius and rebuild theme
  void updateCornerRadius(double radius) {
    if (_cornerRadius != radius) {
      _cornerRadius = radius;
      notifyListeners();
    }
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex =
        prefs.getInt(_themeKey) ?? 1; // Default to dark (index 1)
    _themeMode = AppThemeMode.values[themeIndex];
    notifyListeners();
  }

  void _detectSystemTheme() {
    final brightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    _isSystemDarkMode = brightness == Brightness.dark;

    // Listen for system theme changes
    WidgetsBinding.instance.platformDispatcher.onPlatformBrightnessChanged =
        () {
          final newBrightness =
              WidgetsBinding.instance.platformDispatcher.platformBrightness;
          final newIsSystemDarkMode = newBrightness == Brightness.dark;

          if (_isSystemDarkMode != newIsSystemDarkMode) {
            _isSystemDarkMode = newIsSystemDarkMode;
            if (_themeMode == AppThemeMode.system) {
              notifyListeners();
            }
          }
        };
  }

  Future<void> toggleTheme() async {
    // Cycle through: light -> dark -> system -> light
    switch (_themeMode) {
      case AppThemeMode.light:
        await setThemeMode(AppThemeMode.dark);
        break;
      case AppThemeMode.dark:
        await setThemeMode(AppThemeMode.system);
        break;
      case AppThemeMode.system:
        await setThemeMode(AppThemeMode.light);
        break;
    }
  }

  Future<void> setDarkMode(bool isDark) async {
    await setThemeMode(isDark ? AppThemeMode.dark : AppThemeMode.light);
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    if (_themeMode != mode) {
      _themeMode = mode;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_themeKey, mode.index);
      notifyListeners();
    }
  }

  ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _accentColor,
        brightness: Brightness.light,
        primary: _accentColor,
        secondary: _accentColor.withOpacity(0.8),
        surface: AppColors.lightSurface,
        background: AppColors.lightBackground,
        onPrimary: Colors.white,
        onSecondary: AppColors.lightPrimaryText,
        onSurface: AppColors.lightPrimaryText,
        onBackground: AppColors.lightPrimaryText,
        outline: AppColors.lightSecondaryText,
        error: AppColors.danger,
      ),
      textTheme: _buildTextTheme(Brightness.light),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: AppColors.lightBackground,
        foregroundColor: AppColors.lightPrimaryText,
        iconTheme: const IconThemeData(color: AppColors.lightPrimaryText),
        titleTextStyle: TextStyle(
          color: AppColors.lightPrimaryText,
          fontSize: 20 * _fontSizeScale,
          fontWeight: FontWeight.w600,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        selectedItemColor: _accentColor,
        unselectedItemColor: AppColors.lightSecondaryText,
        selectedLabelStyle: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12 * _fontSizeScale,
        ),
        unselectedLabelStyle: TextStyle(fontSize: 12 * _fontSizeScale),
        backgroundColor: AppColors.lightSurface,
      ),
      cardTheme: CardThemeData(
        color: AppColors.lightSurface,
        elevation: 2,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(_cornerRadius)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_cornerRadius),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_cornerRadius),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_cornerRadius),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_cornerRadius),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_cornerRadius),
          borderSide: const BorderSide(color: AppColors.lightSecondaryText),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_cornerRadius),
          borderSide: BorderSide(color: _accentColor, width: 2),
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            _cornerRadius + 4,
          ), // Slightly rounder
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(_cornerRadius + 8),
          ),
        ),
      ),
      scaffoldBackgroundColor: AppColors.lightBackground,
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _accentColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_cornerRadius),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return _accentColor;
          }
          return AppColors.lightSecondaryText;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return _accentColor.withOpacity(0.3);
          }
          return AppColors.lightSecondaryText.withOpacity(0.3);
        }),
      ),
    );
  }

  ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _accentColor,
        brightness: Brightness.dark,
        primary: _accentColor,
        secondary: _accentColor.withOpacity(0.8),
        surface: AppColors.darkSurface,
        background: AppColors.darkBackground,
        onPrimary: Colors.white,
        onSecondary: AppColors.darkPrimaryText,
        onSurface: AppColors.darkPrimaryText,
        onBackground: AppColors.darkPrimaryText,
        outline: AppColors.darkSecondaryText,
        error: AppColors.danger,
      ),
      textTheme: _buildTextTheme(Brightness.dark),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: AppColors.darkBackground,
        foregroundColor: AppColors.darkPrimaryText,
        iconTheme: const IconThemeData(color: AppColors.darkPrimaryText),
        titleTextStyle: TextStyle(
          color: AppColors.darkPrimaryText,
          fontSize: 20 * _fontSizeScale,
          fontWeight: FontWeight.w600,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        selectedItemColor: _accentColor,
        unselectedItemColor: AppColors.darkSecondaryText,
        selectedLabelStyle: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12 * _fontSizeScale,
        ),
        unselectedLabelStyle: TextStyle(fontSize: 12 * _fontSizeScale),
        backgroundColor: AppColors.darkSurface,
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkSurface,
        elevation: 2,
        shadowColor: Colors.black54,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(_cornerRadius)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_cornerRadius),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_cornerRadius),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_cornerRadius),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_cornerRadius),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_cornerRadius),
          borderSide: const BorderSide(color: AppColors.darkSecondaryText),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_cornerRadius),
          borderSide: BorderSide(color: _accentColor, width: 2),
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_cornerRadius + 4),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(_cornerRadius + 8),
          ),
        ),
      ),
      scaffoldBackgroundColor: AppColors.darkBackground,
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _accentColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_cornerRadius),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return _accentColor;
          }
          return AppColors.darkSecondaryText;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return _accentColor.withOpacity(0.3);
          }
          return AppColors.darkSecondaryText.withOpacity(0.3);
        }),
      ),
    );
  }

  // Build text theme with font size scaling
  TextTheme _buildTextTheme(Brightness brightness) {
    final baseColor = brightness == Brightness.light
        ? AppColors.lightPrimaryText
        : AppColors.darkPrimaryText;

    return TextTheme(
      displayLarge: TextStyle(
        fontSize: 57 * _fontSizeScale,
        fontWeight: FontWeight.w400,
        color: baseColor,
      ),
      displayMedium: TextStyle(
        fontSize: 45 * _fontSizeScale,
        fontWeight: FontWeight.w400,
        color: baseColor,
      ),
      displaySmall: TextStyle(
        fontSize: 36 * _fontSizeScale,
        fontWeight: FontWeight.w400,
        color: baseColor,
      ),
      headlineLarge: TextStyle(
        fontSize: 32 * _fontSizeScale,
        fontWeight: FontWeight.w600,
        color: baseColor,
      ),
      headlineMedium: TextStyle(
        fontSize: 28 * _fontSizeScale,
        fontWeight: FontWeight.w600,
        color: baseColor,
      ),
      headlineSmall: TextStyle(
        fontSize: 24 * _fontSizeScale,
        fontWeight: FontWeight.w600,
        color: baseColor,
      ),
      titleLarge: TextStyle(
        fontSize: 22 * _fontSizeScale,
        fontWeight: FontWeight.w600,
        color: baseColor,
      ),
      titleMedium: TextStyle(
        fontSize: 16 * _fontSizeScale,
        fontWeight: FontWeight.w600,
        color: baseColor,
      ),
      titleSmall: TextStyle(
        fontSize: 14 * _fontSizeScale,
        fontWeight: FontWeight.w600,
        color: baseColor,
      ),
      bodyLarge: TextStyle(
        fontSize: 16 * _fontSizeScale,
        fontWeight: FontWeight.w400,
        color: baseColor,
      ),
      bodyMedium: TextStyle(
        fontSize: 14 * _fontSizeScale,
        fontWeight: FontWeight.w400,
        color: baseColor,
      ),
      bodySmall: TextStyle(
        fontSize: 12 * _fontSizeScale,
        fontWeight: FontWeight.w400,
        color: baseColor,
      ),
      labelLarge: TextStyle(
        fontSize: 14 * _fontSizeScale,
        fontWeight: FontWeight.w500,
        color: baseColor,
      ),
      labelMedium: TextStyle(
        fontSize: 12 * _fontSizeScale,
        fontWeight: FontWeight.w500,
        color: baseColor,
      ),
      labelSmall: TextStyle(
        fontSize: 11 * _fontSizeScale,
        fontWeight: FontWeight.w500,
        color: baseColor,
      ),
    );
  }
}
