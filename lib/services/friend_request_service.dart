import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart' as app_user;
import '../models/friend_request_model.dart';
import '../core/error/error_handler.dart';
import '../core/models/app_error.dart';

/// Friend Request system service implementing Instagram/Snapchat-like patterns using Supabase
class FriendRequestService {
  static FriendRequestService? _instance;
  static FriendRequestService get instance =>
      _instance ??= FriendRequestService._internal();
  FriendRequestService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  final ErrorHandler _errorHandler = ErrorHandler();

  // Stream controllers for real-time updates
  final StreamController<List<FriendRequest>> _receivedRequestsController =
      StreamController<List<FriendRequest>>.broadcast();
  final StreamController<List<FriendRequest>> _sentRequestsController =
      StreamController<List<FriendRequest>>.broadcast();
  final StreamController<List<app_user.User>> _friendsController =
      StreamController<List<app_user.User>>.broadcast();
  final StreamController<FriendRequestStats> _statsController =
      StreamController<FriendRequestStats>.broadcast();

  Stream<List<FriendRequest>> get receivedRequestsStream =>
      _receivedRequestsController.stream;
  Stream<List<FriendRequest>> get sentRequestsStream =>
      _sentRequestsController.stream;
  Stream<List<app_user.User>> get friendsStream => _friendsController.stream;
  Stream<FriendRequestStats> get statsStream => _statsController.stream;

  RealtimeChannel? _friendshipsChannel;
  RealtimeChannel? _receivedRequestsChannel;
  RealtimeChannel? _sentRequestsChannel;

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
      // Check if already friends by looking for an accepted request
      final existingFriendship = await _supabase
          .from('friend_requests')
          .select()
          .or(
            'and(from_user_id.eq.$fromUserId,to_user_id.eq.$toUserId),and(from_user_id.eq.$toUserId,to_user_id.eq.$fromUserId)',
          )
          .eq('status', 'accepted')
          .maybeSingle();

      if (existingFriendship != null) {
        return false; // Already friends
      }

      // Check if pending request already exists
      final existingRequest = await _supabase
          .from('friend_requests')
          .select()
          .eq('from_user_id', fromUserId)
          .eq('to_user_id', toUserId)
          .eq('status', 'pending')
          .maybeSingle();

      if (existingRequest != null) {
        return false; // Request already sent
      }

      // Create friend request
      await _supabase.from('friend_requests').insert({
        'from_user_id': fromUserId,
        'to_user_id': toUserId,
        'message': message ?? 'Hi! I\'d like to be friends.',
        'status': 'pending',
      });

      return true;
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        AppError.service(
          message: 'Failed to send friend request: $e',
          stackTrace: stackTrace,
          originalException: e is Exception ? e : Exception(e.toString()),
        ),
      );
      return false;
    }
  }

  /// Accept a friend request
  Future<bool> acceptFriendRequest({
    required String requestId,
    required String userId,
  }) async {
    try {
      await _supabase
          .from('friend_requests')
          .update({
            'status': 'accepted',
            'responded_at': DateTime.now().toIso8601String(),
          })
          .eq('id', requestId)
          .eq('to_user_id', userId);

      return true;
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        AppError.service(
          message: 'Failed to accept friend request: $e',
          stackTrace: stackTrace,
          originalException: e is Exception ? e : Exception(e.toString()),
        ),
      );
      return false;
    }
  }

  /// Reject a friend request
  Future<bool> rejectFriendRequest({
    required String requestId,
    required String userId,
  }) async {
    try {
      await _supabase
          .from('friend_requests')
          .update({
            'status': 'rejected',
            'responded_at': DateTime.now().toIso8601String(),
          })
          .eq('id', requestId)
          .eq('to_user_id', userId);

      return true;
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        AppError.service(
          message: 'Failed to reject friend request: $e',
          stackTrace: stackTrace,
          originalException: e is Exception ? e : Exception(e.toString()),
        ),
      );
      return false;
    }
  }

  /// Cancel a sent friend request
  Future<bool> cancelFriendRequest({
    required String requestId,
    required String userId,
  }) async {
    try {
      await _supabase
          .from('friend_requests')
          .update({
            'status': 'cancelled',
            'responded_at': DateTime.now().toIso8601String(),
          })
          .eq('id', requestId)
          .eq('from_user_id', userId);

      return true;
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        AppError.service(
          message: 'Failed to cancel friend request: $e',
          stackTrace: stackTrace,
          originalException: e is Exception ? e : Exception(e.toString()),
        ),
      );
      return false;
    }
  }

  /// Check if users are friends
  Future<bool> areFriends({
    required String userId1,
    required String userId2,
  }) async {
    try {
      final response = await _supabase
          .from('friend_requests')
          .select()
          .or(
            'and(from_user_id.eq.$userId1,to_user_id.eq.$userId2),and(from_user_id.eq.$userId2,to_user_id.eq.$userId1)',
          )
          .eq('status', 'accepted')
          .maybeSingle();

      return response != null;
    } catch (e) {
      return false;
    }
  }

  /// Get relationship status between two users
  Future<Map<String, dynamic>> getRelationshipStatus(
    String userId1,
    String userId2,
  ) async {
    if (userId1 == userId2) {
      return {'status': 'self', 'requestId': null};
    }

    try {
      final response = await _supabase
          .from('friend_requests')
          .select()
          .or(
            'and(from_user_id.eq.$userId1,to_user_id.eq.$userId2),and(from_user_id.eq.$userId2,to_user_id.eq.$userId1)',
          )
          .maybeSingle();

      if (response == null) return {'status': 'none', 'requestId': null};

      final status = response['status'] as String;
      final requestId = response['id'] as String;

      if (status == 'accepted') {
        return {'status': 'friends', 'requestId': requestId};
      }

      if (status == 'pending') {
        if (response['from_user_id'] == userId1) {
          return {'status': 'request_sent', 'requestId': requestId};
        } else {
          return {'status': 'request_received', 'requestId': requestId};
        }
      }

      return {'status': 'none', 'requestId': null};
    } catch (e) {
      return {'status': 'none', 'requestId': null};
    }
  }

  /// Get received friend requests (pending)
  Future<List<FriendRequest>> getReceivedFriendRequests({
    required String userId,
    int limit = 20,
  }) async {
    try {
      final response = await _supabase
          .from('friend_requests')
          .select('*, from_user:profiles!from_user_id(*)')
          .eq('to_user_id', userId)
          .eq('status', 'pending')
          .order('sent_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((data) => _mapToFriendRequest(data))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Get sent friend requests (pending)
  Future<List<FriendRequest>> getSentFriendRequests({
    required String userId,
    int limit = 20,
  }) async {
    try {
      final response = await _supabase
          .from('friend_requests')
          .select('*, to_user:profiles!to_user_id(*)')
          .eq('from_user_id', userId)
          .eq('status', 'pending')
          .order('sent_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((data) => _mapToFriendRequest(data))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Get friends list
  Future<List<app_user.User>> getFriends({
    required String userId,
    int limit = 50,
  }) async {
    try {
      final response = await _supabase
          .from('friend_requests')
          .select(
            'from_user_id, to_user_id, from_user:profiles!from_user_id(*), to_user:profiles!to_user_id(*)',
          )
          .or('from_user_id.eq.$userId,to_user_id.eq.$userId')
          .eq('status', 'accepted')
          .limit(limit);

      final List<app_user.User> friends = [];
      for (final data in response as List) {
        if (data['from_user_id'] == userId) {
          friends.add(app_user.User.fromJson(data['to_user']));
        } else {
          friends.add(app_user.User.fromJson(data['from_user']));
        }
      }

      // ALWAYS add Boofer Official as a default friend
      if (!friends.any((f) => f.id == '00000000-0000-4000-8000-000000000000')) {
        friends.insert(
          0,
          app_user.User(
            id: '00000000-0000-4000-8000-000000000000',
            fullName: 'Boofer Official',
            handle: 'boofer',
            virtualNumber: 'BOOFER-001',
            avatar: '🛸',
            bio: 'Your official guide to Boofer.',
            email: 'official@boofer.app',
            isDiscoverable: true,
            status: app_user.UserStatus.online,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
      }

      return friends;
    } catch (e) {
      return [];
    }
  }

  /// Get friend request statistics
  Future<FriendRequestStats> getFriendRequestStats(String userId) async {
    // If user is local-only (offline), return empty stats
    if (userId.startsWith('local_')) {
      return FriendRequestStats.empty();
    }

    try {
      // Use count() which returns PosegrestResponse when used without a full query or with specific options
      final receivedCount = await _supabase
          .from('friend_requests')
          .count(CountOption.exact)
          .eq('to_user_id', userId)
          .eq('status', 'pending');

      final sentCount = await _supabase
          .from('friend_requests')
          .count(CountOption.exact)
          .eq('from_user_id', userId)
          .eq('status', 'pending');

      // For accepted count (friends), we need to check both directions
      final acceptedCount = await _supabase
          .from('friend_requests')
          .count(CountOption.exact)
          .or('from_user_id.eq.$userId,to_user_id.eq.$userId')
          .eq('status', 'accepted');

      return FriendRequestStats(
        pendingReceived: receivedCount,
        pendingSent: sentCount,
        totalFriends: acceptedCount,
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      debugPrint('❌ Error getting friend request stats: $e');
      return FriendRequestStats.empty();
    }
  }

  /// Start listening to friend requests
  void listenToReceivedRequests(String userId) {
    _receivedRequestsChannel?.unsubscribe();
    _receivedRequestsChannel = _supabase
        .channel('public:friend_requests:to_user_id=eq.$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'friend_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'to_user_id',
            value: userId,
          ),
          callback: (payload) async {
            final requests = await getReceivedFriendRequests(userId: userId);
            _receivedRequestsController.add(requests);
            _updateStats(userId);
          },
        )
        .subscribe();
  }

  void listenToSentRequests(String userId) {
    _sentRequestsChannel?.unsubscribe();
    _sentRequestsChannel = _supabase
        .channel('public:friend_requests:from_user_id=eq.$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'friend_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'from_user_id',
            value: userId,
          ),
          callback: (payload) async {
            final requests = await getSentFriendRequests(userId: userId);
            _sentRequestsController.add(requests);
            _updateStats(userId);
          },
        )
        .subscribe();
  }

  void listenToFriends(String userId) {
    _friendshipsChannel?.unsubscribe();
    _friendshipsChannel = _supabase
        .channel('public:friend_requests:friends:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'friend_requests',
          callback: (payload) async {
            // Check if this change affect's user's friendships
            final data = payload.newRecord;
            final oldData = payload.oldRecord;

            bool isRelevant = false;

            if (data.isNotEmpty) {
              if (data['from_user_id'] == userId ||
                  data['to_user_id'] == userId) {
                isRelevant = true;
              }
            } else if (oldData.isNotEmpty) {
              if (oldData['from_user_id'] == userId ||
                  oldData['to_user_id'] == userId) {
                isRelevant = true;
              }
            }

            if (isRelevant) {
              await _updateFriends(userId);
              await _updateStats(userId);
            }
          },
        )
        .subscribe();

    // Initial fetch
    _updateFriends(userId);
  }

  Future<void> _updateFriends(String userId) async {
    final friends = await getFriends(userId: userId);
    _friendsController.add(friends);
  }

  void listenToStats(String userId) {
    // Stats are updated implicitly via request listeners in this implementation
    _updateStats(userId);
  }

  Future<void> _updateStats(String userId) async {
    final stats = await getFriendRequestStats(userId);
    _statsController.add(stats);
  }

  FriendRequest _mapToFriendRequest(Map<String, dynamic> data) {
    return FriendRequest(
      id: data['id'],
      fromUserId: data['from_user_id'],
      toUserId: data['to_user_id'],
      message: data['message'] ?? '',
      status: _parseStatus(data['status']),
      sentAt: DateTime.parse(data['sent_at']),
      respondedAt: data['responded_at'] != null
          ? DateTime.parse(data['responded_at'])
          : null,
    );
  }

  FriendRequestStatus _parseStatus(String status) {
    switch (status) {
      case 'pending':
        return FriendRequestStatus.pending;
      case 'accepted':
        return FriendRequestStatus.accepted;
      case 'rejected':
        return FriendRequestStatus.rejected;
      case 'cancelled':
        return FriendRequestStatus.cancelled;
      default:
        return FriendRequestStatus.pending;
    }
  }

  Future<bool> removeFriendship({
    required String userId,
    required String friendId,
  }) async {
    try {
      await _supabase
          .from('friend_requests')
          .delete()
          .or(
            'and(from_user_id.eq.$userId,to_user_id.eq.$friendId),and(from_user_id.eq.$friendId,to_user_id.eq.$userId)',
          )
          .eq('status', 'accepted');
      return true;
    } catch (e) {
      return false;
    }
  }

  void dispose() {
    _friendshipsChannel?.unsubscribe();
    _receivedRequestsChannel?.unsubscribe();
    _sentRequestsChannel?.unsubscribe();
    _friendsController.close();
    _receivedRequestsController.close();
    _sentRequestsController.close();
    _statsController.close();
  }
}
