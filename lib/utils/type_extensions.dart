import '../models/friend_model.dart';
import '../models/user_model.dart';

/// Extension methods for type conversions between Friend and User
extension FriendListExtensions on List<Friend> {
  /// Convert a list of Friends to a list of Users
  List<User> toUserList() {
    return map((friend) => friend.toUser()).toList();
  }
}

extension UserListExtensions on List<User> {
  /// Convert a list of Users to a list of Friends (for compatibility)
  List<Friend> toFriendList() {
    return map((user) => Friend(
      id: user.id,
      name: user.fullName,
      handle: user.handle,
      virtualNumber: user.virtualNumber ?? '',
      lastMessage: '',
      lastMessageTime: DateTime.now(),
      isOnline: user.status == UserStatus.online,
    )).toList();
  }
}