import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/google_auth_service.dart';

enum AuthenticationState {
  initial,
  loading,
  authenticated,
  unauthenticated,
  error,
}

class AuthStateProvider with ChangeNotifier {
  final GoogleAuthService _googleAuthService = GoogleAuthService();
  
  AuthenticationState _state = AuthenticationState.initial;
  User? _currentUser;
  String? _errorMessage;
  StreamSubscription<User?>? _authSubscription;
  
  AuthenticationState get state => _state;
  User? get currentUser => _currentUser;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _state == AuthenticationState.authenticated;
  bool get isLoading => _state == AuthenticationState.loading;
  
  AuthStateProvider() {
    _initializeAuthState();
  }
  
  void _initializeAuthState() {
    // Listen to Firebase auth state changes
    _authSubscription = _googleAuthService.authStateChanges.listen(
      (User? user) {
        _currentUser = user;
        if (user != null) {
          _setState(AuthenticationState.authenticated);
        } else {
          _setState(AuthenticationState.unauthenticated);
        }
      },
      onError: (error) {
        _setError('Authentication state error: $error');
      },
    );
    
    // Check initial auth state
    _checkInitialAuthState();
  }
  
  Future<void> _checkInitialAuthState() async {
    _setState(AuthenticationState.loading);
    
    try {
      // First check if Firebase user exists (automatic persistence)
      final firebaseUser = _googleAuthService.currentFirebaseUser;
      if (firebaseUser != null) {
        _currentUser = firebaseUser;
        _setState(AuthenticationState.authenticated);
        print('✅ Firebase user found - auto-login successful');
        return;
      }
      
      // Fallback: check local storage and try to restore session
      final restoredUser = await _googleAuthService.restoreUserSession();
      if (restoredUser != null) {
        // We have local user data, but need to verify Firebase auth
        final isSignedIn = await _googleAuthService.isSignedIn();
        if (isSignedIn) {
          _currentUser = _googleAuthService.currentFirebaseUser;
          _setState(AuthenticationState.authenticated);
          print('✅ User session restored successfully');
          return;
        }
      }
      
      // No valid session found
      _setState(AuthenticationState.unauthenticated);
      print('ℹ️ No valid user session - login required');
    } catch (e) {
      print('❌ Error checking auth state: $e');
      _setError('Failed to check authentication state: $e');
    }
  }
  
  Future<void> signInWithGoogle() async {
    _setState(AuthenticationState.loading);
    _clearError();
    
    try {
      final user = await _googleAuthService.signInWithGoogle();
      if (user != null) {
        _currentUser = user;
        _setState(AuthenticationState.authenticated);
      } else {
        // User cancelled sign-in
        _setState(AuthenticationState.unauthenticated);
      }
    } catch (e) {
      _setError('Google sign-in failed: $e');
    }
  }
  
  Future<void> signOut() async {
    _setState(AuthenticationState.loading);
    _clearError();
    
    try {
      await _googleAuthService.signOut();
      _currentUser = null;
      _setState(AuthenticationState.unauthenticated);
    } catch (e) {
      _setError('Sign-out failed: $e');
    }
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
    if (_currentUser != null) {
      _setState(AuthenticationState.authenticated);
    } else {
      _setState(AuthenticationState.unauthenticated);
    }
  }
  
  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}