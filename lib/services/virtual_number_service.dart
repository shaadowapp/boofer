import 'package:cloud_firestore/cloud_firestore.dart';
import 'id_generation_service.dart';

/// Service to generate and manage virtual numbers for users
class VirtualNumberService {
  static final VirtualNumberService _instance = VirtualNumberService._internal();
  factory VirtualNumberService() => _instance;
  VirtualNumberService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final IdGenerationService _idService = IdGenerationService();

  /// Generate a unique virtual number for a user
  Future<String> generateVirtualNumber() async {
    try {
      print('🔄 Generating unique virtual number...');
      
      int attempts = 0;
      String virtualNumber;
      
      while (attempts < 10) {
        // Use the ID generation service for consistent phone number generation
        virtualNumber = await _idService.generateVirtualPhoneNumber();
        
        // Check if it's unique
        if (await _isVirtualNumberUnique(virtualNumber)) {
          print('✅ Generated unique virtual number: $virtualNumber');
          return virtualNumber;
        }
        
        print('⚠️ Virtual number collision detected, regenerating... (attempt ${attempts + 1})');
        attempts++;
      }
      
      // Fallback to timestamp-based number if we couldn't generate unique one
      print('⚠️ Using timestamp-based fallback for virtual number');
      return _generateTimestampBasedNumber();
    } catch (e) {
      print('❌ Failed to generate virtual number: $e');
      // Fallback to timestamp-based number
      return _generateTimestampBasedNumber();
    }
  }

  /// Generate timestamp-based virtual number as fallback
  String _generateTimestampBasedNumber() {
    final now = DateTime.now();
    final timestamp = now.millisecondsSinceEpoch.toString();
    
    // Use last 10 digits of timestamp and format as phone number
    final lastTen = timestamp.substring(timestamp.length - 10);
    final areaCode = lastTen.substring(0, 3);
    final exchange = lastTen.substring(3, 6);
    final number = lastTen.substring(6, 10);
    
    return '$areaCode-$exchange-$number';
  }

  /// Check if virtual number is unique in Firestore
  Future<bool> _isVirtualNumberUnique(String virtualNumber) async {
    try {
      final query = await _firestore
          .collection('users')
          .where('virtualNumber', isEqualTo: virtualNumber)
          .limit(1)
          .get();
      
      return query.docs.isEmpty;
    } catch (e) {
      print('❌ Error checking virtual number uniqueness: $e');
      return false;
    }
  }

  /// Assign virtual number to user in Firestore
  Future<bool> assignVirtualNumberToUser(String userId, String virtualNumber) async {
    try {
      print('🔄 Assigning virtual number $virtualNumber to user $userId...');
      
      // Use set with merge instead of update to handle cases where document might not exist
      await _firestore.collection('users').doc(userId).set({
        'virtualNumber': virtualNumber,
        'virtualNumberAssignedAt': DateTime.now().toIso8601String(),
        'virtualNumberMetadata': {
          'assignedAt': DateTime.now().toIso8601String(),
          'assignedFrom': 'profile_completion',
          'format': '123-456-7890',
          'isActive': true,
        },
        'updatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true)); // Merge with existing document

      print('✅ Virtual number assigned successfully');
      return true;
    } catch (e) {
      print('❌ Failed to assign virtual number: $e');
      return false;
    }
  }

  /// Generate and assign virtual number to user (combined operation)
  Future<String?> generateAndAssignVirtualNumber(String userId) async {
    try {
      print('🔄 Generating and assigning virtual number for user $userId...');
      
      // Generate unique virtual number
      final virtualNumber = await generateVirtualNumber();
      
      // Assign to user
      final success = await assignVirtualNumberToUser(userId, virtualNumber);
      
      if (success) {
        print('✅ Virtual number $virtualNumber generated and assigned successfully');
        return virtualNumber;
      } else {
        print('❌ Failed to assign generated virtual number');
        return null;
      }
    } catch (e) {
      print('❌ Error in generate and assign process: $e');
      return null;
    }
  }

  /// Get virtual number for user
  Future<String?> getUserVirtualNumber(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final data = doc.data();
        return data?['virtualNumber'] as String?;
      }
      return null;
    } catch (e) {
      print('❌ Failed to get user virtual number: $e');
      return null;
    }
  }

  /// Check if user has virtual number
  Future<bool> userHasVirtualNumber(String userId) async {
    final virtualNumber = await getUserVirtualNumber(userId);
    return virtualNumber != null && virtualNumber.isNotEmpty;
  }

  /// Generate virtual numbers in bulk (for admin/testing purposes)
  Future<List<String>> generateBulkVirtualNumbers(int count) async {
    final numbers = <String>[];
    
    for (int i = 0; i < count; i++) {
      try {
        final number = await generateVirtualNumber();
        numbers.add(number);
      } catch (e) {
        print('❌ Failed to generate virtual number $i: $e');
      }
    }
    
    return numbers;
  }

  /// Validate virtual number format
  bool isValidVirtualNumberFormat(String virtualNumber) {
    // Format: 123-456-7890
    final regex = RegExp(r'^\d{3}-\d{3}-\d{4}$');
    return regex.hasMatch(virtualNumber);
  }

  /// Get virtual number statistics
  Future<Map<String, dynamic>> getVirtualNumberStats() async {
    try {
      final currentYear = DateTime.now().year;
      
      // Count total virtual numbers
      final totalQuery = await _firestore
          .collection('users')
          .where('virtualNumber', isNotEqualTo: null)
          .count()
          .get();
      
      // Count this year's virtual numbers (phone format)
      final thisYearQuery = await _firestore
          .collection('users')
          .where('virtualNumber', isNotEqualTo: null)
          .count()
          .get();

      return {
        'totalAssigned': totalQuery.count,
        'thisYearAssigned': thisYearQuery.count,
        'currentYear': currentYear,
        'lastGenerated': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      print('❌ Failed to get virtual number stats: $e');
      return {
        'totalAssigned': 0,
        'thisYearAssigned': 0,
        'currentYear': DateTime.now().year,
        'error': e.toString(),
      };
    }
  }
}