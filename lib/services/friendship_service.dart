import 'dart:async';
import '../core/database/database_manager.dart';
import '../core/error/error_handler.dart';
import '../core/models/app_error.dart';
import '../models/connection_request_model.dart';
import '../models/user_model.dart';
import 'connection_service.dart';

enum FriendshipStatus {
  none,           // No relationship
  requestSent,    // Current user sent a request
  requestReceived, // Current user received a request
  friends,        // They are friends
  blocked,        // One user blocked the other
}

/// Service to manage friendships and enforce friend-only communication
class FriendshipService {
  static FriendshipService? _instance;
  static FriendshipService get instance => _instance ??= FriendshipService._internal();
  FriendshipService._internal();

  final DatabaseManager _database = DatabaseManager.instance;
  final ErrorHandler _errorHandler = ErrorHandler();
  final ConnectionService _connectionService = ConnectionService.instance;
  
  // Stream controllers for real-time updates
  final StreamController<List<User>> _friendsController = StreamController<List<User>>.broadcast();
  final StreamController<List<ConnectionRequest>> _requestsController = StreamController<List<ConnectionRequest>>.broadcast();
  
  Stream<List<User>> get friendsStream => _friendsController.stream;
  Stream<List<ConnectionRequest>> get requestsStream => _requestsController.stream;

  /// Check if two users are friends
  Future<bool> areFriends(String userId1, String userId2) async {
    try {
      final results = await _database.query(
        '''
        SELECT COUNT(*) as count FROM friends 
        WHERE ((user_id = ? AND friend_id = ?) OR (user_id = ? AND friend_id = ?))
        AND status = 'accepted'
        ''',
        [userId1, userId2, userId2, userId1],
      );
      
      return results.isNotEmpty && (results.first['count'] as int) > 0;
    } catch (e, stackTrace) {
      _errorHandler.handleError(AppError.database(
        message: 'Failed to check friendship: $e',
        stackTrace: stackTrace,
        originalException: e is Exception ? e : Exception(e.toString()),
      ));
      return false;
    }
  }

  /// Get friendship status between two users
  Future<FriendshipStatus> getFriendshipStatus(String currentUserId, String otherUserId) async {
    try {
      // Check if they are already friends
      if (await areFriends(currentUserId, otherUserId)) {
        return FriendshipStatus.friends;
      }

      // Check for pending connection requests
      final sentRequest = await _database.query(
        '''
        SELECT * FROM connection_requests 
        WHERE from_user_id = ? AND to_user_id = ? AND status = ?
        ''',
        [currentUserId, otherUserId, ConnectionRequestStatus.pending.name],
      );

      if (sentRequest.isNotEmpty) {
        return FriendshipStatus.requestSent;
      }

      final receivedRequest = await _database.query(
        '''
        SELECT * FROM connection_requests 
        WHERE from_user_id = ? AND to_user_id = ? AND status = ?
        ''',
        [otherUserId, currentUserId, ConnectionRequestStatus.pending.name],
      );

      if (receivedRequest.isNotEmpty) {
        return FriendshipStatus.requestReceived;
      }

      // Check if blocked
      final blocked = await _database.query(
        '''
        SELECT * FROM connection_requests 
        WHERE ((from_user_id = ? AND to_user_id = ?) OR (from_user_id = ? AND to_user_id = ?))
        AND status = ?
        ''',
        [currentUserId, otherUserId, otherUserId, currentUserId, ConnectionRequestStatus.blocked.name],
      );

      if (blocked.isNotEmpty) {
        return FriendshipStatus.blocked;
      }

      return FriendshipStatus.none;
    } catch (e, stackTrace) {
      _errorHandler.handleError(AppError.database(
        message: 'Failed to get friendship status: $e',
        stackTrace: stackTrace,
        originalException: e is Exception ? e : Exception(e.toString()),
      ));
      return FriendshipStatus.none;
    }
  }

  /// Check if user can send message to another user
  Future<bool> canSendMessage(String senderId, String receiverId) async {
    // Users can always send messages to themselves
    if (senderId == receiverId) return true;
    
    // Check if they are friends
    return await areFriends(senderId, receiverId);
  }

  /// Check if user can call another user
  Future<bool> canCall(String callerId, String receiverId) async {
    // Users can't call themselves
    if (callerId == receiverId) return false;
    
    // Check if they are friends
    return await areFriends(callerId, receiverId);
  }

  /// Send friend request
  Future<bool> sendFriendRequest(String fromUserId, String toUserId, {String? message}) async {
    try {
      // Check if request already exists
      final status = await getFriendshipStatus(fromUserId, toUserId);
      if (status != FriendshipStatus.none) {
        return false; // Request already exists or they are friends
      }

      return await _connectionService.sendConnectionRequest(
        fromUserId: fromUserId,
        toUserId: toUserId,
        message: message ?? 'Hi! I\'d like to connect with you.',
      );
    } catch (e, stackTrace) {
      _errorHandler.handleError(AppError.service(
        message: 'Failed to send friend request: $e',
        stackTrace: stackTrace,
        originalException: e is Exception ? e : Exception(e.toString()),
      ));
      return false;
    }
  }

  /// Accept friend request
  Future<bool> acceptFriendRequest(String requestId) async {
    return await _connectionService.acceptConnectionRequest(requestId);
  }

  /// Decline friend request
  Future<bool> declineFriendRequest(String requestId) async {
    return await _connectionService.declineConnectionRequest(requestId);
  }

  /// Remove friend (unfriend)
  Future<bool> removeFriend(String userId, String friendId) async {
    try {
      await _database.delete(
        'friends',
        where: '(user_id = ? AND friend_id = ?) OR (user_id = ? AND friend_id = ?)',
        whereArgs: [userId, friendId, friendId, userId],
      );
      return true;
    } catch (e, stackTrace) {
      _errorHandler.handleError(AppError.database(
        message: 'Failed to remove friend: $e',
        stackTrace: stackTrace,
        originalException: e is Exception ? e : Exception(e.toString()),
      ));
      return false;
    }
  }

  /// Block user
  Future<bool> blockUser(String userId, String blockedUserId) async {
    try {
      // Remove existing friendship if any
      await removeFriend(userId, blockedUserId);

      // Create a blocked connection request
      final requestId = 'block_${DateTime.now().millisecondsSinceEpoch}';
      await _database.insert('connection_requests', {
        'id': requestId,
        'from_user_id': userId,
        'to_user_id': blockedUserId,
        'message': 'User blocked',
        'status': ConnectionRequestStatus.blocked.name,
        'sent_at': DateTime.now().toIso8601String(),
        'responded_at': DateTime.now().toIso8601String(),
      });

      return true;
    } catch (e, stackTrace) {
      _errorHandler.handleError(AppError.database(
        message: 'Failed to block user: $e',
        stackTrace: stackTrace,
        originalException: e is Exception ? e : Exception(e.toString()),
      ));
      return false;
    }
  }

  /// Get user's friends list
  Future<List<User>> getFriends(String userId) async {
    try {
      final friends = await _connectionService.getFriends(userId);
      // Ensure we're returning List<User>
      final userList = friends is List<User> ? friends : <User>[];
      _friendsController.add(userList);
      return userList;
    } catch (e, stackTrace) {
      _errorHandler.handleError(AppError.service(
        message: 'Failed to get friends: $e',
        stackTrace: stackTrace,
        originalException: e is Exception ? e : Exception(e.toString()),
      ));
      return [];
    }
  }

  /// Get pending friend requests (received)
  Future<List<ConnectionRequest>> getPendingRequests(String userId) async {
    try {
      final requests = await _connectionService.getConnectionRequests(userId);
      _requestsController.add(requests);
      return requests;
    } catch (e, stackTrace) {
      _errorHandler.handleError(AppError.service(
        message: 'Failed to get pending requests: $e',
        stackTrace: stackTrace,
        originalException: e is Exception ? e : Exception(e.toString()),
      ));
      return [];
    }
  }

  /// Get sent friend requests
  Future<List<ConnectionRequest>> getSentRequests(String userId) async {
    try {
      final results = await _database.query(
        '''
        SELECT * FROM connection_requests 
        WHERE from_user_id = ? AND status = ?
        ORDER BY sent_at DESC
        ''',
        [userId, ConnectionRequestStatus.pending.name],
      );

      return results.map((json) => ConnectionRequest.fromJson(json)).toList();
    } catch (e, stackTrace) {
      _errorHandler.handleError(AppError.database(
        message: 'Failed to get sent requests: $e',
        stackTrace: stackTrace,
        originalException: e is Exception ? e : Exception(e.toString()),
      ));
      return [];
    }
  }

  /// Dispose resources
  void dispose() {
    _friendsController.close();
    _requestsController.close();
  }
}