import 'dart:async';
import 'dart:math';
import '../core/database/database_manager.dart';
import '../core/error/error_handler.dart';
import '../core/models/app_error.dart';
import '../models/user_model.dart';
import '../models/connection_request_model.dart';

/// Privacy-focused connection service for user discovery
class ConnectionService {
  static ConnectionService? _instance;
  static ConnectionService get instance => _instance ??= ConnectionService._internal();
  ConnectionService._internal();

  final DatabaseManager _database = DatabaseManager.instance;
  final ErrorHandler _errorHandler = ErrorHandler();
  final Random _random = Random();

  final StreamController<List<User>> _nearbyUsersController = 
      StreamController<List<User>>.broadcast();
  final StreamController<List<ConnectionRequest>> _requestsController = 
      StreamController<List<ConnectionRequest>>.broadcast();

  Stream<List<User>> get nearbyUsersStream => _nearbyUsersController.stream;
  Stream<List<ConnectionRequest>> get requestsStream => _requestsController.stream;
  Stream<List<ConnectionRequest>> get connectionRequestsStream => _requestsController.stream;

  /// Search users globally by handle or virtual number
  Future<List<User>> searchUsers(String query) async {
    try {
      if (query.isEmpty) return <User>[];

      final results = await _database.query(
        '''
        SELECT * FROM users 
        WHERE (handle LIKE ? OR virtual_number LIKE ?) 
        AND is_discoverable = 1
        ORDER BY 
          CASE 
            WHEN handle = ? THEN 1
            WHEN virtual_number = ? THEN 2
            WHEN handle LIKE ? THEN 3
            WHEN virtual_number LIKE ? THEN 4
            ELSE 5
          END
        LIMIT 20
        ''',
        [
          '%$query%', '%$query%',  // LIKE searches
          query, query,            // Exact matches (highest priority)
          '$query%', '$query%',    // Starts with (second priority)
        ],
      );

      final users = results.map((json) => User.fromJson(json)).toList();
      return users.cast<User>();
    } catch (e, stackTrace) {
      _errorHandler.handleError(AppError.service(
        message: 'Failed to search users: $e',
        stackTrace: stackTrace,
        originalException: e is Exception ? e : Exception(e.toString()),
      ));
      return <User>[];
    }
  }

  /// Get nearby users (privacy-controlled)
  Future<List<User>> getNearbyUsers({
    double? latitude,
    double? longitude,
    double radiusKm = 10.0,
  }) async {
    try {
      // For privacy, we only show users who explicitly allow nearby discovery
      final results = await _database.query(
        '''
        SELECT u.* FROM users u
        WHERE u.is_discoverable = 1
        AND u.id != ?
        ORDER BY RANDOM()
        LIMIT 10
        ''',
        ['current_user_id'], // Replace with actual current user ID
      );

      final users = results.map((json) => User.fromJson(json)).toList();
      _nearbyUsersController.add(users);
      return users.cast<User>();
    } catch (e, stackTrace) {
      _errorHandler.handleError(AppError.service(
        message: 'Failed to get nearby users: $e',
        stackTrace: stackTrace,
        originalException: e is Exception ? e : Exception(e.toString()),
      ));
      return <User>[];
    }
  }

  /// Send connection request
  Future<bool> sendConnectionRequest({
    required String fromUserId,
    required String toUserId,
    String? message,
  }) async {
    try {
      final requestId = 'req_${DateTime.now().millisecondsSinceEpoch}_${_random.nextInt(1000)}';
      final now = DateTime.now().toIso8601String();

      await _database.insert(
        'connection_requests',
        {
          'id': requestId,
          'from_user_id': fromUserId,
          'to_user_id': toUserId,
          'message': message,
          'status': ConnectionRequestStatus.pending.name,
          'sent_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      await _loadConnectionRequests(toUserId);
      return true;
    } catch (e, stackTrace) {
      _errorHandler.handleError(AppError.service(
        message: 'Failed to send connection request: $e',
        stackTrace: stackTrace,
        originalException: e is Exception ? e : Exception(e.toString()),
      ));
      return false;
    }
  }

  /// Get connection requests for user
  Future<List<ConnectionRequest>> getConnectionRequests(String userId) async {
    try {
      final results = await _database.query(
        '''
        SELECT cr.*, u.handle, u.full_name, u.profile_picture
        FROM connection_requests cr
        JOIN users u ON cr.from_user_id = u.id
        WHERE cr.to_user_id = ? AND cr.status = ?
        ORDER BY cr.sent_at DESC
        ''',
        [userId, ConnectionRequestStatus.pending.name],
      );

      final requests = results.map((json) => ConnectionRequest.fromJson(json)).toList();
      _requestsController.add(requests);
      return requests;
    } catch (e, stackTrace) {
      _errorHandler.handleError(AppError.service(
        message: 'Failed to get connection requests: $e',
        stackTrace: stackTrace,
        originalException: e is Exception ? e : Exception(e.toString()),
      ));
      return [];
    }
  }

  /// Accept connection request
  Future<bool> acceptConnectionRequest(String requestId) async {
    try {
      return await _database.transaction((txn) async {
        final now = DateTime.now().toIso8601String();
        
        // 1. Update connection request status
        await txn.update(
          'connection_requests',
          {
            'status': ConnectionRequestStatus.accepted.name,
            'responded_at': now,
          },
          where: 'id = ?',
          whereArgs: [requestId],
        );

        // 2. Get request details within transaction
        final results = await txn.rawQuery(
          'SELECT * FROM connection_requests WHERE id = ?',
          [requestId],
        );
        
        if (results.isEmpty) return false;
        
        final request = ConnectionRequest.fromJson(results.first);

        // 3. Add bidirectional friend relationships with conflict resolution
        await txn.insert(
          'friends',
          {
            'user_id': request.toUserId,
            'friend_id': request.fromUserId,
            'status': 'accepted',
            'created_at': now,
            'updated_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        await txn.insert(
          'friends',
          {
            'user_id': request.fromUserId,
            'friend_id': request.toUserId,
            'status': 'accepted',
            'created_at': now,
            'updated_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        // 4. Reload connection requests after transaction
        await _loadConnectionRequests(request.toUserId);

        return true;
      });
    } catch (e, stackTrace) {
      _errorHandler.handleError(AppError.service(
        message: 'Failed to accept connection request: $e',
        stackTrace: stackTrace,
        originalException: e is Exception ? e : Exception(e.toString()),
      ));
      return false;
    }
  }

  /// Decline connection request
  Future<bool> declineConnectionRequest(String requestId) async {
    try {
      final now = DateTime.now().toIso8601String();
      
      await _database.update(
        'connection_requests',
        {
          'status': ConnectionRequestStatus.declined.name,
          'responded_at': now,
        },
        where: 'id = ?',
        whereArgs: [requestId],
      );

      return true;
    } catch (e, stackTrace) {
      _errorHandler.handleError(AppError.service(
        message: 'Failed to decline connection request: $e',
        stackTrace: stackTrace,
        originalException: e is Exception ? e : Exception(e.toString()),
      ));
      return false;
    }
  }

  /// Get user's friends
  Future<List<User>> getFriends(String userId) async {
    try {
      final results = await _database.query(
        '''
        SELECT u.* FROM users u
        JOIN friends f ON u.id = f.friend_id
        WHERE f.user_id = ? AND f.status = 'accepted'
        ORDER BY u.full_name, u.handle
        ''',
        [userId],
      );

      final users = results.map((json) => User.fromJson(json)).toList();
      // Ensure we're returning List<User>
      return users.cast<User>();
    } catch (e, stackTrace) {
      _errorHandler.handleError(AppError.service(
        message: 'Failed to get friends: $e',
        stackTrace: stackTrace,
        originalException: e is Exception ? e : Exception(e.toString()),
      ));
      return <User>[];
    }
  }

  Future<ConnectionRequest?> _getConnectionRequest(String requestId) async {
    final results = await _database.query(
      'SELECT * FROM connection_requests WHERE id = ?',
      [requestId],
    );
    
    if (results.isNotEmpty) {
      return ConnectionRequest.fromJson(results.first);
    }
    return null;
  }

  Future<void> _loadConnectionRequests(String userId) async {
    final requests = await getConnectionRequests(userId);
    _requestsController.add(requests);
  }

  void dispose() {
    _nearbyUsersController.close();
    _requestsController.close();
  }

  /// Get pending connection requests
  List<ConnectionRequest> getPendingRequests() {
    // This should return cached pending requests
    // For now, return empty list - implement caching if needed
    return [];
  }

  /// Get sent connection requests
  List<ConnectionRequest> getSentRequests() {
    // This should return cached sent requests
    // For now, return empty list - implement caching if needed
    return [];
  }

  /// Get user by ID
  Future<User?> getUserById(String userId) async {
    try {
      final results = await _database.query(
        'SELECT * FROM users WHERE id = ?',
        [userId],
      );
      
      if (results.isNotEmpty) {
        return User.fromJson(results.first);
      }
      return null;
    } catch (e, stackTrace) {
      _errorHandler.handleError(AppError.service(
        message: 'Failed to get user by ID: $e',
        stackTrace: stackTrace,
        originalException: e is Exception ? e : Exception(e.toString()),
      ));
      return null;
    }
  }
}