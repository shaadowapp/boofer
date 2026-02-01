import 'dart:async';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart' as app_user;
import '../services/local_storage_service.dart';
import '../services/id_generation_service.dart';
import 'user_service.dart' as user_service;

class GoogleAuthService {
  static final GoogleAuthService _instance = GoogleAuthService._internal();
  factory GoogleAuthService() => _instance;
  GoogleAuthService._internal();

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Sign in with Google and authenticate with Firebase
  Future<User?> signInWithGoogle() async {
    try {
      print('🔄 Starting Google Sign-In...');
      
      // Trigger the Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        print('❌ User cancelled Google Sign-In');
        return null;
      }

      print('✅ Google Sign-In successful: ${googleUser.email}');

      // Check if user exists in Firestore BEFORE Firebase authentication
      final userExists = await _checkUserExistsInFirestore(googleUser.email);
      
      if (userExists) {
        print('👤 Existing user detected: ${googleUser.email}');
        return await _handleExistingUserLogin(googleUser);
      } else {
        print('🆕 New user detected: ${googleUser.email}');
        return await _handleNewUserSignup(googleUser);
      }
    } catch (e) {
      print('❌ Error signing in with Google: $e');
      return null;
    }
  }

  /// Check if user exists by checking local storage for email
  Future<bool> _checkUserExistsInFirestore(String email) async {
    try {
      print('🔍 Checking if user exists locally for email: $email');
      
      // Check local storage for stored emails
      final storedEmails = await LocalStorageService.getStringList('registered_emails') ?? [];
      final exists = storedEmails.contains(email);
      
      print(exists ? '✅ User exists locally' : '❌ User not found locally');
      
      return exists;
    } catch (e) {
      print('❌ Error checking user existence: $e');
      return false; // Assume new user on error
    }
  }

  /// Store email in local storage for existence checking
  Future<void> _storeEmailLocally(String email) async {
    try {
      final storedEmails = await LocalStorageService.getStringList('registered_emails') ?? [];
      if (!storedEmails.contains(email)) {
        storedEmails.add(email);
        await LocalStorageService.setStringList('registered_emails', storedEmails);
        print('✅ Email stored locally: $email');
      }
    } catch (e) {
      print('❌ Error storing email locally: $e');
    }
  }

  /// Handle existing user login
  Future<User?> _handleExistingUserLogin(GoogleSignInAccount googleUser) async {
    try {
      print('🔄 Processing existing user login...');
      
      // Authenticate with Firebase
      final firebaseUser = await _authenticateWithFirebase(googleUser);
      if (firebaseUser == null) return null;

      // Update existing user profile with latest info
      await _updateExistingUserProfile(firebaseUser, googleUser);

      // Store user data locally
      await _storeUserLocally(firebaseUser);
      
      print('✅ Existing user login completed successfully');
      return firebaseUser;
    } catch (e) {
      print('❌ Error handling existing user login: $e');
      return null;
    }
  }

  /// Handle new user signup
  Future<User?> _handleNewUserSignup(GoogleSignInAccount googleUser) async {
    try {
      print('🔄 Processing new user signup...');
      
      // Authenticate with Firebase
      final firebaseUser = await _authenticateWithFirebase(googleUser);
      if (firebaseUser == null) return null;

      // Create comprehensive user profile for new user
      await _createNewUserProfile(firebaseUser, googleUser);

      // Store user data locally
      await _storeUserLocally(firebaseUser);
      
      print('✅ New user signup completed successfully');
      return firebaseUser;
    } catch (e) {
      print('❌ Error handling new user signup: $e');
      return null;
    }
  }

  /// Authenticate with Firebase using Google credentials
  Future<User?> _authenticateWithFirebase(GoogleSignInAccount googleUser) async {
    try {
      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final UserCredential userCredential = await _firebaseAuth.signInWithCredential(credential);
      final User? firebaseUser = userCredential.user;
      
      if (firebaseUser == null) {
        print('❌ Firebase authentication failed');
        return null;
      }

      print('✅ Firebase authentication successful: ${firebaseUser.uid}');
      return firebaseUser;
    } catch (e) {
      print('❌ Firebase authentication error: $e');
      return null;
    }
  }

  /// Create comprehensive user profile for new users
  Future<void> _createNewUserProfile(User firebaseUser, GoogleSignInAccount googleUser) async {
    try {
      print('🔄 Creating comprehensive user profile for new user...');
      
      // Generate custom user ID and virtual phone number
      final idService = IdGenerationService();
      final credentials = await idService.generateUserCredentials();
      final customUserId = credentials['userId']!;
      final virtualPhoneNumber = credentials['virtualNumber']!;
      
      print('✅ Generated custom user ID: $customUserId');
      print('✅ Generated virtual phone: $virtualPhoneNumber');
      
      // Create app user model with custom ID
      final appUser = await user_service.UserService.createUserFromGoogleData(
        firebaseUid: customUserId, // Use custom ID as the main ID
        email: firebaseUser.email ?? googleUser.email,
        displayName: firebaseUser.displayName ?? googleUser.displayName ?? '',
        photoURL: firebaseUser.photoURL ?? googleUser.photoUrl,
      );

      // Update with virtual phone number
      final updatedUser = appUser.copyWith(virtualNumber: virtualPhoneNumber);

      // Prepare comprehensive user data for Firestore (without email)
      final userData = {
        'id': customUserId,
        'firebaseUid': firebaseUser.uid, // Keep Firebase UID for auth reference
        // 'email': updatedUser.email, // REMOVED: Store email only locally
        'handle': updatedUser.handle,
        'fullName': updatedUser.fullName,
        'bio': updatedUser.bio,
        'profilePicture': updatedUser.profilePicture,
        'isDiscoverable': updatedUser.isDiscoverable,
        'status': updatedUser.status.toString().split('.').last,
        'virtualNumber': virtualPhoneNumber,
        'lastSeen': updatedUser.lastSeen?.toIso8601String(),
        'createdAt': updatedUser.createdAt.toIso8601String(),
        'updatedAt': updatedUser.updatedAt.toIso8601String(),
        'lastSignIn': DateTime.now().toIso8601String(),
        'provider': 'google',
        // Profile completion status
        'profileCompleted': false,
        'profileVersion': 1,
        // Google account info (without email)
        'googleAccountInfo': {
          'displayName': googleUser.displayName,
          'photoUrl': googleUser.photoUrl,
          // 'email': googleUser.email, // REMOVED: Store email only locally
        },
        // Device and app info
        'deviceInfo': {
          'platform': 'android',
          'createdFrom': 'mobile_app',
          'appVersion': '1.0.0',
        },
        // Privacy settings
        'privacySettings': {
          'showOnlineStatus': true,
          'allowDiscovery': updatedUser.isDiscoverable,
          'showLastSeen': true,
        },
        // Additional metadata
        'metadata': {
          'signUpMethod': 'google',
          'accountType': 'standard',
          'isVerified': true,
          'userType': 'new_signup',
        },
        // Signup tracking
        'signupMetadata': {
          'signupDate': DateTime.now().toIso8601String(),
          'signupMethod': 'google_oauth',
          'signupPlatform': 'android',
          'initialProfileComplete': false,
        },
      };

      // Store in Firestore using custom user ID as document ID
      await _firestore.collection('users').doc(customUserId).set(userData);

      // Store locally with custom user ID
      await user_service.UserService.setCurrentUser(updatedUser);
      
      // Store email locally for existence checking
      await _storeEmailLocally(updatedUser.email);
      
      // Store mapping from Firebase UID to custom user ID
      await LocalStorageService.setString('firebase_to_custom_id', '${firebaseUser.uid}:$customUserId');
      await LocalStorageService.setString('custom_user_id', customUserId);

      print('✅ Comprehensive user profile created for new user');
      print('📄 Custom ID: $customUserId');
      print('📞 Virtual Phone: $virtualPhoneNumber');
    } catch (e) {
      print('❌ Failed to create new user profile: $e');
      throw e;
    }
  }

  /// Update existing user profile for returning users
  Future<void> _updateExistingUserProfile(User firebaseUser, GoogleSignInAccount googleUser) async {
    try {
      print('🔄 Updating existing user profile for returning user...');
      
      // Get custom user ID from Firebase UID mapping
      final customUserId = await _getCustomUserIdFromFirebaseUid(firebaseUser.uid);
      
      if (customUserId == null) {
        print('⚠️ No custom user ID found, treating as new user');
        await _createNewUserProfile(firebaseUser, googleUser);
        return;
      }

      // Get existing user data from Firestore using custom ID
      final existingDoc = await _firestore.collection('users').doc(customUserId).get();
      
      if (!existingDoc.exists) {
        print('⚠️ User document not found, treating as new user');
        await _createNewUserProfile(firebaseUser, googleUser);
        return;
      }

      final existingData = existingDoc.data()!;
      
      // Update data for existing user
      final updateData = {
        'lastSignIn': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        
        // Update profile picture if changed
        if (firebaseUser.photoURL != null && firebaseUser.photoURL != existingData['profilePicture'])
          'profilePicture': firebaseUser.photoURL,
          
        // Update display name if changed
        if (firebaseUser.displayName != null && firebaseUser.displayName != existingData['fullName'])
          'fullName': firebaseUser.displayName,
          
        // Update Google account info
        'googleAccountInfo': {
          'displayName': googleUser.displayName,
          'photoUrl': googleUser.photoUrl,
          'email': googleUser.email,
          'lastUpdated': DateTime.now().toIso8601String(),
        },
        
        // Update device info
        'deviceInfo': {
          ...existingData['deviceInfo'] ?? {},
          'lastUpdatedFrom': 'mobile_app',
          'lastLoginPlatform': 'android',
          'lastLoginAt': DateTime.now().toIso8601String(),
        },
        
        // Update login tracking
        'loginMetadata': {
          'lastLoginMethod': 'google_oauth',
          'lastLoginPlatform': 'android',
          'lastLoginAt': DateTime.now().toIso8601String(),
          'loginCount': (existingData['loginMetadata']?['loginCount'] ?? 0) + 1,
        },
        
        // Update metadata
        'metadata': {
          ...existingData['metadata'] ?? {},
          'userType': 'returning_user',
          'lastActiveAt': DateTime.now().toIso8601String(),
        },
      };

      await _firestore.collection('users').doc(customUserId).update(updateData);

      print('✅ Existing user profile updated successfully');
      print('📄 Custom ID: $customUserId');
      
      final loginMetadata = updateData['loginMetadata'] as Map<String, dynamic>;
      print('🔢 Login count: ${loginMetadata['loginCount']}');
    } catch (e) {
      print('❌ Failed to update existing user profile: $e');
      // Don't throw here, as this is not critical for login
    }
  }

  /// Get custom user ID from Firebase UID
  Future<String?> _getCustomUserIdFromFirebaseUid(String firebaseUid) async {
    try {
      // Check local storage first
      final mapping = await LocalStorageService.getString('firebase_to_custom_id');
      if (mapping != null && mapping.contains(':')) {
        final parts = mapping.split(':');
        if (parts[0] == firebaseUid) {
          return parts[1];
        }
      }
      
      // Query Firestore for user with this Firebase UID
      final query = await _firestore
          .collection('users')
          .where('firebaseUid', isEqualTo: firebaseUid)
          .limit(1)
          .get();
      
      if (query.docs.isNotEmpty) {
        final customUserId = query.docs.first.id;
        // Store mapping locally for future use
        await LocalStorageService.setString('firebase_to_custom_id', '$firebaseUid:$customUserId');
        return customUserId;
      }
      
      return null;
    } catch (e) {
      print('❌ Error getting custom user ID: $e');
      return null;
    }
  }

  /// Store user data locally for offline access
  Future<void> _storeUserLocally(User firebaseUser) async {
    try {
      print('🔄 Storing user data locally...');
      
      // Get custom user ID
      final customUserId = await _getCustomUserIdFromFirebaseUid(firebaseUser.uid);
      
      if (customUserId == null) {
        print('⚠️ No custom user ID found during local storage');
        return;
      }
      
      // Get user data from Firestore using custom ID
      final userDoc = await _firestore.collection('users').doc(customUserId).get();
      
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        final appUser = app_user.User.fromJson(userData);
        await user_service.UserService.setCurrentUser(appUser);
        
        // Store authentication state and metadata
        await LocalStorageService.setString('firebase_uid', firebaseUser.uid);
        await LocalStorageService.setString('custom_user_id', customUserId);
        await LocalStorageService.setString('user_email', firebaseUser.email ?? '');
        await LocalStorageService.setString('last_login', DateTime.now().toIso8601String());
        await LocalStorageService.setString('user_type', userData['metadata']?['userType'] ?? 'unknown');
        
        // Only update profile_completed if it's not already true locally
        // This prevents overwriting local completion status with stale Firestore data
        final currentProfileCompleted = await LocalStorageService.getString('profile_completed');
        if (currentProfileCompleted != 'true') {
          await LocalStorageService.setString('profile_completed', (userData['profileCompleted'] ?? false).toString());
        } else {
          print('ℹ️ Profile already completed locally, keeping local status');
        }
        
        print('✅ User data and auth state stored locally');
        print('👤 Custom ID: $customUserId');
        print('👤 User type: ${userData['metadata']?['userType']}');
        print('✅ Profile completed: ${userData['profileCompleted']}');
      } else {
        print('⚠️ User document not found in Firestore during local storage');
      }
    } catch (e) {
      print('❌ Failed to store user data locally: $e');
    }
  }

  /// Sign out from both Google and Firebase
  Future<void> signOut() async {
    try {
      print('🔄 Signing out...');
      
      // Clear local user data and auth state
      await user_service.UserService.clearUserData();
      await LocalStorageService.remove('firebase_uid');
      await LocalStorageService.remove('user_email');
      await LocalStorageService.remove('last_login');
      await LocalStorageService.remove('current_user');
      
      // Sign out from Firebase and Google
      await Future.wait([
        _googleSignIn.signOut(),
        _firebaseAuth.signOut(),
      ]);
      
      print('✅ Sign out successful');
    } catch (e) {
      print('❌ Error signing out: $e');
      throw e;
    }
  }

  /// Check if user is currently signed in
  Future<bool> isSignedIn() async {
    try {
      final firebaseUser = _firebaseAuth.currentUser;
      
      // If Firebase user exists, we're signed in
      if (firebaseUser != null) {
        // Ensure local data is up to date
        await _storeUserLocally(firebaseUser);
        return true;
      }
      
      // Check if we have local auth data (fallback)
      final localUid = await LocalStorageService.getString('firebase_uid');
      return localUid != null;
    } catch (e) {
      print('Error checking sign-in status: $e');
      return false;
    }
  }

  /// Restore user session from local storage
  Future<app_user.User?> restoreUserSession() async {
    try {
      // Check if we have local user data
      final currentUserData = await LocalStorageService.getString('current_user');
      if (currentUserData != null) {
        final user = app_user.User.fromJsonString(currentUserData);
        print('✅ User session restored from local storage');
        return user;
      }
      
      // If Firebase user exists but no local data, fetch from Firestore
      final firebaseUser = _firebaseAuth.currentUser;
      if (firebaseUser != null) {
        await _storeUserLocally(firebaseUser);
        final restoredData = await LocalStorageService.getString('current_user');
        if (restoredData != null) {
          return app_user.User.fromJsonString(restoredData);
        }
      }
      
      return null;
    } catch (e) {
      print('❌ Failed to restore user session: $e');
      return null;
    }
  }

  /// Get current Google user
  GoogleSignInAccount? get currentGoogleUser => _googleSignIn.currentUser;

  /// Get current Firebase user
  User? get currentFirebaseUser => _firebaseAuth.currentUser;

  /// Stream of authentication state changes
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  /// Get user profile from Firestore
  Future<app_user.User?> getUserProfile(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return app_user.User.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      print('❌ Failed to get user profile: $e');
      return null;
    }
  }

  /// Update user profile in Firestore
  Future<bool> updateUserProfile(app_user.User user) async {
    try {
      print('🔄 Updating user profile in Firestore...');
      
      // Prepare comprehensive user data for Firestore
      final userData = {
        'id': user.id,
        'email': user.email,
        'handle': user.handle,
        'fullName': user.fullName,
        'bio': user.bio,
        'profilePicture': user.profilePicture,
        'isDiscoverable': user.isDiscoverable,
        'status': user.status.toString().split('.').last,
        'virtualNumber': user.virtualNumber,
        'lastSeen': user.lastSeen?.toIso8601String(),
        'createdAt': user.createdAt.toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        'lastSignIn': DateTime.now().toIso8601String(),
        'provider': 'google',
        // Additional profile metadata
        'profileCompleted': true,
        'profileVersion': 1,
        'deviceInfo': {
          'platform': 'android',
          'lastUpdatedFrom': 'mobile_app',
        },
      };

      // Update in Firestore
      await _firestore.collection('users').doc(user.id).set(
        userData,
        SetOptions(merge: true), // Merge with existing data
      );
      
      // Update locally as well
      final updatedUser = user.copyWith(updatedAt: DateTime.now());
      await user_service.UserService.setCurrentUser(updatedUser);
      
      print('✅ User profile updated in Firestore and locally');
      print('📄 Updated data: ${userData.keys.join(', ')}');
      
      return true;
    } catch (e) {
      print('❌ Failed to update user profile: $e');
      return false;
    }
  }
}