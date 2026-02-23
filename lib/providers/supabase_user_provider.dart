import 'dart:async';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/supabase_service.dart';
import '../services/profile_picture_service.dart';

/// Provider that manages real user data from Supabase
class SupabaseUserProvider with ChangeNotifier {
  final SupabaseService _supabaseService = SupabaseService.instance;

  User? _currentUser;
  List<User> _allUsers = [];
  bool _isLoading = false;
  String? _error;

  // Getters
  User? get currentUser => _currentUser;
  List<User> get allUsers => _allUsers;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasCurrentUser => _currentUser != null;

  /// Initialize the provider and load user data
  Future<void> initialize() async {
    try {
      _setLoading(true);

      // Initialize profile picture service
      await ProfilePictureService.instance.initialize();

      // Get current user from Supabase
      await refreshCurrentUser();

      _setLoading(false);
      debugPrint('✅ SupabaseUserProvider initialized successfully');
    } catch (e) {
      _setError('Failed to initialize user provider: $e');
      debugPrint('❌ SupabaseUserProvider initialization failed: $e');
    }
  }

  /// Refresh current user data from Supabase
  Future<void> refreshCurrentUser() async {
    try {
      final user = await _supabaseService.getCurrentUserProfile();
      if (user != null) {
        _currentUser = user;

        // Update profile picture service
        await ProfilePictureService.instance.updateProfilePicture(
          _currentUser!.profilePicture,
        );

        notifyListeners();
        debugPrint('✅ Current user loaded from Supabase: ${_currentUser!.fullName}');
      }
    } catch (e) {
      debugPrint('❌ Failed to refresh current user from Supabase: $e');
    }
  }

  /// Update current user profile in Supabase
  Future<bool> updateCurrentUser({
    String? fullName,
    String? handle,
    String? bio,
    String? profilePicture,
    bool? isDiscoverable,
  }) async {
    if (_currentUser == null) return false;

    try {
      _setLoading(true);

      final updatedUser = _currentUser!.copyWith(
        fullName: fullName ?? _currentUser!.fullName,
        handle: handle ?? _currentUser!.handle,
        bio: bio ?? _currentUser!.bio,
        profilePicture: profilePicture ?? _currentUser!.profilePicture,
        isDiscoverable: isDiscoverable ?? _currentUser!.isDiscoverable,
        updatedAt: DateTime.now(),
      );

      final result = await _supabaseService.createUserProfile(updatedUser);

      if (result != null) {
        _currentUser = result;
        if (profilePicture != null) {
          await ProfilePictureService.instance.updateProfilePicture(
            profilePicture,
          );
        }
        notifyListeners();
        _setLoading(false);
        return true;
      }

      _setLoading(false);
      return false;
    } catch (e) {
      _setError('Failed to update user profile: $e');
      return false;
    }
  }

  /// Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// Set error state
  void _setError(String error) {
    _error = error;
    _isLoading = false;
    notifyListeners();
    debugPrint('❌ SupabaseUserProvider error: $error');
  }
}
