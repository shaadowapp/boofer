import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/friend_model.dart';
import '../providers/chat_provider.dart';
import '../providers/archive_settings_provider.dart';
import '../services/user_service.dart';
import '../utils/svg_icons.dart';
import '../l10n/app_localizations.dart';
import 'archived_chats_screen.dart';

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
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    return Scaffold(
      body: Consumer2<ChatProvider, ArchiveSettingsProvider>(
        builder: (context, chatProvider, archiveSettings, child) {
          final activeChats = chatProvider.activeChats;
          final archivedChats = chatProvider.archivedChats;
          
          return Column(
            children: [
              // Top archive button (if configured)
              if (archivedChats.isNotEmpty && 
                  archiveSettings.archiveButtonPosition == ArchiveButtonPosition.topOfChats)
                _buildArchiveContactCard(context, archivedChats, l10n),
              
              // Active chats
              Expanded(
                child: activeChats.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SvgIcons.sized(
                              SvgIcons.peopleOutline,
                              64,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No friends found',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          Expanded(
                            child: ListView.builder(
                              itemCount: activeChats.length + (archivedChats.isNotEmpty && 
                                  archiveSettings.archiveButtonPosition == ArchiveButtonPosition.bottomOfChats ? 1 : 0),
                              itemBuilder: (context, index) {
                                // Show archive button as last item if configured for bottom position
                                if (archivedChats.isNotEmpty && 
                                    archiveSettings.archiveButtonPosition == ArchiveButtonPosition.bottomOfChats &&
                                    index == activeChats.length) {
                                  return _buildArchiveContactCard(context, archivedChats, l10n);
                                }
                                
                                final friend = activeChats[index];
                                return _buildFriendTile(friend, chatProvider, l10n);
                              },
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildArchiveContactCard(BuildContext context, List<Friend> archivedChats, AppLocalizations l10n) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ArchivedChatsScreen(),
          ),
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
              backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
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
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                        size: 20,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'View archived conversations',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
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

  Widget _buildFriendTile(Friend friend, ChatProvider chatProvider, AppLocalizations l10n) {
    return InkWell(
      onTap: () {
        // Navigate to FriendChatScreen immediately
        Navigator.pushNamed(
          context, 
          '/chat', 
          arguments: friend,
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
              color: Theme.of(context).dividerColor.withOpacity(0.3), 
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            // Avatar
            Stack(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  child: friend.avatar != null
                      ? ClipOval(
                          child: Image.network(
                            friend.avatar!,
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Text(
                          friend.name.split(' ').map((e) => e[0]).take(2).join(),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                ),
                // Online indicator - moved to top
                if (friend.isOnline)
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50),
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
            
            // Friend Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Text(
                              friend.name,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
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
                      ),
                      Text(
                        _formatTime(friend.lastMessageTime),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: friend.unreadCount > 0 
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          fontWeight: friend.unreadCount > 0 
                              ? FontWeight.w600 
                              : FontWeight.normal,
                        ),
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
                            // Mute indicator
                            if (chatProvider.isChatMuted(friend.id)) ...[
                              Icon(
                                Icons.volume_off,
                                size: 16,
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                              ),
                              const SizedBox(width: 4),
                            ],
                            Expanded(
                              child: Text(
                                friend.lastMessage,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (friend.unreadCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: chatProvider.isChatMuted(friend.id)
                                ? Theme.of(context).colorScheme.onSurface.withOpacity(0.5)
                                : Theme.of(context).colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            friend.unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
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

  void _showChatOptionsBottomSheet(Friend friend, ChatProvider chatProvider, AppLocalizations l10n) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
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
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  child: friend.avatar != null
                      ? ClipOval(
                          child: Image.network(
                            friend.avatar!,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Text(
                          friend.name.split(' ').map((e) => e[0]).take(2).join(),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary,
                          ),
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
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
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
                        friend.virtualNumber,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Chat options
            _buildChatOption(
              context,
              icon: Icons.archive,
              title: chatProvider.isChatArchived(friend.id) ? l10n.unarchiveChat : l10n.archiveChat,
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
              icon: chatProvider.isChatMuted(friend.id) ? Icons.volume_up : Icons.volume_off,
              title: chatProvider.isChatMuted(friend.id) ? l10n.unmuteChat : l10n.muteChat,
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
              icon: friend.unreadCount > 0 ? Icons.mark_email_read : Icons.mark_email_unread,
              title: friend.unreadCount > 0 ? l10n.markAsRead : l10n.markAsUnread,
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
              title: chatProvider.isUserBlocked(friend.id) ? l10n.unblockUser : l10n.blockUser,
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

  void _showBlockConfirmation(Friend friend, ChatProvider chatProvider, AppLocalizations l10n) {
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

  void _unblockUser(Friend friend, ChatProvider chatProvider, AppLocalizations l10n) async {
    await chatProvider.unblockUser(friend.id);
    _showSnackBar(l10n.userUnblocked, Colors.green);
  }

  void _showDeleteConfirmation(Friend friend, ChatProvider chatProvider, AppLocalizations l10n) {
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
              await UserService.clearUserData();
              Navigator.pushReplacementNamed(context, '/');
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}