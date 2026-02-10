import 'dart:async';
import 'package:flutter/material.dart';
import '../core/error/error_handler.dart';
import '../services/user_service.dart';
import '../models/user_model.dart';

class UserProvider with ChangeNotifier {
  final UserService _userService;
  final ErrorHandler _errorHandler;
  
  List<User> _users = [];
  User? _currentUser;
  bool _isLoading = false;
  String? _error;
  
  List<User> get users => _users;
  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  StreamSubscription<List<User>>? _usersSubscription;
  
  UserProvider({
    required UserService userService,
    required ErrorHandler errorHandler,
  }) : _userService = userService, 
       _errorHandler = errorHandler {
    _initializeSubscriptions();
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
      await UserService.updateUser(user);
      if (_currentUser?.id == user.id) {
        _currentUser = user.copyWith(updatedAt: DateTime.now());
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
  
  void setCurrentUser(User? user) {
    _currentUser = user;
    notifyListeners();
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
    super.dispose();
  }
}