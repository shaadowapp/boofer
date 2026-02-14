import 'dart:convert';
import '../utils/string_utils.dart';

enum UserStatus { online, offline, away, busy, frozen, deleted }

class User {
  final String id; // Firebase UID
  final String email; // Google email
  final String handle; // @username (alphanumeric + underscore)
  final String fullName; // Full name from Google
  final String bio;
  final bool isDiscoverable;
  final DateTime? lastUsernameChange;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? profilePicture; // Google photo URL
  final String? avatar; // Emoji avatar for profile
  final UserStatus status;
  final DateTime? lastSeen;
  final String? location;
  final int? age;
  final String? virtualNumber; // Virtual number for user identification
  final int followerCount;
  final int followingCount;
  final int friendsCount;
  final int pendingReceivedRequests;
  final int pendingSentRequests;
  final bool isVerified;

  const User({
    required this.id,
    required this.email,
    required this.handle,
    required this.fullName,
    required this.bio,
    required this.isDiscoverable,
    this.lastUsernameChange,
    required this.createdAt,
    required this.updatedAt,
    this.profilePicture,
    this.avatar,
    this.status = UserStatus.offline,
    this.lastSeen,
    this.location,
    this.age,
    this.virtualNumber,
    this.followerCount = 0,
    this.followingCount = 0,
    this.friendsCount = 0,
    this.pendingReceivedRequests = 0,
    this.pendingSentRequests = 0,
    this.isVerified = false,
  });

  /// Get formatted virtual number (XXX-XXX-XXXX)
  String get formattedVirtualNumber =>
      StringUtils.formatVirtualNumber(virtualNumber);

  /// Get formatted handle with @ prefix
  String get formattedHandle => '@$handle';

  /// Get display name (full name or handle if full name is empty)
  String get displayName => fullName.isNotEmpty ? fullName : formattedHandle;

  /// Get initials for avatar (from full name or handle)
  String get initials {
    if (fullName.isNotEmpty) {
      final names = fullName.trim().split(' ');
      if (names.length >= 2) {
        return '${names.first[0]}${names.last[0]}'.toUpperCase();
      } else {
        return names.first.substring(0, 1).toUpperCase();
      }
    } else {
      return handle.substring(0, 1).toUpperCase();
    }
  }

  /// Check if profile is complete
  bool get isProfileComplete {
    return id.isNotEmpty && email.isNotEmpty && handle.isNotEmpty;
  }

  /// Get status display text
  String get statusText {
    switch (status) {
      case UserStatus.online:
        return 'Online';
      case UserStatus.away:
        return 'Away';
      case UserStatus.busy:
        return 'Busy';
      case UserStatus.frozen:
        return 'Account Frozen';
      case UserStatus.deleted:
        return 'Deleted Account';
      case UserStatus.offline:
        if (lastSeen != null) {
          final now = DateTime.now();
          final difference = now.difference(lastSeen!);

          if (difference.inMinutes < 1) {
            return 'Last seen just now';
          } else if (difference.inMinutes < 60) {
            return 'Last seen ${difference.inMinutes}m ago';
          } else if (difference.inHours < 24) {
            return 'Last seen ${difference.inHours}h ago';
          } else if (difference.inDays < 7) {
            return 'Last seen ${difference.inDays}d ago';
          } else {
            return 'Last seen long ago';
          }
        }
        return 'Offline';
    }
  }

  /// Create a copy with updated fields
  User copyWith({
    String? id,
    String? email,
    String? handle,
    String? fullName,
    String? bio,
    bool? isDiscoverable,
    DateTime? lastUsernameChange,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? profilePicture,
    String? avatar,
    UserStatus? status,
    DateTime? lastSeen,
    String? location,
    int? age,
    String? virtualNumber,
    int? followerCount,
    int? followingCount,
    int? friendsCount,
    int? pendingReceivedRequests,
    int? pendingSentRequests,
    bool? isVerified,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      handle: handle ?? this.handle,
      fullName: fullName ?? this.fullName,
      bio: bio ?? this.bio,
      isDiscoverable: isDiscoverable ?? this.isDiscoverable,
      lastUsernameChange: lastUsernameChange ?? this.lastUsernameChange,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      profilePicture: profilePicture ?? this.profilePicture,
      avatar: avatar ?? this.avatar,
      status: status ?? this.status,
      lastSeen: lastSeen ?? this.lastSeen,
      location: location ?? this.location,
      age: age ?? this.age,
      virtualNumber: virtualNumber ?? this.virtualNumber,
      followerCount: followerCount ?? this.followerCount,
      followingCount: followingCount ?? this.followingCount,
      friendsCount: friendsCount ?? this.friendsCount,
      pendingReceivedRequests:
          pendingReceivedRequests ?? this.pendingReceivedRequests,
      pendingSentRequests: pendingSentRequests ?? this.pendingSentRequests,
      isVerified: isVerified ?? this.isVerified,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'handle': handle,
      'fullName': fullName,
      'bio': bio,
      'isDiscoverable': isDiscoverable,
      'lastUsernameChange': lastUsernameChange?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'profilePicture': profilePicture,
      'avatar': avatar,
      'status': status.name,
      'lastSeen': lastSeen?.toIso8601String(),
      'location': location,
      'age': age,
      'virtualNumber': virtualNumber,
      'followerCount': followerCount,
      'followingCount': followingCount,
      'friendsCount': friendsCount,
      'pendingReceivedRequests': pendingReceivedRequests,
      'pendingSentRequests': pendingSentRequests,
      'isVerified': isVerified,
    };
  }

  /// Convert to database JSON (snake_case fields)
  Map<String, dynamic> toDatabaseJson() {
    return {
      'id': id,
      'email': email,
      'handle': handle,
      'full_name': fullName,
      'bio': bio,
      'is_discoverable': isDiscoverable
          ? 1
          : 0, // Convert bool to int for SQLite
      'last_username_change': lastUsernameChange?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'profile_picture': profilePicture,
      'avatar': avatar,
      'status': status.name,
      'last_seen': lastSeen?.toIso8601String(),
      'location': location,
      'age': age,
      'virtual_number': virtualNumber,
      // Removed count columns as they don't exist in the profiles table
      // 'follower_count': followerCount,
      // 'following_count': followingCount,
      // 'friends_count': friendsCount,
      // 'pending_received_requests': pendingReceivedRequests,
      // 'pending_sent_requests': pendingSentRequests,
      'is_verified': isVerified ? 1 : 0,
    };
  }

  /// Create from JSON
  factory User.fromJson(Map<String, dynamic> json) {
    // Robust type conversion helpers
    String toString(dynamic value) => value?.toString() ?? '';
    int toInt(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    bool toBool(dynamic value) {
      if (value == null) return false;
      if (value is bool) return value;
      if (value is int) return value == 1;
      if (value is String) return value.toLowerCase() == 'true' || value == '1';
      return false;
    }

    DateTime parseDate(dynamic value, [DateTime? fallback]) {
      if (value == null) return fallback ?? DateTime.now();
      try {
        if (value is DateTime) return value;
        return DateTime.parse(value.toString());
      } catch (e) {
        return fallback ?? DateTime.now();
      }
    }

    return User(
      id: toString(json['id']),
      email: toString(json['email']),
      handle: toString(json['handle']),
      fullName: toString(json['fullName'] ?? json['full_name']),
      bio: toString(json['bio']),
      isDiscoverable: toBool(json['isDiscoverable'] ?? json['is_discoverable']),
      lastUsernameChange:
          json['lastUsernameChange'] != null ||
              json['last_username_change'] != null
          ? parseDate(
              json['lastUsernameChange'] ?? json['last_username_change'],
            )
          : null,
      createdAt: parseDate(json['createdAt'] ?? json['created_at']),
      updatedAt: parseDate(json['updatedAt'] ?? json['updated_at']),
      profilePicture: json['profilePicture'] ?? json['profile_picture'],
      avatar: json['avatar'],
      status: UserStatus.values.firstWhere(
        (e) => e.name == toString(json['status']),
        orElse: () => UserStatus.offline,
      ),
      lastSeen: json['lastSeen'] != null || json['last_seen'] != null
          ? parseDate(json['lastSeen'] ?? json['last_seen'])
          : null,
      location: toString(json['location']),
      age: toInt(json['age']),
      virtualNumber: toString(json['virtualNumber'] ?? json['virtual_number']),
      followerCount: toInt(json['followerCount'] ?? json['follower_count']),
      followingCount: toInt(json['followingCount'] ?? json['following_count']),
      friendsCount: toInt(json['friendsCount'] ?? json['friends_count']),
      pendingReceivedRequests: toInt(
        json['pendingReceivedRequests'] ?? json['pending_received_requests'],
      ),
      pendingSentRequests: toInt(
        json['pendingSentRequests'] ?? json['pending_sent_requests'],
      ),
      isVerified: toBool(json['isVerified'] ?? json['is_verified']),
    );
  }

  /// Convert to JSON string
  String toJsonString() => jsonEncode(toJson());

  /// Create from JSON string
  factory User.fromJsonString(String jsonString) {
    return User.fromJson(jsonDecode(jsonString));
  }

  @override
  String toString() {
    return 'User(id: $id, email: $email, handle: $handle, fullName: $fullName, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is User && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  /// Create User from Firestore document
  factory User.fromFirestore(Map<String, dynamic> data, String documentId) {
    return User(
      id: documentId,
      email: data['email'] ?? '',
      handle: data['handle'] ?? '',
      fullName: data['fullName'] ?? '',
      bio: data['bio'] ?? '',
      isDiscoverable: data['isDiscoverable'] ?? true,
      lastUsernameChange: data['lastUsernameChange'] != null
          ? DateTime.parse(data['lastUsernameChange'])
          : null,
      createdAt: data['createdAt'] != null
          ? DateTime.parse(data['createdAt'])
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null
          ? DateTime.parse(data['updatedAt'])
          : DateTime.now(),
      profilePicture: data['profilePicture'],
      avatar: data['avatar'],
      status: UserStatus.values.firstWhere(
        (e) => e.toString() == 'UserStatus.${data['status'] ?? 'offline'}',
        orElse: () => UserStatus.offline,
      ),
      lastSeen: data['lastSeen'] != null
          ? DateTime.parse(data['lastSeen'])
          : null,
      location: data['location'],
      age: data['age'],
      virtualNumber: data['virtualNumber'],
      followerCount: data['followerCount'] ?? 0,
      followingCount: data['followingCount'] ?? 0,
      friendsCount: data['friendsCount'] ?? 0,
      pendingReceivedRequests: data['pendingReceivedRequests'] ?? 0,
      pendingSentRequests: data['pendingSentRequests'] ?? 0,
    );
  }

  /// Convert User to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'handle': handle,
      'fullName': fullName,
      'bio': bio,
      'isDiscoverable': isDiscoverable,
      'lastUsernameChange': lastUsernameChange?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'profilePicture': profilePicture,
      'avatar': avatar,
      'status': status.toString().split('.').last,
      'lastSeen': lastSeen?.toIso8601String(),
      'location': location,
      'age': age,
      'virtualNumber': virtualNumber,
      'followerCount': followerCount,
      'followingCount': followingCount,
      'friendsCount': friendsCount,
      'pendingReceivedRequests': pendingReceivedRequests,
      'pendingSentRequests': pendingSentRequests,
    };
  }
}
