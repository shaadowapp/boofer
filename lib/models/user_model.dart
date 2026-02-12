import 'dart:convert';

enum UserStatus { online, offline, away, busy }

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
  });

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
      'follower_count': followerCount,
      'following_count': followingCount,
      'friends_count': friendsCount,
      'pending_received_requests': pendingReceivedRequests,
      'pending_sent_requests': pendingSentRequests,
    };
  }

  /// Create from JSON
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      email:
          json['email'] ??
          '', // Default to empty string if not present in Firestore
      handle: json['handle'] ?? '',
      fullName: json['fullName'] ?? json['full_name'] ?? '',
      bio: json['bio'] ?? '',
      isDiscoverable:
          json['isDiscoverable'] ??
          (json['is_discoverable'] is int
              ? json['is_discoverable'] == 1
              : json['is_discoverable']) ??
          true,
      lastUsernameChange: json['lastUsernameChange'] != null
          ? DateTime.parse(json['lastUsernameChange'])
          : json['last_username_change'] != null
          ? DateTime.parse(json['last_username_change'])
          : null,
      createdAt: DateTime.parse(json['createdAt'] ?? json['created_at']),
      updatedAt: DateTime.parse(json['updatedAt'] ?? json['updated_at']),
      profilePicture: json['profilePicture'] ?? json['profile_picture'],
      avatar: json['avatar'],
      status: UserStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => UserStatus.offline,
      ),
      lastSeen: json['lastSeen'] != null
          ? DateTime.parse(json['lastSeen'])
          : json['last_seen'] != null
          ? DateTime.parse(json['last_seen'])
          : null,
      location: json['location'],
      age: json['age'],
      virtualNumber: json['virtualNumber'] ?? json['virtual_number'],
      followerCount: json['followerCount'] ?? json['follower_count'] ?? 0,
      followingCount: json['followingCount'] ?? json['following_count'] ?? 0,
      friendsCount: json['friendsCount'] ?? json['friends_count'] ?? 0,
      pendingReceivedRequests:
          json['pendingReceivedRequests'] ??
          json['pending_received_requests'] ??
          0,
      pendingSentRequests:
          json['pendingSentRequests'] ?? json['pending_sent_requests'] ?? 0,
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
