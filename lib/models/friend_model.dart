import 'user_model.dart';
import '../utils/string_utils.dart';

class Friend {
  final String id;
  final String name; // Full name
  final String handle; // Username handle (without @)
  final String virtualNumber;
  final String? avatar;
  final String? profilePicture;
  final String lastMessage;
  final DateTime lastMessageTime;
  final int unreadCount;
  final bool isOnline;
  final bool isArchived;
  final bool isBlocked;
  final bool isMuted;
  final bool isVerified;
  final String ephemeralTimer; // 'none', 'after_seen', '24_hours', '72_hours'
  final bool isDeleted; // Intentional deletion from lobby

  Friend({
    required this.id,
    required this.name,
    required this.handle,
    required this.virtualNumber,
    this.avatar,
    this.profilePicture,
    required this.lastMessage,
    required this.lastMessageTime,
    this.unreadCount = 0,
    this.isOnline = false,
    this.isArchived = false,
    this.isBlocked = false,
    this.isMuted = false,
    this.isVerified = false,
    this.ephemeralTimer = '24_hours',
    this.isDeleted = false,
  });

  /// Get formatted virtual number (XXX-XXX-XXXX)
  String get formattedVirtualNumber =>
      StringUtils.formatVirtualNumber(virtualNumber);

  /// Get formatted handle with @ prefix
  String get formattedHandle => '@$handle';

  /// Get display name (full name or handle if full name is empty)
  String get displayName => name.isNotEmpty ? name : formattedHandle;

  /// Get initials for avatar (from full name or handle)
  String get initials {
    if (name.isNotEmpty) {
      final names = name.trim().split(' ');
      if (names.length >= 2) {
        return '${names.first[0]}${names.last[0]}'.toUpperCase();
      } else {
        return names.first.substring(0, 1).toUpperCase();
      }
    } else {
      return handle.substring(0, 1).toUpperCase();
    }
  }

  Friend copyWith({
    String? id,
    String? name,
    String? handle,
    String? virtualNumber,
    String? avatar,
    String? profilePicture,
    String? lastMessage,
    DateTime? lastMessageTime,
    int? unreadCount,
    bool? isOnline,
    bool? isArchived,
    bool? isBlocked,
    bool? isMuted,
    bool? isVerified,
    String? ephemeralTimer,
    bool? isDeleted,
  }) {
    return Friend(
      id: id ?? this.id,
      name: name ?? this.name,
      handle: handle ?? this.handle,
      virtualNumber: virtualNumber ?? this.virtualNumber,
      avatar: avatar ?? this.avatar,
      profilePicture: profilePicture ?? this.profilePicture,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCount: unreadCount ?? this.unreadCount,
      isOnline: isOnline ?? this.isOnline,
      isArchived: isArchived ?? this.isArchived,
      isBlocked: isBlocked ?? this.isBlocked,
      isMuted: isMuted ?? this.isMuted,
      isVerified: isVerified ?? this.isVerified,
      ephemeralTimer: ephemeralTimer ?? this.ephemeralTimer,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  // JSON serialization
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'handle': handle,
      'virtualNumber': virtualNumber,
      'avatar': avatar,
      'profilePicture': profilePicture,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime.toIso8601String(),
      'unreadCount': unreadCount,
      'isOnline': isOnline,
      'isArchived': isArchived,
      'isBlocked': isBlocked,
      'isMuted': isMuted,
      'isVerified': isVerified,
      'ephemeralTimer': ephemeralTimer,
      'isDeleted': isDeleted,
    };
  }

  /// Convert Friend to User for compatibility
  User toUser() {
    return User(
      id: id,
      email: '$handle@friend.local',
      virtualNumber: virtualNumber,
      handle: handle,
      fullName: name,
      bio: '',
      isDiscoverable: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      status: isOnline ? UserStatus.online : UserStatus.offline,
      isVerified: isVerified,
      profilePicture: profilePicture,
      avatar: avatar,
    );
  }

  factory Friend.fromJson(Map<String, dynamic> json) {
    // Handle nested format from SupabaseService.getUserConversations
    final otherUser = json['otherUser'] as Map<String, dynamic>?;

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

    if (otherUser != null) {
      return Friend(
        id: toString(otherUser['id']),
        name: toString(
          otherUser['name'] ?? otherUser['full_name'] ?? 'Unknown',
        ),
        handle: toString(otherUser['handle'] ?? 'unknown'),
        virtualNumber: toString(
          otherUser['virtualNumber'] ?? otherUser['virtual_number'] ?? '',
        ),
        avatar: toString(otherUser['avatar']),
        profilePicture: toString(
          otherUser['profile_picture'] ?? otherUser['profilePicture'],
        ),
        lastMessage: toString(json['lastMessage']),
        lastMessageTime: json['lastMessageTime'] != null
            ? DateTime.parse(json['lastMessageTime'].toString())
            : DateTime.now(),
        unreadCount: toInt(json['unreadCount'] ?? json['unread_count']),
        isOnline:
            (otherUser['status'] == 'online') || (json['isOnline'] == true),
        isArchived: toBool(json['isArchived'] ?? json['is_archived']),
        isBlocked: toBool(json['isBlocked'] ?? json['is_blocked']),
        isMuted: toBool(json['isMuted'] ?? json['is_muted']),
        isVerified:
            toBool(otherUser['is_verified'] ?? otherUser['isVerified']) ||
            toBool(json['isVerified'] ?? json['is_verified']),
        ephemeralTimer: toString(json['ephemeralTimer'] ?? '24_hours'),
        isDeleted: toBool(json['isDeleted'] ?? json['is_deleted']),
      );
    }

    return Friend(
      id: toString(json['id']),
      name: toString(json['name']),
      handle: toString(json['handle']),
      virtualNumber: toString(json['virtualNumber'] ?? json['virtual_number']),
      avatar: toString(json['avatar']),
      profilePicture: toString(
        json['profilePicture'] ?? json['profile_picture'],
      ),
      lastMessage: toString(json['lastMessage']),
      lastMessageTime: DateTime.parse(
        toString(json['lastMessageTime'] ?? DateTime.now().toIso8601String()),
      ),
      unreadCount: toInt(json['unreadCount'] ?? json['unread_count']),
      isOnline:
          toBool(json['isOnline']) || (toString(json['status']) == 'online'),
      isArchived: toBool(json['isArchived'] ?? json['is_archived']),
      isBlocked: toBool(json['isBlocked'] ?? json['is_blocked']),
      isMuted: toBool(json['isMuted'] ?? json['is_muted']),
      isVerified: toBool(json['isVerified'] ?? json['is_verified']),
      ephemeralTimer: toString(json['ephemeralTimer'] ?? '24_hours'),
      isDeleted: toBool(json['isDeleted'] ?? json['is_deleted']),
    );
  }

  static List<Friend> getDemoFriends() {
    return [
      Friend(
        id: '1',
        name: 'Alex Johnson',
        handle: 'alex_nyc',
        virtualNumber: '555-123-4567',
        lastMessage: 'Hey! How are you doing?',
        lastMessageTime: DateTime.now().subtract(const Duration(minutes: 5)),
        unreadCount: 2,
        isOnline: true,
      ),
      Friend(
        id: '2',
        name: 'Sarah Wilson',
        handle: 'sarah_coffee',
        virtualNumber: '555-234-5678',
        lastMessage: 'Thanks for the help earlier 👍',
        lastMessageTime: DateTime.now().subtract(const Duration(hours: 1)),
        unreadCount: 0,
        isOnline: true,
      ),
      Friend(
        id: '3',
        name: 'Mike Chen',
        handle: 'mike_tech',
        virtualNumber: '555-345-6789',
        lastMessage: 'See you tomorrow!',
        lastMessageTime: DateTime.now().subtract(const Duration(hours: 3)),
        unreadCount: 1,
        isOnline: false,
      ),
      Friend(
        id: '4',
        name: 'Emma Davis',
        handle: 'emma_artist',
        virtualNumber: '555-456-7890',
        lastMessage: 'The meeting went great 🎉',
        lastMessageTime: DateTime.now().subtract(const Duration(days: 1)),
        unreadCount: 0,
        isOnline: false,
      ),
      Friend(
        id: '5',
        name: 'James Brown',
        handle: 'james_music',
        virtualNumber: '555-567-8901',
        lastMessage: 'Can you send me the files?',
        lastMessageTime: DateTime.now().subtract(const Duration(days: 2)),
        unreadCount: 3,
        isOnline: true,
      ),
      Friend(
        id: '6',
        name: 'Lisa Garcia',
        handle: 'lisa_travel',
        virtualNumber: '555-678-9012',
        lastMessage: 'Happy birthday! 🎂',
        lastMessageTime: DateTime.now().subtract(const Duration(days: 3)),
        unreadCount: 0,
        isOnline: false,
      ),
    ];
  }
}
