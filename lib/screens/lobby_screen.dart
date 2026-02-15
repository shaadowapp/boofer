import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/friend_model.dart';
import '../providers/chat_provider.dart';
import '../providers/archive_settings_provider.dart';
import '../services/user_service.dart';
import '../services/supabase_service.dart';
import '../utils/svg_icons.dart';
import '../l10n/app_localizations.dart';
import 'archived_chats_screen.dart';
import 'friend_chat_screen.dart';
import '../widgets/user_avatar.dart';
import '../core/constants.dart';
import 'user_search_screen.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  String? _userNumber;

  @override
  void initState() {
    super.initState();
    _loadUserNumber();
  }

  Future<void> _loadUserNumber() async {
    final number = await UserService.getUserNumber();
    setState(() {
      _userNumber = number;
    });
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return 'now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else {
      return '${time.day}/${time.month}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // Handle case where localizations are not available
    if (l10n == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Consumer2<ChatProvider, ArchiveSettingsProvider>(
        builder: (context, chatProvider, archiveSettings, child) {
          final activeChats = chatProvider.activeChats;
          final archivedChats = chatProvider.archivedChats;

          // 1. Initial Loading State (Before cache or network returned anything)
          if (!chatProvider.friendsLoaded && activeChats.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          // 2. Empty State (Loaded but no chats found)
          if (activeChats.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async {
                await chatProvider.refreshFriends();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height - 200,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SvgIcons.sized(
                          SvgIcons.peopleOutline,
                          64,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No chats yet',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.5),
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Start connecting with people',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.5),
                              ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const UserSearchScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.explore_outlined),
                          label: const Text('Explore Users'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              await chatProvider.refreshFriends();
            },
            child: ListView.builder(
              itemCount: _calculateTotalItems(
                activeChats,
                archivedChats,
                archiveSettings,
              ),
              itemBuilder: (context, index) {
                return _buildListItem(
                  context,
                  index,
                  activeChats,
                  archivedChats,
                  archiveSettings,
                  chatProvider,
                  l10n,
                );
              },
            ),
          );
        },
      ),
    );
  }

  int _calculateTotalItems(
    List<Friend> activeChats,
    List<Friend> archivedChats,
    ArchiveSettingsProvider archiveSettings,
  ) {
    int totalItems = activeChats.length;

    // Add archive button if there are archived chats and it should be shown
    if (archivedChats.isNotEmpty) {
      if (archiveSettings.archiveButtonPosition ==
              ArchiveButtonPosition.topOfChats ||
          archiveSettings.archiveButtonPosition ==
              ArchiveButtonPosition.bottomOfChats) {
        totalItems += 1;
      }
    }

    return totalItems;
  }

  Widget _buildListItem(
    BuildContext context,
    int index,
    List<Friend> activeChats,
    List<Friend> archivedChats,
    ArchiveSettingsProvider archiveSettings,
    ChatProvider chatProvider,
    AppLocalizations l10n,
  ) {
    // Show archive button at the top if configured
    if (archivedChats.isNotEmpty &&
        archiveSettings.archiveButtonPosition ==
            ArchiveButtonPosition.topOfChats &&
        index == 0) {
      return _buildArchiveContactCard(context, archivedChats, l10n);
    }

    // Show archive button at the bottom if configured
    if (archivedChats.isNotEmpty &&
        archiveSettings.archiveButtonPosition ==
            ArchiveButtonPosition.bottomOfChats &&
        index == activeChats.length) {
      return _buildArchiveContactCard(context, archivedChats, l10n);
    }

    // Calculate the actual friend index
    int friendIndex = index;
    if (archivedChats.isNotEmpty &&
        archiveSettings.archiveButtonPosition ==
            ArchiveButtonPosition.topOfChats) {
      friendIndex = index - 1;
    }

    // Show friend tile
    if (friendIndex >= 0 && friendIndex < activeChats.length) {
      final friend = activeChats[friendIndex];
      return _buildFriendTile(friend, chatProvider, l10n);
    }

    // Fallback - should not happen
    return const SizedBox.shrink();
  }

  Widget _buildArchiveContactCard(
    BuildContext context,
    List<Friend> archivedChats,
    AppLocalizations l10n,
  ) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ArchivedChatsScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context).dividerColor.withOpacity(0.3),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            // Archive icon as avatar
            CircleAvatar(
              radius: 28,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.primary.withOpacity(0.1),
              child: Icon(
                Icons.archive,
                color: Theme.of(context).colorScheme.primary,
                size: 24,
              ),
            ),

            const SizedBox(width: 16),

            // Archive info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${l10n.archived} (${archivedChats.length} ${archivedChats.length == 1 ? 'chat' : 'chats'})',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.5),
                        size: 20,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'View archived conversations',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.7),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendTile(
    Friend friend,
    ChatProvider chatProvider,
    AppLocalizations l10n,
  ) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FriendChatScreen(
              recipientId: friend.id,
              recipientName: friend.name,
              recipientAvatar: friend.avatar,
              recipientProfilePicture: friend.profilePicture,
              recipientHandle: friend.handle,
              virtualNumber: friend.virtualNumber,
            ),
          ),
        );
      },
      onLongPress: () {
        _showChatOptionsBottomSheet(friend, chatProvider, l10n);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context).dividerColor.withOpacity(0.1),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            Stack(
              children: [
                UserAvatar(
                  avatar: friend.avatar,
                  profilePicture: friend.profilePicture,
                  name: friend.name,
                  radius: 28,
                  fontSize: 24,
                ),
                if (friend.isOnline)
                  Positioned(
                    right: 2,
                    bottom: 2,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                friend.name,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (friend.isVerified) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Icons.verified,
                                size: 14,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ],
                            if (friend.isMutual) ...[
                              const SizedBox(width: 4),
                              Tooltip(
                                message: 'Mutual Connection',
                                child: Icon(
                                  Icons.people,
                                  size: 14,
                                  color: Colors.green.withOpacity(0.7),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          if (chatProvider.isChatMuted(friend.id)) ...[
                            Icon(
                              Icons.volume_off,
                              size: 16,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withOpacity(0.5),
                            ),
                            const SizedBox(width: 4),
                          ],
                          if (chatProvider.isChatPinned(friend.id)) ...[
                            Icon(
                              Icons.push_pin,
                              size: 16,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            _formatTime(friend.lastMessageTime),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: friend.unreadCount > 0
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.onSurface
                                            .withOpacity(0.5),
                                  fontWeight: friend.unreadCount > 0
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                friend.lastMessage.isNotEmpty
                                    ? friend.lastMessage
                                    : 'Say hi to ${friend.name}! 👋',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: friend.unreadCount > 0
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.onSurface
                                          : Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withOpacity(0.5),
                                      fontStyle: friend.lastMessage.isEmpty
                                          ? FontStyle.italic
                                          : FontStyle.normal,
                                      fontWeight: friend.unreadCount > 0
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (friend.unreadCount > 0)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 20,
                            minHeight: 20,
                          ),
                          child: Center(
                            child: Text(
                              friend.unreadCount > 99
                                  ? '99+'
                                  : friend.unreadCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showChatOptionsBottomSheet(
    Friend friend,
    ChatProvider chatProvider,
    AppLocalizations l10n,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allow full height if needed
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header with friend info
              Row(
                children: [
                  Hero(
                    tag: 'avatar_sheet_${friend.id}',
                    child: UserAvatar(
                      avatar: friend.avatar,
                      profilePicture: friend.profilePicture,
                      name: friend.name,
                      radius: 30,
                      fontSize: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              friend.name,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            if (friend.isVerified ||
                                AppConstants.officialIds.contains(
                                  friend.id,
                                )) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Icons.verified,
                                size: 16,
                                color: friend.id == AppConstants.booferId
                                    ? Colors.green
                                    : Theme.of(context).colorScheme.primary,
                              ),
                            ],
                            // Unread eye indicator after name
                            if (friend.unreadCount > 0) ...[
                              const SizedBox(width: 6),
                              Icon(
                                Icons.visibility_off,
                                size: 16,
                                color: chatProvider.isChatMuted(friend.id)
                                    ? Colors.orange
                                    : Theme.of(context).colorScheme.primary,
                              ),
                            ],
                          ],
                        ),
                        Text(
                          '${friend.formattedHandle} • (${friend.formattedVirtualNumber})',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.6),
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Chat options
              // Pin/Unpin
              _buildChatOption(
                context,
                icon: chatProvider.isChatPinned(friend.id)
                    ? Icons.push_pin_outlined
                    : Icons.push_pin,
                title: chatProvider.isChatPinned(friend.id)
                    ? 'Unpin Chat'
                    : 'Pin Chat',
                onTap: () async {
                  Navigator.pop(context);
                  if (chatProvider.isChatPinned(friend.id)) {
                    await chatProvider.unpinChat(friend.id);
                    _showSnackBar('Chat unpinned', Colors.green);
                  } else {
                    await chatProvider.pinChat(friend.id);
                    _showSnackBar('Chat pinned', Colors.green);
                  }
                },
              ),

              _buildChatOption(
                context,
                icon: Icons.archive,
                title: chatProvider.isChatArchived(friend.id)
                    ? l10n.unarchiveChat
                    : l10n.archiveChat,
                onTap: () async {
                  Navigator.pop(context);
                  if (chatProvider.isChatArchived(friend.id)) {
                    await chatProvider.unarchiveChat(friend.id);
                    _showSnackBar(l10n.chatUnarchived, Colors.green);
                  } else {
                    await chatProvider.archiveChat(friend.id);
                    _showSnackBar(l10n.chatArchived, Colors.green);
                  }
                },
              ),

              _buildChatOption(
                context,
                icon: chatProvider.isChatMuted(friend.id)
                    ? Icons.volume_up
                    : Icons.volume_off,
                title: chatProvider.isChatMuted(friend.id)
                    ? l10n.unmuteChat
                    : l10n.muteChat,
                onTap: () async {
                  Navigator.pop(context);
                  if (chatProvider.isChatMuted(friend.id)) {
                    await chatProvider.unmuteChat(friend.id);
                    _showSnackBar(l10n.chatUnmuted, Colors.green);
                  } else {
                    await chatProvider.muteChat(friend.id);
                    _showSnackBar(l10n.chatMuted, Colors.orange);
                  }
                },
              ),

              _buildChatOption(
                context,
                icon: friend.unreadCount > 0
                    ? Icons.mark_email_read
                    : Icons.mark_email_unread,
                title: friend.unreadCount > 0
                    ? l10n.markAsRead
                    : l10n.markAsUnread,
                onTap: () async {
                  Navigator.pop(context);
                  if (friend.unreadCount > 0) {
                    final success = await chatProvider.markAsRead(friend.id);
                    if (success) {
                      _showSnackBar('Marked as read', Colors.green);
                    } else {
                      _showSnackBar('Failed to mark as read', Colors.red);
                    }
                  } else {
                    final success = await chatProvider.markAsUnread(friend.id);
                    if (success) {
                      _showSnackBar('Marked as unread', Colors.blue);
                    } else {
                      _showSnackBar('Failed to mark as unread', Colors.red);
                    }
                  }
                },
              ),

              _buildChatOption(
                context,
                icon: Icons.block,
                title: chatProvider.isUserBlocked(friend.id)
                    ? l10n.unblockUser
                    : l10n.blockUser,
                isDestructive: !chatProvider.isUserBlocked(friend.id),
                onTap: () {
                  Navigator.pop(context);
                  if (chatProvider.isUserBlocked(friend.id)) {
                    _unblockUser(friend, chatProvider, l10n);
                  } else {
                    _showBlockConfirmation(friend, chatProvider, l10n);
                  }
                },
              ),

              _buildChatOption(
                context,
                icon: Icons.delete,
                title: l10n.deleteChat,
                isDestructive: true,
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteConfirmation(friend, chatProvider, l10n);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive
            ? Colors.red.shade600
            : Theme.of(context).colorScheme.onSurface,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDestructive
              ? Colors.red.shade600
              : Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }

  void _showBlockConfirmation(
    Friend friend,
    ChatProvider chatProvider,
    AppLocalizations l10n,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.blockUser),
        content: Text(l10n.confirmBlockUser(friend.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              await chatProvider.blockUser(friend.id);
              Navigator.pop(context);
              _showSnackBar(l10n.userBlocked, Colors.red);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.blockUser),
          ),
        ],
      ),
    );
  }

  void _unblockUser(
    Friend friend,
    ChatProvider chatProvider,
    AppLocalizations l10n,
  ) async {
    await chatProvider.unblockUser(friend.id);
    _showSnackBar(l10n.userUnblocked, Colors.green);
  }

  void _showDeleteConfirmation(
    Friend friend,
    ChatProvider chatProvider,
    AppLocalizations l10n,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteChat),
        content: Text(l10n.confirmDeleteChat(friend.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              await chatProvider.deleteChat(friend.id);
              Navigator.pop(context);
              _showSnackBar(l10n.chatDeleted, Colors.red);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.deleteChat),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, Color backgroundColor) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: backgroundColor,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// Quick toggle read/unread status for testing (double-tap)
  void _quickToggleReadStatus(Friend friend, ChatProvider chatProvider) async {
    try {
      if (friend.unreadCount > 0) {
        final success = await chatProvider.markAsRead(friend.id);
        if (success) {
          _showSnackBar('✓ Marked "${friend.name}" as read', Colors.green);
        } else {
          _showSnackBar('✗ Failed to mark as read', Colors.red);
        }
      } else {
        final success = await chatProvider.markAsUnread(friend.id);
        if (success) {
          _showSnackBar('✓ Marked "${friend.name}" as unread', Colors.blue);
        } else {
          _showSnackBar('✗ Failed to mark as unread', Colors.red);
        }
      }
    } catch (e) {
      _showSnackBar('Error: $e', Colors.red);
    }
  }

  /// Test method: Mark all chats as read
  void _testMarkAllAsRead(ChatProvider chatProvider) async {
    int count = 0;
    for (final friend in chatProvider.activeChats) {
      if (friend.unreadCount > 0) {
        await chatProvider.markAsRead(friend.id);
        count++;
      }
    }
    _showSnackBar('✓ Marked $count chats as read', Colors.green);
  }

  /// Test method: Mark all chats as unread
  void _testMarkAllAsUnread(ChatProvider chatProvider) async {
    int count = 0;
    for (final friend in chatProvider.activeChats) {
      await chatProvider.markAsUnread(friend.id);
      count++;
    }
    _showSnackBar('✓ Marked $count chats as unread', Colors.orange);
  }

  void _showProfileDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your Virtual Number:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              _userNumber ?? 'Not set',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            const Text(
              'Privacy-first messaging with Boofer',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () async {
              // Use Supabase for logout
              await SupabaseService.instance.signOut();
              Navigator.pushReplacementNamed(context, '/onboarding');
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
