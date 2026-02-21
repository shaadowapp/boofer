import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import '../models/user_model.dart';
import '../core/constants.dart';
import 'local_storage_service.dart';
import '../utils/string_utils.dart';

class FollowService {
  static FollowService? _instance;
  static FollowService get instance => _instance ??= FollowService._internal();
  FollowService._internal();

  final _supabase = Supabase.instance.client;

  /// Ensures that the given user follows the Boofer Official account.
  Future<void> ensureFollowingBoofer(String userId) async {
    const booferId = AppConstants.booferId;
    if (userId == booferId) return;

    try {
      final following = await isFollowing(
        followerId: userId,
        followingId: booferId,
      );

      if (!following) {
        await followUser(followerId: userId, followingId: booferId);
      }
    } catch (e) {
      // Silently fail if something goes wrong
    }
  }

  Future<List<User>> getSuggestedUsers({
    int limit = 20,
    required String currentUserId,
  }) async {
    try {
      // Very basic suggestion: users you don't follow, excluding yourself
      // In a real app, this would be more complex (interests, mutuals, etc.)

      // Get IDs of people already followed
      final followingResponse = await _supabase
          .from('follows')
          .select('following_id')
          .eq('follower_id', currentUserId);

      final List<String> followingIds = (followingResponse as List)
          .map((f) => f['following_id'] as String)
          .toList();
      followingIds.add(currentUserId); // Exclude self

      final response = await _supabase
          .from('profiles')
          .select()
          .not('id', 'in', '(${followingIds.join(',')})')
          .limit(limit);

      return (response as List)
          .map<User>((json) => User.fromJson(json))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<User>> getFollowers({
    required String userId,
    int limit = 50,
  }) async {
    try {
      final response = await _supabase
          .from('follows')
          .select('follower:profiles!follower_id(*)')
          .eq('following_id', userId)
          .limit(limit);

      return (response as List)
          .map<User>((f) => User.fromJson(f['follower']))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<User>> getFollowing({
    required String userId,
    int limit = 50,
  }) async {
    try {
      final response = await _supabase
          .from('follows')
          .select('following:profiles!following_id(*)')
          .eq('follower_id', userId)
          .limit(limit);

      return (response as List)
          .map<User>((f) => User.fromJson(f['following']))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Gets mutual follows (friends) for the given user.
  Future<List<User>> getFriends({required String userId}) async {
    try {
      // Validate userId is a UUID
      if (!StringUtils.isUuid(userId)) {
        debugPrint(
          '⚠️ Skipping getFriends: userId is not a valid UUID ($userId)',
        );
        return [];
      }

      // 1. Get everyone I follow
      final following = await getFollowing(userId: userId, limit: 1000);
      if (following.isEmpty) return [];

      // Filter to only valid UUIDs to avoid Postgrest errors in the 'in' filter
      final followingIds = following
          .map((u) => u.id)
          .where((id) => StringUtils.isUuid(id))
          .toList();

      if (followingIds.isEmpty) return [];

      // 2. Filter for those who follow me back
      final response = await _supabase
          .from('follows')
          .select('follower_id')
          .eq('following_id', userId)
          .filter('follower_id', 'in', '(${followingIds.join(',')})');

      final mutualIds = (response as List)
          .map((f) => f['follower_id'] as String)
          .toSet();

      // Return only those who are mutuals
      return following.where((u) => mutualIds.contains(u.id)).toList();
    } catch (e) {
      debugPrint('Error getting friends: $e');
      return [];
    }
  }

  /// Gets all users that the current user is related to (following or followed by).
  Future<List<User>> getAllRelatedUsers({required String userId}) async {
    try {
      if (!StringUtils.isUuid(userId)) return [];

      // Fetch followers and following in parallel
      final results = await Future.wait([
        getFollowers(userId: userId, limit: 1000),
        getFollowing(userId: userId, limit: 1000),
      ]);

      final followers = results[0];
      final following = results[1];

      // Combine and remove duplicates based on ID
      final Map<String, User> userMap = {};
      for (final u in followers) {
        userMap[u.id] = u;
      }
      for (final u in following) {
        userMap[u.id] = u;
      }

      return userMap.values.toList();
    } catch (e) {
      debugPrint('Error getting related users: $e');
      return [];
    }
  }

  Future<bool> isFollowing({
    required String followerId,
    required String followingId,
  }) async {
    try {
      final response = await _supabase
          .from('follows')
          .select()
          .eq('follower_id', followerId)
          .eq('following_id', followingId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, bool>> batchCheckFollowStatus({
    required String followerId,
    required List<String> followingIds,
  }) async {
    if (followingIds.isEmpty) return {};

    try {
      final response = await _supabase
          .from('follows')
          .select('following_id')
          .eq('follower_id', followerId)
          .inFilter('following_id', followingIds);

      final List<String> foundIds = (response as List)
          .map((f) => f['following_id'] as String)
          .toList();

      final Map<String, bool> results = {};
      for (final id in followingIds) {
        results[id] = foundIds.contains(id);
      }
      return results;
    } catch (e) {
      return {};
    }
  }

  Future<String> getFollowStatus({
    required String currentUserId,
    required String targetUserId,
  }) async {
    try {
      if (currentUserId == targetUserId) return 'self';

      // DEBUG OVERRIDE: If debug flag is set, treat as mutual (except for self)
      final debugForced = await LocalStorageService.isDebugMutualFollowForced();
      if (debugForced) {
        debugPrint(
          'FollowService DEBUG: Mutual follow status FORCED for $targetUserId',
        );
        return 'mutual';
      }

      final following = await isFollowing(
        followerId: currentUserId,
        followingId: targetUserId,
      );

      final follower = await isFollowing(
        followerId: targetUserId,
        followingId: currentUserId,
      );

      if (following && follower) return 'mutual';
      if (following) return 'following';
      if (follower) return 'follower';
      return 'none';
    } catch (e) {
      return 'none';
    }
  }

  Future<bool> followUser({
    required String followerId,
    required String followingId,
  }) async {
    if (followerId == followingId) return false;

    // Validate both IDs are UUIDs
    if (!StringUtils.isUuid(followerId) || !StringUtils.isUuid(followingId)) {
      debugPrint(
        '⚠️ FollowService: Skipping followUser - invalid UUID(s). '
        'followerId: $followerId, followingId: $followingId',
      );
      return false;
    }

    debugPrint(
      'FollowService: following user $followingId with follower $followerId',
    );
    try {
      await _supabase.from('follows').insert({
        'follower_id': followerId,
        'following_id': followingId,
      });
      debugPrint('FollowService: Successfully followed');
      return true;
    } catch (e) {
      if (e.toString().contains('23505') ||
          e.toString().contains('duplicate key')) {
        debugPrint('FollowService: User already followed (handled gracefully)');
        return true;
      }
      debugPrint('FollowService: Error following user $followingId: $e');
      return false;
    }
  }

  Future<bool> unfollowUser({
    required String followerId,
    required String followingId,
  }) async {
    if (!StringUtils.isUuid(followerId) || !StringUtils.isUuid(followingId)) {
      debugPrint(
        '⚠️ FollowService: Skipping unfollowUser - invalid UUID(s). '
        'followerId: $followerId, followingId: $followingId',
      );
      return false;
    }

    try {
      await _supabase
          .from('follows')
          .delete()
          .eq('follower_id', followerId)
          .eq('following_id', followingId);
      debugPrint('FollowService: Successfully unfollowed');
      return true;
    } catch (e) {
      debugPrint('FollowService: Error unfollowing user $followingId: $e');
      return false;
    }
  }

  Future<Map<String, int>> getFollowCounts(String userId) async {
    try {
      final followersCount = await _supabase
          .from('follows')
          .count(CountOption.exact)
          .eq('following_id', userId);

      final followingCount = await _supabase
          .from('follows')
          .count(CountOption.exact)
          .eq('follower_id', userId);

      return {'followers': followersCount, 'following': followingCount};
    } catch (e) {
      return {'followers': 0, 'following': 0};
    }
  }

  Future<List<User>> getMutualFollowers({
    required String userId1,
    required String userId2,
  }) async {
    try {
      // Find users followed by both userId1 and userId2
      final response = await _supabase.rpc(
        'get_mutual_followers',
        params: {'user1_id': userId1, 'user2_id': userId2},
      );

      return (response as List).map((json) => User.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<bool> removeFollower({
    required String userId,
    required String followerId,
  }) async {
    try {
      await _supabase
          .from('follows')
          .delete()
          .eq('follower_id', followerId)
          .eq('following_id', userId);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, bool>> batchFollowUsers({
    required String followerId,
    required List<String> userIds,
  }) async {
    final Map<String, bool> results = {};
    for (final id in userIds) {
      results[id] = await followUser(followerId: followerId, followingId: id);
    }
    return results;
  }

  Stream<Map<String, int>>? listenToFollowCounts(String userId) {
    // We can use a combination of streams or just a polling/manual update approach
    // Supabase standard realtime doesn't support aggregate counts directly
    // Returning null for now to rely on manual refreshes via Provider
    return null;
  }

  Stream<List<String>>? listenToFollowing(String userId) {
    return _supabase
        .from('follows')
        .stream(primaryKey: ['id'])
        .eq('follower_id', userId)
        .map((data) => data.map((f) => f['following_id'] as String).toList());
  }
}
