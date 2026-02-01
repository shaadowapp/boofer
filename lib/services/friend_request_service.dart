import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/friend_request_model.dart';
import '../core/error/error_handler.dart';
import '../core/models/app_error.dart';

/// Friend Request system service implementing Instagram/Snapchat-like patterns
/// 
/// Data Model:
/// - friend_requests/{requestId} - Individual friend requests
/// - users/{userId}/sent_requests/{requestId} - Outgoing requests
/// - users/{userId}/received_requests/{requestId} - Incoming requests
/// - friends/{userId}/friends/{friendId} - Mutual friendships
/// - users/{userId} - User document with friend counts
/// 
/// Flow:
/// 1. Send friend request → Creates pending request
/// 2. Receive notification → Shows in friend requests screen
/// 3. Accept/Reject → Becomes friends or gets rejected
/// 4. Only friends can message each other
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

  Stream<List<FriendRequest>> get receivedRequestsStream => _receivedRequestsController.stream;
  Stream<List<FriendRequest>> get sentRequestsStream => _sentRequestsController.stream;
  Stream<FriendRequestStats> get statsStream => _statsController.stream;

  /// Send a friend request (like Instagram/Snapchat)
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
        // Check if already friends
        final friendshipDoc = await transaction.get(
          _firestore.collection('friends').doc(fromUserId).collection('friends').doc(toUserId)
        );
        
        if (friendshipDoc.exists) {
          return false; // Already friends
        }

        // Check if request already exists
        final existingRequestQuery = await _firestore
            .collection('friend_requests')
            .where('fromUserId', isEqualTo: fromUserId)
            .where('toUserId', isEqualTo: toUserId)
            .where('status', isEqualTo: 'pending')
            .get();

        if (existingRequestQuery.docs.isNotEmpty) {
          return false; // Request already sent
        }

        // Create friend request
        final request = FriendRequest.create(
          fromUserId: fromUserId,
          toUserId: toUserId,
          message: message ?? 'Hi! I\'d like to be friends.',
        );

        // Save main request document
        transaction.set(
          _firestore.collection('friend_requests').doc(request.id),
          request.toJson(),
        );

        // Add to sender's sent requests
        transaction.set(
          _firestore.collection('users').doc(fromUserId).collection('sent_requests').doc(request.id),
          {
            'requestId': request.id,
            'toUserId': toUserId,
            'sentAt': request.sentAt.toIso8601String(),
            'status': request.status.name,
          },
        );

        // Add to receiver's received requests
        transaction.set(
          _firestore.collection('users').doc(toUserId).collection('received_requests').doc(request.id),
          {
            'requestId': request.id,
            'fromUserId': fromUserId,
            'sentAt': request.sentAt.toIso8601String(),
            'status': request.status.name,
          },
        );

        // Update sender's stats
        transaction.update(
          _firestore.collection('users').doc(fromUserId),
          {
            'pendingSentRequests': FieldValue.increment(1),
            'updatedAt': DateTime.now().toIso8601String(),
          },
        );

        // Update receiver's stats
        transaction.update(
          _firestore.collection('users').doc(toUserId),
          {
            'pendingReceivedRequests': FieldValue.increment(1),
            'updatedAt': DateTime.now().toIso8601String(),
          },
        );

        return true;
      });
    } catch (e, stackTrace) {
      _errorHandler.handleError(AppError.service(
        message: 'Failed to send friend request: $e',
        stackTrace: stackTrace,
        originalException: e is Exception ? e : Exception(e.toString()),
      ));
      return false;
    }
  }

  /// Accept a friend request
  Future<bool> acceptFriendRequest({
    required String requestId,
    required String userId,
  }) async {
    try {
      return await _firestore.runTransaction((transaction) async {
        // Get the request
        final requestDoc = await transaction.get(
          _firestore.collection('friend_requests').doc(requestId)
        );

        if (!requestDoc.exists) {
          return false; // Request not found
        }

        final request = FriendRequest.fromJson(requestDoc.data()!);
        
        if (request.toUserId != userId || !request.isPending) {
          return false; // Not authorized or already processed
        }

        final now = DateTime.now();

        // Update request status
        transaction.update(
          _firestore.collection('friend_requests').doc(requestId),
          {
            'status': FriendRequestStatus.accepted.name,
            'respondedAt': now.toIso8601String(),
          },
        );

        // Create mutual friendship
        transaction.set(
          _firestore.collection('friends').doc(request.fromUserId).collection('friends').doc(request.toUserId),
          {
            'userId': request.toUserId,
            'friendsSince': now.toIso8601String(),
            'requestId': requestId,
          },
        );

        transaction.set(
          _firestore.collection('friends').doc(request.toUserId).collection('friends').doc(request.fromUserId),
          {
            'userId': request.fromUserId,
            'friendsSince': now.toIso8601String(),
            'requestId': requestId,
          },
        );

        // Update sender's collections
        transaction.update(
          _firestore.collection('users').doc(request.fromUserId).collection('sent_requests').doc(requestId),
          {'status': FriendRequestStatus.accepted.name},
        );

        // Update receiver's collections
        transaction.update(
          _firestore.collection('users').doc(request.toUserId).collection('received_requests').doc(requestId),
          {'status': FriendRequestStatus.accepted.name},
        );

        // Update user stats
        transaction.update(
          _firestore.collection('users').doc(request.fromUserId),
          {
            'pendingSentRequests': FieldValue.increment(-1),
            'friendsCount': FieldValue.increment(1),
            'updatedAt': now.toIso8601String(),
          },
        );

        transaction.update(
          _firestore.collection('users').doc(request.toUserId),
          {
            'pendingReceivedRequests': FieldValue.increment(-1),
            'friendsCount': FieldValue.increment(1),
            'updatedAt': now.toIso8601String(),
          },
        );

        return true;
      });
    } catch (e, stackTrace) {
      _errorHandler.handleError(AppError.service(
        message: 'Failed to accept friend request: $e',
        stackTrace: stackTrace,
        originalException: e is Exception ? e : Exception(e.toString()),
      ));
      return false;
    }
  }

  /// Reject a friend request
  Future<bool> rejectFriendRequest({
    required String requestId,
    required String userId,
  }) async {
    try {
      return await _firestore.runTransaction((transaction) async {
        // Get the request
        final requestDoc = await transaction.get(
          _firestore.collection('friend_requests').doc(requestId)
        );

        if (!requestDoc.exists) {
          return false; // Request not found
        }

        final request = FriendRequest.fromJson(requestDoc.data()!);
        
        if (request.toUserId != userId || !request.isPending) {
          return false; // Not authorized or already processed
        }

        final now = DateTime.now();

        // Update request status
        transaction.update(
          _firestore.collection('friend_requests').doc(requestId),
          {
            'status': FriendRequestStatus.rejected.name,
            'respondedAt': now.toIso8601String(),
          },
        );

        // Update sender's collections
        transaction.update(
          _firestore.collection('users').doc(request.fromUserId).collection('sent_requests').doc(requestId),
          {'status': FriendRequestStatus.rejected.name},
        );

        // Update receiver's collections
        transaction.update(
          _firestore.collection('users').doc(request.toUserId).collection('received_requests').doc(requestId),
          {'status': FriendRequestStatus.rejected.name},
        );

        // Update user stats
        transaction.update(
          _firestore.collection('users').doc(request.fromUserId),
          {
            'pendingSentRequests': FieldValue.increment(-1),
            'updatedAt': now.toIso8601String(),
          },
        );

        transaction.update(
          _firestore.collection('users').doc(request.toUserId),
          {
            'pendingReceivedRequests': FieldValue.increment(-1),
            'updatedAt': now.toIso8601String(),
          },
        );

        return true;
      });
    } catch (e, stackTrace) {
      _errorHandler.handleError(AppError.service(
        message: 'Failed to reject friend request: $e',
        stackTrace: stackTrace,
        originalException: e is Exception ? e : Exception(e.toString()),
      ));
      return false;
    }
  }

  /// Cancel a sent friend request
  Future<bool> cancelFriendRequest({
    required String requestId,
    required String userId,
  }) async {
    try {
      return await _firestore.runTransaction((transaction) async {
        // Get the request
        final requestDoc = await transaction.get(
          _firestore.collection('friend_requests').doc(requestId)
        );

        if (!requestDoc.exists) {
          return false; // Request not found
        }

        final request = FriendRequest.fromJson(requestDoc.data()!);
        
        if (request.fromUserId != userId || !request.isPending) {
          return false; // Not authorized or already processed
        }

        final now = DateTime.now();

        // Update request status
        transaction.update(
          _firestore.collection('friend_requests').doc(requestId),
          {
            'status': FriendRequestStatus.cancelled.name,
            'respondedAt': now.toIso8601String(),
          },
        );

        // Update sender's collections
        transaction.update(
          _firestore.collection('users').doc(request.fromUserId).collection('sent_requests').doc(requestId),
          {'status': FriendRequestStatus.cancelled.name},
        );

        // Update receiver's collections
        transaction.update(
          _firestore.collection('users').doc(request.toUserId).collection('received_requests').doc(requestId),
          {'status': FriendRequestStatus.cancelled.name},
        );

        // Update user stats
        transaction.update(
          _firestore.collection('users').doc(request.fromUserId),
          {
            'pendingSentRequests': FieldValue.increment(-1),
            'updatedAt': now.toIso8601String(),
          },
        );

        transaction.update(
          _firestore.collection('users').doc(request.toUserId),
          {
            'pendingReceivedRequests': FieldValue.increment(-1),
            'updatedAt': now.toIso8601String(),
          },
        );

        return true;
      });
    } catch (e, stackTrace) {
      _errorHandler.handleError(AppError.service(
        message: 'Failed to cancel friend request: $e',
        stackTrace: stackTrace,
        originalException: e is Exception ? e : Exception(e.toString()),
      ));
      return false;
    }
  }

  /// Check if users are friends
  Future<bool> areFriends({
    required String userId1,
    required String userId2,
  }) async {
    try {
      final doc = await _firestore
          .collection('friends')
          .doc(userId1)
          .collection('friends')
          .doc(userId2)
          .get();

      return doc.exists;
    } catch (e, stackTrace) {
      _errorHandler.handleError(AppError.service(
        message: 'Failed to check friendship status: $e',
        stackTrace: stackTrace,
        originalException: e is Exception ? e : Exception(e.toString()),
      ));
      return false;
    }
  }

  /// Check friend request status between two users
  Future<FriendRequest?> getFriendRequestStatus({
    required String fromUserId,
    required String toUserId,
  }) async {
    try {
      final query = await _firestore
          .collection('friend_requests')
          .where('fromUserId', isEqualTo: fromUserId)
          .where('toUserId', isEqualTo: toUserId)
          .orderBy('sentAt', descending: true)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        return FriendRequest.fromJson(query.docs.first.data());
      }

      return null;
    } catch (e, stackTrace) {
      _errorHandler.handleError(AppError.service(
        message: 'Failed to get friend request status: $e',
        stackTrace: stackTrace,
        originalException: e is Exception ? e : Exception(e.toString()),
      ));
      return null;
    }
  }

  /// Get received friend requests (pending)
  Future<List<FriendRequest>> getReceivedFriendRequests({
    required String userId,
    int limit = 20,
  }) async {
    try {
      final query = await _firestore
          .collection('friend_requests')
          .where('toUserId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .orderBy('sentAt', descending: true)
          .limit(limit)
          .get();

      return query.docs
          .map((doc) => FriendRequest.fromJson(doc.data()))
          .toList();
    } catch (e, stackTrace) {
      _errorHandler.handleError(AppError.service(
        message: 'Failed to get received friend requests: $e',
        stackTrace: stackTrace,
        originalException: e is Exception ? e : Exception(e.toString()),
      ));
      return [];
    }
  }

  /// Get sent friend requests (pending)
  Future<List<FriendRequest>> getSentFriendRequests({
    required String userId,
    int limit = 20,
  }) async {
    try {
      final query = await _firestore
          .collection('friend_requests')
          .where('fromUserId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .orderBy('sentAt', descending: true)
          .limit(limit)
          .get();

      return query.docs
          .map((doc) => FriendRequest.fromJson(doc.data()))
          .toList();
    } catch (e, stackTrace) {
      _errorHandler.handleError(AppError.service(
        message: 'Failed to get sent friend requests: $e',
        stackTrace: stackTrace,
        originalException: e is Exception ? e : Exception(e.toString()),
      ));
      return [];
    }
  }

  /// Get friends list
  Future<List<User>> getFriends({
    required String userId,
    int limit = 50,
  }) async {
    try {
      final query = await _firestore
          .collection('friends')
          .doc(userId)
          .collection('friends')
          .orderBy('friendsSince', descending: true)
          .limit(limit)
          .get();

      final friendIds = query.docs
          .map((doc) => doc.data()['userId'] as String)
          .toList();

      return await _getUsersByIds(friendIds);
    } catch (e, stackTrace) {
      _errorHandler.handleError(AppError.service(
        message: 'Failed to get friends: $e',
        stackTrace: stackTrace,
        originalException: e is Exception ? e : Exception(e.toString()),
      ));
      return [];
    }
  }

  /// Get friend request statistics
  Future<FriendRequestStats> getFriendRequestStats(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data() ?? {};

      return FriendRequestStats(
        pendingReceived: userData['pendingReceivedRequests'] ?? 0,
        pendingSent: userData['pendingSentRequests'] ?? 0,
        totalFriends: userData['friendsCount'] ?? 0,
        lastUpdated: DateTime.now(),
      );
    } catch (e, stackTrace) {
      _errorHandler.handleError(AppError.service(
        message: 'Failed to get friend request stats: $e',
        stackTrace: stackTrace,
        originalException: e is Exception ? e : Exception(e.toString()),
      ));
      return FriendRequestStats.empty();
    }
  }

  /// Remove friend (unfriend)
  Future<bool> removeFriend({
    required String userId,
    required String friendId,
  }) async {
    try {
      return await _firestore.runTransaction((transaction) async {
        final now = DateTime.now();

        // Remove friendship from both sides
        transaction.delete(
          _firestore.collection('friends').doc(userId).collection('friends').doc(friendId)
        );

        transaction.delete(
          _firestore.collection('friends').doc(friendId).collection('friends').doc(userId)
        );

        // Update friend counts
        transaction.update(
          _firestore.collection('users').doc(userId),
          {
            'friendsCount': FieldValue.increment(-1),
            'updatedAt': now.toIso8601String(),
          },
        );

        transaction.update(
          _firestore.collection('users').doc(friendId),
          {
            'friendsCount': FieldValue.increment(-1),
            'updatedAt': now.toIso8601String(),
          },
        );

        return true;
      });
    } catch (e, stackTrace) {
      _errorHandler.handleError(AppError.service(
        message: 'Failed to remove friend: $e',
        stackTrace: stackTrace,
        originalException: e is Exception ? e : Exception(e.toString()),
      ));
      return false;
    }
  }

  /// Listen to received friend requests
  StreamSubscription<QuerySnapshot>? listenToReceivedRequests(String userId) {
    try {
      return _firestore
          .collection('friend_requests')
          .where('toUserId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .snapshots()
          .listen((snapshot) {
        final requests = snapshot.docs
            .map((doc) => FriendRequest.fromJson(doc.data()))
            .toList();
        _receivedRequestsController.add(requests);
      });
    } catch (e, stackTrace) {
      _errorHandler.handleError(AppError.service(
        message: 'Failed to listen to received requests: $e',
        stackTrace: stackTrace,
        originalException: e is Exception ? e : Exception(e.toString()),
      ));
      return null;
    }
  }

  /// Listen to sent friend requests
  StreamSubscription<QuerySnapshot>? listenToSentRequests(String userId) {
    try {
      return _firestore
          .collection('friend_requests')
          .where('fromUserId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .snapshots()
          .listen((snapshot) {
        final requests = snapshot.docs
            .map((doc) => FriendRequest.fromJson(doc.data()))
            .toList();
        _sentRequestsController.add(requests);
      });
    } catch (e, stackTrace) {
      _errorHandler.handleError(AppError.service(
        message: 'Failed to listen to sent requests: $e',
        stackTrace: stackTrace,
        originalException: e is Exception ? e : Exception(e.toString()),
      ));
      return null;
    }
  }

  /// Listen to friend request stats
  StreamSubscription<DocumentSnapshot>? listenToStats(String userId) {
    try {
      return _firestore
          .collection('users')
          .doc(userId)
          .snapshots()
          .listen((snapshot) {
        if (snapshot.exists) {
          final data = snapshot.data() as Map<String, dynamic>;
          final stats = FriendRequestStats(
            pendingReceived: data['pendingReceivedRequests'] ?? 0,
            pendingSent: data['pendingSentRequests'] ?? 0,
            totalFriends: data['friendsCount'] ?? 0,
            lastUpdated: DateTime.now(),
          );
          _statsController.add(stats);
        }
      });
    } catch (e, stackTrace) {
      _errorHandler.handleError(AppError.service(
        message: 'Failed to listen to stats: $e',
        stackTrace: stackTrace,
        originalException: e is Exception ? e : Exception(e.toString()),
      ));
      return null;
    }
  }

  // Helper methods

  /// Batch get users by IDs
  Future<List<User>> _getUsersByIds(List<String> userIds) async {
    if (userIds.isEmpty) return [];

    final users = <User>[];
    
    // Firestore 'in' queries are limited to 10 items
    final chunks = <List<String>>[];
    for (int i = 0; i < userIds.length; i += 10) {
      chunks.add(userIds.sublist(i, i + 10 > userIds.length ? userIds.length : i + 10));
    }

    for (final chunk in chunks) {
      final snapshot = await _firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();

      for (final doc in snapshot.docs) {
        try {
          users.add(User.fromJson(doc.data()));
        } catch (e) {
          // Skip invalid user documents
          continue;
        }
      }
    }

    return users;
  }

  void dispose() {
    _receivedRequestsController.close();
    _sentRequestsController.close();
    _statsController.close();
  }
}