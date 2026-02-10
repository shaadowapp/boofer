import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/user_model.dart' as app_user;
import '../services/local_storage_service.dart';
import '../services/id_generation_service.dart';
import '../services/virtual_number_service.dart';
import 'user_service.dart' as user_service;

/// Privacy-focused anonymous authentication service
/// Creates users without requiring email or external auth providers
class AnonymousAuthService {
  static final AnonymousAuthService _instance = AnonymousAuthService._internal();
  factory AnonymousAuthService() => _instance;
  AnonymousAuthService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final IdGenerationService _idService = IdGenerationService();
  final VirtualNumberService _virtualNumberService = VirtualNumberService();
  final Random _random = Random();

  /// Create anonymous user with auto-generated profile
  /// REQUIRES INTERNET CONNECTION - Will fail if Firestore write fails
  Future<app_user.User?> createAnonymousUser() async {
    try {
      print('🔄 Creating anonymous user profile...');
      
      // Check internet connectivity first
      print('🔄 Checking internet connectivity...');
      final hasInternet = await _checkInternetConnectivity();
      if (!hasInternet) {
        print('❌ No internet connection - signup requires internet');
        throw Exception('Internet connection required for signup. Please check your connection and try again.');
      }
      print('✅ Internet connection verified');
      
      // Generate unique user ID and virtual phone number
      final credentials = await _idService.generateUserCredentials();
      final customUserId = credentials['userId']!;
      final virtualPhoneNumber = credentials['virtualNumber']!;
      
      print('✅ Generated custom user ID: $customUserId');
      print('✅ Generated virtual phone: $virtualPhoneNumber');
      
      // Generate random full name first
      final nameComponents = _generateRandomNameComponents();
      final firstName = nameComponents['firstName']!;
      final lastName = nameComponents['lastName']!;
      final fullName = '$firstName $lastName';
      
      // Generate userhandle from the same name components
      final username = _generateUserhandleFromName(firstName, lastName);
      
      print('✅ Generated full name: $fullName');
      print('✅ Generated userhandle: $username');
      
      // Create user model
      final now = DateTime.now();
      final appUser = app_user.User(
        id: customUserId,
        email: '', // No email for anonymous users
        handle: username,
        fullName: fullName,
        bio: _generateRandomBio(),
        profilePicture: _generateRandomAvatar(fullName),
        isDiscoverable: true,
        status: app_user.UserStatus.online,
        virtualNumber: virtualPhoneNumber,
        lastSeen: now,
        createdAt: now,
        updatedAt: now,
      );

      // Prepare user data for Firestore (no Firebase Auth, no email)
      final userData = {
        'id': customUserId,
        'handle': appUser.handle,
        'fullName': appUser.fullName,
        'bio': appUser.bio,
        'profilePicture': appUser.profilePicture,
        'isDiscoverable': appUser.isDiscoverable,
        'status': appUser.status.toString().split('.').last,
        'virtualNumber': virtualPhoneNumber,
        'lastSeen': appUser.lastSeen?.toIso8601String(),
        'createdAt': appUser.createdAt.toIso8601String(),
        'updatedAt': appUser.updatedAt.toIso8601String(),
        'lastSignIn': DateTime.now().toIso8601String(),
        'provider': 'anonymous',
        // Profile completion status
        'profileCompleted': true,
        'profileVersion': 1,
        // Device and app info
        'deviceInfo': {
          'platform': 'android',
          'createdFrom': 'mobile_app',
          'appVersion': '1.0.0',
        },
        // Privacy settings
        'privacySettings': {
          'showOnlineStatus': true,
          'allowDiscovery': true,
          'showLastSeen': true,
        },
        // Additional metadata
        'metadata': {
          'signUpMethod': 'anonymous',
          'accountType': 'anonymous',
          'isVerified': false,
          'userType': 'anonymous_user',
        },
        // Signup tracking
        'signupMetadata': {
          'signupDate': DateTime.now().toIso8601String(),
          'signupMethod': 'anonymous',
          'signupPlatform': 'android',
          'initialProfileComplete': true,
        },
      };

      // CRITICAL: Store in Firestore - MUST succeed for signup to complete
      print('🔄 Storing user data in Firestore (REQUIRED)...');
      print('📄 User ID: $customUserId');
      print('📄 Collection: users');
      
      try {
        await _firestore.collection('users').doc(customUserId).set(userData).timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            print('❌ Firestore write timeout after 15 seconds');
            throw TimeoutException('Firestore write timeout - please check your internet connection');
          },
        );
        print('✅ User data stored in Firestore successfully!');
        
        // Verify the write by reading it back
        print('🔄 Verifying Firestore write...');
        final verifyDoc = await _firestore.collection('users').doc(customUserId).get().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            print('❌ Firestore read verification timeout');
            throw TimeoutException('Failed to verify Firestore write');
          },
        );
        
        if (!verifyDoc.exists) {
          print('❌ Firestore verification failed - document does not exist');
          throw Exception('Failed to verify user creation in Firestore');
        }
        print('✅ Firestore write verified successfully!');
        
      } on FirebaseException catch (e) {
        print('❌ Firebase Exception: ${e.code} - ${e.message}');
        print('❌ Plugin: ${e.plugin}');
        if (e.code == 'permission-denied') {
          print('❌ PERMISSION DENIED: Firestore rules need to be deployed!');
          throw Exception('Firestore permission denied. Please contact support.');
        } else if (e.code == 'unavailable') {
          print('❌ Firestore unavailable - network issue');
          throw Exception('Unable to connect to server. Please check your internet connection.');
        }
        // Re-throw to prevent signup completion
        throw Exception('Failed to create profile in database: ${e.message}');
      } on TimeoutException catch (e) {
        print('❌ Timeout: ${e.message}');
        throw Exception('Connection timeout. Please check your internet and try again.');
      } catch (e) {
        print('❌ Failed to store in Firestore: $e');
        // Re-throw to prevent signup completion
        throw Exception('Failed to create profile: $e');
      }

      // Only store locally AFTER Firestore write succeeds
      print('🔄 Storing user data locally...');
      await user_service.UserService.setCurrentUser(appUser);
      
      // Store authentication state locally
      await LocalStorageService.setString('custom_user_id', customUserId);
      await LocalStorageService.setString('auth_method', 'anonymous');
      await LocalStorageService.setString('last_login', DateTime.now().toIso8601String());
      await LocalStorageService.setString('user_type', 'anonymous_user');
      await LocalStorageService.setString('profile_completed', 'true');
      await LocalStorageService.setString('firestore_synced', 'true'); // Mark as synced

      print('✅ Anonymous user profile created successfully');
      print('📄 Custom ID: $customUserId');
      print('📞 Virtual Phone: $virtualPhoneNumber');
      print('👤 Username: $username');
      print('👤 Full Name: $fullName');
      print('✅ Profile stored in both Firestore and local storage');
      
      return appUser;
    } catch (e) {
      print('❌ Failed to create anonymous user: $e');
      // Clean up any partial local data
      await _cleanupFailedSignup();
      return null;
    }
  }
  
  /// Check internet connectivity by attempting to reach Firestore
  Future<bool> _checkInternetConnectivity() async {
    try {
      // Try to read a small document or check Firestore connection
      await _firestore.collection('_connection_test').limit(1).get().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException('Connection check timeout');
        },
      );
      return true;
    } catch (e) {
      print('⚠️ Internet connectivity check failed: $e');
      return false;
    }
  }
  
  /// Clean up any partial data from failed signup
  Future<void> _cleanupFailedSignup() async {
    try {
      print('🔄 Cleaning up failed signup data...');
      await LocalStorageService.remove('custom_user_id');
      await LocalStorageService.remove('auth_method');
      await LocalStorageService.remove('last_login');
      await LocalStorageService.remove('user_type');
      await LocalStorageService.remove('profile_completed');
      await LocalStorageService.remove('current_user');
      await LocalStorageService.remove('firestore_synced');
      print('✅ Cleanup completed');
    } catch (e) {
      print('⚠️ Cleanup error: $e');
    }
  }

  /// Generate random name components (first and last name)
  Map<String, String> _generateRandomNameComponents() {
    final firstNames = [
      'Alex', 'Jordan', 'Taylor', 'Morgan', 'Casey', 'Riley', 'Avery', 'Quinn',
      'Skyler', 'Dakota', 'Sage', 'River', 'Phoenix', 'Rowan', 'Kai', 'Ash',
      'Blake', 'Cameron', 'Drew', 'Ellis', 'Finley', 'Gray', 'Harper', 'Indigo',
    ];
    
    final lastNames = [
      'Smith', 'Johnson', 'Williams', 'Brown', 'Jones', 'Garcia', 'Miller', 'Davis',
      'Rodriguez', 'Martinez', 'Hernandez', 'Lopez', 'Gonzalez', 'Wilson', 'Anderson',
      'Thomas', 'Taylor', 'Moore', 'Jackson', 'Martin', 'Lee', 'Walker', 'Hall',
    ];
    
    final firstName = firstNames[_random.nextInt(firstNames.length)];
    final lastName = lastNames[_random.nextInt(lastNames.length)];
    
    return {
      'firstName': firstName,
      'lastName': lastName,
    };
  }

  /// Generate userhandle from name components
  /// Example: "Finley Martin" -> "finleymartin" or "finley_martin" if taken
  String _generateUserhandleFromName(String firstName, String lastName) {
    // Convert to lowercase and combine
    final baseHandle = '${firstName.toLowerCase()}${lastName.toLowerCase()}';
    
    // Add random number suffix to ensure uniqueness
    final number = _random.nextInt(9999);
    
    return '$baseHandle$number';
  }

  /// Generate random bio
  String _generateRandomBio() {
    final bios = [
      'Privacy enthusiast 🔒',
      'Just here to chat 💬',
      'Anonymous but friendly 👋',
      'Keeping it private 🤫',
      'Secure messaging advocate 🛡️',
      'Privacy-first user 🔐',
      'Anonymous explorer 🌐',
      'Secure chatter 💬',
      'Privacy matters 🔒',
      'Anonymous by choice 🎭',
    ];
    
    return bios[_random.nextInt(bios.length)];
  }

  /// Generate random avatar URL (using UI Avatars service)
  String _generateRandomAvatar(String name) {
    // Use UI Avatars service for consistent avatar generation
    final encodedName = Uri.encodeComponent(name);
    final colors = ['3B82F6', '10B981', 'F59E0B', 'EF4444', '8B5CF6', 'EC4899'];
    final color = colors[_random.nextInt(colors.length)];
    
    return 'https://ui-avatars.com/api/?name=$encodedName&background=$color&color=fff&size=200&bold=true';
  }

  /// Check if user is currently signed in
  Future<bool> isSignedIn() async {
    try {
      final localUserId = await LocalStorageService.getString('custom_user_id');
      return localUserId != null;
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
      
      // Try to fetch from Firestore if we have user ID
      final userId = await LocalStorageService.getString('custom_user_id');
      if (userId != null) {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        if (userDoc.exists) {
          final user = app_user.User.fromJson(userDoc.data()!);
          await user_service.UserService.setCurrentUser(user);
          return user;
        }
      }
      
      return null;
    } catch (e) {
      print('❌ Failed to restore user session: $e');
      return null;
    }
  }

  /// Sign out and clear local data
  Future<void> signOut() async {
    try {
      print('🔄 Signing out...');
      
      // Clear local user data and auth state
      await user_service.UserService.clearUserData();
      await LocalStorageService.remove('custom_user_id');
      await LocalStorageService.remove('auth_method');
      await LocalStorageService.remove('last_login');
      await LocalStorageService.remove('current_user');
      await LocalStorageService.remove('profile_completed');
      
      print('✅ Sign out successful');
    } catch (e) {
      print('❌ Error signing out: $e');
      rethrow;
    }
  }

  /// Get user profile from Firestore
  Future<app_user.User?> getUserProfile(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
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
      
      final userData = {
        'id': user.id,
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
        'provider': 'anonymous',
        'profileCompleted': true,
        'profileVersion': 1,
        'deviceInfo': {
          'platform': 'android',
          'lastUpdatedFrom': 'mobile_app',
        },
      };

      await _firestore.collection('users').doc(user.id).set(
        userData,
        SetOptions(merge: true),
      );
      
      // Update locally as well
      final updatedUser = user.copyWith(updatedAt: DateTime.now());
      await user_service.UserService.setCurrentUser(updatedUser);
      
      print('✅ User profile updated successfully');
      return true;
    } catch (e) {
      print('❌ Failed to update user profile: $e');
      return false;
    }
  }
}
