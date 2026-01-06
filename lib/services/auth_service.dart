import 'dart:async';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/database/database_manager.dart';
import '../core/models/app_error.dart';
import '../core/error/error_handler.dart';
import '../models/user_model.dart';

/// Privacy-first authentication service using virtual numbers and PINs
class AuthService {
  final DatabaseManager _database;
  final SharedPreferences _storage;
  final ErrorHandler _errorHandler;
  
  static const String _currentUserIdKey = 'current_user_id';
  static const String _userPinKey = 'user_pin';
  static const String _isFirstLaunchKey = 'is_first_launch';
  
  final StreamController<User?> _authStateController = StreamController<User?>.broadcast();
  Stream<User?> get authStateChanges => _authStateController.stream;
  
  User? _currentUser;
  User? get currentUser => _currentUser;
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;
  
  AuthService({
    required DatabaseManager database,
    required SharedPreferences storage,
    required ErrorHandler errorHandler,
  }) : _database = database, 
       _storage = storage,
       _errorHandler = errorHandler {
    _initializeAuth();
  }

  /// Generate a unique numeric user ID with current date
  /// Format: YYYYMMDDHHMMSS + 4-digit random number
  /// Example: 20250106143045 + 1234 = 202501061430451234
  static String _generateNumericUserId() {
    final now = DateTime.now();
    
    final dateTime = now.year.toString() +
        now.month.toString().padLeft(2, '0') +
        now.day.toString().padLeft(2, '0') +
        now.hour.toString().padLeft(2, '0') +
        now.minute.toString().padLeft(2, '0') +
        now.second.toString().padLeft(2, '0');
    
    final random = (now.millisecond * 10 + (now.microsecond % 10)).toString().padLeft(4, '0');
    
    return '$dateTime$random';
  }
  
  Future<void> _initializeAuth() async {
    try {
      print('AuthService: Initializing authentication...');
      final userId = _storage.getString(_currentUserIdKey);
      print('AuthService: Stored user ID: $userId');
      
      if (userId != null) {
        print('AuthService: Found stored user ID, querying database...');
        final results = await _database.query(
          'SELECT * FROM users WHERE id = ?',
          [userId],
        );
        
        print('AuthService: Database query results: ${results.length} rows');
        
        if (results.isNotEmpty) {
          _currentUser = User.fromJson(results.first);
          print('AuthService: User loaded: ${_currentUser?.handle}');
        } else {
          print('AuthService: No user found in database, clearing storage');
          await _storage.remove(_currentUserIdKey);
          await _storage.remove(_userPinKey);
          _currentUser = null;
        }
      } else {
        print('AuthService: No stored user ID, user not authenticated');
        _currentUser = null;
      }
      
      _isInitialized = true;
      _authStateController.add(_currentUser);
      print('AuthService: Authentication initialization completed, user: ${_currentUser?.handle ?? 'null'}');
    } catch (e, stackTrace) {
      print('AuthService: Error during initialization: $e');
      print('AuthService: Stack trace: $stackTrace');
      _errorHandler.handleError(AppError.authentication(
        message: 'Failed to initialize authentication: $e',
        stackTrace: stackTrace,
        originalException: e is Exception ? e : Exception(e.toString()),
      ));
      _currentUser = null;
      _isInitialized = true;
      _authStateController.add(null);
    }
  }
  
  /// Create new account with virtual number and PIN
  Future<User> createAccount({
    required String handle,
    required String pin,
    String? fullName,
    String? bio,
  }) async {
    try {
      // Validate handle
      if (!_isValidHandle(handle)) {
        throw AppError.validation(
          message: 'Invalid handle. Use only letters, numbers, and underscores.',
        );
      }
      
      // Check if handle is available
      final existingUser = await _getUserByHandle(handle);
      if (existingUser != null) {
        throw AppError.validation(
          message: 'Handle already taken. Please choose another one.',
        );
      }
      
      // Generate virtual number
      final virtualNumber = _generateVirtualNumber();
      
      // Create user
      final now = DateTime.now();
      final userId = _generateNumericUserId();
      
      final user = User(
        id: userId,
        virtualNumber: virtualNumber,
        handle: handle,
        fullName: fullName ?? '',
        bio: bio ?? '',
        isDiscoverable: true,
        createdAt: now,
        updatedAt: now,
        status: UserStatus.online,
      );
      
      // Save to database
      await _database.insert('users', user.toJson());
      
      // Save authentication data
      await _storage.setString(_currentUserIdKey, userId);
      await _storage.setString(_userPinKey, _hashPin(pin));
      await _storage.setBool(_isFirstLaunchKey, false);
      
      _currentUser = user;
      _authStateController.add(_currentUser);
      
      return user;
    } catch (e, stackTrace) {
      if (e is AppError) rethrow;
      
      _errorHandler.handleError(AppError.authentication(
        message: 'Failed to create account: $e',
        stackTrace: stackTrace,
        originalException: e is Exception ? e : Exception(e.toString()),
      ));
      rethrow;
    }
  }
  
  /// Sign in with virtual number/handle and PIN
  Future<User> signIn({
    required String identifier, // virtual number or handle
    required String pin,
  }) async {
    try {
      User? user;
      
      // Try to find user by virtual number or handle
      if (identifier.startsWith('+')) {
        user = await _getUserByVirtualNumber(identifier);
      } else {
        user = await _getUserByHandle(identifier);
      }
      
      if (user == null) {
        throw AppError.authentication(
          message: 'User not found. Please check your virtual number or handle.',
        );
      }
      
      // Verify PIN
      final storedPin = _storage.getString(_userPinKey);
      if (storedPin == null || storedPin != _hashPin(pin)) {
        throw AppError.authentication(
          message: 'Invalid PIN. Please try again.',
        );
      }
      
      // Update user status
      final updatedUser = user.copyWith(
        status: UserStatus.online,
        updatedAt: DateTime.now(),
      );
      
      await _database.update(
        'users',
        updatedUser.toJson(),
        where: 'id = ?',
        whereArgs: [user.id],
      );
      
      await _storage.setString(_currentUserIdKey, user.id);
      
      _currentUser = updatedUser;
      _authStateController.add(_currentUser);
      
      return updatedUser;
    } catch (e, stackTrace) {
      if (e is AppError) rethrow;
      
      _errorHandler.handleError(AppError.authentication(
        message: 'Sign in failed: $e',
        stackTrace: stackTrace,
        originalException: e is Exception ? e : Exception(e.toString()),
      ));
      rethrow;
    }
  }
  
  /// Change PIN
  Future<bool> changePin({
    required String currentPin,
    required String newPin,
  }) async {
    try {
      if (_currentUser == null) {
        throw AppError.authentication(message: 'Not authenticated');
      }
      
      // Verify current PIN
      final storedPin = _storage.getString(_userPinKey);
      if (storedPin == null || storedPin != _hashPin(currentPin)) {
        throw AppError.authentication(message: 'Current PIN is incorrect');
      }
      
      // Update PIN
      await _storage.setString(_userPinKey, _hashPin(newPin));
      return true;
    } catch (e, stackTrace) {
      if (e is AppError) rethrow;
      
      _errorHandler.handleError(AppError.authentication(
        message: 'Failed to change PIN: $e',
        stackTrace: stackTrace,
        originalException: e is Exception ? e : Exception(e.toString()),
      ));
      return false;
    }
  }
  
  /// Update user profile
  Future<User?> updateProfile({
    String? fullName,
    String? bio,
    bool? isDiscoverable,
    String? profilePicture,
  }) async {
    try {
      if (_currentUser == null) return null;
      
      final updatedUser = _currentUser!.copyWith(
        fullName: fullName,
        bio: bio,
        isDiscoverable: isDiscoverable,
        profilePicture: profilePicture,
        updatedAt: DateTime.now(),
      );
      
      await _database.update(
        'users',
        updatedUser.toJson(),
        where: 'id = ?',
        whereArgs: [_currentUser!.id],
      );
      
      _currentUser = updatedUser;
      _authStateController.add(_currentUser);
      
      return updatedUser;
    } catch (e, stackTrace) {
      _errorHandler.handleError(AppError.service(
        message: 'Failed to update profile: $e',
        stackTrace: stackTrace,
        originalException: e is Exception ? e : Exception(e.toString()),
      ));
      return null;
    }
  }
  
  /// Sign out
  Future<void> signOut() async {
    try {
      if (_currentUser != null) {
        // Update user status to offline
        final offlineUser = _currentUser!.copyWith(
          status: UserStatus.offline,
          lastSeen: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        await _database.update(
          'users',
          offlineUser.toJson(),
          where: 'id = ?',
          whereArgs: [_currentUser!.id],
        );
      }
      
      await _storage.remove(_currentUserIdKey);
      await _storage.remove(_userPinKey);
      
      _currentUser = null;
      _authStateController.add(null);
    } catch (e, stackTrace) {
      _errorHandler.handleError(AppError.authentication(
        message: 'Sign out failed: $e',
        stackTrace: stackTrace,
        originalException: e is Exception ? e : Exception(e.toString()),
      ));
    }
  }
  
  /// Check if this is first launch
  bool get isFirstLaunch => _storage.getBool(_isFirstLaunchKey) ?? true;
  
  /// Check if user is authenticated
  bool get isAuthenticated => _currentUser != null;
  
  /// Generate virtual phone number
  String _generateVirtualNumber() {
    final random = Random();
    final countryCode = '+1'; // US country code for simplicity
    final areaCode = 555; // Fake area code
    final number = random.nextInt(9000000) + 1000000; // 7-digit number
    return '$countryCode$areaCode$number';
  }
  
  /// Validate handle format
  bool _isValidHandle(String handle) {
    if (handle.length < 3 || handle.length > 20) return false;
    return RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(handle);
  }
  
  /// Hash PIN for storage (simple hash for demo)
  String _hashPin(String pin) {
    return pin.hashCode.toString();
  }
  
  /// Get user by virtual number
  Future<User?> _getUserByVirtualNumber(String virtualNumber) async {
    final results = await _database.query(
      'SELECT * FROM users WHERE virtual_number = ?',
      [virtualNumber],
    );
    
    if (results.isNotEmpty) {
      return User.fromJson(results.first);
    }
    return null;
  }
  
  /// Get user by handle
  Future<User?> _getUserByHandle(String handle) async {
    final results = await _database.query(
      'SELECT * FROM users WHERE handle = ?',
      [handle],
    );
    
    if (results.isNotEmpty) {
      return User.fromJson(results.first);
    }
    return null;
  }
  
  void dispose() {
    _authStateController.close();
  }
}