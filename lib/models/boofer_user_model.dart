import 'dart:convert';
import 'user_model.dart';

class BooferUser extends User {
  final String? displayName;
  final String? avatar;
  final String? location;
  final List<String> interests;
  final bool allowNearbyDiscovery;
  final double? latitude;
  final double? longitude;

  const BooferUser({
    required super.id,
    required super.virtualNumber,
    required super.handle,
    required super.fullName,
    required super.bio,
    required super.isDiscoverable,
    super.lastUsernameChange,
    required super.createdAt,
    required super.updatedAt,
    super.profilePicture,
    super.status,
    super.lastSeen,
    this.displayName,
    this.avatar,
    this.location,
    this.interests = const [],
    this.allowNearbyDiscovery = true,
    this.latitude,
    this.longitude,
  });

  /// Get effective name (displayName, fullName, or handle)
  @override
  String get displayName {
    if (this.displayName != null && this.displayName!.isNotEmpty) {
      return this.displayName!;
    }
    return super.displayName;
  }

  /// Get username without @ prefix
  String get username => handle;

  /// Check if user is online
  bool get isOnline => status == UserStatus.online;

  /// Create a copy with updated fields
  @override
  BooferUser copyWith({
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
    String? displayName,
    String? avatar,
    String? location,
    List<String>? interests,
    bool? allowNearbyDiscovery,
    double? latitude,
    double? longitude,
  }) {
    return BooferUser(
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
      displayName: displayName ?? this.displayName,
      avatar: avatar ?? this.avatar,
      location: location ?? this.location,
      interests: interests ?? this.interests,
      allowNearbyDiscovery: allowNearbyDiscovery ?? this.allowNearbyDiscovery,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  /// Convert to JSON
  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json.addAll({
      'displayName': displayName,
      'avatar': avatar,
      'location': location,
      'interests': interests,
      'allowNearbyDiscovery': allowNearbyDiscovery,
      'latitude': latitude,
      'longitude': longitude,
    });
    return json;
  }

  /// Create from JSON
  factory BooferUser.fromJson(Map<String, dynamic> json) {
    return BooferUser(
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
      displayName: json['displayName'],
      avatar: json['avatar'],
      location: json['location'],
      interests: List<String>.from(json['interests'] ?? []),
      allowNearbyDiscovery: json['allowNearbyDiscovery'] ?? true,
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
    );
  }

  /// Create from JSON string
  factory BooferUser.fromJsonString(String jsonString) {
    return BooferUser.fromJson(jsonDecode(jsonString));
  }

  /// Get demo users for testing
  static List<BooferUser> getDemoUsers() {
    final now = DateTime.now();
    return [
      BooferUser(
        id: 'user_1',
        virtualNumber: '+1234567890',
        handle: 'alice_dev',
        fullName: 'Alice Johnson',
        bio: 'Flutter developer passionate about mobile apps',
        isDiscoverable: true,
        createdAt: now.subtract(const Duration(days: 30)),
        updatedAt: now.subtract(const Duration(hours: 2)),
        status: UserStatus.online,
        displayName: 'Alice',
        avatar: 'https://i.pravatar.cc/150?img=1',
        location: 'San Francisco, CA',
        interests: ['Flutter', 'Mobile Development', 'UI/UX'],
        allowNearbyDiscovery: true,
        latitude: 37.7749,
        longitude: -122.4194,
      ),
      BooferUser(
        id: 'user_2',
        virtualNumber: '+1234567891',
        handle: 'bob_designer',
        fullName: 'Bob Smith',
        bio: 'UI/UX Designer creating beautiful experiences',
        isDiscoverable: true,
        createdAt: now.subtract(const Duration(days: 25)),
        updatedAt: now.subtract(const Duration(minutes: 30)),
        status: UserStatus.away,
        displayName: 'Bob',
        avatar: 'https://i.pravatar.cc/150?img=2',
        location: 'New York, NY',
        interests: ['Design', 'Prototyping', 'User Research'],
        allowNearbyDiscovery: true,
        latitude: 40.7128,
        longitude: -74.0060,
      ),
      BooferUser(
        id: 'user_3',
        virtualNumber: '+1234567892',
        handle: 'charlie_pm',
        fullName: 'Charlie Brown',
        bio: 'Product Manager building the future',
        isDiscoverable: true,
        createdAt: now.subtract(const Duration(days: 20)),
        updatedAt: now.subtract(const Duration(hours: 1)),
        status: UserStatus.busy,
        displayName: 'Charlie',
        avatar: 'https://i.pravatar.cc/150?img=3',
        location: 'Austin, TX',
        interests: ['Product Management', 'Strategy', 'Analytics'],
        allowNearbyDiscovery: false,
        latitude: 30.2672,
        longitude: -97.7431,
      ),
      BooferUser(
        id: 'user_4',
        virtualNumber: '+1234567893',
        handle: 'diana_data',
        fullName: 'Diana Wilson',
        bio: 'Data Scientist exploring insights',
        isDiscoverable: true,
        createdAt: now.subtract(const Duration(days: 15)),
        updatedAt: now.subtract(const Duration(days: 1)),
        status: UserStatus.offline,
        lastSeen: now.subtract(const Duration(hours: 6)),
        displayName: 'Diana',
        avatar: 'https://i.pravatar.cc/150?img=4',
        location: 'Seattle, WA',
        interests: ['Data Science', 'Machine Learning', 'Python'],
        allowNearbyDiscovery: true,
        latitude: 47.6062,
        longitude: -122.3321,
      ),
      BooferUser(
        id: 'user_5',
        virtualNumber: '+1234567894',
        handle: 'evan_backend',
        fullName: 'Evan Davis',
        bio: 'Backend Engineer scaling systems',
        isDiscoverable: true,
        createdAt: now.subtract(const Duration(days: 10)),
        updatedAt: now.subtract(const Duration(minutes: 15)),
        status: UserStatus.online,
        displayName: 'Evan',
        avatar: 'https://i.pravatar.cc/150?img=5',
        location: 'Denver, CO',
        interests: ['Backend Development', 'DevOps', 'Cloud'],
        allowNearbyDiscovery: true,
        latitude: 39.7392,
        longitude: -104.9903,
      ),
    ];
  }

  @override
  String toString() {
    return 'BooferUser(id: $id, handle: $handle, displayName: ${this.displayName}, status: $status)';
  }
}