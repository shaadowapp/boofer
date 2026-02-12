import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../core/database/database_manager.dart';
import '../core/error/error_handler.dart';
import '../core/models/app_error.dart';
import '../models/message_model.dart';
import 'supabase_service.dart';
import 'supabase_auth_service.dart';

/// Hybrid sync service that manages data between local SQLite and Supabase
class SyncService {
  static SyncService? _instance;
  static SyncService get instance => _instance ??= SyncService._internal();
  SyncService._internal();

  final DatabaseManager _database = DatabaseManager.instance;
  final SupabaseService _supabase = SupabaseService.instance;
  final SupabaseAuthService _auth = SupabaseAuthService();
  final ErrorHandler _errorHandler = ErrorHandler();
  final Connectivity _connectivity = Connectivity();

  bool _isOnline = false;
  bool _isSyncing = false;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  Timer? _syncTimer;

  // Sync status streams
  final StreamController<bool> _syncStatusController =
      StreamController<bool>.broadcast();
  final StreamController<String> _syncMessageController =
      StreamController<String>.broadcast();

  Stream<bool> get syncStatusStream => _syncStatusController.stream;
  Stream<String> get syncMessageStream => _syncMessageController.stream;

  /// Initialize sync service
  Future<void> initialize() async {
    try {
      // Check initial connectivity
      final connectivityResult = await _connectivity.checkConnectivity();
      _isOnline = connectivityResult != ConnectivityResult.none;

      // Listen to connectivity changes
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
        result,
      ) {
        final wasOnline = _isOnline;
        _isOnline = result != ConnectivityResult.none;

        if (!wasOnline && _isOnline) {
          // Just came online - sync data
          _performFullSync();
        }
      });

      // Set up periodic sync when online
      _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
        if (_isOnline && !_isSyncing) {
          _performIncrementalSync();
        }
      });

      // Initial sync if online
      if (_isOnline) {
        _performFullSync();
      }

      debugPrint('Sync service initialized - Online: $_isOnline');
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        AppError.service(
          message: 'Failed to initialize sync service: $e',
          stackTrace: stackTrace,
          originalException: e is Exception ? e : Exception(e.toString()),
        ),
      );
    }
  }

  /// Perform full sync (on startup or reconnection)
  Future<void> _performFullSync() async {
    if (_isSyncing || !_isOnline) return;

    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    _isSyncing = true;
    _syncStatusController.add(true);
    _syncMessageController.add('Syncing data...');

    try {
      // 1. Sync pending local messages to Supabase
      await _syncPendingMessages();

      _syncMessageController.add('Sync completed');
    } catch (e, stackTrace) {
      _syncMessageController.add('Sync failed');
      _errorHandler.handleError(
        AppError.service(
          message: 'Full sync failed: $e',
          stackTrace: stackTrace,
          originalException: e is Exception ? e : Exception(e.toString()),
        ),
      );
    } finally {
      _isSyncing = false;
      _syncStatusController.add(false);
    }
  }

  /// Perform incremental sync (periodic updates)
  Future<void> _performIncrementalSync() async {
    if (_isSyncing || !_isOnline) return;

    try {
      await _syncPendingMessages();
    } catch (e) {
      debugPrint('Incremental sync failed: $e');
    }
  }

  /// Sync pending messages to Supabase
  Future<void> _syncPendingMessages() async {
    try {
      // Get pending messages from local database
      final pendingMessages = await _database.query(
        'SELECT * FROM messages WHERE status = ? ORDER BY timestamp ASC',
        ['pending'],
      );

      for (final messageData in pendingMessages) {
        final message = Message.fromJson(messageData);

        // Send to Supabase
        final sentMessage = await _supabase.sendMessage(
          conversationId: message.conversationId!,
          senderId: message.senderId,
          receiverId: message.receiverId!,
          text: message.text,
          type: message.type,
        );

        if (sentMessage != null) {
          // Update local message status
          await _database.update(
            'messages',
            {
              'status': MessageStatus.sent.name,
              'updated_at': DateTime.now().toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [message.id],
          );
        }
      }
    } catch (e) {
      debugPrint('Pending messages sync failed: $e');
    }
  }

  /// Force sync now
  Future<void> forcSync() async {
    if (_isOnline) {
      await _performFullSync();
    }
  }

  /// Get sync status
  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;

  void dispose() {
    _connectivitySubscription?.cancel();
    _syncTimer?.cancel();
    _syncStatusController.close();
    _syncMessageController.close();
  }
}
