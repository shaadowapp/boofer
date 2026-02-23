import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../models/user_model.dart';
import '../core/error/error_handler.dart';
import '../core/models/app_error.dart';

class UserProfileSyncService {
  sb.SupabaseClient get _supabase => sb.Supabase.instance.client;
  final ErrorHandler _errorHandler = ErrorHandler();

  Future<bool> syncUserProfile(
    User user, {
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      // Check if we have a valid Supabase session
      if (_supabase.auth.currentUser == null) {
        // We can't sync if we aren't logged in to Supabase
        // But we should return true to allow local flow to continue
        // The data will be synced later when connection is restored
        debugPrint('⚠️ Skipping Supabase sync: No active session');
        return true;
      }

      final userData = user.toDatabaseJson();
      if (additionalData != null) {
        userData.addAll(additionalData);
      }

      // Ensure ID matches the authenticated user
      userData['id'] = _supabase.auth.currentUser!.id;

      await _supabase.from('profiles').upsert(userData).select();

      return true;
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        AppError.service(
          message: 'Failed to sync user profile: $e',
          stackTrace: stackTrace,
          originalException: e is Exception ? e : Exception(e.toString()),
        ),
      );
      return false;
    }
  }
}
