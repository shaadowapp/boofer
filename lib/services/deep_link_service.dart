import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import '../screens/user_profile_screen.dart';
import '../screens/friend_chat_screen.dart';
import '../services/user_service.dart';
import '../services/supabase_service.dart';
import '../models/user_model.dart';

class DeepLinkService {
  static final DeepLinkService instance = DeepLinkService._internal();
  DeepLinkService._internal();

  final _appLinks = AppLinks();
  late final GlobalKey<NavigatorState> _navigatorKey;

  void init(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;
    
    debugPrint('🔗 [DeepLink] Service Initialized');

    // Handle deep links when app is running
    _appLinks.uriLinkStream.listen((uri) {
      _handleUri(uri);
    });

    // Handle initial link if app was closed
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) {
        debugPrint('🔗 [DeepLink] Initial Link Detected: $uri');
        // Delay slightly for UI to settle
        Future.delayed(const Duration(seconds: 1), () => _handleUri(uri));
      }
    });
  }

  void _handleUri(Uri uri) async {
    debugPrint('🔗 [DeepLink] Processing URI: $uri');
    
    String scheme = uri.scheme;
    String host = uri.host ?? '';
    String path = uri.path;

    if (path.endsWith('/')) path = path.substring(0, path.length - 1);

    // --- 1. HANDLE PROFILE ---
    bool isProfileLink = path.startsWith('/@') || (scheme == 'boofer' && !path.startsWith('/chat'));
    
    if (isProfileLink) {
      String handle = '';
      if (path.startsWith('/@')) {
        handle = path.substring(2);
      } else if (scheme == 'boofer') {
        handle = host.startsWith('@') ? host.substring(1) : host;
      }
      
      if (handle.isNotEmpty) {
        debugPrint('🔗 [DeepLink] Routing to Profile: @$handle');
        _navigateToProfileByHandle(handle);
        return;
      }
    }

    // --- 2. HANDLE CHAT ---
    if (path.startsWith('/chat/') || host == 'chat') {
      String identifier = '';
      if (scheme == 'boofer' && host == 'chat') {
        identifier = path.startsWith('/') ? path.substring(1) : path;
      } else if (path.startsWith('/chat/')) {
        identifier = path.substring(6);
      }

      if (identifier.isNotEmpty) {
        debugPrint('🔗 [DeepLink] Routing to Chat: $identifier');
        if (identifier.startsWith('@')) {
          _navigateToChatByHandle(identifier.substring(1));
        } else {
          _navigateToChatByNumber(identifier);
        }
        return;
      }
    }
  }

  void _navigateToProfileByHandle(String handle) async {
    User? user = await UserService.instance.getUserByHandle(handle);
    if (user == null) {
      user = await SupabaseService.instance.getUserByHandle(handle);
      if (user != null) await UserService.instance.insertUser(user);
    }

    if (user != null) {
      final String userId = user.id; // Type promotion to non-nullable
      _pushRoute(MaterialPageRoute(builder: (context) => UserProfileScreen(userId: userId)));
    } else {
      debugPrint('❌ [DeepLink] User @$handle not found globally');
    }
  }

  void _navigateToChatByHandle(String handle) async {
    User? user = await UserService.instance.getUserByHandle(handle);
    if (user == null) {
      user = await SupabaseService.instance.getUserByHandle(handle);
      if (user != null) await UserService.instance.insertUser(user);
    }

    if (user != null) {
      _pushChat(user);
    } else {
      debugPrint('❌ [DeepLink] Chat handle $handle not found globally');
    }
  }

  void _navigateToChatByNumber(String number) async {
    User? user = await UserService.instance.getUserByVirtualNumber(number);
    if (user == null) {
      user = await SupabaseService.instance.getUserByVirtualNumber(number);
      if (user != null) await UserService.instance.insertUser(user);
    }

    if (user != null) {
      _pushChat(user);
    } else {
      debugPrint('❌ [DeepLink] No user found for number: $number');
    }
  }

  void _pushChat(User user) {
    // Capture data in local variables to avoid closure null-safety issues
    final String rId = user.id;
    final String rName = user.fullName;
    final String? rHandle = user.handle;
    final String? rAvatar = user.avatar;
    final String? rPic = user.profilePicture;
    final String? vNum = user.virtualNumber;

    _pushRoute(MaterialPageRoute(
      builder: (context) => FriendChatScreen(
        recipientId: rId,
        recipientName: rName,
        recipientHandle: rHandle,
        recipientAvatar: rAvatar,
        recipientProfilePicture: rPic,
        virtualNumber: vNum,
      ),
    ));
  }

  void _pushRoute(Route route) {
    if (_navigatorKey.currentState != null) {
      debugPrint('🚀 [DeepLink] Pushing Route');
      _navigatorKey.currentState!.push(route);
    } else {
      debugPrint('❌ [DeepLink] Navigator NULL. Retrying...');
      Future.delayed(const Duration(milliseconds: 500), () => _pushRoute(route));
    }
  }
}
