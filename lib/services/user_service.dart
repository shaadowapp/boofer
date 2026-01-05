import 'package:shared_preferences/shared_preferences.dart';

class UserService {
  static const String _onboardedKey = 'user_onboarded';
  static const String _userNumberKey = 'user_number';

  static Future<bool> isOnboarded() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardedKey) ?? false;
  }

  static Future<void> setOnboarded(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardedKey, value);
  }

  static Future<void> completeOnboarding() async {
    await setOnboarded(true);
  }

  static Future<void> saveUserNumber(String number) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userNumberKey, number);
  }

  static Future<String?> getUserNumber() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userNumberKey);
  }

  static Future<void> clearUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}