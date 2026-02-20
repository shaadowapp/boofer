class UserPrivacySettings {
  final String userId;
  final String lastSeen;
  final String onlineStatus;
  final String profilePhoto;
  final String about;
  final bool readReceipts;
  final String defaultMessageTimer;
  final DateTime updatedAt;

  UserPrivacySettings({
    required this.userId,
    this.lastSeen = 'everyone',
    this.onlineStatus = 'everyone',
    this.profilePhoto = 'everyone',
    this.about = 'everyone',
    this.readReceipts = true,
    this.defaultMessageTimer = '12_hours',
    required this.updatedAt,
  });

  factory UserPrivacySettings.fromJson(Map<String, dynamic> json) {
    return UserPrivacySettings(
      userId: json['user_id'] ?? '',
      lastSeen: json['last_seen'] ?? 'everyone',
      onlineStatus: json['online_status'] ?? 'everyone',
      profilePhoto: json['profile_photo'] ?? 'everyone',
      about: json['about'] ?? 'everyone',
      readReceipts: json['read_receipts'] ?? true,
      defaultMessageTimer: json['default_message_timer'] ?? '12_hours',
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'last_seen': lastSeen,
      'online_status': onlineStatus,
      'profile_photo': profilePhoto,
      'about': about,
      'read_receipts': readReceipts,
      'default_message_timer': defaultMessageTimer,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  UserPrivacySettings copyWith({
    String? lastSeen,
    String? onlineStatus,
    String? profilePhoto,
    String? about,
    bool? readReceipts,
    String? defaultMessageTimer,
  }) {
    return UserPrivacySettings(
      userId: this.userId,
      lastSeen: lastSeen ?? this.lastSeen,
      onlineStatus: onlineStatus ?? this.onlineStatus,
      profilePhoto: profilePhoto ?? this.profilePhoto,
      about: about ?? this.about,
      readReceipts: readReceipts ?? this.readReceipts,
      defaultMessageTimer: defaultMessageTimer ?? this.defaultMessageTimer,
      updatedAt: DateTime.now(),
    );
  }
}
