import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/friend_model.dart';
import '../models/message_model.dart';
import '../providers/chat_provider.dart';
import '../providers/archive_settings_provider.dart';
import '../services/user_service.dart';
import '../utils/svg_icons.dart';
import '../l10n/app_localizations.dart';
import 'archived_chats_screen.dart';
import 'friend_chat_screen.dart';
import '../widgets/user_avatar.dart';
import '../core/constants.dart';
import 'user_search_screen.dart';
import '../widgets/skeleton_chat_tile.dart';
import '../services/code_push_service.dart';
import 'package:flutter/services.dart';
import 'user_profile_screen.dart';
import 'support_chat_screen.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  String? _currentUserId;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    debugPrint('🚀 [LOBBY_UI] initState triggered');
    _loadUserNumber();
    _loadCurrentUserId();
  }

  Future<void> _loadCurrentUserId() async {
    try {
      debugPrint('🚀 [LOBBY_UI] Loading current user ID from UserService...');
      final user = await UserService.getCurrentUser().timeout(
        const Duration(seconds: 5),
      );
      debugPrint('✅ [LOBBY_UI] User ID loaded: ${user?.id}');
      if (mounted) {
        setState(() {
          _currentUserId = user?.id;
        });
      }
    } catch (e) {
      debugPrint('⚠️ [LOBBY_UI] Could not load current user ID: $e');
    }
  }

  Future<void> _loadUserNumber() async {
    try {
      debugPrint('🚀 [LOBBY_UI] Loading user number...');
      final number = await UserService.getUserNumber().timeout(
        const Duration(seconds: 5),
      );
      debugPrint('✅ [LOBBY_UI] User number loaded: $number');
    } catch (e) {
      debugPrint('⚠️ [LOBBY_UI] Could not load user number: $e');
    }
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
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      body: Column(
        children: [
          // RESTART REQUIRED BANNER (Real feedback)
          ValueListenableBuilder<bool>(
            valueListenable: CodePushService.instance.isUpdateReady,
            builder: (context, isReady, child) {
              if (!isReady) return const SizedBox.shrink();
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 16,
                ),
                color: Colors.orange.shade800,
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Update downloaded! Restart Boofer to apply.',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        debugPrint('🚀 [RESTART] Triggered from Lobby Banner');
                        // Use exit(0) to ensure Shorebird marks the launch as clean
                        // and applies any staged patches.
                        exit(0);
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.2),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      child: const Text(
                        'RESTART',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // LOCAL SEARCH BAR (Saves Bandwidth)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: SizedBox(
              height: 42,
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.trim().toLowerCase();
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search chats...',
                  hintStyle: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.5),
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    size: 20,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.5),
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  filled: true,
                  fillColor:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ),

          Expanded(
            child: Consumer2<ChatProvider, ArchiveSettingsProvider>(
              builder: (context, chatProvider, archiveSettings, child) {
                final activeChats = chatProvider.activeChats;
                final archivedChats = chatProvider.archivedChats;

                // Apply local search filtering
                final filteredActiveChats = _searchQuery.isEmpty
                    ? activeChats
                    : activeChats.where((friend) {
                        final searchLower = _searchQuery.toLowerCase();
                        final numericSearch =
                            _searchQuery.replaceAll(RegExp(r'\D'), '');

                        return friend.name
                                .toLowerCase()
                                .contains(searchLower) ||
                            friend.handle.toLowerCase().contains(searchLower) ||
                            (numericSearch.isNotEmpty &&
                                friend.virtualNumber.contains(numericSearch));
                      }).toList();

                debugPrint('🚀 [LOBBY_UI] UI CONSUMER REBUILD');
                debugPrint(
                  '🚀 [LOBBY_UI] Provider State: friendsLoaded=${chatProvider.friendsLoaded}, isLoadingFromNetwork=${chatProvider.isLoadingFromNetwork}',
                );
                debugPrint(
                  '🚀 [LOBBY_UI] Data State: activeChats=${activeChats.length} (filtered: ${filteredActiveChats.length}), archivedChats=${archivedChats.length}',
                );

                // 1. Initial Loading State (Before cache or network returned anything)
                if (!chatProvider.friendsLoaded && activeChats.isEmpty) {
                  debugPrint('🚀 [LOBBY_UI] Showing skeleton loading');
                  return ListView.builder(
                    itemCount: 8,
                    itemBuilder: (context, index) => const SkeletonChatTile(),
                  );
                }

                // 2. Empty State (Loaded but no chats found)
                if (filteredActiveChats.isEmpty) {
                  debugPrint('🚀 [LOBBY_UI] Showing "No results" state');
                  return RefreshIndicator(
                    onRefresh: () async {
                      await chatProvider.refreshFriends();
                    },
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight,
                            ),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SvgIcons.sized(
                                    _searchQuery.isEmpty
                                        ? SvgIcons.peopleOutline
                                        : SvgIcons.searchOff,
                                    64,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface.withOpacity(0.5),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _searchQuery.isEmpty
                                        ? 'No chats yet'
                                        : 'No matches found',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withOpacity(0.5),
                                        ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _searchQuery.isEmpty
                                        ? 'Start connecting with people'
                                        : 'Try searching for something else',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withOpacity(0.5),
                                        ),
                                  ),
                                  if (_searchQuery.isEmpty) ...[
                                    const SizedBox(height: 24),
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const UserSearchScreen(),
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
                                          borderRadius:
                                              BorderRadius.circular(30),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    await chatProvider.refreshFriends();
                  },
                  child: ListView.separated(
                    itemCount: _calculateTotalItems(
                      filteredActiveChats,
                      archivedChats,
                      archiveSettings,
                    ),
                    separatorBuilder: (context, index) => Divider(
                      height: 0,
                      thickness: 0.5,
                      indent:
                          74, // align with text start (16 padding + 56 avatar + 2)
                      endIndent: 0,
                      color: Theme.of(context).dividerColor.withOpacity(0.15),
                    ),
                    itemBuilder: (context, index) {
                      return _buildListItem(
                        context,
                        index,
                        filteredActiveChats,
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
          ),
        ],
      ),
    );
  }

  int _calculateTotalItems(
    List<Friend> activeChats,
    List<Friend> archivedChats,
    ArchiveSettingsProvider archiveSettings,
  ) {
    int totalItems = activeChats.length + 1; // +1 for Support Hub

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
    // 1. Support Chat (at the very top)
    if (index == 0) {
      return _buildSupportTile(context, l10n);
    }

    // Adjust index for subsequent items
    final int adjustedIndex = index - 1;

    // Show archive button at the top if configured
    if (archivedChats.isNotEmpty &&
        archiveSettings.archiveButtonPosition ==
            ArchiveButtonPosition.topOfChats &&
        adjustedIndex == 0) {
      return _buildArchiveContactCard(context, archivedChats, l10n);
    }

    // Show archive button at the bottom if configured
    if (archivedChats.isNotEmpty &&
        archiveSettings.archiveButtonPosition ==
            ArchiveButtonPosition.bottomOfChats &&
        adjustedIndex == activeChats.length) {
      return _buildArchiveContactCard(context, archivedChats, l10n);
    }

    // Calculate the actual friend index
    int friendIndex = adjustedIndex;
    if (archivedChats.isNotEmpty &&
        archiveSettings.archiveButtonPosition ==
            ArchiveButtonPosition.topOfChats) {
      friendIndex = adjustedIndex - 1;
    }

    // Show friend tile
    if (friendIndex >= 0 && friendIndex < activeChats.length) {
      final friend = activeChats[friendIndex];
      return _buildFriendTile(friend, chatProvider, l10n);
    }

    // Fallback - should not happen
    return const SizedBox.shrink();
  }

  Widget _buildSupportTile(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SupportChatScreen()),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Stack(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withOpacity(0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: colorScheme.primary.withOpacity(0.1),
                      ),
                    ),
                    child: const Center(
                      child: Text(
                        '🛣️',
                        style: TextStyle(fontSize: 24),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 1,
                    bottom: 1,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: const Color(0xFF25D366), // Online status
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.scaffoldBackgroundColor,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Boofer',
                          style: textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.verified_rounded,
                          size: 14,
                          color: Colors.green,
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Chat with us for help and updates!',
                      style: textTheme.bodyMedium?.copyWith(
                        fontSize: 13.5,
                        color: colorScheme.onSurface.withOpacity(0.55),
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
      ),
    );
  }

  Widget _buildArchiveContactCard(
    BuildContext context,
    List<Friend> archivedChats,
    AppLocalizations l10n,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ArchivedChatsScreen()),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: colorScheme.primary.withOpacity(0.12),
                child: Icon(
                  Icons.archive_rounded,
                  color: colorScheme.primary,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.archived,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 15.5,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${archivedChats.length} ${archivedChats.length == 1 ? 'chat' : 'chats'}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontSize: 13.5,
                            color: colorScheme.onSurface.withOpacity(0.55),
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: colorScheme.onSurface.withOpacity(0.35),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFriendTile(
    Friend friend,
    ChatProvider chatProvider,
    AppLocalizations l10n,
  ) {
    final bool hasUnread =
        friend.unreadCount > 0 && friend.lastSenderId != _currentUserId;
    final bool isMuted = chatProvider.isChatMuted(friend.id);
    final bool isPinned = chatProvider.isChatPinned(friend.id);
    final bool isSentByMe = friend.lastSenderId == _currentUserId;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
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
          ).then((_) {
            if (mounted) {
              context.read<ChatProvider>().refreshFriends();
            }
          });
        },
        onLongPress: () {
          _showChatOptionsBottomSheet(friend, chatProvider, l10n);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Avatar with online dot ──
              Stack(
                children: [
                  UserAvatar(
                    avatar: friend.avatar,
                    profilePicture: friend.profilePicture,
                    name: friend.name,
                    radius: 28,
                    fontSize: 22,
                    isCompany: friend.isCompany,
                  ),
                  if (friend.isOnline)
                    Positioned(
                      right: 1,
                      bottom: 1,
                      child: Container(
                        width: 13,
                        height: 13,
                        decoration: BoxDecoration(
                          color: const Color(0xFF25D366), // WhatsApp green
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

              const SizedBox(width: 14),

              // ── Content ──
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name row
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  friend.name,
                                  style: textTheme.bodyLarge?.copyWith(
                                    fontWeight: hasUnread
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                    fontSize: 15.5,
                                    letterSpacing: -0.1,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (friend.isVerified) ...[
                                const SizedBox(width: 3),
                                Icon(
                                  Icons.verified_rounded,
                                  size: 14,
                                  color: colorScheme.primary,
                                ),
                              ],
                            ],
                          ),
                        ),
                        // Status icons + time
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isMuted) ...[
                              Icon(
                                Icons.volume_off_rounded,
                                size: 14,
                                color: colorScheme.onSurface.withOpacity(0.40),
                              ),
                              const SizedBox(width: 3),
                            ],
                            if (isPinned) ...[
                              Icon(
                                Icons.push_pin_rounded,
                                size: 13,
                                color: colorScheme.primary.withOpacity(0.75),
                              ),
                              const SizedBox(width: 3),
                            ],
                            Text(
                              _formatTime(friend.lastMessageTime),
                              style: textTheme.bodySmall?.copyWith(
                                fontSize: 12,
                                color: hasUnread
                                    ? colorScheme.primary
                                    : colorScheme.onSurface.withOpacity(0.50),
                                fontWeight: hasUnread
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 3),

                    // Preview row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Status tick (for our own sent messages)
                        if (isSentByMe && friend.lastMessage.isNotEmpty) ...[
                          _buildStatusIcon(friend.lastMessageStatus),
                          const SizedBox(width: 3),
                        ],
                        Expanded(
                          child: Text(
                            friend.lastMessage.isNotEmpty
                                ? friend.lastMessage
                                : 'Say hi to ${friend.name}! 👋',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodyMedium?.copyWith(
                              fontSize: 13.5,
                              color: hasUnread
                                  ? colorScheme.onSurface.withOpacity(0.85)
                                  : colorScheme.onSurface.withOpacity(0.55),
                              fontStyle: friend.lastMessage.isEmpty
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                              fontWeight: hasUnread
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                        // Unread badge
                        if (hasUnread)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isMuted
                                  ? colorScheme.onSurface.withOpacity(0.35)
                                  : colorScheme.primary,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              friend.unreadCount > 99
                                  ? '99+'
                                  : friend.unreadCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                height: 1.2,
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
      ),
    );
  }

  Widget _buildStatusIcon(MessageStatus? status) {
    if (status == null) return const SizedBox.shrink();

    switch (status) {
      case MessageStatus.pending:
        return Icon(
          Icons.access_time,
          size: 14,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
        );
      case MessageStatus.sent:
        return Icon(
          Icons.check,
          size: 14,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
        );
      case MessageStatus.delivered:
        return Icon(
          Icons.done_all,
          size: 14,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
        );
      case MessageStatus.read:
        return const Icon(Icons.done_all, size: 14, color: Colors.blue);
      case MessageStatus.failed:
        return const Icon(Icons.error_outline, size: 14, color: Colors.red);
      case MessageStatus.decryptionFailed:
        return const Icon(
          Icons.warning_amber_rounded,
          size: 14,
          color: Colors.orange,
        );
    }
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
                      isCompany: friend.isCompany,
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
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
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
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
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

              if (friend.id != AppConstants.booferId &&
                  friend.handle != 'boofer' &&
                  friend.id != _currentUserId)
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

              const Divider(height: 32),

              _buildChatOption(
                context,
                icon: Icons.person_outline,
                title: 'View Profile',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => UserProfileScreen(
                        userId: friend.id,
                        userName: friend.name,
                        userHandle: friend.handle,
                        userAvatar: friend.avatar,
                      ),
                    ),
                  );
                },
              ),

              _buildChatOption(
                context,
                icon: Icons.share_rounded,
                title: 'Share Profile Link',
                onTap: () {
                  Navigator.pop(context);
                  final link = 'https://booferapp.github.io/@${friend.handle}';
                  Clipboard.setData(ClipboardData(text: link));
                  _showSnackBar('Profile link copied!', Colors.blue);
                },
              ),

              const SizedBox(height: 12),
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
}
