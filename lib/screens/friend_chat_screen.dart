import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
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
import '../services/supabase_service.dart';

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
  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _messageController.dispose();
    _realtimeChannel?.unsubscribe();
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
      final relationshipStatus = await _followService.getFollowStatus(
        currentUserId: currentUser.id,
        targetUserId: widget.recipientId,
      );

      final isBoofer = widget.recipientId == AppConstants.booferId;
      final isMutual = relationshipStatus == 'mutual';
      final isFollowing = relationshipStatus == 'following';

      // Can chat if it's Boofer OR if there's ANY follow relationship
      final canChat = isBoofer || relationshipStatus != 'none';

      const isBlocked = false;

      // Load ACTUAL recipient user profile
      User? freshRecipient;
      final isSelf = widget.recipientId == currentUser.id;

      if (!isSelf) {
        try {
          freshRecipient = await SupabaseService.instance.getUserProfile(
            widget.recipientId,
          );
        } catch (e) {
          debugPrint('Error fetching fresh profile: $e');
        }
      } else {
        freshRecipient = currentUser;
      }

      // Create recipient user object with fallback to widget params
      final recipientUser =
          freshRecipient ??
          User(
            id: widget.recipientId,
            email:
                '${widget.recipientName.toLowerCase().replaceAll(' ', '_')}@demo.com',
            virtualNumber: 'VN${widget.recipientId.hashCode.abs() % 10000}',
            handle:
                widget.recipientHandle ??
                widget.recipientName.toLowerCase().replaceAll(' ', '_'),
            fullName: widget.recipientName,
            bio: 'User profile',
            isDiscoverable: freshRecipient?.isDiscoverable ?? true,
            createdAt: freshRecipient?.createdAt ?? DateTime.now(),
            updatedAt: freshRecipient?.updatedAt ?? DateTime.now(),
            profilePicture:
                freshRecipient?.profilePicture ??
                (widget.recipientAvatar != null &&
                        widget.recipientAvatar!.startsWith('http')
                    ? widget.recipientAvatar
                    : null),
            avatar:
                freshRecipient?.avatar ??
                (widget.recipientAvatar != null &&
                        !widget.recipientAvatar!.startsWith('http')
                    ? widget.recipientAvatar
                    : null),
          );

      if (mounted) {
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
      }

      if (canChat) {
        // Load existing messages from Supabase
        await _loadMessages(conversationId);

        // Set up realtime listener
        _setupRealtimeListener(conversationId);
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

  Future<void> _loadMessages(String conversationId) async {
    try {
      debugPrint('📥 Loading messages for conversation: $conversationId');
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('messages')
          .select()
          .eq('conversation_id', conversationId)
          .order('timestamp', ascending: true);

      debugPrint('📥 Loaded ${response.length} messages from database');

      final messages = (response as List)
          .map(
            (data) => Message.fromJson({
              'id': data['id'],
              'text': data['text'] ?? '',
              'senderId': data['sender_id'],
              'receiverId': data['receiver_id'],
              'conversationId': data['conversation_id'],
              'timestamp': data['timestamp'],
              'isOffline': data['is_offline'] ?? false,
              'status': data['status'] ?? 'sent',
              'type': data['type'] ?? 'text',
              'messageHash': data['message_hash'],
              'mediaUrl': data['media_url'],
              'metadata': data['metadata'],
            }),
          )
          .toList();

      if (mounted) {
        setState(() {
          _messages = messages;
        });
        _scrollToBottom();
      }
      debugPrint('✅ Messages loaded and displayed');
    } catch (e) {
      debugPrint('Error loading messages: $e');
    }
  }

  void _setupRealtimeListener(String conversationId) {
    final supabase = Supabase.instance.client;

    debugPrint('🔴 Setting up realtime listener for: $conversationId');

    _realtimeChannel = supabase
        .channel('messages:$conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) {
            debugPrint('🔔 REALTIME MESSAGE RECEIVED!');
            debugPrint('   Payload: $payload');

            final data = payload.newRecord;
            final newMessage = Message.fromJson({
              'id': data['id'],
              'text': data['text'] ?? '',
              'senderId': data['sender_id'],
              'receiverId': data['receiver_id'],
              'conversationId': data['conversation_id'],
              'timestamp': data['timestamp'],
              'isOffline': data['is_offline'] ?? false,
              'status': data['status'] ?? 'sent',
              'type': data['type'] ?? 'text',
              'messageHash': data['message_hash'],
              'mediaUrl': data['media_url'],
              'metadata': data['metadata'],
            });

            debugPrint('   Message text: ${newMessage.text}');

            if (mounted) {
              setState(() {
                _messages.add(newMessage);
              });
              _scrollToBottom();
              debugPrint('✅ Message added to UI');
            }
          },
        )
        .subscribe((status, error) {
          debugPrint('🔴 Realtime status: $status');
          if (error != null) debugPrint('❌ Error: $error');
          if (status == RealtimeSubscribeStatus.subscribed) {
            debugPrint('✅ Subscribed to realtime!');
          }
        });
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
    final isOfficial = AppConstants.officialIds.contains(widget.recipientId);

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
    // Optimization: Use a simple AppBar during transition or if lag is detected
    // backdrop filter is expensive.
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight + 8),
      child: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
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
                    backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                    backgroundImage: _recipientUser?.profilePicture != null
                        ? NetworkImage(_recipientUser!.profilePicture!)
                        : (widget.recipientAvatar != null &&
                                  widget.recipientAvatar!.startsWith('http')
                              ? NetworkImage(widget.recipientAvatar!)
                              : null),
                    child:
                        _recipientUser?.profilePicture == null &&
                            (_recipientUser?.avatar != null ||
                                widget.recipientAvatar != null)
                        ? Text(
                            (_recipientUser?.avatar ?? widget.recipientAvatar)!,
                            style: const TextStyle(fontSize: 18),
                          )
                        : (_recipientUser == null &&
                                  (widget.recipientAvatar == null ||
                                      widget.recipientAvatar!.isEmpty)
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
                              widget.recipientId == _currentUserId
                                  ? 'You (${_recipientUser?.fullName ?? widget.recipientName})'
                                  : (_recipientUser?.fullName ??
                                        widget.recipientName),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if ((_recipientUser?.isVerified ?? false) ||
                              isOfficial) ...[
                            const SizedBox(width: 4),
                            Icon(
                              Icons.verified,
                              size: 16,
                              // If it's an official account (isOfficial covers Boofer), verify green color
                              color: isOfficial
                                  ? Colors.green
                                  : theme.colorScheme.primary,
                            ),
                          ],
                        ],
                      ),
                      Text(
                        widget.recipientId == _currentUserId
                            ? 'Message yourself'
                            : (_isMutual ? 'Online' : 'View profile'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: widget.recipientId == _currentUserId
                              ? theme.colorScheme.onSurface.withOpacity(0.6)
                              : (_isMutual
                                    ? Colors.green
                                    : theme.colorScheme.onSurface.withOpacity(
                                        0.6,
                                      )),
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
          if (_isMutual &&
              widget.recipientId != _currentUserId &&
              widget.recipientId != AppConstants.booferId) ...[
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: theme.colorScheme.outline.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            IconButton(
              icon: Icon(
                Icons.emoji_emotions_outlined,
                color: theme.colorScheme.primary,
              ),
              onPressed: _showEmojiPicker,
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
                  ? const SizedBox.shrink()
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
      debugPrint(
        '❌ Cannot send message: text=${text.trim().isEmpty}, userId=$_currentUserId, convId=$_conversationId',
      );
      return;
    }

    debugPrint('📨 Sending message from UI...');
    debugPrint('   Current User: $_currentUserId');
    debugPrint('   Recipient: ${widget.recipientId}');
    debugPrint('   Conversation: $_conversationId');
    debugPrint('   Message: $text');

    try {
      final result = await SupabaseService.instance.sendMessage(
        conversationId: _conversationId!,
        senderId: _currentUserId!,
        receiverId: widget.recipientId,
        text: text.trim(),
      );

      if (result != null) {
        debugPrint('✅ Message sent successfully from UI');
      } else {
        debugPrint('⚠️ Message send returned null');
      }
    } catch (e) {
      debugPrint('❌ Error in UI message handler: $e');
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
    _navigateToProfile();
  }

  void _showEmojiPicker() {
    final theme = Theme.of(context);
    final emojis = [
      '😀',
      '😃',
      '😄',
      '😁',
      '😆',
      '😅',
      '🤣',
      '😂',
      '🙂',
      '🙃',
      '😉',
      '😊',
      '😇',
      '🥰',
      '😍',
      '🤩',
      '😘',
      '😗',
      '😚',
      '😙',
      '😋',
      '😛',
      '😜',
      '🤪',
      '😝',
      '🤑',
      '🤗',
      '🤭',
      '🤫',
      '🤔',
      '🤐',
      '🤨',
      '😐',
      '😑',
      '😶',
      '😏',
      '😒',
      '🙄',
      '😬',
      '🤥',
      '😌',
      '😔',
      '😪',
      '🤤',
      '😴',
      '😷',
      '🤒',
      '🤕',
      '🤢',
      '🤮',
      '🤧',
      '🥵',
      '🥶',
      '🥴',
      '😵',
      '🤯',
      '🤠',
      '🥳',
      '😎',
      '🤓',
      '🧐',
      '😕',
      '😟',
      '🙁',
      '☹️',
      '😮',
      '😯',
      '😲',
      '😳',
      '🥺',
      '😦',
      '😧',
      '😨',
      '😰',
      '😥',
      '😢',
      '😭',
      '😱',
      '😖',
      '😣',
      '😞',
      '😓',
      '😩',
      '😫',
      '🥱',
      '😤',
      '😡',
      '😠',
      '🤬',
      '😈',
      '👿',
      '💀',
      '☠️',
      '💩',
      '🤡',
      '👹',
      '👺',
      '👻',
      '👽',
      '👾',
      '🤖',
      '😺',
      '😸',
      '😹',
      '😻',
      '😼',
      '😽',
      '🙀',
      '😿',
      '😾',
      '❤️',
      '🧡',
      '💛',
      '💚',
      '💙',
      '💜',
      '🖤',
      '🤍',
      '🤎',
      '💔',
      '❣️',
      '💕',
      '💞',
      '💓',
      '💗',
      '💖',
      '💘',
      '💝',
      '💟',
      '☮️',
      '✝️',
      '☪️',
      '🕉️',
      '☸️',
      '✡️',
      '🔯',
      '🕎',
      '☯️',
      '☦️',
      '🛐',
      '⛎',
      '♈',
      '♉',
      '♊',
      '♋',
      '♌',
      '♍',
      '♎',
      '♏',
      '♐',
      '👍',
      '👎',
      '👊',
      '✊',
      '🤛',
      '🤜',
      '🤞',
      '✌️',
      '🤟',
      '🤘',
      '👌',
      '🤏',
      '👈',
      '👉',
      '👆',
      '👇',
      '☝️',
      '✋',
      '🤚',
      '🖐️',
      '🖖',
      '👋',
      '🤙',
      '💪',
      '🦾',
      '🖕',
      '✍️',
      '🙏',
      '🦶',
      '🦵',
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: 300,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.outline.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Pick an Emoji',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 8,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: emojis.length,
                itemBuilder: (context, index) {
                  return InkWell(
                    onTap: () {
                      _messageController.text += emojis[index];
                      setState(() {});
                      Navigator.pop(context);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          emojis[index],
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
