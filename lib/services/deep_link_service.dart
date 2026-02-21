import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../main.dart';
import '../screens/select_friends_screen.dart';

class DeepLinkService {
  static final DeepLinkService instance = DeepLinkService._internal();
  DeepLinkService._internal();

  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  void initialize() {
    // Handle opening the app from a cold start
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) {
        _handleDeepLink(uri);
      }
    });

    // Handle opening the app from the background
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    });
  }

  void dispose() {
    _linkSubscription?.cancel();
  }

  Future<void> _handleDeepLink(Uri uri) async {
    debugPrint('🔗 Handling Deep Link: $uri');

    // Check for boofer:// or https://boofer.chat redirects
    if (uri.scheme != 'boofer' && !uri.toString().contains('boofer.chat'))
      return;

    // boofer://send?phone=[virtual_number]&text=[message]
    // OR boofer://send?text=[message]
    if (uri.path.contains('send') || (uri.host == 'send')) {
      final phone = uri.queryParameters['phone'];
      final text = uri.queryParameters['text'];

      if (text == null || text.isEmpty) {
        debugPrint('⚠️ Deep Link: Mandatory "text" parameter is missing');
        return;
      }

      if (phone != null && phone.isNotEmpty) {
        // Find user by virtual number
        final user = await SupabaseService.instance.getUserByVirtualNumber(
          phone,
        );
        if (user != null) {
          // Open chat screen with specific user
          BooferApp.navigatorKey.currentState?.pushNamed(
            '/chat',
            arguments: {
              'recipientId': user.id,
              'recipientName': user.fullName,
              'recipientHandle': user.handle,
              'recipientAvatar': user.profilePicture,
              'recipientProfilePicture': user.profilePicture,
              'initialText': text,
            },
          );
        } else {
          // Fallback to general share if user not found? Or show error.
          debugPrint('⚠️ Deep Link: User with number $phone not found');
          _showError('User not found on Boofer');
        }
      } else {
        // Universal sharing style via URI: show select friends screen
        _navigateToSelectFriends(text);
      }
    }
  }

  void _showError(String message) {
    final context = BooferApp.navigatorKey.currentContext;
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
    }
  }

  void _navigateToSelectFriends(String text) {
    BooferApp.navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (context) => SelectFriendsScreen(sharedText: text),
      ),
    );
  }
}
