import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/local_storage_service.dart';
import '../core/error/error_handler.dart';
import '../core/models/app_error.dart';

/// Service to manage Firebase Auth UID ↔ Custom User ID mapping
/// This enables secure Firestore rules while using custom user IDs
class UserMappingService {
  static final UserMappingService _instance = UserMappingService._internal();
  factory UserMappingService() => _instance;
  UserMappingService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ErrorHandler _errorHandler = ErrorHandler();

  // Cache for mappings to reduce Firestore reads
  final Map<String, String> _firebaseToCustomCache = {};
  final Map<String, String> _customToFirebaseCache = {};

  /// Create a mapping between Firebase Auth UID and Custom User ID
  /// This should be called immediately after user creation
  Future<bool> createMapping({
    required String firebaseUid,
    required String customUserId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      print('🔄 Creating user mapping: $firebaseUid → $customUserId');

      final mappingData = {
        'firebaseUid': firebaseUid,
        'customUserId': customUserId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'metadata': metadata ?? {},
      };

      // Store mapping using Firebase UID as document ID for fast lookups
      await _firestore
          .collection('user_mappings')
          .doc(firebaseUid)
          .set(mappingData);

      // Update cache
      _firebaseToCustomCache[firebaseUid] = customUserId;
      _customToFirebaseCache[customUserId] = firebaseUid;

      // Store locally for offline access
      await _storeMappingLocally(firebaseUid, customUserId);

      print('✅ User mapping created successfully');
      return true;
    } catch (e, stackTrace) {
      _errorHandler.handleError(AppError.service(
        message: 'Failed to create user mapping: $e',
        stackTrace: stackTrace,
        originalException: e is Exception ? e : Exception(e.toString()),
      ));
      return false;
    }
  }

  /// Get custom user ID from Firebase Auth UID
  Future<String?> getCustomUserId(String firebaseUid) async {
    try {
      // Check cache first
      if (_firebaseToCustomCache.containsKey(firebaseUid)) {
        return _firebaseToCustomCache[firebaseUid];
      }

      // Check local storage
      final localMapping = await _getMappingFromLocal(firebaseUid);
      if (localMapping != null) {
        _firebaseToCustomCache[firebaseUid] = localMapping;
        return localMapping;
      }

      // Query Firestore
      final doc = await _firestore
          .collection('user_mappings')
          .doc(firebaseUid)
          .get();

      if (doc.exists) {
        final customUserId = doc.data()?['customUserId'] as String?;
        if (customUserId != null) {
          _firebaseToCustomCache[firebaseUid] = customUserId;
          _customToFirebaseCache[customUserId] = firebaseUid;
          await _storeMappingLocally(firebaseUid, customUserId);
          return customUserId;
        }
      }

      return null;
    } catch (e, stackTrace) {
      _errorHandler.handleError(AppError.service(
        message: 'Failed to get custom user ID: $e',
        stackTrace: stackTrace,
        originalException: e is Exception ? e : Exception(e.toString()),
      ));
      return null;
    }
  }

  /// Get Firebase Auth UID from custom user ID
  Future<String?> getFirebaseUid(String customUserId) async {
    try {
      // Check cache first
      if (_customToFirebaseCache.containsKey(customUserId)) {
        return _customToFirebaseCache[customUserId];
      }

      // Query Firestore
      final query = await _firestore
          .collection('user_mappings')
          .where('customUserId', isEqualTo: customUserId)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final firebaseUid = query.docs.first.data()['firebaseUid'] as String?;
        if (firebaseUid != null) {
          _firebaseToCustomCache[firebaseUid] = customUserId;
          _customToFirebaseCache[customUserId] = firebaseUid;
          await _storeMappingLocally(firebaseUid, customUserId);
          return firebaseUid;
        }
      }

      return null;
    } catch (e, stackTrace) {
      _errorHandler.handleError(AppError.service(
        message: 'Failed to get Firebase UID: $e',
        stackTrace: stackTrace,
        originalException: e is Exception ? e : Exception(e.toString()),
      ));
      return null;
    }
  }

  /// Get custom user ID for currently authenticated user
  Future<String?> getCurrentUserCustomId() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return null;

    return await getCustomUserId(firebaseUser.uid);
  }

  /// Update mapping metadata
  Future<bool> updateMappingMetadata({
    required String firebaseUid,
    required Map<String, dynamic> metadata,
  }) async {
    try {
      await _firestore
          .collection('user_mappings')
          .doc(firebaseUid)
          .update({
        'metadata': metadata,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e, stackTrace) {
      _errorHandler.handleError(AppError.service(
        message: 'Failed to update mapping metadata: $e',
        stackTrace: stackTrace,
        originalException: e is Exception ? e : Exception(e.toString()),
      ));
      return false;
    }
  }

  /// Delete mapping (use with caution - only for account deletion)
  Future<bool> deleteMapping(String firebaseUid) async {
    try {
      final customUserId = await getCustomUserId(firebaseUid);

      await _firestore
          .collection('user_mappings')
          .doc(firebaseUid)
          .delete();

      // Clear cache
      _firebaseToCustomCache.remove(firebaseUid);
      if (customUserId != null) {
        _customToFirebaseCache.remove(customUserId);
      }

      // Clear local storage
      await LocalStorageService.remove('user_mapping_$firebaseUid');

      print('✅ User mapping deleted');
      return true;
    } catch (e, stackTrace) {
      _errorHandler.handleError(AppError.service(
        message: 'Failed to delete mapping: $e',
        stackTrace: stackTrace,
        originalException: e is Exception ? e : Exception(e.toString()),
      ));
      return false;
    }
  }

  /// Verify mapping exists and is valid
  Future<bool> verifyMapping(String firebaseUid, String customUserId) async {
    try {
      final doc = await _firestore
          .collection('user_mappings')
          .doc(firebaseUid)
          .get();

      if (!doc.exists) return false;

      final storedCustomId = doc.data()?['customUserId'] as String?;
      return storedCustomId == customUserId;
    } catch (e) {
      return false;
    }
  }

  /// Store mapping locally for offline access
  Future<void> _storeMappingLocally(String firebaseUid, String customUserId) async {
    try {
      await LocalStorageService.setString(
        'user_mapping_$firebaseUid',
        customUserId,
      );
      await LocalStorageService.setString('firebase_uid', firebaseUid);
      await LocalStorageService.setString('custom_user_id', customUserId);
    } catch (e) {
      print('⚠️ Failed to store mapping locally: $e');
    }
  }

  /// Get mapping from local storage
  Future<String?> _getMappingFromLocal(String firebaseUid) async {
    try {
      return await LocalStorageService.getString('user_mapping_$firebaseUid');
    } catch (e) {
      return null;
    }
  }

  /// Clear all cached mappings
  void clearCache() {
    _firebaseToCustomCache.clear();
    _customToFirebaseCache.clear();
  }

  /// Batch create mappings (for migration)
  Future<int> batchCreateMappings(List<Map<String, String>> mappings) async {
    int successCount = 0;

    try {
      final batch = _firestore.batch();

      for (final mapping in mappings) {
        final firebaseUid = mapping['firebaseUid'];
        final customUserId = mapping['customUserId'];

        if (firebaseUid == null || customUserId == null) continue;

        final docRef = _firestore.collection('user_mappings').doc(firebaseUid);
        batch.set(docRef, {
          'firebaseUid': firebaseUid,
          'customUserId': customUserId,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'metadata': {
            'migrated': true,
            'migratedAt': DateTime.now().toIso8601String(),
          },
        });

        successCount++;
      }

      await batch.commit();
      print('✅ Batch created $successCount mappings');

      return successCount;
    } catch (e, stackTrace) {
      _errorHandler.handleError(AppError.service(
        message: 'Failed to batch create mappings: $e',
        stackTrace: stackTrace,
        originalException: e is Exception ? e : Exception(e.toString()),
      ));
      return successCount;
    }
  }

  /// Get all mappings (admin function - use with caution)
  Future<List<Map<String, String>>> getAllMappings({int limit = 100}) async {
    try {
      final query = await _firestore
          .collection('user_mappings')
          .limit(limit)
          .get();

      return query.docs.map((doc) {
        final data = doc.data();
        return {
          'firebaseUid': data['firebaseUid'] as String? ?? '',
          'customUserId': data['customUserId'] as String? ?? '',
        };
      }).toList();
    } catch (e, stackTrace) {
      _errorHandler.handleError(AppError.service(
        message: 'Failed to get all mappings: $e',
        stackTrace: stackTrace,
        originalException: e is Exception ? e : Exception(e.toString()),
      ));
      return [];
    }
  }
}
