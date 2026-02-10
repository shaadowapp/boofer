import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../services/anonymous_auth_service.dart';
import '../services/local_storage_service.dart';

/// Provider that manages real user data from Firestore
class FirestoreUserProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AnonymousAuthService _authService = AnonymousAuthService();
  
  User? _currentUser;
  List<User> _allUsers = [];
  bool _isLoading = false;
  String? _error;
  
  StreamSubscription<DocumentSnapshot>? _currentUserSubscription;
  StreamSubscription<QuerySnapshot>? _allUsersSubscription;
  
  // Getters
  User? get currentUser => _currentUser;
  List<User> get allUsers => _allUsers;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasCurrentUser => _currentUser != null;
  
  /// Initialize the provider and start listening to user data
  Future<void> initialize() async {
    try {
      _setLoading(true);
      
      // Get current user ID from local storage (anonymous auth)
      final customUserId = await LocalStorageService.getString('custom_user_id');
      if (customUserId != null) {
        await _initializeCurrentUser(customUserId);
        _listenToCurrentUser(customUserId);
        _listenToAllUsers();
      }
      
      _setLoading(false);
      print('✅ FirestoreUserProvider initialized successfully');
    } catch (e) {
      _setError('Failed to initialize user provider: $e');
      print('❌ FirestoreUserProvider initialization failed: $e');
    }
  }
  
  /// Initialize current user from Firestore
  Future<void> _initializeCurrentUser(String customUserId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(customUserId).get();
      if (userDoc.exists) {
        _currentUser = User.fromJson(userDoc.data()!);
        
        // Also store locally for offline access
        await LocalStorageService.setString('current_user', _currentUser!.toJsonString());
        await LocalStorageService.setString('custom_user_id', customUserId);
        
        notifyListeners();
        print('✅ Current user loaded: ${_currentUser!.fullName} (ID: $customUserId)');
      }
    } catch (e) {
      print('❌ Failed to initialize current user: $e');
    }
  }

  /// Listen to real-time updates for current user
  void _listenToCurrentUser(String customUserId) {
    _currentUserSubscription?.cancel();
    
    _currentUserSubscription = _firestore
        .collection('users')
        .doc(customUserId)
        .snapshots()
        .listen(
      (snapshot) {
        if (snapshot.exists) {
          _currentUser = User.fromJson(snapshot.data()!);
          
          // Update local storage
          LocalStorageService.setString('current_user', _currentUser!.toJsonString());
          
          notifyListeners();
          print('🔄 Current user updated: ${_currentUser!.fullName}');
        }
      },
      onError: (error) {
        _setError('Failed to listen to current user: $error');
      },
    );
  }
  
  /// Listen to all users for discovery and search
  void _listenToAllUsers() {
    _allUsersSubscription?.cancel();
    
    _allUsersSubscription = _firestore
        .collection('users')
        .where('isDiscoverable', isEqualTo: true)
        .orderBy('fullName')
        .limit(100) // Limit for performance
        .snapshots()
        .listen(
      (snapshot) {
        _allUsers = snapshot.docs
            .map((doc) => User.fromJson(doc.data()))
            .toList();
        
        notifyListeners();
        print('🔄 All users updated: ${_allUsers.length} users');
      },
      onError: (error) {
        _setError('Failed to listen to all users: $error');
      },
    );
  }
  
  /// Update current user profile
  Future<bool> updateCurrentUser({
    String? fullName,
    String? handle,
    String? bio,
    String? profilePicture,
    bool? isDiscoverable,
  }) async {
    if (_currentUser == null) return false;
    
    try {
      _setLoading(true);
      
      final updateData = <String, dynamic>{
        'updatedAt': DateTime.now().toIso8601String(),
      };
      
      if (fullName != null) updateData['fullName'] = fullName;
      if (handle != null) updateData['handle'] = handle;
      if (bio != null) updateData['bio'] = bio;
      if (profilePicture != null) updateData['profilePicture'] = profilePicture;
      if (isDiscoverable != null) updateData['isDiscoverable'] = isDiscoverable;
      
      // Use the custom user ID (which is stored in _currentUser.id)
      await _firestore
          .collection('users')
          .doc(_currentUser!.id)
          .update(updateData);
      
      _setLoading(false);
      print('✅ User profile updated successfully (Custom ID: ${_currentUser!.id})');
      return true;
    } catch (e) {
      _setError('Failed to update user profile: $e');
      return false;
    }
  }
  
  /// Search users by name, handle, or virtual number
  Future<List<User>> searchUsers(String query, {String? currentUserId}) async {
    if (query.trim().isEmpty) return [];
    
    try {
      _setLoading(true);
      final queryLower = query.toLowerCase().trim();
      
      print('🔍 Searching users with query: "$query"');
      
      // Search by multiple fields
      final List<User> results = [];
      final Set<String> addedUserIds = {};
      
      // 1. Search by handle (prefix match)
      try {
        final handleQuery = await _firestore
            .collection('users')
            .where('handle', isGreaterThanOrEqualTo: queryLower)
            .where('handle', isLessThanOrEqualTo: '$queryLower\uf8ff')
            .limit(10)
            .get();
        
        for (final doc in handleQuery.docs) {
          // Skip current user
          if (currentUserId != null && doc.id == currentUserId) continue;
          
          if (!addedUserIds.contains(doc.id)) {
            results.add(User.fromFirestore(doc.data(), doc.id));
            addedUserIds.add(doc.id);
          }
        }
        print('✅ Found ${handleQuery.docs.length} users by handle');
      } catch (e) {
        print('⚠️ Handle search failed: $e');
      }
      
      // 2. Search by virtual number (exact match)
      if (query.contains('#') || query.contains('-')) {
        try {
          final virtualNumberQuery = await _firestore
              .collection('users')
              .where('virtualNumber', isEqualTo: query)
              .limit(5)
              .get();
          
          for (final doc in virtualNumberQuery.docs) {
            // Skip current user
            if (currentUserId != null && doc.id == currentUserId) continue;
            
            if (!addedUserIds.contains(doc.id)) {
              results.add(User.fromFirestore(doc.data(), doc.id));
              addedUserIds.add(doc.id);
            }
          }
          print('✅ Found ${virtualNumberQuery.docs.length} users by virtual number');
        } catch (e) {
          print('⚠️ Virtual number search failed: $e');
        }
      }
      
      // 3. Search by full name (get all users and filter - not ideal but works)
      try {
        final allUsersQuery = await _firestore
            .collection('users')
            .where('isDiscoverable', isEqualTo: true)
            .limit(50)
            .get();
        
        for (final doc in allUsersQuery.docs) {
          // Skip current user
          if (currentUserId != null && doc.id == currentUserId) continue;
          
          if (!addedUserIds.contains(doc.id)) {
            final user = User.fromFirestore(doc.data(), doc.id);
            if (user.fullName.toLowerCase().contains(queryLower)) {
              results.add(user);
              addedUserIds.add(doc.id);
            }
          }
        }
        print('✅ Searched ${allUsersQuery.docs.length} users for full name matches');
      } catch (e) {
        print('⚠️ Full name search failed: $e');
      }
      
      // 4. Also search in cached users
      for (final user in _cachedUsers.values) {
        if (user != null && !addedUserIds.contains(user.id)) {
          // Skip current user
          if (currentUserId != null && user.id == currentUserId) continue;
          
          if (user.handle.toLowerCase().contains(queryLower) ||
              user.fullName.toLowerCase().contains(queryLower) ||
              (user.virtualNumber?.contains(query) ?? false)) {
            results.add(user);
            addedUserIds.add(user.id);
          }
        }
      }
      
      _setLoading(false);
      print('✅ Total search results: ${results.length} (current user filtered)');
      return results;
      
    } catch (e) {
      _setError('Search failed: $e');
      return [];
    }
  }
  
  /// Get user by ID
  final Map<String, User?> _cachedUsers = {};
  
  Future<User?> getUserById(String userId) async {
    // Check cache first
    if (_cachedUsers.containsKey(userId)) {
      return _cachedUsers[userId];
    }
    
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      
      if (doc.exists) {
        final user = User.fromFirestore(doc.data()!, doc.id);
        _cachedUsers[userId] = user;
        return user;
      } else {
        _cachedUsers[userId] = null;
        return null;
      }
    } catch (e) {
      print('❌ Error getting user by ID $userId: $e');
      _cachedUsers[userId] = null;
      return null;
    }
  }
  
  /// Get user by handle
  Future<User?> getUserByHandle(String handle) async {
    try {
      // Check cache first
      final cachedUser = _allUsers.where((user) => user.handle == handle).firstOrNull;
      if (cachedUser != null) return cachedUser;
      
      // Fetch from Firestore
      final query = await _firestore
          .collection('users')
          .where('handle', isEqualTo: handle)
          .limit(1)
          .get();
      
      if (query.docs.isNotEmpty) {
        return User.fromJson(query.docs.first.data());
      }
      return null;
    } catch (e) {
      _setError('Failed to get user by handle: $e');
      return null;
    }
  }
  
  /// Get user by virtual number
  Future<User?> getUserByVirtualNumber(String virtualNumber) async {
    try {
      // Check cache first
      final cachedUser = _allUsers.where((user) => user.virtualNumber == virtualNumber).firstOrNull;
      if (cachedUser != null) return cachedUser;
      
      // Fetch from Firestore
      final query = await _firestore
          .collection('users')
          .where('virtualNumber', isEqualTo: virtualNumber)
          .limit(1)
          .get();
      
      if (query.docs.isNotEmpty) {
        return User.fromJson(query.docs.first.data());
      }
      return null;
    } catch (e) {
      _setError('Failed to get user by virtual number: $e');
      return null;
    }
  }
  
  /// Update user status (online/offline/away)
  Future<void> updateUserStatus(UserStatus status) async {
    if (_currentUser == null) return;
    
    try {
      await _firestore
          .collection('users')
          .doc(_currentUser!.id)
          .update({
        'status': status.toString().split('.').last,
        'lastSeen': status == UserStatus.offline ? DateTime.now().toIso8601String() : null,
        'updatedAt': DateTime.now().toIso8601String(),
      });
      
      print('✅ User status updated to: $status');
    } catch (e) {
      print('❌ Failed to update user status: $e');
    }
  }
  
  /// Get discoverable users for friend suggestions
  Future<List<User>> getDiscoverableUsers({int limit = 20}) async {
    try {
      final query = await _firestore
          .collection('users')
          .where('isDiscoverable', isEqualTo: true)
          .limit(limit)
          .get();

      final users = query.docs.map((doc) {
        final user = User.fromFirestore(doc.data(), doc.id);
        // Cache the user
        _cachedUsers[doc.id] = user;
        return user;
      }).toList();

      print('✅ Loaded ${users.length} discoverable users');
      return users;
    } catch (e) {
      print('❌ Error loading discoverable users: $e');
      return [];
    }
  }
  
  /// Clear user cache
  void clearUserCache() {
    _cachedUsers.clear();
  }
  
  /// Refresh current user data
  Future<void> refreshCurrentUser() async {
    final customUserId = await LocalStorageService.getString('custom_user_id');
    if (customUserId != null) {
      await _initializeCurrentUser(customUserId);
    }
  }
  
  /// Refresh all users data
  Future<void> refreshAllUsers() async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('isDiscoverable', isEqualTo: true)
          .orderBy('fullName')
          .limit(100)
          .get();
      
      _allUsers = snapshot.docs
          .map((doc) => User.fromJson(doc.data()))
          .toList();
      
      notifyListeners();
      print('✅ All users refreshed: ${_allUsers.length} users');
    } catch (e) {
      _setError('Failed to refresh users: $e');
    }
  }
  
  /// Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
  
  /// Set error state
  void _setError(String error) {
    _error = error;
    _isLoading = false;
    notifyListeners();
    print('❌ FirestoreUserProvider error: $error');
  }
  
  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
  
  @override
  void dispose() {
    _currentUserSubscription?.cancel();
    _allUsersSubscription?.cancel();
    super.dispose();
  }
}

extension _ListExtension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}