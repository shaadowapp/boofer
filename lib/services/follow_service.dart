import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/friend_request_model.dart';
import '../core/error/error_handler.dart';
import '../core/models/app_error.dart';

/// Follow/Friend system service implementing Instagram/Snapchat-like patterns
class FriendRequestService {
  static FriendRequestService? _instance;
  static FriendRequestService get instance => _instance ??= FriendRequestService._internal();
  FriendRequestService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ErrorHandler _errorHandler = ErrorHandler();

  // Stream controllers for real-time updates
  final StreamController<List<FriendRequest>> _receivedRequestsController = StreamController<List<FriendRequest>>.broadcast();
  final StreamController<List<FriendRequest>> _sentRequestsController = StreamController<List<FriendRequest>>.broadcast();
  final StreamController<FriendRequestStats> _statsController = StreamController<FriendRequestStats>.broadcast();

  // Stream subscriptions
  final Map<String, StreamSubscription> _subscriptions = {};

  Stream<List<FriendRequest>> get receivedRequestsStream => _receivedRequestsController.stream;
  Stream<List<FriendRequest>> get sentRequestsStream => _sentRequestsController.stream;
  Stream<FriendRequestStats> get statsStream => _statsController.stream;

  /// Get suggested users for discovery
  Future<List<User>> getSuggestedUsers({int limit = 20}) async {
    try {
      print('🔍 Loading suggested users from Firestore...');
      
      final query = await _firestore
          .collection('users')
          .where('isDiscoverable', isEqualTo: true)
          .limit(limit)
          .get();

      final users = query.docs.map((doc) {
        final data = doc.data();
        return User.fromFirestore(data, doc.id);
      }).cast<User>().toList();

      print('✅ Loaded ${users.length} suggested users');
      return users;
    } catch (e) {
      print('❌ Error loading suggested users: $e');
      _errorHandler.handleError(AppError.service(
        message: 'Failed to load suggested users: $e',
        originalException: e is Exception ? e : Exception(e.toString()),
      ));
      return [];
    }
  }

  /// Get followers for a user
  Future<List<User>> getFollowers(String userId, {int limit = 50}) async {
    try {
      print('🔍 Loading followers for user: $userId');
      
      final query = await _firestore
          .collection('friends')
          .doc(userId)
          .collection('followers')
          .limit(limit)
          .get();

      final List<User> followers = [];
      for (final doc in query.docs) {
        final userData = await _firestore.collection('users').doc(doc.id).get();
        if (userData.exists) {
          followers.add(User.fromFirestore(userData.data()!, userData.id));
        }
      }

      print('✅ Loaded ${followers.length} followers');
      return followers;
    } catch (e) {
      print('❌ Error loading followers: $e');
      return [];
    }
  }

  /// Get following for a user
  Future<List<User>> getFollowing(String userId, {int limit = 50}) async {
    try {
      print('🔍 Loading following for user: $userId');
      
      final query = await _firestore
          .collection('friends')
          .doc(userId)
          .collection('following')
          .limit(limit)
          .get();

      final List<User> following = [];
      for (final doc in query.docs) {
        final userData = await _firestore.collection('users').doc(doc.id).get();
        if (userData.exists) {
          following.add(User.fromFirestore(userData.data()!, userData.id));
        }
      }

      print('✅ Loaded ${following.length} following');
      return following;
    } catch (e) {
      print('❌ Error loading following: $e');
      return [];
    }
  }

  /// Check if user is following another user
  Future<bool> isFollowing(String userId, String targetUserId) async {
    try {
      final doc = await _firestore
          .collection('friends')
          .doc(userId)
          .collection('following')
          .doc(targetUserId)
          .get();
      
      return doc.exists;
    } catch (e) {
      print('❌ Error checking follow status: $e');
      return false;
    }
  }

  /// Get follow stats for a user
  Future<FollowStats> getFollowStats(String userId) async {
    try {
      final followersQuery = await _firestore
          .collection('friends')
          .doc(userId)
          .collection('followers')
          .get();
      
      final followingQuery = await _firestore
          .collection('friends')
          .doc(userId)
          .collection('following')
          .get();

      return FollowStats(
        followersCount: followersQuery.docs.length,
        followingCount: followingQuery.docs.length,
      );
    } catch (e) {
      print('❌ Error getting follow stats: $e');
      return FollowStats(followersCount: 0, followingCount: 0);
    }
  }

  /// Send a friend request
  Future<bool> sendFriendRequest({
    required String fromUserId,
    required String toUserId,
    String? message,
  }) async {
    if (fromUserId == toUserId) {
      throw ArgumentError('User cannot send friend request to themselves');
    }

    try {
      return await _firestore.runTransaction((transaction) async {
        // Check if request already exists
        final existingRequest = await _firestore
            .collection('friend_requests')
            .where('fromUserId', isEqualTo: fromUserId)
            .where('toUserId', isEqualTo: toUserId)
            .where('status', isEqualTo: 'pending')
            .get();

        if (existingRequest.docs.isNotEmpty) {
          print('⚠️ Friend request already exists');
          return false;
        }

        // Create friend request
        final requestId = _firestore.collection('friend_requests').doc().id;
        final request = FriendRequest(
          id: requestId,
          fromUserId: fromUserId,
          toUserId: toUserId,
          message: message,
          status: FriendRequestStatus.pending,
          sentAt: DateTime.now(),
        );

        transaction.set(
          _firestore.collection('friend_requests').doc(requestId),
          request.toFirestore(),
        );

        // Add to sender's sent requests
        transaction.set(
          _firestore.collection('users').doc(fromUserId).collection('sent_requests').doc(requestId),
          {'requestId': requestId, 'toUserId': toUserId, 'createdAt': DateTime.now().toIso8601String()},
        );

        // Add to receiver's received requests
        transaction.set(
          _firestore.collection('users').doc(toUserId).collection('received_requests').doc(requestId),
          {'requestId': requestId, 'fromUserId': fromUserId, 'createdAt': DateTime.now().toIso8601String()},
        );

        print('✅ Friend request sent successfully');
        return true;
      });
    } catch (e) {
      print('❌ Error sending friend request: $e');
      _errorHandler.handleError(AppError.service(
        message: 'Failed to send friend request: $e',
        originalException: e is Exception ? e : Exception(e.toString()),
      ));
      return false;
    }
  }

  /// Accept a friend request
  Future<bool> acceptFriendRequest(String requestId) async {
    try {
      return await _firestore.runTransaction((transaction) async {
        final requestDoc = await transaction.get(
          _firestore.collection('friend_requests').doc(requestId)
        );

        if (!requestDoc.exists) {
          throw Exception('Friend request not found');
        }

        final request = FriendRequest.fromFirestore(requestDoc.data()!, requestDoc.id);
        
        if (request.status != FriendRequestStatus.pending) {
          throw Exception('Friend request is not pending');
        }

        // Update request status
        transaction.update(
          _firestore.collection('friend_requests').doc(requestId),
          {'status': 'accepted', 'updatedAt': DateTime.now().toIso8601String()},
        );

        // Create mutual friendship
        final friendshipData = {
          'createdAt': DateTime.now().toIso8601String(),
          'status': 'active',
        };

        transaction.set(
          _firestore.collection('friends').doc(request.fromUserId).collection('friends').doc(request.toUserId),
          friendshipData,
        );

        transaction.set(
          _firestore.collection('friends').doc(request.toUserId).collection('friends').doc(request.fromUserId),
          friendshipData,
        );

        // Clean up request references
        transaction.delete(
          _firestore.collection('users').doc(request.fromUserId).collection('sent_requests').doc(requestId)
        );
        transaction.delete(
          _firestore.collection('users').doc(request.toUserId).collection('received_requests').doc(requestId)
        );

        print('✅ Friend request accepted successfully');
        return true;
      });
    } catch (e) {
      print('❌ Error accepting friend request: $e');
      return false;
    }
  }

  /// Reject a friend request
  Future<bool> rejectFriendRequest(String requestId) async {
    try {
      return await _firestore.runTransaction((transaction) async {
        final requestDoc = await transaction.get(
          _firestore.collection('friend_requests').doc(requestId)
        );

        if (!requestDoc.exists) {
          throw Exception('Friend request not found');
        }

        final request = FriendRequest.fromFirestore(requestDoc.data()!, requestDoc.id);

        // Update request status
        transaction.update(
          _firestore.collection('friend_requests').doc(requestId),
          {'status': 'rejected', 'updatedAt': DateTime.now().toIso8601String()},
        );

        // Clean up request references
        transaction.delete(
          _firestore.collection('users').doc(request.fromUserId).collection('sent_requests').doc(requestId)
        );
        transaction.delete(
          _firestore.collection('users').doc(request.toUserId).collection('received_requests').doc(requestId)
        );

        print('✅ Friend request rejected successfully');
        return true;
      });
    } catch (e) {
      print('❌ Error rejecting friend request: $e');
      return false;
    }
  }

  /// Cancel a sent friend request
  Future<bool> cancelFriendRequest(String requestId) async {
    try {
      // Get the request first to get user IDs
      final requestDoc = await _firestore.collection('friend_requests').doc(requestId).get();
      if (!requestDoc.exists) {
        print('❌ Friend request not found');
        return false;
      }

      final request = FriendRequest.fromFirestore(requestDoc.data()!, requestDoc.id);

      // Delete the request in a transaction
      return await _firestore.runTransaction((transaction) async {
        // Delete from main collection
        transaction.delete(_firestore.collection('friend_requests').doc(requestId));
        
        // Delete from user subcollections
        transaction.delete(
          _firestore.collection('users').doc(request.fromUserId).collection('sent_requests').doc(requestId)
        );
        transaction.delete(
          _firestore.collection('users').doc(request.toUserId).collection('received_requests').doc(requestId)
        );

        print('✅ Friend request cancelled successfully');
        return true;
      });
    } catch (e) {
      print('❌ Error cancelling friend request: $e');
      return false;
    }
  }

  /// Get received friend requests
  Future<List<FriendRequest>> getReceivedRequests(String userId) async {
    try {
      final query = await _firestore
          .collection('friend_requests')
          .where('toUserId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .get();

      return query.docs.map((doc) => FriendRequest.fromFirestore(doc.data(), doc.id)).cast<FriendRequest>().toList();
    } catch (e) {
      print('❌ Error getting received requests: $e');
      return [];
    }
  }

  /// Get sent friend requests
  Future<List<FriendRequest>> getSentRequests(String userId) async {
    try {
      final query = await _firestore
          .collection('friend_requests')
          .where('fromUserId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .get();

      return query.docs.map((doc) => FriendRequest.fromFirestore(doc.data(), doc.id)).cast<FriendRequest>().toList();
    } catch (e) {
      print('❌ Error getting sent requests: $e');
      return [];
    }
  }

  /// Listen to received requests in real-time
  void listenToReceivedRequests(String userId) {
    _subscriptions['received_requests']?.cancel();
    _subscriptions['received_requests'] = _firestore
        .collection('friend_requests')
        .where('toUserId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      final requests = snapshot.docs.map((doc) => FriendRequest.fromFirestore(doc.data(), doc.id)).cast<FriendRequest>().toList();
      _receivedRequestsController.add(requests);
    });
  }

  /// Listen to sent requests in real-time
  void listenToSentRequests(String userId) {
    _subscriptions['sent_requests']?.cancel();
    _subscriptions['sent_requests'] = _firestore
        .collection('friend_requests')
        .where('fromUserId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      final requests = snapshot.docs.map((doc) => FriendRequest.fromFirestore(doc.data(), doc.id)).cast<FriendRequest>().toList();
      _sentRequestsController.add(requests);
    });
  }

  /// Listen to stats in real-time
  void listenToStats(String userId) {
    _subscriptions['stats']?.cancel();
    
    // Listen to received requests count
    _subscriptions['stats'] = _firestore
        .collection('friend_requests')
        .where('toUserId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) async {
      final receivedCount = snapshot.docs.length;
      
      // Get sent requests count
      final sentQuery = await _firestore
          .collection('friend_requests')
          .where('fromUserId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .get();
      
      final sentCount = sentQuery.docs.length;
      
      // Get friends count
      final friendsQuery = await _firestore
          .collection('friends')
          .doc(userId)
          .collection('friends')
          .get();
      
      final friendsCount = friendsQuery.docs.length;
      
      final stats = FriendRequestStats(
        pendingReceived: receivedCount,
        pendingSent: sentCount,
        totalFriends: friendsCount,
        lastUpdated: DateTime.now(),
      );
      
      _statsController.add(stats);
    });
  }

  /// Dispose resources
  void dispose() {
    for (final subscription in _subscriptions.values) {
      subscription.cancel();
    }
    _subscriptions.clear();
    
    _receivedRequestsController.close();
    _sentRequestsController.close();
    _statsController.close();
  }
}

/// Follow statistics model
class FollowStats {
  final int followersCount;
  final int followingCount;

  FollowStats({
    required this.followersCount,
    required this.followingCount,
  });
}