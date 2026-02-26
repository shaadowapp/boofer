import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:collection';
import 'package:sqflite/sqflite.dart';
import '../core/database/database_manager.dart';
import '../core/models/app_error.dart';
import '../core/error/error_handler.dart';
import '../models/user_model.dart';
import 'local_storage_service.dart';
import 'profile_picture_service.dart';

/// Privacy-focused user service for local user management
class UserService {
  static UserService? _instance;
  static UserService get instance => _instance ??= UserService._internal();

  final DatabaseManager _database;
  final ErrorHandler _errorHandler;

  UserService._internal()
    : _database = DatabaseManager.instance,
      _errorHandler = ErrorHandler();

  // Named constructor for dependency injection
  UserService({
    required DatabaseManager database,
    required ErrorHandler errorHandler,
  }) : _database = database,
       _errorHandler = errorHandler;
  
  // LRU cache with size limit to prevent memory leaks
  static const int _maxCacheSize = 1000;
  final LinkedHashMap<String, User> _cache = LinkedHashMap();
  final StreamController<List<User>> _usersController =
      StreamController<List<User>>.broadcast();

  Stream<List<User>> get usersStream => _usersController.stream;

  /// Add user to cache with LRU eviction
  void _addToCache(String id, User user) {
    if (_cache.length >= _maxCacheSize) {
      _cache.remove(_cache.keys.first); // Remove oldest entry
    }
    _cache[id] = user;
  }

  // Static methods for backward compatibility
  static Future<String?> getUserEmail() async {
    final currentUser = await instance._getCurrentUser();
    return currentUser?.email;
  }

  static Future<User?> getCurrentUser() async {
    return await instance._getCurrentUser();
  }

  static Future<void> updateUser(User user) async {
    await instance._updateUserInternal(user);
  }

  static Future<void> clearUserData() async {
    await instance._clearUserData();
  }

  static Future<bool> isOnboarded() async {
    return await LocalStorageService.isOnboardingCompleted();
  }

  /// Get user's virtual number
  static Future<String?> getUserNumber() async {
    final currentUser = await instance._getCurrentUser();
    return currentUser?.virtualNumber ??
        await LocalStorageService.getVirtualNumber();
  }

  /*
  /// Create user from Google account data
  static Future<User> createUserFromGoogleData({
    required String firebaseUid,
    required String email,
    required String displayName,
    String? photoURL,
  }) async {
    final now = DateTime.now();

    // Generate a handle from display name or email
    String handle =
        _generateHandleFromName(displayName) ?? _generateHandleFromEmail(email);

    // Ensure handle is unique
    handle = await _ensureUniqueHandle(handle);

    // Generate Virtual Number
    final virtualNumber = await VirtualNumberService()
        .generateAndAssignVirtualNumber(firebaseUid);

    return User(
      id: firebaseUid, // This will be the custom user ID passed from GoogleAuthService
      email: email,
      handle: handle,
      fullName: displayName.isNotEmpty ? displayName : email.split('@').first,
      bio: 'Hey there! I\'m using Boofer 👋',
      isDiscoverable: true,
      status: UserStatus.online,
      profilePicture: photoURL,
      virtualNumber: virtualNumber,
      createdAt: now,
      updatedAt: now,
    );
  }
  */

  /// Generate a unique numeric user ID with current date
  /// Format: YYYYMMDDHHMMSS + 4-digit random number
  /// Example: 20250106143045 + 1234 = 202501061430451234
  static String _generateNumericUserId() {
    final now = DateTime.now();

    final dateTime =
        now.year.toString() +
        now.month.toString().padLeft(2, '0') +
        now.day.toString().padLeft(2, '0') +
        now.hour.toString().padLeft(2, '0') +
        now.minute.toString().padLeft(2, '0') +
        now.second.toString().padLeft(2, '0');

    final random = (now.millisecond * 10 + (now.microsecond % 10))
        .toString()
        .padLeft(4, '0');

    return '$dateTime$random';
  }

  /// Get current user from Firebase Auth or local storage
  Future<User?> _getCurrentUser() async {
    try {
      // First check if we have a stored user from Firebase Auth
      final storedUserData = await LocalStorageService.getString(
        'current_user',
      );
      if (storedUserData != null) {
        return User.fromJsonString(storedUserData);
      }

      // Fallback to onboarding data for backward compatibility
      final onboardingData = await LocalStorageService.getOnboardingData();
      if (onboardingData != null && onboardingData.completed) {
        // Create a User object from onboarding data (legacy support)
        return User(
          id: _generateNumericUserId(), // Generate numeric ID for legacy users
          handle: onboardingData.userName,
          fullName: onboardingData.userName,
          email:
              '${onboardingData.userName}@legacy.local', // Placeholder email for legacy users
          bio: 'Hey there! I\'m using Boofer 👋',
          isDiscoverable: true,
          status: UserStatus.online,
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
          updatedAt: DateTime.now(),
        );
      }

      return null;
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        AppError.service(
          message: 'Failed to get current user: $e',
          stackTrace: stackTrace,
          originalException: e is Exception ? e : Exception(e.toString()),
        ),
      );
      return null;
    }
  }

  /// Store current user data
  static Future<void> setCurrentUser(User user) async {
    await LocalStorageService.setString('current_user', user.toJsonString());

    // Also update profile picture service and dedicated storage key
    final ProfilePictureService profilePictureService =
        ProfilePictureService.instance;
    await profilePictureService.updateProfilePicture(user.profilePicture);

    debugPrint('✅ User stored with profile picture: ${user.profilePicture}');
  }

  /// Clear user data
  Future<void> _clearUserData() async {
    try {
      _cache.clear();
      // Clear stored user session data
      await LocalStorageService.remove('current_user');
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        AppError.service(
          message: 'Failed to clear user data: $e',
          stackTrace: stackTrace,
          originalException: e is Exception ? e : Exception(e.toString()),
        ),
      );
    }
  }

  /// Update user (private method)
  Future<User?> _updateUserInternal(User user) async {
    try {
      final updatedUser = user.copyWith(updatedAt: DateTime.now());

      await _database.update(
        'users',
        updatedUser.toDatabaseJson(),
        where: 'id = ?',
        whereArgs: [user.id],
      );

      _addToCache(user.id, updatedUser);
      await loadUsers(); // Refresh the stream

      return updatedUser;
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        AppError.database(
          message: 'Failed to update user: $e',
          stackTrace: stackTrace,
          originalException: e is Exception ? e : Exception(e.toString()),
        ),
      );
      return null;
    }
  }

  Future<void> loadUsers() async {
    try {
      final results = await _database.query(
        'SELECT * FROM users ORDER BY full_name, handle',
      );
      final users = results.map((json) => User.fromJson(json)).toList();

      // Update cache
      _cache.clear();
      for (final user in users) {
        _addToCache(user.id, user);
      }

      _usersController.add(users);
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        AppError.database(
          message: 'Failed to load users: $e',
          stackTrace: stackTrace,
          originalException: e is Exception ? e : Exception(e.toString()),
        ),
      );
    }
  }

  /// Get user by ID
  Future<User?> getUser(String id) async {
    // Check cache first
    if (_cache.containsKey(id)) {
      return _cache[id];
    }

    try {
      final results = await _database.query(
        'SELECT * FROM users WHERE id = ?',
        [id],
      );

      if (results.isNotEmpty) {
        final user = User.fromJson(results.first);
        _addToCache(id, user);
        return user;
      }

      return null;
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        AppError.database(
          message: 'Failed to get user: $e',
          stackTrace: stackTrace,
          originalException: e is Exception ? e : Exception(e.toString()),
        ),
      );
      return null;
    }
  }

  /// Get user by handle
  Future<User?> getUserByHandle(String handle) async {
    try {
      final results = await _database.query(
        'SELECT * FROM users WHERE handle = ?',
        [handle],
      );

      if (results.isNotEmpty) {
        final user = User.fromJson(results.first);
        _addToCache(user.id, user);
        return user;
      }

      return null;
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        AppError.database(
          message: 'Failed to get user by handle: $e',
          stackTrace: stackTrace,
          originalException: e is Exception ? e : Exception(e.toString()),
        ),
      );
      return null;
    }
  }

  /// Get user by virtual number
  Future<User?> getUserByVirtualNumber(String number) async {
    try {
      final results = await _database.query(
        'SELECT * FROM users WHERE virtual_number = ?',
        [number],
      );

      if (results.isNotEmpty) {
        final user = User.fromJson(results.first);
        _addToCache(user.id, user);
        return user;
      }

      return null;
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        AppError.database(
          message: 'Failed to get user by virtual number: $e',
          stackTrace: stackTrace,
          originalException: e is Exception ? e : Exception(e.toString()),
        ),
      );
      return null;
    }
  }

  /// Get user by email
  Future<User?> getUserByEmail(String email) async {
    try {
      final results = await _database.query(
        'SELECT * FROM users WHERE email = ?',
        [email],
      );

      if (results.isNotEmpty) {
        final user = User.fromJson(results.first);
        _addToCache(user.id, user);
        return user;
      }

      return null;
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        AppError.database(
          message: 'Failed to get user by email: $e',
          stackTrace: stackTrace,
          originalException: e is Exception ? e : Exception(e.toString()),
        ),
      );
      return null;
    }
  }

  /// Get all cached users
  List<User> getAllUsers() => _cache.values.toList().cast<User>();

  /// Insert or update user
  Future<bool> insertUser(User user) async {
    try {
      await _database.insert(
        'users',
        user.toDatabaseJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      _addToCache(user.id, user);
      await loadUsers(); // Refresh the stream
      return true;
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        AppError.database(
          message: 'Failed to insert user: $e',
          stackTrace: stackTrace,
          originalException: e is Exception ? e : Exception(e.toString()),
        ),
      );
      return false;
    }
  }

  /// Search users by handle or email
  Future<List<User>> searchUsers(String query) async {
    try {
      if (query.isEmpty) return <User>[];

      final results = await _database.query(
        '''
        SELECT * FROM users 
        WHERE (handle LIKE ? OR email LIKE ? OR full_name LIKE ?) 
        AND is_discoverable = 1
        ORDER BY 
          CASE 
            WHEN handle = ? THEN 1
            WHEN email = ? THEN 2
            WHEN handle LIKE ? THEN 3
            WHEN email LIKE ? THEN 4
            ELSE 5
          END
        LIMIT 20
        ''',
        [
          '%$query%', '%$query%', '%$query%', // LIKE searches
          query, query, // Exact matches (highest priority)
          '$query%', '$query%', // Starts with (second priority)
        ],
      );

      final users = results.map((json) => User.fromJson(json)).toList();
      return users.cast<User>();
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        AppError.database(
          message: 'Failed to search users: $e',
          stackTrace: stackTrace,
          originalException: e is Exception ? e : Exception(e.toString()),
        ),
      );
      return <User>[];
    }
  }

  /// Update user status
  Future<void> updateUserStatus(String userId, UserStatus status) async {
    try {
      final user = await getUser(userId);
      if (user != null) {
        final updatedUser = user.copyWith(
          status: status,
          lastSeen: status == UserStatus.offline ? DateTime.now() : null,
          updatedAt: DateTime.now(),
        );

        await UserService.updateUser(updatedUser);
      }
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        AppError.database(
          message: 'Failed to update user status: $e',
          stackTrace: stackTrace,
          originalException: e is Exception ? e : Exception(e.toString()),
        ),
      );
    }
  }

  /// Get discoverable users
  Future<List<User>> getDiscoverableUsers({int limit = 20}) async {
    try {
      final results = await _database.query(
        '''
        SELECT * FROM users 
        WHERE is_discoverable = 1
        ORDER BY RANDOM()
        LIMIT ?
        ''',
        [limit],
      );

      final users = results.map((json) => User.fromJson(json)).toList();
      return users.cast<User>();
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        AppError.database(
          message: 'Failed to get discoverable users: $e',
          stackTrace: stackTrace,
          originalException: e is Exception ? e : Exception(e.toString()),
        ),
      );
      return <User>[];
    }
  }

  /// Check if handle is available
  Future<bool> isHandleAvailable(String handle) async {
    final user = await getUserByHandle(handle);
    return user == null;
  }

  /// Check if email exists
  Future<bool> emailExists(String email) async {
    final user = await getUserByEmail(email);
    return user != null;
  }

  void dispose() {
    _usersController.close();
  }
}
