import 'dart:async';
import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import '../screens/select_friends_screen.dart';

class ReceiveShareService {
  static final ReceiveShareService _instance = ReceiveShareService._internal();
  static ReceiveShareService get instance => _instance;

  StreamSubscription? _mediaSubscription;
  GlobalKey<NavigatorState>? _navigatorKey;

  // Cache to store shared content received before initialization
  List<SharedMediaFile>? _pendingMedia;

  ReceiveShareService._internal();

  /// Initialize the service with a navigator key for navigation
  void init(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;
    debugPrint('🚀 ReceiveShareService: Initializing...');

    // Cancel existing subscription if any
    _mediaSubscription?.cancel();

    // 1. Handle sharing while app is IN MEMORY
    _mediaSubscription = ReceiveSharingIntent.instance.getMediaStream().listen(
      (List<SharedMediaFile> value) {
        debugPrint(
          '🚀 ReceiveShareService: Stream Received ${value.length} items',
        );
        _handleMediaContent(value);
      },
      onError: (err) {
        debugPrint('❌ ReceiveShareService: getMediaStream error: $err');
      },
    );

    // 2. Handle COLD START (App closed)
    ReceiveSharingIntent.instance.getInitialMedia().then((
      List<SharedMediaFile> value,
    ) {
      if (value.isNotEmpty) {
        debugPrint(
          '🚀 ReceiveShareService: Initial Received ${value.length} items',
        );
        _handleMediaContent(value);
      }
    });

    // 3. Check for pending media captured via checkInitialShare
    if (_pendingMedia != null && _pendingMedia!.isNotEmpty) {
      debugPrint(
        '🚀 ReceiveShareService: Processing ${_pendingMedia!.length} PENDING items',
      );
      _handleMediaContent(_pendingMedia!);
      _pendingMedia = null;
    }
  }

  /// NEW: Static method to check for initial share as early as possible (before init)
  Future<void> checkInitialShare() async {
    try {
      final initialMedia = await ReceiveSharingIntent.instance
          .getInitialMedia();
      if (initialMedia.isNotEmpty) {
        debugPrint(
          '🚀 ReceiveShareService: PRE-INITIAL Captured ${initialMedia.length} items',
        );
        _pendingMedia = initialMedia;
      }
    } catch (e) {
      debugPrint('❌ ReceiveShareService: Error in checkInitialShare: $e');
    }
  }

  void dispose() {
    _mediaSubscription?.cancel();
  }

  void _handleMediaContent(List<SharedMediaFile> media) {
    if (media.isEmpty) return;

    debugPrint('📦 Processing ${media.length} shared items...');

    String? sharedText;
    final List<String> sharedFiles = [];

    for (var item in media) {
      debugPrint('📄 Item: ${item.type} - Path: ${item.path}');

      // 🛡️ SECURITY: Ignore Boofer's own deep links so DeepLinkService can handle them
      if (item.path.contains('booferapp.github.io') || 
          item.path.startsWith('boofer://')) {
        debugPrint('🚫 ReceiveShareService: Ignoring Boofer Deep Link path: ${item.path}');
        continue;
      }

      if (item.type == SharedMediaType.text ||
          item.type == SharedMediaType.url) {
        sharedText = (sharedText == null)
            ? item.path
            : '$sharedText\n${item.path}';
      } else {
        sharedFiles.add(item.path);
      }
    }

    if (sharedText != null || sharedFiles.isNotEmpty) _navigateToSelection(sharedText, sharedFiles);
  }

  void _navigateToSelection(String? text, List<String> files) {
    // If navigator state is not ready yet, retry after a short delay
    if (_navigatorKey == null || _navigatorKey!.currentState == null) {
      debugPrint(
        '❌ ReceiveShareService: Navigator state is NULL, retrying in 500ms...',
      );
      Future.delayed(
        const Duration(milliseconds: 500),
        () => _navigateToSelection(text, files),
      );
      return;
    }

    debugPrint('🎯 Navigating to SelectFriendsScreen...');

    _navigatorKey!.currentState!.push(
      MaterialPageRoute(
        builder: (context) => SelectFriendsScreen(
          sharedText: text,
          sharedFiles: files.isNotEmpty ? files : null,
        ),
      ),
    );
  }
}
