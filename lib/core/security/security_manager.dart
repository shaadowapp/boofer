import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecurityManager {
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );
  
  // Encrypt sensitive data
  static String encryptData(String data, String key) {
    final keyBytes = utf8.encode(key);
    final dataBytes = utf8.encode(data);
    final hmac = Hmac(sha256, keyBytes);
    final digest = hmac.convert(dataBytes);
    return base64.encode(digest.bytes);
  }
  
  // Generate secure random string
  static String generateSecureToken({int length = 32}) {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return List.generate(length, (index) => chars[random.nextInt(chars.length)]).join();
  }
  
  // Hash password
  static String hashPassword(String password, String salt) {
    final bytes = utf8.encode(password + salt);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
  
  // Generate salt
  static String generateSalt() {
    return generateSecureToken(length: 16);
  }
  
  // Secure storage operations
  static Future<void> storeSecurely(String key, String value) async {
    await _secureStorage.write(key: key, value: value);
  }
  
  static Future<String?> readSecurely(String key) async {
    return await _secureStorage.read(key: key);
  }
  
  static Future<void> deleteSecurely(String key) async {
    await _secureStorage.delete(key: key);
  }
  
  static Future<void> clearAllSecure() async {
    await _secureStorage.deleteAll();
  }
  
  // Validate input to prevent injection attacks
  static bool isValidInput(String input, {int maxLength = 1000}) {
    if (input.length > maxLength) return false;
    
    // Check for common injection patterns
    final dangerousPatterns = [
      RegExp(r'<script', caseSensitive: false),
      RegExp(r'javascript:', caseSensitive: false),
      RegExp(r'on\w+\s*=', caseSensitive: false),
      RegExp(r'sql\s+(select|insert|update|delete|drop)', caseSensitive: false),
    ];
    
    for (final pattern in dangerousPatterns) {
      if (pattern.hasMatch(input)) return false;
    }
    
    return true;
  }
  
  // Sanitize user input
  static String sanitizeInput(String input) {
    return input
        .replaceAll(RegExp(r'[<>"\']'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}