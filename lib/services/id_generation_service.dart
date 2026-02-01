import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Service to generate unique IDs and virtual phone numbers
class IdGenerationService {
  static final IdGenerationService _instance = IdGenerationService._internal();
  factory IdGenerationService() => _instance;
  IdGenerationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Random _random = Random();

  /// Generate unique user ID in format: sUY7e-nd45-3jeUHuw-de45
  Future<String> generateUniqueUserId() async {
    try {
      String userId;
      bool isUnique = false;
      int attempts = 0;
      const maxAttempts = 10;

      do {
        userId = _generateUserIdFormat();
        isUnique = await _isUserIdUnique(userId);
        attempts++;
        
        if (attempts >= maxAttempts) {
          // Fallback with timestamp
          userId = _generateTimestampBasedUserId();
          break;
        }
      } while (!isUnique);

      print('✅ Generated unique user ID: $userId (attempts: $attempts)');
      return userId;
    } catch (e) {
      print('❌ Failed to generate user ID: $e');
      return _generateTimestampBasedUserId();
    }
  }

  /// Generate user ID in format: sUY7e-nd45-3jeUHuw-de45
  String _generateUserIdFormat() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    
    // Generate 4 segments with different lengths
    final segment1 = _generateRandomString(5, chars); // 5 chars
    final segment2 = _generateRandomString(4, chars); // 4 chars  
    final segment3 = _generateRandomString(6, chars); // 6 chars
    final segment4 = _generateRandomString(4, chars); // 4 chars
    
    return '$segment1-$segment2-$segment3-$segment4';
  }

  /// Generate timestamp-based user ID as fallback
  String _generateTimestampBasedUserId() {
    final now = DateTime.now();
    final timestamp = now.millisecondsSinceEpoch.toString();
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    
    final segment1 = _generateRandomString(3, chars);
    final segment2 = timestamp.substring(timestamp.length - 4);
    final segment3 = _generateRandomString(4, chars);
    final segment4 = timestamp.substring(timestamp.length - 6, timestamp.length - 2);
    
    return '$segment1$segment2-$segment3-${segment1}$segment4';
  }

  /// Generate random string from character set
  String _generateRandomString(int length, String chars) {
    return String.fromCharCodes(Iterable.generate(
      length, (_) => chars.codeUnitAt(_random.nextInt(chars.length))
    ));
  }

  /// Check if user ID is unique
  Future<bool> _isUserIdUnique(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      return !doc.exists;
    } catch (e) {
      print('❌ Error checking user ID uniqueness: $e');
      return false;
    }
  }

  /// Generate virtual phone number in format: 123-456-7890
  Future<String> generateVirtualPhoneNumber() async {
    try {
      String phoneNumber;
      bool isUnique = false;
      int attempts = 0;
      const maxAttempts = 10;

      do {
        phoneNumber = _generatePhoneNumberFormat();
        isUnique = await _isPhoneNumberUnique(phoneNumber);
        attempts++;
        
        if (attempts >= maxAttempts) {
          // Fallback with timestamp
          phoneNumber = _generateTimestampBasedPhoneNumber();
          break;
        }
      } while (!isUnique);

      print('✅ Generated unique phone number: $phoneNumber (attempts: $attempts)');
      return phoneNumber;
    } catch (e) {
      print('❌ Failed to generate phone number: $e');
      return _generateTimestampBasedPhoneNumber();
    }
  }

  /// Generate phone number in format: 123-456-7890
  String _generatePhoneNumberFormat() {
    // Area code: 200-999 (avoid 0xx and 1xx)
    final areaCode = (200 + _random.nextInt(800)).toString();
    
    // Exchange: 200-999 (avoid 0xx and 1xx)
    final exchange = (200 + _random.nextInt(800)).toString();
    
    // Number: 0000-9999
    final number = _random.nextInt(10000).toString().padLeft(4, '0');
    
    return '$areaCode-$exchange-$number';
  }

  /// Generate timestamp-based phone number as fallback
  String _generateTimestampBasedPhoneNumber() {
    final now = DateTime.now();
    final timestamp = now.millisecondsSinceEpoch.toString();
    
    // Use last 10 digits of timestamp and format as phone number
    final lastTen = timestamp.substring(timestamp.length - 10);
    final areaCode = lastTen.substring(0, 3);
    final exchange = lastTen.substring(3, 6);
    final number = lastTen.substring(6, 10);
    
    return '$areaCode-$exchange-$number';
  }

  /// Check if phone number is unique
  Future<bool> _isPhoneNumberUnique(String phoneNumber) async {
    try {
      final query = await _firestore
          .collection('users')
          .where('virtualNumber', isEqualTo: phoneNumber)
          .limit(1)
          .get();
      
      return query.docs.isEmpty;
    } catch (e) {
      print('❌ Error checking phone number uniqueness: $e');
      return false;
    }
  }

  /// Validate user ID format
  bool isValidUserIdFormat(String userId) {
    // Format: xxxxx-xxxx-xxxxxx-xxxx
    final regex = RegExp(r'^[a-zA-Z0-9]{5}-[a-zA-Z0-9]{4}-[a-zA-Z0-9]{6}-[a-zA-Z0-9]{4}$');
    return regex.hasMatch(userId);
  }

  /// Validate phone number format
  bool isValidPhoneNumberFormat(String phoneNumber) {
    // Format: 123-456-7890
    final regex = RegExp(r'^\d{3}-\d{3}-\d{4}$');
    return regex.hasMatch(phoneNumber);
  }

  /// Generate both user ID and phone number
  Future<Map<String, String>> generateUserCredentials() async {
    final userId = await generateUniqueUserId();
    final phoneNumber = await generateVirtualPhoneNumber();
    
    return {
      'userId': userId,
      'virtualNumber': phoneNumber,
    };
  }
}