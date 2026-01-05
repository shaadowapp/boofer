import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/onboarding_data.dart';

class LocalStorageService {
  static const String _onboardingKey = 'onboarding_completed';
  static const String _userNameKey = 'user_name';
  static const String _virtualNumberKey = 'virtual_number';
  static const String _userPinKey = 'user_pin';
  static const String _onboardingDataKey = 'onboarding_data';

  // Secure storage for sensitive data like PIN
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: const IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  /// Check if onboarding has been completed
  static Future<bool> isOnboardingCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_onboardingKey) ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Save complete onboarding data
  static Future<void> saveOnboardingData(OnboardingData data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Save basic data to SharedPreferences
      await prefs.setString(_onboardingDataKey, jsonEncode(data.toJson()));
      await prefs.setBool(_onboardingKey, data.completed);
      await prefs.setString(_userNameKey, data.userName);
      await prefs.setString(_virtualNumberKey, data.virtualNumber);
      
      // Save PIN securely if provided
      if (data.pin != null) {
        await _secureStorage.write(key: _userPinKey, value: data.pin);
      }
    } catch (e) {
      throw Exception('Failed to save onboarding data: $e');
    }
  }

  /// Retrieve complete onboarding data
  static Future<OnboardingData?> getOnboardingData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dataJson = prefs.getString(_onboardingDataKey);
      
      if (dataJson == null) return null;
      
      final data = OnboardingData.fromJson(jsonDecode(dataJson));
      
      // Get PIN from secure storage if it exists
      final pin = await _secureStorage.read(key: _userPinKey);
      
      return data.copyWith(pin: pin);
    } catch (e) {
      return null;
    }
  }

  /// Get user name
  static Future<String?> getUserName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_userNameKey);
    } catch (e) {
      return null;
    }
  }

  /// Get virtual number
  static Future<String?> getVirtualNumber() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_virtualNumberKey);
    } catch (e) {
      return null;
    }
  }

  /// Get PIN securely
  static Future<String?> getUserPin() async {
    try {
      return await _secureStorage.read(key: _userPinKey);
    } catch (e) {
      return null;
    }
  }

  /// Clear all onboarding data (for testing or reset)
  static Future<void> clearOnboardingData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_onboardingKey);
      await prefs.remove(_userNameKey);
      await prefs.remove(_virtualNumberKey);
      await prefs.remove(_onboardingDataKey);
      await _secureStorage.delete(key: _userPinKey);
    } catch (e) {
      throw Exception('Failed to clear onboarding data: $e');
    }
  }

  /// Update specific onboarding fields
  static Future<void> updateUserName(String userName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userNameKey, userName);
      
      // Update complete data if it exists
      final existingData = await getOnboardingData();
      if (existingData != null) {
        final updatedData = existingData.copyWith(userName: userName);
        await prefs.setString(_onboardingDataKey, jsonEncode(updatedData.toJson()));
      }
    } catch (e) {
      throw Exception('Failed to update user name: $e');
    }
  }

  /// Update PIN securely
  static Future<void> updateUserPin(String? pin) async {
    try {
      if (pin != null) {
        await _secureStorage.write(key: _userPinKey, value: pin);
      } else {
        await _secureStorage.delete(key: _userPinKey);
      }
      
      // Update complete data if it exists
      final existingData = await getOnboardingData();
      if (existingData != null) {
        final updatedData = existingData.copyWith(pin: pin);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_onboardingDataKey, jsonEncode(updatedData.toJson()));
      }
    } catch (e) {
      throw Exception('Failed to update user PIN: $e');
    }
  }
}