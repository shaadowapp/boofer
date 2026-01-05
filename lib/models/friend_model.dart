class Friend {
  final String id;
  final String name;
  final String virtualNumber;
  final String? avatar;
  final String lastMessage;
  final DateTime lastMessageTime;
  final int unreadCount;
  final bool isOnline;
  final bool isArchived;

  Friend({
    required this.id,
    required this.name,
    required this.virtualNumber,
    this.avatar,
    required this.lastMessage,
    required this.lastMessageTime,
    this.unreadCount = 0,
    this.isOnline = false,
    this.isArchived = false,
  });

  Friend copyWith({
    String? id,
    String? name,
    String? virtualNumber,
    String? avatar,
    String? lastMessage,
    DateTime? lastMessageTime,
    int? unreadCount,
    bool? isOnline,
    bool? isArchived,
  }) {
    return Friend(
      id: id ?? this.id,
      name: name ?? this.name,
      virtualNumber: virtualNumber ?? this.virtualNumber,
      avatar: avatar ?? this.avatar,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCount: unreadCount ?? this.unreadCount,
      isOnline: isOnline ?? this.isOnline,
      isArchived: isArchived ?? this.isArchived,
    );
  }

  static List<Friend> getDemoFriends() {
    return [
      Friend(
        id: '1',
        name: 'Alex Johnson',
        virtualNumber: '(555) 123-4567',
        lastMessage: 'Hey! How are you doing?',
        lastMessageTime: DateTime.now().subtract(const Duration(minutes: 5)),
        unreadCount: 2,
        isOnline: true,
      ),
      Friend(
        id: '2',
        name: 'Sarah Wilson',
        virtualNumber: '(555) 234-5678',
        lastMessage: 'Thanks for the help earlier 👍',
        lastMessageTime: DateTime.now().subtract(const Duration(hours: 1)),
        unreadCount: 0,
        isOnline: true,
      ),
      Friend(
        id: '3',
        name: 'Mike Chen',
        virtualNumber: '(555) 345-6789',
        lastMessage: 'See you tomorrow!',
        lastMessageTime: DateTime.now().subtract(const Duration(hours: 3)),
        unreadCount: 1,
        isOnline: false,
      ),
      Friend(
        id: '4',
        name: 'Emma Davis',
        virtualNumber: '(555) 456-7890',
        lastMessage: 'The meeting went great 🎉',
        lastMessageTime: DateTime.now().subtract(const Duration(days: 1)),
        unreadCount: 0,
        isOnline: false,
      ),
      Friend(
        id: '5',
        name: 'James Brown',
        virtualNumber: '(555) 567-8901',
        lastMessage: 'Can you send me the files?',
        lastMessageTime: DateTime.now().subtract(const Duration(days: 2)),
        unreadCount: 3,
        isOnline: true,
      ),
      Friend(
        id: '6',
        name: 'Lisa Garcia',
        virtualNumber: '(555) 678-9012',
        lastMessage: 'Happy birthday! 🎂',
        lastMessageTime: DateTime.now().subtract(const Duration(days: 3)),
        unreadCount: 0,
        isOnline: false,
      ),
    ];
  }
}