import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_colors.dart';

enum AppThemeMode { light, dark, system }

class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'theme_mode';
  AppThemeMode _themeMode = AppThemeMode.system;
  bool _isSystemDarkMode = false;

  AppThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == AppThemeMode.dark || 
                        (_themeMode == AppThemeMode.system && _isSystemDarkMode);
  
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

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt(_themeKey) ?? 2; // Default to system
    _themeMode = AppThemeMode.values[themeIndex];
    notifyListeners();
  }

  void _detectSystemTheme() {
    final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    _isSystemDarkMode = brightness == Brightness.dark;
    
    // Listen for system theme changes
    WidgetsBinding.instance.platformDispatcher.onPlatformBrightnessChanged = () {
      final newBrightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
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
        seedColor: AppColors.loveRose,
        brightness: Brightness.light,
        primary: AppColors.loveRose,
        secondary: AppColors.deepBlush,
        surface: AppColors.lightSurface, // #ffffff
        background: AppColors.lightBackground, // #f9f9f9
        onPrimary: Colors.white,
        onSecondary: AppColors.lightPrimaryText,
        onSurface: AppColors.lightPrimaryText,
        onBackground: AppColors.lightPrimaryText,
        outline: AppColors.lightSecondaryText,
        error: AppColors.danger,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: AppColors.lightBackground, // #f9f9f9
        foregroundColor: AppColors.lightPrimaryText,
        iconTheme: IconThemeData(color: AppColors.lightPrimaryText),
        titleTextStyle: TextStyle(
          color: AppColors.lightPrimaryText,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        selectedItemColor: AppColors.loveRose,
        unselectedItemColor: AppColors.lightSecondaryText,
        selectedLabelStyle: TextStyle(fontWeight: FontWeight.w600),
        backgroundColor: AppColors.lightSurface, // #ffffff
      ),
      cardTheme: const CardThemeData(
        color: AppColors.lightSurface, // Pure white
        elevation: 2,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      scaffoldBackgroundColor: AppColors.lightBackground, // #f9f9f9
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.loveRose,
        foregroundColor: Colors.white,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.loveRose;
          }
          return AppColors.lightSecondaryText;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.loveRose.withOpacity(0.3);
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
        seedColor: AppColors.loveRose,
        brightness: Brightness.dark,
        primary: AppColors.loveRose,
        secondary: AppColors.deepBlush,
        surface: AppColors.darkSurface, // #121212
        background: AppColors.darkBackground, // #000000
        onPrimary: Colors.white,
        onSecondary: AppColors.darkPrimaryText,
        onSurface: AppColors.darkPrimaryText,
        onBackground: AppColors.darkPrimaryText,
        outline: AppColors.darkSecondaryText,
        error: AppColors.danger,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: AppColors.darkBackground, // #000000
        foregroundColor: AppColors.darkPrimaryText,
        iconTheme: IconThemeData(color: AppColors.darkPrimaryText),
        titleTextStyle: TextStyle(
          color: AppColors.darkPrimaryText,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        selectedItemColor: AppColors.brandAccent,
        unselectedItemColor: AppColors.darkSecondaryText,
        selectedLabelStyle: TextStyle(fontWeight: FontWeight.w600),
        backgroundColor: AppColors.darkSurface, // #121212
      ),
      cardTheme: const CardThemeData(
        color: AppColors.darkSurface, // #121212
        elevation: 2,
        shadowColor: Colors.black54,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      scaffoldBackgroundColor: AppColors.darkBackground, // #000000
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.loveRose,
        foregroundColor: Colors.white,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.loveRose;
          }
          return AppColors.darkSecondaryText;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.loveRose.withOpacity(0.3);
          }
          return AppColors.darkSecondaryText.withOpacity(0.3);
        }),
      ),
    );
  }
}