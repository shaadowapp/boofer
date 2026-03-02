import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/supabase_auth_service.dart';
import '../services/supabase_service.dart';
import '../services/user_service.dart';
import '../services/virtual_number_service.dart';
import '../services/location_service.dart';
import '../utils/random_data_generator.dart';
import '../services/multi_account_storage_service.dart';

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

          debugPrint('✅ User session restored successfully from Supabase');
          return;
        }
      }

      // No valid session found
      _setState(AuthenticationState.unauthenticated);
      debugPrint('ℹ️ No valid user session - onboarding required');
    } catch (e) {
      debugPrint('❌ Error checking auth state: $e');
      _setError('Failed to check authentication state: $e');
    }
  }

  Future<void> createAnonymousUser({
    String? fullName,
    String? handle,
    String? bio,
    String? avatar,
    int? age,
    String? gender,
    String? lookingFor,
    List<String>? interests,
    List<String>? hobbies,
    String? guardianId,
    String? prefetchedLocation,
  }) async {
    _setState(AuthenticationState.loading);
    _clearError();

    User? newUser;

    try {
      // 0. Pre-generate or Use provided Random Data
      final finalFullName = fullName ?? RandomDataGenerator.generateFullName();
      final finalHandle =
          handle ?? RandomDataGenerator.generateHandle(finalFullName);
      final finalBio = bio ?? RandomDataGenerator.generateBio();
      final demoVirtualNumber = RandomDataGenerator.generateVirtualNumber();

      // Get location (prefetched or fresh)
      String? location = prefetchedLocation;
      if (location == null) {
        try {
          // Timeout quickly if not prefetched to avoid blocking UI too long
          location = await LocationService.getCityStateFromIP()
              .timeout(const Duration(seconds: 2));
        } catch (e) {
          debugPrint('⚠️ Fresh location fetch failed: $e');
        }
      }
      // (This is the most critical path)
      final authUser = await _authService.signInAnonymously(
        data: {
          'full_name': finalFullName,
          'handle': finalHandle,
          'bio': finalBio,
          'virtual_number': demoVirtualNumber,
          'age': age,
          'gender': gender,
          'looking_for': lookingFor,
          'interests': interests,
          'hobbies': hobbies,
          'location': location,
        },
      );

      if (authUser == null) {
        throw Exception('Failed to sign in anonymously via Supabase');
      }

      // 2. Parallelize profile enrichment and setup
      // We do virtual number assignment and profile creation in parallel
      // and also start the 'follow' process.
      String? virtualNumber;

      debugPrint('🚀 [AUTH] Running setup tasks in parallel...');

      await Future.wait([
        // Task A: Virtual Number Assignment
        VirtualNumberService()
            .generateAndAssignVirtualNumber(authUser.id)
            .then((val) => virtualNumber = val)
            .catchError((e) {
          debugPrint('⚠️ VirtualNumberService failed: $e');
          return null;
        }),

        // Task B: Profile Record Creation on Supabase
        Future(() async {
          final tempUser = User(
            id: authUser.id,
            email: '${authUser.id}@anonymous.boofer.local',
            fullName: finalFullName,
            handle: finalHandle,
            bio: finalBio,
            isDiscoverable: true,
            status: UserStatus.online,
            virtualNumber:
                demoVirtualNumber, // Temporary, will be updated locally later
            age: age,
            gender: gender,
            lookingFor: lookingFor,
            interests: interests ?? [],
            hobbies: hobbies ?? [],
            avatar: avatar ?? RandomDataGenerator.generateAvatar(),
            location: location,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            guardianId: guardianId,
          );

          try {
            await _supabaseService.createUserProfile(tempUser);
          } catch (e) {
            debugPrint('⚠️ Failed to create Supabase profile: $e');
          }
        }),
      ]);

      virtualNumber ??= demoVirtualNumber;

      newUser = User(
        id: authUser.id,
        email: '${authUser.id}@anonymous.boofer.local',
        fullName: finalFullName,
        handle: finalHandle,
        bio: finalBio,
        isDiscoverable: true,
        status: UserStatus.online,
        virtualNumber: virtualNumber,
        age: age,
        gender: gender,
        lookingFor: lookingFor,
        interests: interests ?? [],
        hobbies: hobbies ?? [],
        avatar: avatar ?? RandomDataGenerator.generateAvatar(),
        location: location,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        guardianId: guardianId,
      );

      // 3. Save and Finish
      await UserService.setCurrentUser(newUser);
      _currentUserId = newUser.id;
      _setState(AuthenticationState.authenticated);

      // Save to multi-account storage
      final session = _authService.currentSession;
      await MultiAccountStorageService.upsertAccount(
        id: newUser.id,
        handle: newUser.handle,
        fullName: newUser.fullName,
        avatar: newUser.avatar,
        supabaseSession: session != null ? jsonEncode(session.toJson()) : null,
        guardianId: guardianId,
        isPrimary: guardianId == null, // Primary if no guardian
      );
      await MultiAccountStorageService.setLastActiveAccountId(newUser.id);
    } catch (e) {
      debugPrint('❌ Anonymous auth failed: $e');
      _setError(e.toString().replaceAll('Exception: ', ''));
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

      // Clear only the current session and last active ID, NOT the entire local storage
      // so other profiles remain available in the chooser.
      await MultiAccountStorageService.setLastActiveAccountId('');

      _currentUserId = null;
      _setState(AuthenticationState.unauthenticated);
    } catch (e) {
      _setError('Sign-out failed: $e');
    }
  }

  Future<void> switchAccount(String accountId) async {
    _setState(AuthenticationState.loading);
    try {
      final sessionJson = await MultiAccountStorageService.getSession(
        accountId,
      );
      if (sessionJson == null) {
        throw Exception('No saved session found for this account');
      }

      await _authService.recoverSession(sessionJson);

      final profile = await _supabaseService.getUserProfile(accountId);
      if (profile == null) {
        throw Exception('Profile not found for this account');
      }

      await UserService.setCurrentUser(profile);
      await MultiAccountStorageService.setLastActiveAccountId(accountId);

      _currentUserId = accountId;
      _setState(AuthenticationState.authenticated);
    } catch (e) {
      debugPrint('❌ Switch account failed: $e');
      _setError('Switch account failed: $e');
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
