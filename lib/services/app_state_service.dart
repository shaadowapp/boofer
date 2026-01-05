import '../models/onboarding_data.dart';
import 'local_storage_service.dart';

/// Service to manage app state and user session
class AppStateService {
  static AppStateService? _instance;
  static AppStateService get instance => _instance ??= AppStateService._internal();
  AppStateService._internal();

  OnboardingData? _currentUser;
  bool _isInitialized = false;

  /// Get current user data
  OnboardingData? get currentUser => _currentUser;

  /// Check if app is initialized
  bool get isInitialized => _isInitialized;

  /// Check if user is logged in (has completed onboarding)
  bool get isUserLoggedIn => _currentUser != null && _currentUser!.completed;

  /// Initialize app state from local storage
  Future<bool> initialize() async {
    try {
      final isOnboardingCompleted = await LocalStorageService.isOnboardingCompleted();
      
      if (isOnboardingCompleted) {
        _currentUser = await LocalStorageService.getOnboardingData();
      }
      
      _isInitialized = true;
      return isOnboardingCompleted;
    } catch (e) {
      _isInitialized = true;
      return false;
    }
  }

  /// Set current user after onboarding completion
  void setCurrentUser(OnboardingData userData) {
    _currentUser = userData;
  }

  /// Clear user session (for logout or reset)
  Future<void> clearUserSession() async {
    try {
      await LocalStorageService.clearOnboardingData();
      _currentUser = null;
    } catch (e) {
      throw Exception('Failed to clear user session: $e');
    }
  }

  /// Get user display name
  String get userDisplayName => _currentUser?.userName ?? 'User';

  /// Get user virtual number
  String get userVirtualNumber => _currentUser?.virtualNumber ?? '';

  /// Check if user has PIN set
  bool get hasPinSet => _currentUser?.pin != null && _currentUser!.pin!.isNotEmpty;

  /// Validate user PIN
  Future<bool> validateUserPin(String pin) async {
    if (_currentUser?.pin == null) return false;
    return _currentUser!.pin == pin;
  }

  /// Update user data
  Future<void> updateUserData(OnboardingData updatedData) async {
    try {
      await LocalStorageService.saveOnboardingData(updatedData);
      _currentUser = updatedData;
    } catch (e) {
      throw Exception('Failed to update user data: $e');
    }
  }

  /// Get app initialization summary
  Map<String, dynamic> getAppSummary() {
    return {
      'isInitialized': _isInitialized,
      'isUserLoggedIn': isUserLoggedIn,
      'userName': userDisplayName,
      'virtualNumber': userVirtualNumber,
      'hasPinSet': hasPinSet,
      'onboardingCompleted': _currentUser?.completed ?? false,
    };
  }
}