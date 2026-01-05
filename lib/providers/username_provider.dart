import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UsernameProvider extends ChangeNotifier {
  static const String _usernameKey = 'username';
  static const String _lastUsernameChangeKey = 'last_username_change';
  static const int _changeIntervalMonths = 6;
  
  String _username = '';
  DateTime? _lastUsernameChange;
  
  String get username => _username;
  DateTime? get lastUsernameChange => _lastUsernameChange;
  
  UsernameProvider() {
    _loadUsername();
  }
  
  Future<void> _loadUsername() async {
    final prefs = await SharedPreferences.getInstance();
    _username = prefs.getString(_usernameKey) ?? '';
    
    final lastChangeTimestamp = prefs.getInt(_lastUsernameChangeKey);
    if (lastChangeTimestamp != null) {
      _lastUsernameChange = DateTime.fromMillisecondsSinceEpoch(lastChangeTimestamp);
    }
    
    notifyListeners();
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
    if (_username.isEmpty) return '';
    return '@$_username';
  }
  
  Future<bool> setUsername(String newUsername) async {
    // Remove @ if user included it
    newUsername = newUsername.replaceAll('@', '').trim();
    
    // Validate username
    if (!_isValidUsername(newUsername)) {
      return false;
    }
    
    // Check if user can change username
    if (!canChangeUsername()) {
      return false;
    }
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_usernameKey, newUsername);
    await prefs.setInt(_lastUsernameChangeKey, DateTime.now().millisecondsSinceEpoch);
    
    _username = newUsername;
    _lastUsernameChange = DateTime.now();
    
    notifyListeners();
    return true;
  }
  
  bool _isValidUsername(String username) {
    // Username validation rules:
    // - 3-20 characters
    // - Only letters, numbers, and underscores
    // - Must start with a letter
    // - Cannot end with underscore
    
    if (username.length < 3 || username.length > 20) return false;
    
    final regex = RegExp(r'^[a-zA-Z][a-zA-Z0-9_]*[a-zA-Z0-9]$');
    if (username.length == 3) {
      // For 3-character usernames, allow ending with letter or number
      return RegExp(r'^[a-zA-Z][a-zA-Z0-9_]*$').hasMatch(username);
    }
    
    return regex.hasMatch(username);
  }
  
  String? validateUsername(String username) {
    username = username.replaceAll('@', '').trim();
    
    if (username.isEmpty) {
      return 'Username cannot be empty';
    }
    
    if (username.length < 3) {
      return 'Username must be at least 3 characters';
    }
    
    if (username.length > 20) {
      return 'Username must be 20 characters or less';
    }
    
    if (!RegExp(r'^[a-zA-Z]').hasMatch(username)) {
      return 'Username must start with a letter';
    }
    
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username)) {
      return 'Username can only contain letters, numbers, and underscores';
    }
    
    if (username.length > 3 && username.endsWith('_')) {
      return 'Username cannot end with underscore';
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