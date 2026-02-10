import 'dart:async';
import 'package:flutter/material.dart';
import '../services/anonymous_auth_service.dart';
import '../services/local_storage_service.dart';

enum AuthenticationState {
  initial,
  loading,
  authenticated,
  unauthenticated,
  error,
}

class AuthStateProvider with ChangeNotifier {
  final AnonymousAuthService _anonymousAuthService = AnonymousAuthService();
  
  AuthenticationState _state = AuthenticationState.initial;
  String? _currentUserId;
  String? _errorMessage;
  
  AuthenticationState get state => _state;
  String? get currentUserId => _currentUserId;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _state == AuthenticationState.authenticated;
  bool get isLoading => _state == AuthenticationState.loading;
  
  AuthStateProvider() {
    _initializeAuthState();
  }
  
  void _initializeAuthState() {
    // Check initial auth state
    _checkInitialAuthState();
  }
  
  Future<void> _checkInitialAuthState() async {
    _setState(AuthenticationState.loading);
    
    try {
      // Check if user is signed in (has local user ID)
      final isSignedIn = await _anonymousAuthService.isSignedIn();
      
      if (isSignedIn) {
        // Try to restore user session
        final restoredUser = await _anonymousAuthService.restoreUserSession();
        if (restoredUser != null) {
          _currentUserId = restoredUser.id;
          _setState(AuthenticationState.authenticated);
          print('✅ User session restored successfully');
          return;
        }
      }
      
      // No valid session found
      _setState(AuthenticationState.unauthenticated);
      print('ℹ️ No valid user session - onboarding required');
    } catch (e) {
      print('❌ Error checking auth state: $e');
      _setError('Failed to check authentication state: $e');
    }
  }
  
  Future<void> createAnonymousUser() async {
    _setState(AuthenticationState.loading);
    _clearError();
    
    try {
      final user = await _anonymousAuthService.createAnonymousUser();
      if (user != null) {
        _currentUserId = user.id;
        _setState(AuthenticationState.authenticated);
      } else {
        _setError('Failed to create anonymous user');
      }
    } catch (e) {
      _setError('Anonymous user creation failed: $e');
    }
  }
  
  Future<void> signOut() async {
    _setState(AuthenticationState.loading);
    _clearError();
    
    try {
      await _anonymousAuthService.signOut();
      _currentUserId = null;
      _setState(AuthenticationState.unauthenticated);
    } catch (e) {
      _setError('Sign-out failed: $e');
    }
  }
  
  Future<void> checkAuthState() async {
    await _checkInitialAuthState();
  }
  
  void _setState(AuthenticationState newState) {
    if (_state != newState) {
      _state = newState;
      notifyListeners();
    }
  }
  
  void _setError(String error) {
    _errorMessage = error;
    _setState(AuthenticationState.error);
  }
  
  void _clearError() {
    _errorMessage = null;
  }
  
  void clearError() {
    _clearError();
    if (_currentUserId != null) {
      _setState(AuthenticationState.authenticated);
    } else {
      _setState(AuthenticationState.unauthenticated);
    }
  }
  
  @override
  void dispose() {
    super.dispose();
  }
}