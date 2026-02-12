import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/supabase_auth_service.dart';
import '../services/supabase_service.dart';
import '../services/local_storage_service.dart';
import '../services/user_service.dart';
import '../services/virtual_number_service.dart';
import '../services/location_service.dart';
import '../utils/random_data_generator.dart';
import '../services/follow_service.dart';

enum AuthenticationState {
  initial,
  loading,
  authenticated,
  unauthenticated,
  error,
}

class AuthStateProvider with ChangeNotifier {
  final SupabaseAuthService _authService = SupabaseAuthService();
  final SupabaseService _supabaseService = SupabaseService.instance;

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
      // Check if user is signed in via Supabase
      final user = _authService.currentUser;

      if (user != null) {
        // Try to fetch profile from Supabase
        final profile = await _supabaseService.getCurrentUserProfile();
        if (profile != null) {
          _currentUserId = profile.id;
          _setState(AuthenticationState.authenticated);

          // Ensure following Boofer Official
          FollowService.instance.ensureFollowingBoofer(profile.id);

          print('✅ User session restored successfully from Supabase');
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

  Future<void> createAnonymousUser({int? age}) async {
    _setState(AuthenticationState.loading);
    _clearError();

    User? newUser;

    try {
      // 0. Pre-generate Random Data (as demo values as requested)
      final fullName = RandomDataGenerator.generateFullName();
      final handle = RandomDataGenerator.generateHandle(fullName);
      final bio = RandomDataGenerator.generateBio();
      final demoVirtualNumber = RandomDataGenerator.generateVirtualNumber();

      // 0.1 Fetch Location from IP (no permission required)
      String? location;
      try {
        location = await LocationService.getCityStateFromIP();
      } catch (e) {
        debugPrint('⚠️ Location fetch failed: $e');
      }

      // 1. Try Supabase Auth with Metadata
      // This ensures the database trigger can pick these up immediately
      final authUser = await _authService.signInAnonymously(
        data: {
          'full_name': fullName,
          'handle': handle,
          'bio': bio,
          'virtual_number': demoVirtualNumber,
          'age': age,
          'location': location,
        },
      );

      if (authUser != null) {
        // Authenticated with Supabase

        // Generate/Assign Virtual Number (Real assignment if available)
        String? virtualNumber;
        try {
          virtualNumber = await VirtualNumberService()
              .generateAndAssignVirtualNumber(authUser.id);
        } catch (e) {
          debugPrint('⚠️ VirtualNumberService failed: $e');
        }

        // Fallback to pre-generated demo number if service fails
        virtualNumber ??= demoVirtualNumber;

        newUser = User(
          id: authUser.id,
          email: '${authUser.id}@anonymous.boofer.local',
          fullName: fullName,
          handle: handle,
          bio: bio,
          isDiscoverable: true,
          status: UserStatus.online,
          virtualNumber: virtualNumber,
          age: age,
          location: location,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Try to update/create profile on server to be sure
        try {
          await _supabaseService.createUserProfile(newUser);
        } catch (e) {
          debugPrint('⚠️ Failed to create Supabase profile: $e');
        }

        // 3. Save and Finish
        await UserService.setCurrentUser(newUser);
        _currentUserId = newUser.id;
        _setState(AuthenticationState.authenticated);

        // Ensure following Boofer Official
        FollowService.instance.ensureFollowingBoofer(newUser.id);
      } else {
        throw Exception('Failed to sign in anonymously via Supabase');
      }
    } catch (e) {
      debugPrint('❌ Anonymous auth failed: $e');
      _setError(e.toString().replaceAll('Exception: ', ''));
      // DO NOT fall back to local user - strict access restriction
    }
  }

  Future<void> signOut() async {
    _setState(AuthenticationState.loading);
    _clearError();

    try {
      try {
        // Attempt remote sign out with a timeout to prevent hanging
        await _authService.signOut().timeout(const Duration(seconds: 3));
      } catch (e) {
        debugPrint('⚠️ Remote sign out failed or timed out: $e');
        // Continue to local cleanup even if remote fails
      }

      // STRICTLY clear EVERYTHING from local storage as requested
      await LocalStorageService.clearAll();

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
}
