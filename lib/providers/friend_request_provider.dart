import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../models/friend_request_model.dart';
import '../services/friend_request_service.dart';

/// Provider for managing friend request system state (Instagram/Snapchat style)
class FriendRequestProvider extends ChangeNotifier {
  final FriendRequestService _friendRequestService = FriendRequestService.instance;

  // State
  String? _currentUserId;
  final Map<String, FriendRequest?> _friendRequestStatus = {};
  final Map<String, bool> _friendshipStatus = {};
  FriendRequestStats _stats = FriendRequestStats.empty();
  List<FriendRequest> _receivedRequests = [];
  List<FriendRequest> _sentRequests = [];
  final List<User> _friends = [];
  
  bool _isLoading = false;
  String? _error;

  // Stream subscriptions
  final Map<String, StreamSubscription> _subscriptions = {};

  // Getters
  String? get currentUserId => _currentUserId;
  bool get isLoading => _isLoading;
  String? get error => _error;
  FriendRequestStats get stats => _stats;
  List<FriendRequest> get receivedRequests => _receivedRequests;
  List<FriendRequest> get sentRequests => _sentRequests;
  List<User> get friends => _friends;

  /// Initialize the provider with current user
  void initialize(String userId) {
    if (_currentUserId == userId) return;
    
    _currentUserId = userId;
    _startListening();
    loadReceivedRequests();
    loadSentRequests();
  }

  /// Start real-time listeners
  void _startListening() {
    if (_currentUserId == null) return;
    
    _friendRequestService.listenToReceivedRequests(_currentUserId!);
    _friendRequestService.listenToSentRequests(_currentUserId!);
    _friendRequestService.listenToStats(_currentUserId!);
    
    // Listen to streams
    _subscriptions['received'] = _friendRequestService.receivedRequestsStream.listen((requests) {
      _receivedRequests = requests;
      notifyListeners();
    });
    
    _subscriptions['sent'] = _friendRequestService.sentRequestsStream.listen((requests) {
      _sentRequests = requests;
      notifyListeners();
    });
    
    _subscriptions['stats'] = _friendRequestService.statsStream.listen((stats) {
      _stats = stats;
      notifyListeners();
    });
  }

  /// Load received requests
  Future<void> loadReceivedRequests({bool refresh = false}) async {
    if (_currentUserId == null) return;
    
    if (refresh || _receivedRequests.isEmpty) {
      _setLoading(true);
      try {
        _receivedRequests = await _friendRequestService.getReceivedFriendRequests(
          userId: _currentUserId!,
        );
        _setError(null);
      } catch (e) {
        _setError('Failed to load received requests: $e');
        print('❌ Error getting received requests: $e');
      } finally {
        _setLoading(false);
      }
    }
  }

  /// Load sent requests
  Future<void> loadSentRequests({bool refresh = false}) async {
    if (_currentUserId == null) return;
    
    if (refresh || _sentRequests.isEmpty) {
      _setLoading(true);
      try {
        _sentRequests = await _friendRequestService.getSentFriendRequests(
          userId: _currentUserId!,
        );
        _setError(null);
      } catch (e) {
        _setError('Failed to load sent requests: $e');
        print('❌ Error getting sent requests: $e');
      } finally {
        _setLoading(false);
      }
    }
  }

  /// Send a friend request
  Future<bool> sendFriendRequest(String toUserId, {String? message}) async {
    if (_currentUserId == null) return false;
    
    _setLoading(true);
    try {
      final success = await _friendRequestService.sendFriendRequest(
        fromUserId: _currentUserId!,
        toUserId: toUserId,
        message: message,
      );
      
      if (success) {
        // Refresh sent requests
        await loadSentRequests(refresh: true);
      }
      
      _setError(null);
      return success;
    } catch (e) {
      _setError('Failed to send friend request: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Accept a friend request
  Future<bool> acceptFriendRequest(String requestId) async {
    if (_currentUserId == null) return false;
    
    _setLoading(true);
    try {
      final success = await _friendRequestService.acceptFriendRequest(
        requestId: requestId,
        userId: _currentUserId!,
      );
      
      if (success) {
        // Refresh received requests
        await loadReceivedRequests(refresh: true);
      }
      
      _setError(null);
      return success;
    } catch (e) {
      _setError('Failed to accept friend request: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Reject a friend request
  Future<bool> rejectFriendRequest(String requestId) async {
    if (_currentUserId == null) return false;
    
    _setLoading(true);
    try {
      final success = await _friendRequestService.rejectFriendRequest(
        requestId: requestId,
        userId: _currentUserId!,
      );
      
      if (success) {
        // Refresh received requests
        await loadReceivedRequests(refresh: true);
      }
      
      _setError(null);
      return success;
    } catch (e) {
      _setError('Failed to reject friend request: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Cancel a sent friend request
  Future<bool> cancelFriendRequest(String requestId) async {
    if (_currentUserId == null) return false;
    
    _setLoading(true);
    try {
      final success = await _friendRequestService.cancelFriendRequest(
        requestId: requestId,
        userId: _currentUserId!,
      );
      
      if (success) {
        // Refresh sent requests
        await loadSentRequests(refresh: true);
      }
      
      _setError(null);
      return success;
    } catch (e) {
      _setError('Failed to cancel friend request: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Check if users are friends
  Future<bool> areFriends(String userId1, String userId2) async {
    try {
      return await _friendRequestService.areFriends(
        userId1: userId1,
        userId2: userId2,
      );
    } catch (e) {
      return false;
    }
  }

  /// Get friend request status between users
  FriendRequest? getFriendRequestStatus(String userId) {
    return _friendRequestStatus[userId];
  }

  /// Check if user is a friend
  bool isFriend(String userId) {
    return _friendshipStatus[userId] ?? false;
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions.values) {
      subscription.cancel();
    }
    _subscriptions.clear();
    _friendRequestService.dispose();
    super.dispose();
  }

  /// Remove a friend (unfriend)
  Future<bool> removeFriend(String friendId) async {
    if (_currentUserId == null) return false;

    _setLoading(true);
    _clearError();

    try {
      // Remove friendship from both sides
      final success = await _friendRequestService.removeFriendship(
        userId: _currentUserId!,
        friendId: friendId,
      );

      if (success) {
        _friendshipStatus[friendId] = false;
        _friends.removeWhere((user) => user.id == friendId);
        notifyListeners();
      }

      return success;
    } catch (e) {
      _setError('Failed to remove friend: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Get relationship status with another user
  String getRelationshipStatus(String userId) {
    if (userId == _currentUserId) return 'self';
    if (_friendshipStatus[userId] == true) return 'friends';
    
    final sentRequest = _sentRequests.where((r) => r.toUserId == userId).firstOrNull;
    if (sentRequest != null) return 'pending_sent';
    
    final receivedRequest = _receivedRequests.where((r) => r.fromUserId == userId).firstOrNull;
    if (receivedRequest != null) return 'pending_received';
    
    return 'none';
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}