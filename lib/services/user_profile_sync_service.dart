import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../services/local_storage_service.dart';
import '../services/user_service.dart';

/// Service to sync user profile data between Firestore and local storage
class UserProfileSyncService {
  static final UserProfileSyncService _instance = UserProfileSyncService._internal();
  factory UserProfileSyncService() => _instance;
  UserProfileSyncService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Sync user profile to both Firestore and local storage
  Future<bool> syncUserProfile(User user, {Map<String, dynamic>? additionalData}) async {
    try {
      print('🔄 Syncing user profile comprehensively...');
      
      // Prepare comprehensive user data
      final userData = _prepareUserData(user, additionalData);
      
      // Sync to Firestore
      await _syncToFirestore(user.id, userData);
      
      // Sync to local storage
      await _syncToLocalStorage(user);
      
      print('✅ User profile synced successfully to both Firestore and local storage');
      return true;
    } catch (e) {
      print('❌ Failed to sync user profile: $e');
      return false;
    }
  }

  /// Prepare comprehensive user data for storage
  Map<String, dynamic> _prepareUserData(User user, Map<String, dynamic>? additionalData) {
    final baseData = {
      // Core user information
      'id': user.id,
      'email': user.email,
      'handle': user.handle,
      'fullName': user.fullName,
      'bio': user.bio,
      'profilePicture': user.profilePicture,
      'virtualNumber': user.virtualNumber,
      
      // Status and visibility
      'status': user.status.toString().split('.').last,
      'isDiscoverable': user.isDiscoverable,
      'lastSeen': user.lastSeen?.toIso8601String(),
      
      // Timestamps
      'createdAt': user.createdAt.toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
      'lastSyncAt': DateTime.now().toIso8601String(),
      
      // Profile metadata
      'profileVersion': 2,
      'dataVersion': DateTime.now().millisecondsSinceEpoch,
      
      // Privacy settings
      'privacySettings': {
        'showOnlineStatus': true,
        'allowDiscovery': user.isDiscoverable,
        'showLastSeen': true,
        'allowFriendRequests': true,
      },
      
      // App metadata
      'appMetadata': {
        'platform': 'android',
        'appVersion': '1.0.0',
        'lastUpdatedFrom': 'mobile_app',
        'syncMethod': 'comprehensive_sync',
      },
    };

    // Merge with additional data if provided
    if (additionalData != null) {
      baseData.addAll(additionalData);
    }

    return baseData;
  }

  /// Sync data to Firestore
  Future<void> _syncToFirestore(String userId, Map<String, dynamic> userData) async {
    try {
      await _firestore.collection('users').doc(userId).set(
        userData,
        SetOptions(merge: true),
      );
      
      print('✅ Data synced to Firestore');
      print('📄 Firestore fields: ${userData.keys.join(', ')}');
    } catch (e) {
      print('❌ Failed to sync to Firestore: $e');
      throw e;
    }
  }

  /// Sync data to local storage
  Future<void> _syncToLocalStorage(User user) async {
    try {
      // Store user profile
      await UserService.setCurrentUser(user);
      
      // Store additional metadata
      await LocalStorageService.setString('profile_sync_timestamp', DateTime.now().toIso8601String());
      await LocalStorageService.setString('profile_version', '2');
      
      print('✅ Data synced to local storage');
    } catch (e) {
      print('❌ Failed to sync to local storage: $e');
      throw e;
    }
  }

  /// Update specific profile fields
  Future<bool> updateProfileField(String userId, String field, dynamic value) async {
    try {
      final updateData = {
        field: value,
        'updatedAt': DateTime.now().toIso8601String(),
        'lastSyncAt': DateTime.now().toIso8601String(),
      };

      await _firestore.collection('users').doc(userId).update(updateData);
      
      print('✅ Profile field "$field" updated in Firestore');
      return true;
    } catch (e) {
      print('❌ Failed to update profile field: $e');
      return false;
    }
  }

  /// Mark profile as completed with metadata
  Future<bool> markProfileCompleted(String userId, {
    required List<String> completedFields,
    String completionMethod = 'profile_modal',
  }) async {
    try {
      final completionData = {
        'profileCompleted': true,
        'profileCompletedAt': DateTime.now().toIso8601String(),
        'profileVersion': 2,
        'completionMetadata': {
          'completedFrom': 'mobile_app',
          'completionMethod': completionMethod,
          'fieldsCompleted': completedFields,
          'completedAt': DateTime.now().toIso8601String(),
          'completionTimestamp': DateTime.now().millisecondsSinceEpoch,
        },
        'updatedAt': DateTime.now().toIso8601String(),
      };

      await _firestore.collection('users').doc(userId).update(completionData);
      
      print('✅ Profile marked as completed in Firestore');
      print('📋 Completed fields: ${completedFields.join(', ')}');
      return true;
    } catch (e) {
      print('❌ Failed to mark profile as completed: $e');
      return false;
    }
  }

  /// Get user profile from Firestore
  Future<Map<String, dynamic>?> getUserProfileFromFirestore(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      print('❌ Failed to get user profile from Firestore: $e');
      return null;
    }
  }

  /// Check if profile data is in sync
  Future<bool> isProfileInSync(String userId) async {
    try {
      // Get local sync timestamp
      final localSyncTime = await LocalStorageService.getString('profile_sync_timestamp');
      if (localSyncTime == null) return false;

      // Get Firestore sync timestamp
      final firestoreData = await getUserProfileFromFirestore(userId);
      if (firestoreData == null) return false;

      final firestoreSyncTime = firestoreData['lastSyncAt'] as String?;
      if (firestoreSyncTime == null) return false;

      // Compare timestamps (allowing 1 minute tolerance)
      final localTime = DateTime.parse(localSyncTime);
      final firestoreTime = DateTime.parse(firestoreSyncTime);
      final difference = localTime.difference(firestoreTime).abs();

      return difference.inMinutes <= 1;
    } catch (e) {
      print('❌ Failed to check sync status: $e');
      return false;
    }
  }

  /// Force sync from Firestore to local storage
  Future<bool> syncFromFirestore(String userId) async {
    try {
      final firestoreData = await getUserProfileFromFirestore(userId);
      if (firestoreData == null) return false;

      final user = User.fromJson(firestoreData);
      await _syncToLocalStorage(user);
      
      print('✅ Profile synced from Firestore to local storage');
      return true;
    } catch (e) {
      print('❌ Failed to sync from Firestore: $e');
      return false;
    }
  }
}