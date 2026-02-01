import 'dart:convert';

/// Model representing a follow relationship
class Follow {
  final String id;
  final String followerId;
  final String followingId;
  final DateTime followedAt;
  final bool isActive;
  final Map<String, dynamic>? metadata;

  const Follow({
    required this.id,
    required this.followerId,
    required this.followingId,
    required this.followedAt,
    this.isActive = true,
    this.metadata,
  });

  /// Create a follow relationship
  factory Follow.create({
    required String followerId,
    required String followingId,
    Map<String, dynamic>? metadata,
  }) {
    return Follow(
      id: '${followerId}_${followingId}',
      followerId: followerId,
      followingId: followingId,
      followedAt: DateTime.now(),
      isActive: true,
      metadata: metadata,
    );
  }

  /// Create a copy with updated fields
  Follow copyWith({
    String? id,
    String? followerId,
    String? followingId,
    DateTime? followedAt,
    bool? isActive,
    Map<String, dynamic>? metadata,
  }) {
    return Follow(
      id: id ?? this.id,
      followerId: followerId ?? this.followerId,
      followingId: followingId ?? this.followingId,
      followedAt: followedAt ?? this.followedAt,
      isActive: isActive ?? this.isActive,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'followerId': followerId,
      'followingId': followingId,
      'followedAt': followedAt.toIso8601String(),
      'isActive': isActive,
      'metadata': metadata,
    };
  }

  /// Create from JSON
  factory Follow.fromJson(Map<String, dynamic> json) {
    return Follow(
      id: json['id'] ?? '',
      followerId: json['followerId'] ?? '',
      followingId: json['followingId'] ?? '',
      followedAt: DateTime.parse(json['followedAt']),
      isActive: json['isActive'] ?? true,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Convert to JSON string
  String toJsonString() => jsonEncode(toJson());

  /// Create from JSON string
  factory Follow.fromJsonString(String jsonString) {
    return Follow.fromJson(jsonDecode(jsonString));
  }

  @override
  String toString() {
    return 'Follow(id: $id, followerId: $followerId, followingId: $followingId, followedAt: $followedAt, isActive: $isActive)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Follow && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Model for follow statistics
class FollowStats {
  final int followersCount;
  final int followingCount;
  final int mutualFollowsCount;
  final DateTime lastUpdated;

  const FollowStats({
    required this.followersCount,
    required this.followingCount,
    required this.mutualFollowsCount,
    required this.lastUpdated,
  });

  /// Create empty stats
  factory FollowStats.empty() {
    return FollowStats(
      followersCount: 0,
      followingCount: 0,
      mutualFollowsCount: 0,
      lastUpdated: DateTime.now(),
    );
  }

  /// Create a copy with updated fields
  FollowStats copyWith({
    int? followersCount,
    int? followingCount,
    int? mutualFollowsCount,
    DateTime? lastUpdated,
  }) {
    return FollowStats(
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      mutualFollowsCount: mutualFollowsCount ?? this.mutualFollowsCount,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'followersCount': followersCount,
      'followingCount': followingCount,
      'mutualFollowsCount': mutualFollowsCount,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  /// Create from JSON
  factory FollowStats.fromJson(Map<String, dynamic> json) {
    return FollowStats(
      followersCount: json['followersCount'] ?? 0,
      followingCount: json['followingCount'] ?? 0,
      mutualFollowsCount: json['mutualFollowsCount'] ?? 0,
      lastUpdated: DateTime.parse(json['lastUpdated']),
    );
  }

  @override
  String toString() {
    return 'FollowStats(followers: $followersCount, following: $followingCount, mutual: $mutualFollowsCount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FollowStats &&
        other.followersCount == followersCount &&
        other.followingCount == followingCount &&
        other.mutualFollowsCount == mutualFollowsCount;
  }

  @override
  int get hashCode => Object.hash(followersCount, followingCount, mutualFollowsCount);
}