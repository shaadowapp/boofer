import 'dart:convert';

enum UserStatus { online, offline, away, busy }

class User {
  final String id;
  final String virtualNumber;
  final String handle; // @username (alphanumeric + underscore)
  final String fullName; // Full name with spaces
  final String bio;
  final bool isDiscoverable;
  final DateTime? lastUsernameChange;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? profilePicture;
  final UserStatus status;
  final DateTime? lastSeen;
  final String? location;

  const User({
    required this.id,
    required this.virtualNumber,
    required this.handle,
    required this.fullName,
    required this.bio,
    required this.isDiscoverable,
    this.lastUsernameChange,
    required this.createdAt,
    required this.updatedAt,
    this.profilePicture,
    this.status = UserStatus.offline,
    this.lastSeen,
    this.location,
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
    return id.isNotEmpty && 
           virtualNumber.isNotEmpty && 
           handle.isNotEmpty;
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
    String? virtualNumber,
    String? handle,
    String? fullName,
    String? bio,
    bool? isDiscoverable,
    DateTime? lastUsernameChange,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? profilePicture,
    UserStatus? status,
    DateTime? lastSeen,
    String? location,
  }) {
    return User(
      id: id ?? this.id,
      virtualNumber: virtualNumber ?? this.virtualNumber,
      handle: handle ?? this.handle,
      fullName: fullName ?? this.fullName,
      bio: bio ?? this.bio,
      isDiscoverable: isDiscoverable ?? this.isDiscoverable,
      lastUsernameChange: lastUsernameChange ?? this.lastUsernameChange,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      profilePicture: profilePicture ?? this.profilePicture,
      status: status ?? this.status,
      lastSeen: lastSeen ?? this.lastSeen,
      location: location ?? this.location,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'virtualNumber': virtualNumber,
      'handle': handle,
      'fullName': fullName,
      'bio': bio,
      'isDiscoverable': isDiscoverable,
      'lastUsernameChange': lastUsernameChange?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'profilePicture': profilePicture,
      'status': status.name,
      'lastSeen': lastSeen?.toIso8601String(),
      'location': location,
    };
  }

  /// Create from JSON
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      virtualNumber: json['virtualNumber'] ?? '',
      handle: json['handle'] ?? '',
      fullName: json['fullName'] ?? '',
      bio: json['bio'] ?? '',
      isDiscoverable: json['isDiscoverable'] ?? true,
      lastUsernameChange: json['lastUsernameChange'] != null 
          ? DateTime.parse(json['lastUsernameChange'])
          : null,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      profilePicture: json['profilePicture'],
      status: UserStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => UserStatus.offline,
      ),
      lastSeen: json['lastSeen'] != null 
          ? DateTime.parse(json['lastSeen'])
          : null,
      location: json['location'],
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
    return 'User(id: $id, handle: $handle, fullName: $fullName, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is User && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}