import 'package:flutter/material.dart';
import '../services/unified_storage_service.dart';
import '../services/local_storage_service.dart';

class UsernameProvider extends ChangeNotifier {
  static const int _changeIntervalMonths = 6;
  
  String _handle = '';
  DateTime? _lastUsernameChange;
  
  String get username => _handle; // For backward compatibility
  String get handle => _handle;
  DateTime? get lastUsernameChange => _lastUsernameChange;
  
  UsernameProvider() {
    _loadHandle();
  }
  
  Future<void> _loadHandle() async {
    // First try to load from unified storage
    _handle = await UnifiedStorageService.getString(UnifiedStorageService.userHandle) ?? '';
    
    // If not found, try to load from onboarding data
    if (_handle.isEmpty) {
      try {
        final onboardingData = await LocalStorageService.getOnboardingData();
        if (onboardingData != null && onboardingData.completed) {
          _handle = onboardingData.userName;
          // Save to unified storage for future use
          await UnifiedStorageService.setString(UnifiedStorageService.userHandle, _handle);
        }
      } catch (e) {
        // Ignore errors and continue with empty handle
      }
    }
    
    final lastChangeTimestamp = await UnifiedStorageService.getInt(UnifiedStorageService.lastUsernameChange);
    if (lastChangeTimestamp != null) {
      _lastUsernameChange = DateTime.fromMillisecondsSinceEpoch(lastChangeTimestamp);
    }
    
    notifyListeners();
  }

  // Public method to reload handle data
  Future<void> reloadHandle() async {
    await _loadHandle();
  }
  
  bool canChangeUsername() {
    if (_lastUsernameChange == null) return true;
    
    final now = DateTime.now();
    final monthsSinceLastChange = _calculateMonthsDifference(_lastUsernameChange!, now);
    
    return monthsSinceLastChange >= _changeIntervalMonths;
  }
  
  int daysUntilNextChange() {
    if (_lastUsernameChange == null) return 0;
    
    final nextChangeDate = DateTime(
      _lastUsernameChange!.year,
      _lastUsernameChange!.month + _changeIntervalMonths,
      _lastUsernameChange!.day,
    );
    
    final now = DateTime.now();
    if (now.isAfter(nextChangeDate)) return 0;
    
    return nextChangeDate.difference(now).inDays;
  }
  
  String getFormattedUsername() {
    if (_handle.isEmpty) return '';
    return '@$_handle';
  }
  
  Future<bool> setUsername(String newHandle) async {
    // Remove @ if user included it
    newHandle = newHandle.replaceAll('@', '').trim();
    
    // Validate handle
    if (!_isValidHandle(newHandle)) {
      return false;
    }
    
    // Check if user can change handle
    if (!canChangeUsername()) {
      return false;
    }
    
    await UnifiedStorageService.setString(UnifiedStorageService.userHandle, newHandle);
    await UnifiedStorageService.setInt(UnifiedStorageService.lastUsernameChange, DateTime.now().millisecondsSinceEpoch);
    
    _handle = newHandle;
    _lastUsernameChange = DateTime.now();
    
    notifyListeners();
    return true;
  }
  
  bool _isValidHandle(String handle) {
    // Handle validation rules:
    // - 3-20 characters
    // - Only letters, numbers, and underscores
    // - Must start with a letter
    // - Cannot end with underscore
    
    if (handle.length < 3 || handle.length > 20) return false;
    
    final regex = RegExp(r'^[a-zA-Z][a-zA-Z0-9_]*[a-zA-Z0-9]$');
    if (handle.length == 3) {
      // For 3-character handles, allow ending with letter or number
      return RegExp(r'^[a-zA-Z][a-zA-Z0-9_]*$').hasMatch(handle);
    }
    
    return regex.hasMatch(handle);
  }
  
  String? validateUsername(String handle) {
    handle = handle.replaceAll('@', '').trim();
    
    if (handle.isEmpty) {
      return 'Handle cannot be empty';
    }
    
    if (handle.length < 3) {
      return 'Handle must be at least 3 characters';
    }
    
    if (handle.length > 20) {
      return 'Handle must be 20 characters or less';
    }
    
    if (!RegExp(r'^[a-zA-Z]').hasMatch(handle)) {
      return 'Handle must start with a letter';
    }
    
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(handle)) {
      return 'Handle can only contain letters, numbers, and underscores';
    }
    
    if (handle.length > 3 && handle.endsWith('_')) {
      return 'Handle cannot end with underscore';
    }
    
    return null;
  }
  
  int _calculateMonthsDifference(DateTime start, DateTime end) {
    int months = (end.year - start.year) * 12 + (end.month - start.month);
    
    // If the day hasn't been reached yet in the current month, subtract one month
    if (end.day < start.day) {
      months--;
    }
    
    return months;
  }
}