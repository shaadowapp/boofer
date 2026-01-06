import 'dart:async';
import 'package:flutter/material.dart';
import '../core/error/error_handler.dart';
import '../services/user_service.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';

class UserProvider with ChangeNotifier {
  final UserService _userService;
  final AuthService _authService;
  final ErrorHandler _errorHandler;
  
  List<User> _users = [];
  User? _currentUser;
  bool _isLoading = false;
  String? _error;
  
  List<User> get users => _users;
  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _authService.isAuthenticated;
  
  StreamSubscription<List<User>>? _usersSubscription;
  StreamSubscription<User?>? _authSubscription;
  
  UserProvider({
    required UserService userService,
    required AuthService authService,
    required ErrorHandler errorHandler,
  }) : _userService = userService, 
       _authService = authService,
       _errorHandler = errorHandler {
    _initializeSubscriptions();
    _currentUser = _authService.currentUser;
  }
  
  void _initializeSubscriptions() {
    _usersSubscription = _userService.usersStream.listen(
      (users) {
        _users = users;
        _isLoading = false;
        _error = null;
        notifyListeners();
      },
      onError: (error) {
        _handleError(error);
      },
    );
    
    _authSubscription = _authService.authStateChanges.listen(
      (user) {
        _currentUser = user;
        notifyListeners();
      },
    );
  }
  
  Future<void> loadUsers() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      await _userService.loadUsers();
    } catch (e) {
      _handleError(e);
    }
  }
  
  Future<User?> getUser(String id) async {
    try {
      return await _userService.getUser(id);
    } catch (e) {
      _handleError(e);
      return null;
    }
  }
  
  Future<void> updateUser(User user) async {
    try {
      final updatedUser = await _userService.updateUser(user);
      if (_currentUser?.id == user.id) {
        _currentUser = updatedUser;
        notifyListeners();
      }
    } catch (e) {
      _handleError(e);
      rethrow;
    }
  }
  
  Future<List<User>> searchUsers(String query) async {
    try {
      final result = await _userService.searchUsers(query);
      return result.cast<User>();
    } catch (e) {
      _handleError(e);
      return <User>[];
    }
  }
  
  Future<void> updateUserStatus(UserStatus status) async {
    if (_currentUser == null) return;
    
    try {
      await _userService.updateUserStatus(_currentUser!.id, status);
    } catch (e) {
      _handleError(e);
    }
  }
  
  Future<User> createAccount({
    required String handle,
    required String pin,
    String? fullName,
    String? bio,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final user = await _authService.createAccount(
        handle: handle,
        pin: pin,
        fullName: fullName,
        bio: bio,
      );
      _currentUser = user;
      return user;
    } catch (e) {
      _handleError(e);
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<User> signIn({
    required String identifier,
    required String pin,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final user = await _authService.signIn(
        identifier: identifier,
        pin: pin,
      );
      _currentUser = user;
      return user;
    } catch (e) {
      _handleError(e);
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<bool> changePin({
    required String currentPin,
    required String newPin,
  }) async {
    try {
      return await _authService.changePin(
        currentPin: currentPin,
        newPin: newPin,
      );
    } catch (e) {
      _handleError(e);
      return false;
    }
  }
  
  Future<void> updateProfile({
    String? fullName,
    String? bio,
    bool? isDiscoverable,
    String? profilePicture,
  }) async {
    try {
      final updatedUser = await _authService.updateProfile(
        fullName: fullName,
        bio: bio,
        isDiscoverable: isDiscoverable,
        profilePicture: profilePicture,
      );
      if (updatedUser != null) {
        _currentUser = updatedUser;
        notifyListeners();
      }
    } catch (e) {
      _handleError(e);
      rethrow;
    }
  }
  
  Future<void> signOut() async {
    try {
      await _authService.signOut();
      _currentUser = null;
      _users.clear();
      notifyListeners();
    } catch (e) {
      _handleError(e);
    }
  }
  
  void _handleError(dynamic error) {
    _isLoading = false;
    _error = error.toString();
    _errorHandler.handleError(error);
    notifyListeners();
  }
  
  void clearError() {
    _error = null;
    notifyListeners();
  }
  
  @override
  void dispose() {
    _usersSubscription?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }
}