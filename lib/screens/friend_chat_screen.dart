import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';
import '../services/chat_service.dart';
import '../services/follow_service.dart';
import '../services/user_service.dart';
import '../core/constants.dart';
import '../widgets/message_bubble.dart';
import '../widgets/friend_only_message_widget.dart';
import '../core/database/database_manager.dart';
import '../core/error/error_handler.dart';
import '../providers/appearance_provider.dart';
import '../services/chat_cache_service.dart';

/// Chat screen that enforces friend-only messaging
class FriendChatScreen extends StatefulWidget {
  final String recipientId;
  final String recipientName;
  final String? recipientHandle;
  final String? recipientAvatar;

  const FriendChatScreen({
    super.key,
    required this.recipientId,
    required this.recipientName,
    this.recipientHandle,
    this.recipientAvatar,
  });

  @override
  State<FriendChatScreen> createState() => _FriendChatScreenState();
}

class _FriendChatScreenState extends State<FriendChatScreen> {
  late final ChatService _chatService;
  final FollowService _followService = FollowService.instance;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _messageController = TextEditingController();

  String? _currentUserId;
  String? _conversationId;
  List<Message> _messages = [];
  bool _loading = true;
  bool _canChat = false;
  bool _isBlocked = false;
  bool _isMutual = false;
  bool _isFollowing = false;
  User? _recipientUser;
  late StreamSubscription<List<Message>> _messagesSubscription;
  late StreamSubscription<Message> _newMessageSubscription;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _messageController.dispose();
    _messagesSubscription.cancel();
    _newMessageSubscription.cancel();
    super.dispose();
  }

  Future<void> _initializeChat() async {
    try {
      // Get current user
      final currentUser = await UserService.getCurrentUser();
      if (currentUser == null) {
        throw Exception('No current user found');
      }

      // Initialize chat service
      _chatService = ChatService(
        database: DatabaseManager.instance,
        errorHandler: ErrorHandler(),
      );

      // Create conversation ID
      final conversationId = _chatService.getConversationId(
        currentUser.id,
        widget.recipientId,
      );

      // Check relationship status
      final relationshipStatus = await _followService.getRelationshipStatus(
        currentUserId: currentUser.id,
        targetUserId: widget.recipientId,
      );

      final isBoofer = widget.recipientId == AppConstants.booferId;
      final isMutual = relationshipStatus == 'mutual';
      final isFollowing = relationshipStatus == 'following';

      // Can chat if it's Boofer OR if mutual follow
      // (Optionally allow if following, but user said "boofer common friend" so mutual is safer for others)
      final canChat = isBoofer || isMutual;

      const isBlocked = false; // TODO: Implement block check if needed

      // Create recipient user object
      final recipientUser = User(
        id: widget.recipientId,
        email:
            '${widget.recipientName.toLowerCase().replaceAll(' ', '_')}@demo.com',
        virtualNumber: 'VN${widget.recipientId.hashCode.abs() % 10000}',
        handle: widget.recipientName.toLowerCase().replaceAll(' ', '_'),
        fullName: widget.recipientName,
        bio: 'User profile',
        isDiscoverable: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        profilePicture:
            widget.recipientAvatar != null &&
                widget.recipientAvatar!.startsWith('http')
            ? widget.recipientAvatar
            : null,
        avatar:
            widget.recipientAvatar != null &&
                !widget.recipientAvatar!.startsWith('http')
            ? widget.recipientAvatar
            : null,
      );

      setState(() {
        _currentUserId = currentUser.id;
        _conversationId = conversationId;
        _canChat = canChat;
        _isMutual = isMutual;
        _isBlocked = isBlocked;
        _isFollowing = isFollowing || isMutual;
        _recipientUser = recipientUser;
        _loading = false;
      });

      if (canChat) {
        // Load demo messages for UI design
        _loadMessagesWithCache(conversationId, currentUser.id);

        // Set up message stream listeners (for real implementation)
        _messagesSubscription = _chatService.messagesStream.listen((messages) {
          if (mounted) {
            setState(() {
              _messages = messages;
            });
            _scrollToBottom();
          }
        });

        _newMessageSubscription = _chatService.newMessageStream.listen((
          message,
        ) {
          if (mounted && message.conversationId == conversationId) {
            setState(() {
              _messages.add(message);
            });
            _scrollToBottom();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to initialize chat: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadMessagesWithCache(
    String conversationId,
    String currentUserId,
  ) async {
    final cacheService = ChatCacheService.instance;

    // STEP 1: Load from cache immediately
    final cachedMessages = await cacheService.getCachedMessages(conversationId);
    if (cachedMessages.isNotEmpty && mounted) {
      setState(() {
        _messages = cachedMessages
            .map((json) => Message.fromJson(json))
            .toList();
      });
      _scrollToBottom();
      print('✅ Loaded ${cachedMessages.length} messages from cache (instant)');
    }

    // STEP 2: Check if cache is still valid
    final isCacheValid = await cacheService.isMessagesCacheValid(
      conversationId,
    );

    if (isCacheValid && cachedMessages.isNotEmpty) {
      print('✅ Message cache is fresh (<1h), skipping network call');
      return; // Cache is fresh, no need to fetch from network
    }

    // STEP 3: Cache is stale or empty, fetch from network in background
    print('🔄 Message cache is stale or empty, fetching from network...');

    // TODO: Replace with actual Supabase message fetching when implemented
    // For now, generate demo messages and cache them
    final demoMessages = _generateDemoMessages(
      conversationId,
      currentUserId,
      widget.recipientId,
    );

    if (mounted) {
      setState(() {
        _messages = demoMessages;
      });
      _scrollToBottom();
    }

    // Cache the messages for next time
    final messageMaps = demoMessages.map((msg) => msg.toJson()).toList();
    await cacheService.cacheMessages(conversationId, messageMaps);
    print('💾 Cached ${demoMessages.length} messages locally');
  }

  List<Message> _generateDemoMessages(
    String conversationId,
    String currentUserId,
    String recipientId,
  ) {
    final now = DateTime.now();
    return [
      Message(
        id: 'demo_1',
        conversationId: conversationId,
        senderId: recipientId,
        text: 'Hey! How are you doing?',
        timestamp: now.subtract(const Duration(hours: 2)),
        type: MessageType.text,
        status: MessageStatus.delivered,
        isOffline: false,
      ),
      Message(
        id: 'demo_2',
        conversationId: conversationId,
        senderId: currentUserId,
        text: 'I\'m doing great! Just finished a big project at work 🎉',
        timestamp: now.subtract(const Duration(hours: 1, minutes: 55)),
        type: MessageType.text,
        status: MessageStatus.delivered,
        isOffline: false,
      ),
      Message(
        id: 'demo_3',
        conversationId: conversationId,
        senderId: recipientId,
        text: 'That\'s awesome! Congratulations 👏',
        timestamp: now.subtract(const Duration(hours: 1, minutes: 50)),
        type: MessageType.text,
        status: MessageStatus.delivered,
        isOffline: false,
      ),
      Message(
        id: 'demo_4',
        conversationId: conversationId,
        senderId: currentUserId,
        text: 'Thanks! Want to grab coffee this weekend to celebrate?',
        timestamp: now.subtract(const Duration(hours: 1, minutes: 45)),
        type: MessageType.text,
        status: MessageStatus.delivered,
        isOffline: false,
      ),
      Message(
        id: 'demo_5',
        conversationId: conversationId,
        senderId: recipientId,
        text: 'Absolutely! I know a great new place downtown ☕',
        timestamp: now.subtract(const Duration(hours: 1, minutes: 40)),
        type: MessageType.text,
        status: MessageStatus.delivered,
        isOffline: false,
      ),
      Message(
        id: 'demo_6',
        conversationId: conversationId,
        senderId: currentUserId,
        text: 'Perfect! Saturday around 2 PM?',
        timestamp: now.subtract(const Duration(hours: 1, minutes: 35)),
        type: MessageType.text,
        status: MessageStatus.delivered,
        isOffline: false,
      ),
      Message(
        id: 'demo_7',
        conversationId: conversationId,
        senderId: recipientId,
        text: 'Sounds great! See you then 😊',
        timestamp: now.subtract(const Duration(hours: 1, minutes: 30)),
        type: MessageType.text,
        status: MessageStatus.delivered,
        isOffline: false,
      ),
      Message(
        id: 'demo_8',
        conversationId: conversationId,
        senderId: currentUserId,
        text: 'Looking forward to it! 🙌',
        timestamp: now.subtract(const Duration(minutes: 5)),
        type: MessageType.text,
        status: MessageStatus.sent,
        isOffline: false,
      ),
    ];
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0.0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appearance = Provider.of<AppearanceProvider>(context);
    final isOfficial =
        widget.recipientId == '00000000-0000-4000-8000-000000000000';

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _buildModernAppBar(theme, isOfficial),
      body: appearance.getWallpaperWidget(
        child: Column(
          children: [
            Expanded(child: _buildMessagesList()),
            _buildModernInputArea(theme),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildModernAppBar(ThemeData theme, bool isOfficial) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight + 8),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AppBar(
            backgroundColor: theme.scaffoldBackgroundColor.withOpacity(0.7),
            elevation: 0,
            centerTitle: false,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            title: InkWell(
              onTap: _navigateToProfile,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  children: [
                    Hero(
                      tag: 'avatar_${widget.recipientId}',
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: theme.colorScheme.primary.withOpacity(
                          0.1,
                        ),
                        backgroundImage:
                            widget.recipientAvatar != null &&
                                widget.recipientAvatar!.startsWith('http')
                            ? NetworkImage(widget.recipientAvatar!)
                            : null,
                        child:
                            widget.recipientAvatar != null &&
                                !widget.recipientAvatar!.startsWith('http') &&
                                (widget.recipientAvatar!.length <= 2 ||
                                    widget.recipientAvatar!.runes.length <= 2)
                            ? Text(
                                widget.recipientAvatar!,
                                style: const TextStyle(fontSize: 18),
                              )
                            : (widget.recipientAvatar == null ||
                                      widget.recipientAvatar!.isEmpty ||
                                      !widget.recipientAvatar!.startsWith(
                                        'http',
                                      )
                                  ? Text(
                                      widget.recipientName[0].toUpperCase(),
                                      style: TextStyle(
                                        color: theme.colorScheme.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  : null),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  widget.recipientName,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isOfficial) ...[
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.verified,
                                  size: 16,
                                  color: theme.colorScheme.primary,
                                ),
                              ],
                            ],
                          ),
                          Text(
                            _isMutual ? 'Online' : 'Click to view profile',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: _isMutual
                                  ? Colors.green
                                  : theme.colorScheme.onSurface.withOpacity(
                                      0.6,
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              if (_isMutual) ...[
                IconButton(
                  icon: const Icon(Icons.videocam_outlined),
                  onPressed: _startVideoCall,
                ),
                IconButton(
                  icon: const Icon(Icons.call_outlined),
                  onPressed: _startVoiceCall,
                ),
              ],
              IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: _showMoreOptionsBottomSheet,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToProfile() {
    Navigator.pushNamed(context, '/profile', arguments: widget.recipientId);
  }

  Widget _buildModernInputArea(ThemeData theme) {
    if (!_canChat) {
      return _buildFriendOnlyScreen();
    }

    if (_isBlocked) {
      return Container(
        padding: const EdgeInsets.all(16),
        color: theme.colorScheme.errorContainer.withOpacity(0.3),
        child: const Center(
          child: Text(
            'You have blocked this user',
            style: TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        12,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor.withOpacity(0.2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withOpacity(0.7),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: theme.colorScheme.outline.withOpacity(0.1),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.add_circle_outline,
                    color: theme.colorScheme.primary,
                  ),
                  onPressed: _showAttachmentOptions,
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    ),
                    maxLines: 5,
                    minLines: 1,
                    onChanged: (value) {
                      setState(() {});
                    },
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _messageController.text.trim().isEmpty
                      ? IconButton(
                          key: const ValueKey('mic'),
                          icon: Icon(
                            Icons.mic_none,
                            color: theme.colorScheme.primary,
                          ),
                          onPressed: () {},
                        )
                      : Container(
                          margin: const EdgeInsets.only(right: 4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            key: const ValueKey('send'),
                            icon: const Icon(
                              Icons.send,
                              color: Colors.white,
                              size: 18,
                            ),
                            onPressed: () {
                              final text = _messageController.text;
                              if (text.trim().isNotEmpty) {
                                _handleSendMessage(text);
                                _messageController.clear();
                              }
                            },
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

  Widget _buildFriendOnlyScreen() {
    if (_recipientUser == null) {
      return const Center(child: Text('User not found'));
    }

    return Center(
      child: FriendOnlyMessageWidget(
        user: _recipientUser!,
        onFollowChanged: () {
          // Refresh the chat state after follow status changes
          _initializeChat();
        },
      ),
    );
  }

  Widget _buildMessagesList() {
    if (_loading && _messages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_messages.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + kToolbarHeight + 20,
        bottom: 20,
      ),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        // With reverse: true, index 0 is the bottom (latest)
        final message = _messages[_messages.length - 1 - index];
        return MessageBubble(
          message: message,
          currentUserId: _currentUserId!,
          senderName: message.senderId == _currentUserId
              ? null
              : widget.recipientName,
          onTap: () => _handleMessageTap(message),
          onLongPress: () => _handleMessageLongPress(message),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'No messages yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start a conversation with ${widget.recipientName}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSendMessage(String text) async {
    if (text.trim().isEmpty ||
        _currentUserId == null ||
        _conversationId == null) {
      return;
    }

    // Add message to demo list immediately for UI feedback
    final newMessage = Message(
      id: 'demo_${DateTime.now().millisecondsSinceEpoch}',
      conversationId: _conversationId!,
      senderId: _currentUserId!,
      text: text.trim(),
      timestamp: DateTime.now(),
      type: MessageType.text,
      status: MessageStatus.pending,
      isOffline: false,
    );

    setState(() {
      _messages.add(newMessage);
    });
    _scrollToBottom();

    try {
      // In a real app, this would send the message through the chat service
      await _chatService.sendMessage(
        conversationId: _conversationId!,
        senderId: _currentUserId!,
        content: text.trim(),
        receiverId: widget.recipientId,
      );

      // Update message status to sent
      setState(() {
        final index = _messages.indexWhere((m) => m.id == newMessage.id);
        if (index != -1) {
          _messages[index] = newMessage.copyWith(status: MessageStatus.sent);
        }
      });
    } catch (e) {
      // Update message status to failed
      setState(() {
        final index = _messages.indexWhere((m) => m.id == newMessage.id);
        if (index != -1) {
          _messages[index] = newMessage.copyWith(status: MessageStatus.failed);
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handleMessageTap(Message message) {
    // Handle message tap
  }

  void _handleMessageLongPress(Message message) {
    showModalBottomSheet(
      context: context,
      builder: (context) => _buildMessageContextMenu(message),
    );
  }

  Widget _buildMessageContextMenu(Message message) {
    final isOwnMessage = message.senderId == _currentUserId;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.copy),
            title: const Text('Copy text'),
            onTap: () {
              Navigator.pop(context);
              // Copy to clipboard
            },
          ),
          if (isOwnMessage)
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Delete message'),
              onTap: () {
                Navigator.pop(context);
                _deleteMessage(message);
              },
            ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Message info'),
            onTap: () {
              Navigator.pop(context);
              _showMessageInfo(message);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _deleteMessage(Message message) async {
    try {
      await _chatService.deleteMessage(message.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Message deleted'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete message: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showMessageInfo(Message message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Message Info'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Sender', message.senderId),
            _buildInfoRow('Status', message.status.name),
            _buildInfoRow('Time', message.timestamp.toString()),
            _buildInfoRow('ID', message.id),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Future<void> _startVoiceCall() async {
    if (_currentUserId == null) return;

    if (!_isMutual) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You can only call mutual follows'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Voice calling ${widget.recipientName}...'),
        backgroundColor: Colors.green,
        action: SnackBarAction(label: 'Cancel', onPressed: () {}),
      ),
    );
  }

  Future<void> _startVideoCall() async {
    if (_currentUserId == null) return;

    if (!_isMutual) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You can only call mutual follows'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Video calling ${widget.recipientName}...'),
        backgroundColor: Colors.green,
        action: SnackBarAction(label: 'Cancel', onPressed: () {}),
      ),
    );
  }

  Future<void> _sendFollowRequest() async {
    if (_currentUserId == null) return;

    try {
      // Show loading state
      setState(() {
        _isFollowing = true;
      });

      // Follow the user
      await _followService.followUser(
        followerId: _currentUserId!,
        followingId: widget.recipientId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('You are now following ${widget.recipientName}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      // Revert state on error
      setState(() {
        _isFollowing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to follow user: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _toggleBlockUser() async {
    if (_currentUserId == null) return;

    try {
      if (_isBlocked) {
        // Unblock user (mock implementation for now)
        // await _friendshipService.unblockUser(_currentUserId!, widget.recipientId);
        setState(() {
          _isBlocked = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${widget.recipientName} has been unblocked'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Block user (mock implementation for now)
        // await _friendshipService.blockUser(_currentUserId!, widget.recipientId);
        setState(() {
          _isBlocked = true;
          _isMutual = false;
          _isFollowing = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${widget.recipientName} has been blocked'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to ${_isBlocked ? 'unblock' : 'block'} user: $e',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showMoreOptionsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header with user info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.1),
                    child: widget.recipientAvatar != null
                        ? ClipOval(
                            child: Image.network(
                              widget.recipientAvatar!,
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Text(
                                    widget.recipientName[0].toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                  ),
                            ),
                          )
                        : Text(
                            widget.recipientName[0].toUpperCase(),
                            style: TextStyle(
                              fontSize: 20,
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
                        Text(
                          widget.recipientName,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        if (widget.recipientHandle != null)
                          Text(
                            '@${widget.recipientHandle}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface.withOpacity(0.6),
                                ),
                          )
                        else
                          Text(
                            'Tap to view profile',
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
            ),
            const SizedBox(height: 20),
            // Options list
            _buildBottomSheetOption(
              icon: Icons.person,
              title: 'View profile',
              onTap: () {
                Navigator.pop(context);
                _showUserProfile();
              },
            ),
            // Show add friend option if not mutual, not blocked, and not following
            if (!_isMutual && !_isBlocked && !_isFollowing)
              _buildBottomSheetOption(
                icon: Icons.person_add,
                title: 'Follow',
                onTap: () {
                  Navigator.pop(context);
                  _sendFollowRequest();
                },
              ),
            // Show following status if following but not mutual
            if (!_isMutual && !_isBlocked && _isFollowing)
              _buildBottomSheetOption(
                icon: Icons.check_circle_outline,
                title: 'Following',
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('You are following this user'),
                    ),
                  );
                },
              ),
            // Show media & files only for mutual follows
            if (_isMutual)
              _buildBottomSheetOption(
                icon: Icons.photo_library,
                title: 'Media & files',
                onTap: () {
                  Navigator.pop(context);
                  _showMediaAndFiles();
                },
              ),
            // Show block/unblock option
            _buildBottomSheetOption(
              icon: _isBlocked ? Icons.person_add : Icons.block,
              title: _isBlocked ? 'Unblock user' : 'Block user',
              onTap: () {
                Navigator.pop(context);
                _toggleBlockUser();
              },
              isDestructive: !_isBlocked,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomSheetOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isDestructive
              ? Colors.red.withOpacity(0.1)
              : Theme.of(context).colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: isDestructive
              ? Colors.red
              : Theme.of(context).colorScheme.primary,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDestructive
              ? Colors.red
              : Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
    );
  }

  void _showMediaAndFiles() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header with back button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                      // Show the main options bottom sheet again
                      _showMoreOptionsBottomSheet();
                    },
                    icon: const Icon(Icons.arrow_back),
                    tooltip: 'Back',
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Media & Files',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Media options list
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _buildMediaOption(
                    icon: Icons.photo,
                    title: 'Photos',
                    subtitle: '42 items',
                    onTap: () => _showMediaCategory('photos'),
                  ),
                  _buildMediaOption(
                    icon: Icons.videocam,
                    title: 'Videos',
                    subtitle: '8 items',
                    onTap: () => _showMediaCategory('videos'),
                  ),
                  _buildMediaOption(
                    icon: Icons.insert_drive_file,
                    title: 'Documents',
                    subtitle: '15 items',
                    onTap: () => _showMediaCategory('documents'),
                  ),
                  _buildMediaOption(
                    icon: Icons.music_note,
                    title: 'Audio',
                    subtitle: '3 items',
                    onTap: () => _showMediaCategory('audio'),
                  ),
                  _buildMediaOption(
                    icon: Icons.link,
                    title: 'Links',
                    subtitle: '12 items',
                    onTap: () => _showMediaCategory('links'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Theme.of(context).colorScheme.primary),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  void _showMediaCategory(String category) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Opening $category...')));
  }

  void _showUserProfile() {
    // Show user profile dialog or navigate to profile screen
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.recipientName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: widget.recipientAvatar != null
                  ? ClipOval(
                      child: Image.network(
                        widget.recipientAvatar!,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Text(
                          widget.recipientName.substring(0, 1).toUpperCase(),
                          style: const TextStyle(
                            fontSize: 32,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    )
                  : Text(
                      widget.recipientName.substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        fontSize: 32,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.recipientName,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (widget.recipientHandle != null) ...[
              const SizedBox(height: 4),
              Text(
                '@${widget.recipientHandle}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'ID: ${widget.recipientId}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo),
              title: const Text('Photo'),
              onTap: () {
                Navigator.pop(context);
                // Handle photo attachment
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam),
              title: const Text('Video'),
              onTap: () {
                Navigator.pop(context);
                // Handle video attachment
              },
            ),
            ListTile(
              leading: const Icon(Icons.attach_file),
              title: const Text('File'),
              onTap: () {
                Navigator.pop(context);
                // Handle file attachment
              },
            ),
          ],
        ),
      ),
    );
  }
}
