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
  List<User> _friends = [];
  
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

  /// Check if users are friends
  bool areFriends(String userId) {
    return _friendshipStatus[userId] ?? false;
  }

  /// Get friend request status with another user
  FriendRequest? getFriendRequestStatus(String userId) {
    return _friendRequestStatus[userId];
  }

  /// Check if current user can message another user (only friends can message)
  bool canMessage(String userId) {
    return areFriends(userId);
  }

  /// Get relationship status for UI display
  String getRelationshipStatus(String userId) {
    if (userId == _currentUserId) return 'self';
    
    if (areFriends(userId)) return 'friends';
    
    final request = getFriendRequestStatus(userId);
    if (request != null) {
      if (request.fromUserId == _currentUserId) {
        switch (request.status) {
          case FriendRequestStatus.pending:
            return 'request_sent';
          case FriendRequestStatus.rejected:
            return 'request_rejected';
          case FriendRequestStatus.cancelled:
            return 'request_cancelled';
          default:
            return 'none';
        }
      } else {
        switch (request.status) {
          case FriendRequestStatus.pending:
            return 'request_received';
          default:
            return 'none';
        }
      }
    }
    
    return 'none';
  }

  /// Initialize provider with current user
  Future<void> initialize(String userId) async {
    _currentUserId = userId;
    await _loadInitialData();
    _setupRealTimeListeners();
  }

  /// Send friend request
  Future<bool> sendFriendRequest(String userId, {String? message}) async {
    if (_currentUserId == null) return false;

    _setLoading(true);
    _clearError();

    try {
      final success = await _friendRequestService.sendFriendRequest(
        fromUserId: _currentUserId!,
        toUserId: userId,
        message: message,
      );

      if (success) {
        // Update local state optimistically
        final request = FriendRequest.create(
          fromUserId: _currentUserId!,
          toUserId: userId,
          message: message,
        );
        _friendRequestStatus[userId] = request;
        _sentRequests.add(request);
        
        // Update stats
        _stats = _stats.copyWith(
          pendingSent: _stats.pendingSent + 1,
          lastUpdated: DateTime.now(),
        );
        
        notifyListeners();
      }

      return success;
    } catch (e) {
      _setError('Failed to send friend request: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Accept friend request
  Future<bool> acceptFriendRequest(String requestId) async {
    if (_currentUserId == null) return false;

    _setLoading(true);
    _clearError();

    try {
      final success = await _friendRequestService.acceptFriendRequest(
        requestId: requestId,
        userId: _currentUserId!,
      );

      if (success) {
        // Find and update the request
        final requestIndex = _receivedRequests.indexWhere((r) => r.id == requestId);
        if (requestIndex != -1) {
          final request = _receivedRequests[requestIndex];
          _receivedRequests.removeAt(requestIndex);
          
          // Update friendship status
          _friendshipStatus[request.fromUserId] = true;
          
          // Update request status
          _friendRequestStatus[request.fromUserId] = request.copyWith(
            status: FriendRequestStatus.accepted,
            respondedAt: DateTime.now(),
          );
          
          // Update stats
          _stats = _stats.copyWith(
            pendingReceived: _stats.pendingReceived - 1,
            totalFriends: _stats.totalFriends + 1,
            lastUpdated: DateTime.now(),
          );
        }
        
        // Refresh friends list
        await _loadFriends();
        
        notifyListeners();
      }

      return success;
    } catch (e) {
      _setError('Failed to accept friend request: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Reject friend request
  Future<bool> rejectFriendRequest(String requestId) async {
    if (_currentUserId == null) return false;

    _setLoading(true);
    _clearError();

    try {
      final success = await _friendRequestService.rejectFriendRequest(
        requestId: requestId,
        userId: _currentUserId!,
      );

      if (success) {
        // Find and remove the request
        final requestIndex = _receivedRequests.indexWhere((r) => r.id == requestId);
        if (requestIndex != -1) {
          final request = _receivedRequests[requestIndex];
          _receivedRequests.removeAt(requestIndex);
          
          // Update request status
          _friendRequestStatus[request.fromUserId] = request.copyWith(
            status: FriendRequestStatus.rejected,
            respondedAt: DateTime.now(),
          );
          
          // Update stats
          _stats = _stats.copyWith(
            pendingReceived: _stats.pendingReceived - 1,
            lastUpdated: DateTime.now(),
          );
        }
        
        notifyListeners();
      }

      return success;
    } catch (e) {
      _setError('Failed to reject friend request: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Cancel sent friend request
  Future<bool> cancelFriendRequest(String requestId) async {
    if (_currentUserId == null) return false;

    _setLoading(true);
    _clearError();

    try {
      final success = await _friendRequestService.cancelFriendRequest(
        requestId: requestId,
        userId: _currentUserId!,
      );

      if (success) {
        // Find and remove the request
        final requestIndex = _sentRequests.indexWhere((r) => r.id == requestId);
        if (requestIndex != -1) {
          final request = _sentRequests[requestIndex];
          _sentRequests.removeAt(requestIndex);
          
          // Update request status
          _friendRequestStatus[request.toUserId] = request.copyWith(
            status: FriendRequestStatus.cancelled,
            respondedAt: DateTime.now(),
          );
          
          // Update stats
          _stats = _stats.copyWith(
            pendingSent: _stats.pendingSent - 1,
            lastUpdated: DateTime.now(),
          );
        }
        
        notifyListeners();
      }

      return success;
    } catch (e) {
      _setError('Failed to cancel friend request: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Remove friend (unfriend)
  Future<bool> removeFriend(String friendId) async {
    if (_currentUserId == null) return false;

    _setLoading(true);
    _clearError();

    try {
      final success = await _friendRequestService.removeFriend(
        userId: _currentUserId!,
        friendId: friendId,
      );

      if (success) {
        // Update local state
        _friendshipStatus[friendId] = false;
        _friends.removeWhere((friend) => friend.id == friendId);
        
        // Update stats
        _stats = _stats.copyWith(
          totalFriends: _stats.totalFriends - 1,
          lastUpdated: DateTime.now(),
        );
        
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

  /// Load received friend requests
  Future<void> loadReceivedRequests({bool refresh = false}) async {
    if (_currentUserId == null) return;
    if (!refresh && _receivedRequests.isNotEmpty) return;

    _setLoading(true);
    _clearError();

    try {
      final requests = await _friendRequestService.getReceivedFriendRequests(
        userId: _currentUserId!,
      );
      _receivedRequests = requests;
      notifyListeners();
    } catch (e) {
      _setError('Failed to load received requests: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Load sent friend requests
  Future<void> loadSentRequests({bool refresh = false}) async {
    if (_currentUserId == null) return;
    if (!refresh && _sentRequests.isNotEmpty) return;

    _setLoading(true);
    _clearError();

    try {
      final requests = await _friendRequestService.getSentFriendRequests(
        userId: _currentUserId!,
      );
      _sentRequests = requests;
      notifyListeners();
    } catch (e) {
      _setError('Failed to load sent requests: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Load friends list
  Future<void> loadFriends({bool refresh = false}) async {
    await _loadFriends(refresh: refresh);
  }

  /// Check friendship status for multiple users
  Future<void> checkFriendshipStatus(List<String> userIds) async {
    if (_currentUserId == null) return;

    try {
      for (final userId in userIds) {
        final areFriends = await _friendRequestService.areFriends(
          userId1: _currentUserId!,
          userId2: userId,
        );
        _friendshipStatus[userId] = areFriends;

        // Also check for pending requests
        final request = await _friendRequestService.getFriendRequestStatus(
          fromUserId: _currentUserId!,
          toUserId: userId,
        );
        if (request != null) {
          _friendRequestStatus[userId] = request;
        } else {
          // Check reverse direction
          final reverseRequest = await _friendRequestService.getFriendRequestStatus(
            fromUserId: userId,
            toUserId: _currentUserId!,
          );
          if (reverseRequest != null) {
            _friendRequestStatus[userId] = reverseRequest;
          }
        }
      }
      notifyListeners();
    } catch (e) {
      _setError('Failed to check friendship status: $e');
    }
  }

  // Private methods

  Future<void> _loadInitialData() async {
    if (_currentUserId == null) return;

    await Future.wait([
      _loadStats(),
      loadReceivedRequests(),
      loadSentRequests(),
      _loadFriends(),
    ]);
  }

  Future<void> _loadStats() async {
    if (_currentUserId == null) return;

    try {
      _stats = await _friendRequestService.getFriendRequestStats(_currentUserId!);
      notifyListeners();
    } catch (e) {
      _setError('Failed to load stats: $e');
    }
  }

  Future<void> _loadFriends({bool refresh = false}) async {
    if (_currentUserId == null) return;
    if (!refresh && _friends.isNotEmpty) return;

    try {
      _friends = await _friendRequestService.getFriends(userId: _currentUserId!);
      
      // Update friendship status for all friends
      for (final friend in _friends) {
        _friendshipStatus[friend.id] = true;
      }
      
      notifyListeners();
    } catch (e) {
      _setError('Failed to load friends: $e');
    }
  }

  void _setupRealTimeListeners() {
    if (_currentUserId == null) return;

    // Listen to stats changes
    _subscriptions['stats'] = _friendRequestService.statsStream.listen(
      (stats) {
        _stats = stats;
        notifyListeners();
      },
    );

    // Listen to received requests
    _subscriptions['received'] = _friendRequestService.receivedRequestsStream.listen(
      (requests) {
        _receivedRequests = requests;
        notifyListeners();
      },
    );

    // Listen to sent requests
    _subscriptions['sent'] = _friendRequestService.sentRequestsStream.listen(
      (requests) {
        _sentRequests = requests;
        notifyListeners();
      },
    );

    // Start the actual Firestore listeners
    _friendRequestService.listenToStats(_currentUserId!);
    _friendRequestService.listenToReceivedRequests(_currentUserId!);
    _friendRequestService.listenToSentRequests(_currentUserId!);
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }

  /// Clear all cached data
  void clearCache() {
    _friendRequestStatus.clear();
    _friendshipStatus.clear();
    _receivedRequests.clear();
    _sentRequests.clear();
    _friends.clear();
    _stats = FriendRequestStats.empty();
    notifyListeners();
  }

  @override
  void dispose() {
    // Cancel all subscriptions
    for (final subscription in _subscriptions.values) {
      subscription.cancel();
    }
    _subscriptions.clear();
    
    super.dispose();
  }
}