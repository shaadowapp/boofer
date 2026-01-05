import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserService {
  static const String _userNumberKey = 'user_virtual_number';
  static const String _isOnboardedKey = 'is_onboarded';

  static Future<void> saveUserNumber(String number) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userNumberKey, number);
    await prefs.setBool(_isOnboardedKey, true);
  }

  static Future<String?> getUserNumber() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userNumberKey);
  }

  static Future<bool> isOnboarded() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isOnboardedKey) ?? false;
  }

  static Future<void> clearUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userNumberKey);
    await prefs.remove(_isOnboardedKey);
  }
}