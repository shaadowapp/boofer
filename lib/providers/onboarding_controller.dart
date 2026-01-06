import 'package:flutter/foundation.dart';
import '../models/onboarding_data.dart';
import '../services/local_storage_service.dart';
import '../services/unified_storage_service.dart';
import '../utils/virtual_number_generator.dart';

class OnboardingController extends ChangeNotifier {
  int _currentStep = 1;
  String _userName = '';
  String? _userPin;
  String _virtualNumber = '';
  bool _termsAccepted = false;
  bool _onboardingCompleted = false;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  int get currentStep => _currentStep;
  String get userName => _userName;
  String? get userPin => _userPin;
  String get virtualNumber => _virtualNumber;
  bool get termsAccepted => _termsAccepted;
  bool get onboardingCompleted => _onboardingCompleted;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Validation getters
  bool get isStep1Valid => _userName.trim().isNotEmpty && _termsAccepted;
  bool get isStep2Valid => _userPin == null || _userPin!.length == 4;

  /// Initialize the controller and check existing onboarding status
  Future<void> initialize() async {
    _setLoading(true);
    try {
      final isCompleted = await LocalStorageService.isOnboardingCompleted();
      if (isCompleted) {
        final data = await LocalStorageService.getOnboardingData();
        if (data != null) {
          _userName = data.userName;
          _userPin = data.pin;
          _virtualNumber = data.virtualNumber;
          _onboardingCompleted = data.completed;
          _termsAccepted = true; // Must be true if onboarding was completed
        }
      }
      _clearError();
    } catch (e) {
      _setError('Failed to initialize onboarding: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Set user name
  void setUserName(String name) {
    _userName = name.trim();
    _clearError();
    notifyListeners();
  }

  /// Set terms acceptance
  void setTermsAccepted(bool accepted) {
    _termsAccepted = accepted;
    _clearError();
    notifyListeners();
  }

  /// Set user PIN with secure storage
  Future<void> setUserPin(String? pin) async {
    try {
      _userPin = pin;
      
      // Save PIN securely if provided
      if (pin != null) {
        await LocalStorageService.updateUserPin(pin);
      } else {
        // Clear PIN from secure storage
        await LocalStorageService.updateUserPin(null);
      }
      
      _clearError();
      notifyListeners();
    } catch (e) {
      _setError('Failed to save PIN securely: $e');
    }
  }

  /// Generate virtual number for step 3
  void generateVirtualNumber() {
    try {
      // Generate a new virtual number
      _virtualNumber = VirtualNumberGenerator.generate();
      
      // Validate the generated number
      if (!_isValidVirtualNumber(_virtualNumber)) {
        // Retry generation if invalid
        _virtualNumber = VirtualNumberGenerator.generate();
      }
      
      _clearError();
      notifyListeners();
    } catch (e) {
      _setError('Failed to generate virtual number: $e');
      // Fallback to a simple format if generation fails
      _virtualNumber = _generateFallbackNumber();
      notifyListeners();
    }
  }

  /// Generate a fallback virtual number
  String _generateFallbackNumber() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final lastSixDigits = timestamp.toString().substring(timestamp.toString().length - 6);
    return '555-${lastSixDigits.substring(0, 3)}-${lastSixDigits.substring(3)}';
  }

  /// Validate complete onboarding data
  bool validateCompleteOnboarding() {
    // Check step 1 requirements
    if (_userName.trim().isEmpty || !_termsAccepted) {
      return false;
    }

    // Check step 2 requirements (PIN is optional)
    if (_userPin != null && _userPin!.length != 4) {
      return false;
    }

    // Check step 3 requirements
    if (_virtualNumber.isEmpty || !_isValidVirtualNumber(_virtualNumber)) {
      return false;
    }

    return true;
  }

  /// Get onboarding summary for debugging
  Map<String, dynamic> getOnboardingSummary() {
    return {
      'currentStep': _currentStep,
      'userName': _userName,
      'termsAccepted': _termsAccepted,
      'hasPIN': _userPin != null,
      'virtualNumber': _virtualNumber,
      'onboardingCompleted': _onboardingCompleted,
      'isValid': validateCompleteOnboarding(),
    };
  }

  /// Move to next step
  Future<void> nextStep() async {
    if (_currentStep < 3) {
      _currentStep++;
      
      // Generate virtual number when moving to step 3
      if (_currentStep == 3 && _virtualNumber.isEmpty) {
        generateVirtualNumber();
      }
      
      _clearError();
      notifyListeners();
    }
  }

  /// Move to previous step
  void previousStep() {
    if (_currentStep > 1) {
      _currentStep--;
      _clearError();
      notifyListeners();
    }
  }

  /// Go to specific step
  void goToStep(int step) {
    if (step >= 1 && step <= 3) {
      _currentStep = step;
      
      // Generate virtual number when going to step 3
      if (_currentStep == 3 && _virtualNumber.isEmpty) {
        generateVirtualNumber();
      }
      
      _clearError();
      notifyListeners();
    }
  }

  /// Complete the onboarding process
  Future<void> completeOnboarding() async {
    _setLoading(true);
    try {
      // Validate all required data
      if (!validateCompleteOnboarding()) {
        // Get detailed validation info
        final summary = getOnboardingSummary();
        throw Exception('Onboarding validation failed. Summary: $summary');
      }

      // Ensure virtual number is generated and valid
      if (_virtualNumber.isEmpty) {
        generateVirtualNumber();
      }

      // Double-check virtual number after generation
      if (_virtualNumber.isEmpty || !_isValidVirtualNumber(_virtualNumber)) {
        throw Exception('Failed to generate valid virtual number');
      }

      // Create final onboarding data
      final onboardingData = OnboardingData(
        userName: _userName.trim(),
        virtualNumber: _virtualNumber,
        pin: _userPin,
        completed: true,
        completedAt: DateTime.now(),
      );

      // Save all data to local storage
      await saveToLocalStorage(onboardingData);
      
      // Also save to unified storage for consistency
      await _saveToUnifiedStorage(onboardingData);
      
      // Mark as completed
      _onboardingCompleted = true;
      _clearError();
      notifyListeners();
    } catch (e) {
      _setError('Failed to complete onboarding: $e');
      rethrow; // Re-throw to allow caller to handle
    } finally {
      _setLoading(false);
    }
  }

  /// Validate virtual number format
  bool _isValidVirtualNumber(String number) {
    // Check if it matches XXX-XXX-XXXX format
    final RegExp formatRegex = RegExp(r'^\d{3}-\d{3}-\d{4}$');
    return formatRegex.hasMatch(number);
  }

  /// Save onboarding data to local storage
  Future<void> saveToLocalStorage([OnboardingData? data]) async {
    try {
      final dataToSave = data ?? OnboardingData(
        userName: _userName,
        virtualNumber: _virtualNumber,
        pin: _userPin,
        completed: _onboardingCompleted,
        completedAt: DateTime.now(),
      );

      await LocalStorageService.saveOnboardingData(dataToSave);
    } catch (e) {
      throw Exception('Failed to save to local storage: $e');
    }
  }

  /// Save onboarding data to unified storage for consistency
  Future<void> _saveToUnifiedStorage(OnboardingData data) async {
    try {
      // Save user data to unified storage
      await UnifiedStorageService.setString(UnifiedStorageService.userHandle, data.userName);
      await UnifiedStorageService.setString(UnifiedStorageService.userVirtualNumber, data.virtualNumber);
      await UnifiedStorageService.setBool(UnifiedStorageService.onboardingCompleted, data.completed);
      await UnifiedStorageService.setString(UnifiedStorageService.userCreatedAt, data.completedAt.toIso8601String());
      await UnifiedStorageService.setString(UnifiedStorageService.userUpdatedAt, DateTime.now().toIso8601String());
      
      // Run migration to ensure all data is properly set
      await UnifiedStorageService.migrateOldKeys();
    } catch (e) {
      throw Exception('Failed to save to unified storage: $e');
    }
  }

  /// Reset onboarding state (for testing)
  Future<void> resetOnboarding() async {
    _setLoading(true);
    try {
      await LocalStorageService.clearOnboardingData();
      _currentStep = 1;
      _userName = '';
      _userPin = null;
      _virtualNumber = '';
      _termsAccepted = false;
      _onboardingCompleted = false;
      _clearError();
      notifyListeners();
    } catch (e) {
      _setError('Failed to reset onboarding: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Validate current step
  bool validateCurrentStep() {
    switch (_currentStep) {
      case 1:
        return isStep1Valid;
      case 2:
        return isStep2Valid;
      case 3:
        return _virtualNumber.isNotEmpty;
      default:
        return false;
    }
  }

  /// Skip PIN setup (for step 2) with secure storage cleanup
  Future<void> skipPinSetup() async {
    try {
      _userPin = null;
      
      // Clear any existing PIN from secure storage
      await LocalStorageService.updateUserPin(null);
      
      _clearError();
      notifyListeners();
    } catch (e) {
      _setError('Failed to clear PIN data: $e');
    }
  }

  /// Validate PIN against stored PIN
  Future<bool> validatePin(String pin) async {
    try {
      final storedPin = await LocalStorageService.getUserPin();
      return storedPin != null && storedPin == pin;
    } catch (e) {
      _setError('Failed to validate PIN: $e');
      return false;
    }
  }

  /// Check if PIN is set
  Future<bool> isPinSet() async {
    try {
      final storedPin = await LocalStorageService.getUserPin();
      return storedPin != null && storedPin.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Update PIN securely
  Future<void> updatePin(String oldPin, String newPin) async {
    try {
      // Validate old PIN first
      final isValidOldPin = await validatePin(oldPin);
      if (!isValidOldPin) {
        _setError('Current PIN is incorrect');
        return;
      }

      // Set new PIN
      await setUserPin(newPin);
    } catch (e) {
      _setError('Failed to update PIN: $e');
    }
  }

  /// Clear PIN data securely (for testing/reset)
  Future<void> clearPinData() async {
    try {
      _userPin = null;
      await LocalStorageService.updateUserPin(null);
      _clearError();
      notifyListeners();
    } catch (e) {
      _setError('Failed to clear PIN data: $e');
    }
  }

  // Private helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }

  @override
  void dispose() {
    super.dispose();
  }
}