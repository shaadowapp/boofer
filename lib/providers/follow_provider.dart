import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../models/friend_request_model.dart';
import '../services/follow_service.dart';

/// Provider for managing friend request system state (Instagram/Snapchat style)
class FriendRequestProvider extends ChangeNotifier {
  final FriendRequestService _friendRequestService = FriendRequestService.instance;

  // State
  String? _currentUserId;
  final Map<String, bool> _followingStatus = {};
  final Map<String, FollowStats> _followStats = {};
  final Map<String, List<User>> _followersCache = {};
  final Map<String, List<User>> _followingCache = {};
  final Map<String, List<User>> _suggestedUsers = {};
  
  bool _isLoading = false;
  String? _error;

  // Stream subscriptions
  final Map<String, StreamSubscription> _subscriptions = {};

  // Getters
  String? get currentUserId => _currentUserId;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Check if current user follows another user
  bool isFollowing(String userId) {
    return _followingStatus[userId] ?? false;
  }

  /// Get follow stats for a user
  FollowStats? getFollowStats(String userId) {
    return _followStats[userId];
  }

  /// Get cached followers for a user
  List<User> getFollowers(String userId) {
    return _followersCache[userId] ?? [];
  }

  /// Get cached following for a user
  List<User> getFollowing(String userId) {
    return _followingCache[userId] ?? [];
  }

  /// Get suggested users to follow
  List<User> getSuggestedUsers() {
    return _suggestedUsers[_currentUserId] ?? [];
  }

  /// Initialize provider with current user
  Future<void> initialize(String userId) async {
    _currentUserId = userId;
    await _loadInitialData();
    _setupRealTimeListeners();
  }

  /// Follow a user
  Future<bool> followUser(String userId) async {
    if (_currentUserId == null) return false;

    _setLoading(true);
    _clearError();

    try {
      final success = await _followService.followUser(
        followerId: _currentUserId!,
        followingId: userId,
      );

      if (success) {
        _followingStatus[userId] = true;
        
        // Update local stats optimistically
        final currentStats = _followStats[_currentUserId!] ?? FollowStats.empty();
        _followStats[_currentUserId!] = currentStats.copyWith(
          followingCount: currentStats.followingCount + 1,
          lastUpdated: DateTime.now(),
        );

        final targetStats = _followStats[userId] ?? FollowStats.empty();
        _followStats[userId] = targetStats.copyWith(
          followersCount: targetStats.followersCount + 1,
          lastUpdated: DateTime.now(),
        );

        // Refresh following list
        await _loadFollowing(_currentUserId!);
        
        notifyListeners();
      }

      return success;
    } catch (e) {
      _setError('Failed to follow user: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Unfollow a user
  Future<bool> unfollowUser(String userId) async {
    if (_currentUserId == null) return false;

    _setLoading(true);
    _clearError();

    try {
      final success = await _followService.unfollowUser(
        followerId: _currentUserId!,
        followingId: userId,
      );

      if (success) {
        _followingStatus[userId] = false;
        
        // Update local stats optimistically
        final currentStats = _followStats[_currentUserId!] ?? FollowStats.empty();
        _followStats[_currentUserId!] = currentStats.copyWith(
          followingCount: (currentStats.followingCount - 1).clamp(0, double.infinity).toInt(),
          lastUpdated: DateTime.now(),
        );

        final targetStats = _followStats[userId] ?? FollowStats.empty();
        _followStats[userId] = targetStats.copyWith(
          followersCount: (targetStats.followersCount - 1).clamp(0, double.infinity).toInt(),
          lastUpdated: DateTime.now(),
        );

        // Refresh following list
        await _loadFollowing(_currentUserId!);
        
        notifyListeners();
      }

      return success;
    } catch (e) {
      _setError('Failed to unfollow user: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Toggle follow status for a user
  Future<bool> toggleFollow(String userId) async {
    if (isFollowing(userId)) {
      return await unfollowUser(userId);
    } else {
      return await followUser(userId);
    }
  }

  /// Load followers for a user
  Future<void> loadFollowers(String userId, {bool refresh = false}) async {
    if (!refresh && _followersCache.containsKey(userId)) return;

    _setLoading(true);
    _clearError();

    try {
      final followers = await _followService.getFollowers(userId: userId);
      _followersCache[userId] = followers;
      notifyListeners();
    } catch (e) {
      _setError('Failed to load followers: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Load following for a user
  Future<void> loadFollowing(String userId, {bool refresh = false}) async {
    await _loadFollowing(userId, refresh: refresh);
  }

  /// Load suggested users to follow
  Future<void> loadSuggestedUsers({bool refresh = false}) async {
    if (_currentUserId == null) return;
    if (!refresh && _suggestedUsers.containsKey(_currentUserId!)) return;

    _setLoading(true);
    _clearError();

    try {
      final suggested = await _followService.getSuggestedUsers(userId: _currentUserId!);
      _suggestedUsers[_currentUserId!] = suggested;
      notifyListeners();
    } catch (e) {
      _setError('Failed to load suggested users: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Load follow stats for a user
  Future<void> loadFollowStats(String userId, {bool refresh = false}) async {
    if (!refresh && _followStats.containsKey(userId)) return;

    try {
      final counts = await _followService.getFollowCounts(userId);
      _followStats[userId] = FollowStats(
        followersCount: counts['followers'] ?? 0,
        followingCount: counts['following'] ?? 0,
        mutualFollowsCount: 0, // Will be calculated separately if needed
        lastUpdated: DateTime.now(),
      );
      notifyListeners();
    } catch (e) {
      _setError('Failed to load follow stats: $e');
    }
  }

  /// Check follow status for multiple users
  Future<void> checkFollowStatus(List<String> userIds) async {
    if (_currentUserId == null) return;

    try {
      for (final userId in userIds) {
        final isFollowing = await _followService.isFollowing(
          followerId: _currentUserId!,
          followingId: userId,
        );
        _followingStatus[userId] = isFollowing;
      }
      notifyListeners();
    } catch (e) {
      _setError('Failed to check follow status: $e');
    }
  }

  /// Get mutual followers between current user and another user
  Future<List<User>> getMutualFollowers(String userId) async {
    if (_currentUserId == null) return [];

    try {
      return await _followService.getMutualFollowers(
        userId1: _currentUserId!,
        userId2: userId,
      );
    } catch (e) {
      _setError('Failed to get mutual followers: $e');
      return [];
    }
  }

  /// Remove a follower (block functionality)
  Future<bool> removeFollower(String followerId) async {
    if (_currentUserId == null) return false;

    _setLoading(true);
    _clearError();

    try {
      final success = await _followService.removeFollower(
        userId: _currentUserId!,
        followerId: followerId,
      );

      if (success) {
        // Update local stats
        final currentStats = _followStats[_currentUserId!] ?? FollowStats.empty();
        _followStats[_currentUserId!] = currentStats.copyWith(
          followersCount: (currentStats.followersCount - 1).clamp(0, double.infinity).toInt(),
          lastUpdated: DateTime.now(),
        );

        // Refresh followers list
        await loadFollowers(_currentUserId!, refresh: true);
        
        notifyListeners();
      }

      return success;
    } catch (e) {
      _setError('Failed to remove follower: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Batch follow multiple users
  Future<Map<String, bool>> batchFollowUsers(List<String> userIds) async {
    if (_currentUserId == null) return {};

    _setLoading(true);
    _clearError();

    try {
      final results = await _followService.batchFollowUsers(
        followerId: _currentUserId!,
        userIds: userIds,
      );

      // Update local status for successful follows
      for (final entry in results.entries) {
        if (entry.value) {
          _followingStatus[entry.key] = true;
        }
      }

      // Refresh data
      await _loadFollowing(_currentUserId!);
      await loadFollowStats(_currentUserId!, refresh: true);
      
      notifyListeners();
      return results;
    } catch (e) {
      _setError('Failed to batch follow users: $e');
      return {};
    } finally {
      _setLoading(false);
    }
  }

  // Private methods

  Future<void> _loadInitialData() async {
    if (_currentUserId == null) return;

    await Future.wait([
      _loadFollowing(_currentUserId!),
      loadFollowStats(_currentUserId!),
      loadSuggestedUsers(),
    ]);
  }

  Future<void> _loadFollowing(String userId, {bool refresh = false}) async {
    if (!refresh && _followingCache.containsKey(userId)) return;

    try {
      final following = await _followService.getFollowing(userId: userId);
      _followingCache[userId] = following;
      
      // Update following status for current user
      if (userId == _currentUserId) {
        for (final user in following) {
          _followingStatus[user.id] = true;
        }
      }
      
      notifyListeners();
    } catch (e) {
      _setError('Failed to load following: $e');
    }
  }

  void _setupRealTimeListeners() {
    if (_currentUserId == null) return;

    // Listen to follow counts
    _subscriptions['counts'] = _followService.listenToFollowCounts(_currentUserId!)?.listen(
      (counts) {
        _followStats[_currentUserId!] = FollowStats(
          followersCount: counts['followers'] ?? 0,
          followingCount: counts['following'] ?? 0,
          mutualFollowsCount: _followStats[_currentUserId!]?.mutualFollowsCount ?? 0,
          lastUpdated: DateTime.now(),
        );
        notifyListeners();
      },
    );

    // Listen to following changes
    _subscriptions['following'] = _followService.listenToFollowing(_currentUserId!)?.listen(
      (followingIds) async {
        // Refresh following list when changes occur
        await _loadFollowing(_currentUserId!, refresh: true);
      },
    );
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
    _followingStatus.clear();
    _followStats.clear();
    _followersCache.clear();
    _followingCache.clear();
    _suggestedUsers.clear();
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