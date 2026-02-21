import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

class SupabaseAuthService {
  static final SupabaseAuthService _instance = SupabaseAuthService._internal();
  factory SupabaseAuthService() => _instance;
  SupabaseAuthService._internal();

  final sb.SupabaseClient _supabase = sb.Supabase.instance.client;

  /// Sign in anonymously via Supabase
  Future<sb.User?> signInAnonymously({Map<String, dynamic>? data}) async {
    try {
      final sb.AuthResponse res = await _supabase.auth.signInAnonymously(
        data: data,
      );

      return res.user;
    } catch (e) {
      debugPrint('❌ Error signing in anonymously via Supabase: $e');
      return null;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      debugPrint('❌ Error signing out from Supabase: $e');
      rethrow;
    }
  }

  /// Restore session
  sb.Session? get currentSession => _supabase.auth.currentSession;
  sb.User? get currentUser => _supabase.auth.currentUser;
  Stream<sb.AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  bool get isAuthenticated => _supabase.auth.currentSession != null;

  /// Recover session from JSON string
  Future<void> recoverSession(String sessionJson) async {
    try {
      await _supabase.auth.recoverSession(sessionJson);
    } catch (e) {
      debugPrint('❌ Error recovering session: $e');
      rethrow;
    }
  }
}
