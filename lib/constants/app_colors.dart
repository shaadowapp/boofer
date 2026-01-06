import 'package:flutter/material.dart';

/// App color constants based on the updated neutral palette with strategic brand accent usage
class AppColors {
  // Primary Brand Colors - Intimate & Secure
  static const Color loveRose = Color(0xFFFF6B9D); // Warm pink - main brand color for romance
  static const Color deepBlush = Color(0xFFE91E63); // Deeper pink - accents and highlights
  static const Color trustBlue = Color(0xFF2196F3); // Security blue - privacy indicators
  static const Color secretGreen = Color(0xFF00C853); // Encrypted green - secure status
  
  // Light Mode Colors - Clean & Minimal Theme
  static const Color lightBackground = Color(0xFFF9F9F9); // Very light grey background
  static const Color lightSurface = Color(0xFFFFFFFF); // Pure white surfaces
  static const Color lightSearchBar = Color(0xFFF5F5F5); // Soft grey search
  static const Color lightSenderBubble = Color(0xFFFFE0E6); // Light rose - your messages
  static const Color lightReceiverBubble = Color(0xFFF0F0F0); // Soft grey - partner's messages
  static const Color lightPrimaryText = Color(0xFF2C2C2C); // Warm dark grey
  static const Color lightSecondaryText = Color(0xFF757575); // Medium grey for timestamps
  
  // Dark Mode Colors - Pure Dark Theme
  static const Color darkBackground = Color(0xFF000000); // Pure black background
  static const Color darkSurface = Color(0xFF121212); // Dark grey surfaces
  static const Color darkSearchBar = Color(0xFF2C2C2C); // Search bar background
  static const Color darkSenderBubble = Color(0xFF4A1942); // Deep rose - your messages
  static const Color darkReceiverBubble = Color(0xFF2C2C2C); // Dark grey - partner's messages
  static const Color darkPrimaryText = Color(0xFFFFFFFF); // Pure white text
  static const Color darkSecondaryText = Color(0xFFB0B0B0); // Light grey for timestamps
  
  // Status & Feature Colors
  static const Color onlineStatus = secretGreen; // Green for online/active
  static const Color encryptedStatus = trustBlue; // Blue for encrypted messages
  static const Color heartReaction = loveRose; // Pink for likes/hearts
  static const Color disappearingMessage = Color(0xFFFF9800); // Orange for disappearing messages
  
  // Privacy & Security Indicators
  static const Color privateMode = Color(0xFF6A1B9A); // Deep purple for private mode
  static const Color secureConnection = trustBlue; // Blue for secure connection
  static const Color biometricLock = Color(0xFF4CAF50); // Green for biometric security
  
  // Floating Action Button - Heart-themed
  static Color floatingActionButton(bool isDark) => isDark ? deepBlush : loveRose;
  static Color floatingActionButtonIcon(bool isDark) => Colors.white;
  
  // Alert/Status Colors
  static const Color danger = Color(0xFFE53935); // Red for errors
  static const Color warning = Color(0xFFFF9800); // Orange for warnings
  static const Color success = secretGreen; // Green for success
  static const Color info = trustBlue; // Blue for info messages
  
  // Legacy aliases for backward compatibility (deprecated)
  @deprecated
  static const Color electricOrchid = loveRose;
  @deprecated
  static const Color brandAccent = loveRose;
  @deprecated
  static const Color neonMint = secretGreen;
  @deprecated
  static const Color securityAccent = trustBlue;
  @deprecated
  static const Color securityAccentDark = trustBlue;
  
  // Context-aware color getters
  static Color scaffoldBackground(bool isDark) => isDark ? darkBackground : lightBackground;
  static Color headerBackground(bool isDark) => isDark ? darkSurface : lightSurface;
  static Color searchBarColor(bool isDark) => isDark ? darkSearchBar : lightSearchBar;
  static Color primaryText(bool isDark) => isDark ? darkPrimaryText : lightPrimaryText;
  static Color senderBubble(bool isDark) => isDark ? darkSenderBubble : lightSenderBubble;
  static Color receiverBubble(bool isDark) => isDark ? darkReceiverBubble : lightReceiverBubble;
  
  // Utility Methods
  static Color withOpacity(Color color, double opacity) {
    return color.withOpacity(opacity);
  }
  
  static Color blend(Color color1, Color color2, double ratio) {
    return Color.lerp(color1, color2, ratio) ?? color1;
  }
}

/// Extension to add convenience methods to Color class
extension AppColorExtensions on Color {
  /// Returns appropriate text color for this background
  Color get contrastingTextColor {
    final luminance = computeLuminance();
    return luminance > 0.5 
        ? AppColors.lightPrimaryText 
        : AppColors.darkPrimaryText;
  }
  
  /// Creates a romantic accent overlay for interactive elements
  Color get withRomanticAccent => Color.lerp(this, AppColors.loveRose, 0.1) ?? this;
  
  /// Creates a secure trust overlay for privacy elements
  Color get withTrustAccent => Color.lerp(this, AppColors.trustBlue, 0.1) ?? this;
  
  /// Creates a warm glow effect for intimate features
  Color get withWarmGlow => Color.lerp(this, AppColors.deepBlush, 0.15) ?? this;
}