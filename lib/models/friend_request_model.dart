import 'dart:convert';

/// Status of a friend request
enum FriendRequestStatus {
  pending,
  accepted,
  rejected,
  cancelled,
}

/// Model representing a friend request
class FriendRequest {
  final String id;
  final String fromUserId;
  final String toUserId;
  final String? message;
  final FriendRequestStatus status;
  final DateTime sentAt;
  final DateTime? respondedAt;
  final Map<String, dynamic>? metadata;

  const FriendRequest({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    this.message,
    required this.status,
    required this.sentAt,
    this.respondedAt,
    this.metadata,
  });

  /// Create a new friend request
  factory FriendRequest.create({
    required String fromUserId,
    required String toUserId,
    String? message,
    Map<String, dynamic>? metadata,
  }) {
    final now = DateTime.now();
    return FriendRequest(
      id: '${fromUserId}_${toUserId}_${now.millisecondsSinceEpoch}',
      fromUserId: fromUserId,
      toUserId: toUserId,
      message: message,
      status: FriendRequestStatus.pending,
      sentAt: now,
      metadata: metadata,
    );
  }

  /// Check if request is pending
  bool get isPending => status == FriendRequestStatus.pending;

  /// Check if request is accepted
  bool get isAccepted => status == FriendRequestStatus.accepted;

  /// Check if request is rejected
  bool get isRejected => status == FriendRequestStatus.rejected;

  /// Check if request is cancelled
  bool get isCancelled => status == FriendRequestStatus.cancelled;

  /// Get status display text
  String get statusText {
    switch (status) {
      case FriendRequestStatus.pending:
        return 'Pending';
      case FriendRequestStatus.accepted:
        return 'Accepted';
      case FriendRequestStatus.rejected:
        return 'Rejected';
      case FriendRequestStatus.cancelled:
        return 'Cancelled';
    }
  }

  /// Create a copy with updated fields
  FriendRequest copyWith({
    String? id,
    String? fromUserId,
    String? toUserId,
    String? message,
    FriendRequestStatus? status,
    DateTime? sentAt,
    DateTime? respondedAt,
    Map<String, dynamic>? metadata,
  }) {
    return FriendRequest(
      id: id ?? this.id,
      fromUserId: fromUserId ?? this.fromUserId,
      toUserId: toUserId ?? this.toUserId,
      message: message ?? this.message,
      status: status ?? this.status,
      sentAt: sentAt ?? this.sentAt,
      respondedAt: respondedAt ?? this.respondedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'message': message,
      'status': status.name,
      'sentAt': sentAt.toIso8601String(),
      'respondedAt': respondedAt?.toIso8601String(),
      'metadata': metadata,
    };
  }

  /// Create from JSON
  factory FriendRequest.fromJson(Map<String, dynamic> json) {
    return FriendRequest(
      id: json['id'] ?? '',
      fromUserId: json['fromUserId'] ?? '',
      toUserId: json['toUserId'] ?? '',
      message: json['message'],
      status: FriendRequestStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => FriendRequestStatus.pending,
      ),
      sentAt: DateTime.parse(json['sentAt']),
      respondedAt: json['respondedAt'] != null 
          ? DateTime.parse(json['respondedAt'])
          : null,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Convert to JSON string
  String toJsonString() => jsonEncode(toJson());

  /// Create from JSON string
  factory FriendRequest.fromJsonString(String jsonString) {
    return FriendRequest.fromJson(jsonDecode(jsonString));
  }

  @override
  String toString() {
    return 'FriendRequest(id: $id, from: $fromUserId, to: $toUserId, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FriendRequest && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Model for friend request statistics
class FriendRequestStats {
  final int pendingReceived;
  final int pendingSent;
  final int totalFriends;
  final DateTime lastUpdated;

  const FriendRequestStats({
    required this.pendingReceived,
    required this.pendingSent,
    required this.totalFriends,
    required this.lastUpdated,
  });

  /// Create empty stats
  factory FriendRequestStats.empty() {
    return FriendRequestStats(
      pendingReceived: 0,
      pendingSent: 0,
      totalFriends: 0,
      lastUpdated: DateTime.now(),
    );
  }

  /// Create a copy with updated fields
  FriendRequestStats copyWith({
    int? pendingReceived,
    int? pendingSent,
    int? totalFriends,
    DateTime? lastUpdated,
  }) {
    return FriendRequestStats(
      pendingReceived: pendingReceived ?? this.pendingReceived,
      pendingSent: pendingSent ?? this.pendingSent,
      totalFriends: totalFriends ?? this.totalFriends,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'pendingReceived': pendingReceived,
      'pendingSent': pendingSent,
      'totalFriends': totalFriends,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  /// Create from JSON
  factory FriendRequestStats.fromJson(Map<String, dynamic> json) {
    return FriendRequestStats(
      pendingReceived: json['pendingReceived'] ?? 0,
      pendingSent: json['pendingSent'] ?? 0,
      totalFriends: json['totalFriends'] ?? 0,
      lastUpdated: DateTime.parse(json['lastUpdated']),
    );
  }

  @override
  String toString() {
    return 'FriendRequestStats(received: $pendingReceived, sent: $pendingSent, friends: $totalFriends)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FriendRequestStats &&
        other.pendingReceived == pendingReceived &&
        other.pendingSent == pendingSent &&
        other.totalFriends == totalFriends;
  }

  @override
  int get hashCode => Object.hash(pendingReceived, pendingSent, totalFriends);
}