import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SvgIcons {
  // Base path for SVG icons
  static const String _basePath = 'assets/icons/';
  
  // Navigation icons (with filled/outlined variants)
  static const String homeOutlined = 'home_outlined.svg';
  static const String homeFilled = 'home_filled.svg';
  static const String chatOutlined = 'chat_outlined.svg';
  static const String chatFilled = 'chat_filled.svg';
  static const String callOutlined = 'call_outlined.svg';
  static const String callFilled = 'call_filled.svg';
  
  // Action icons
  static const String addCall = 'add_call.svg';
  static const String addUser = 'add_user.svg';
  static const String addChat = 'add_chat_fab.svg';
  static const String dialpad = 'dialpad.svg';
  static const String sendMessage = 'send_message.svg';
  
  // Call type icons
  static const String voiceCall = 'voice_call.svg';
  static const String videoCall = 'video_call.svg';
  
  // Theme icons
  static const String lightMode = 'light_mode.svg';
  static const String darkMode = 'dark_mode.svg';
  
  // Menu and navigation
  static const String moreHorizontal = 'more_horizontal.svg';
  static const String moreVertical = 'more_vertical.svg';
  
  // User and settings
  static const String profile = 'profile.svg';
  static const String settings = 'settings.svg';
  static const String help = 'help.svg';
  static const String info = 'info.svg';
  static const String search = 'search.svg';
  static const String notification = 'notification.svg';
  static const String privacy = 'privacy.svg';
  
  // Additional icons
  static const String add = 'add.svg';
  static const String clear = 'clear.svg';
  static const String backspace = 'backspace.svg';
  static const String peopleOutline = 'people_outline.svg';
  static const String searchOff = 'search_off.svg';
  static const String callReceived = 'call_received.svg';
  static const String callMade = 'call_made.svg';
  static const String palette = 'palette.svg';
  static const String chatBubbleRounded = 'chat_bubble_rounded.svg';
  static const String edit = 'edit.svg';
  static const String phone = 'phone.svg';
  static const String storage = 'storage.svg';
  
  // Helper method to create SvgPicture widget
  static Widget icon(
    String iconName, {
    double? width,
    double? height,
    Color? color,
    BoxFit fit = BoxFit.contain,
  }) {
    return SvgPicture.asset(
      '$_basePath$iconName',
      width: width,
      height: height,
      colorFilter: color != null 
          ? ColorFilter.mode(color, BlendMode.srcIn)
          : null,
      fit: fit,
    );
  }
  
  // Convenience methods for common sizes
  static Widget small(String iconName, {Color? color}) {
    return icon(iconName, width: 16, height: 16, color: color);
  }
  
  static Widget medium(String iconName, {Color? color}) {
    return icon(iconName, width: 24, height: 24, color: color);
  }
  
  static Widget large(String iconName, {Color? color}) {
    return icon(iconName, width: 32, height: 32, color: color);
  }
  
  // Custom sized icon
  static Widget sized(String iconName, double size, {Color? color}) {
    return icon(iconName, width: size, height: size, color: color);
  }
  
  // Specific icon methods for better code readability with theme awareness
  static Widget home({bool filled = false, double? size, Color? color, BuildContext? context}) {
    final iconColor = color ?? (context != null ? Theme.of(context).colorScheme.onSurface : null);
    return sized(filled ? homeFilled : homeOutlined, size ?? 24, color: iconColor);
  }
  
  static Widget chat({bool filled = false, double? size, Color? color, BuildContext? context}) {
    final iconColor = color ?? (context != null ? Theme.of(context).colorScheme.onSurface : null);
    return sized(filled ? chatFilled : chatOutlined, size ?? 24, color: iconColor);
  }
  
  static Widget call({bool filled = false, double? size, Color? color, BuildContext? context}) {
    final iconColor = color ?? (context != null ? Theme.of(context).colorScheme.onSurface : null);
    return sized(filled ? callFilled : callOutlined, size ?? 24, color: iconColor);
  }
  
  static Widget theme({bool isDark = false, double? size, Color? color}) {
    return sized(isDark ? lightMode : darkMode, size ?? 24, color: color);
  }
  
  static Widget more({bool horizontal = false, double? size, Color? color, BuildContext? context}) {
    final iconColor = color ?? (context != null ? Theme.of(context).colorScheme.onSurface : null);
    return sized(horizontal ? moreHorizontal : moreVertical, size ?? 24, color: iconColor);
  }
}

// Extension to make it even easier to use
extension SvgIconExtension on String {
  Widget toSvgIcon({
    double? width,
    double? height,
    Color? color,
    BoxFit fit = BoxFit.contain,
  }) {
    return SvgIcons.icon(this, width: width, height: height, color: color, fit: fit);
  }
  
  Widget toSmallSvgIcon({Color? color}) => SvgIcons.small(this, color: color);
  Widget toMediumSvgIcon({Color? color}) => SvgIcons.medium(this, color: color);
  Widget toLargeSvgIcon({Color? color}) => SvgIcons.large(this, color: color);
}