import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import '../models/message_model.dart';
import '../models/user_model.dart';
import '../services/chat_service.dart';
import '../services/follow_service.dart';
import '../services/user_service.dart';
import '../core/constants.dart';
import '../widgets/message_bubble.dart';
import '../core/database/database_manager.dart';
import '../core/error/error_handler.dart';
import '../providers/appearance_provider.dart';
import '../providers/chat_provider.dart';
import '../widgets/user_avatar.dart';
import '../utils/svg_icons.dart';
import '../widgets/modern_chat_input.dart';
import '../widgets/media_edit_viewer.dart';
import '../services/moderation_service.dart';
import '../services/media_service.dart';
import '../services/supabase_service.dart';
import '../services/virgil_e2ee_service.dart';
import '../services/virgil_key_service.dart';
import '../services/local_storage_service.dart';
import '../widgets/smart_maintenance.dart';
import '../widgets/skeleton_chat_loading.dart';
import 'dart:io';

/// Chat screen that enforces friend-only messaging
class FriendChatScreen extends StatefulWidget {
  final String recipientId;
  final String recipientName;
  final String? recipientHandle;
  final String? recipientAvatar;
  final String? recipientProfilePicture;
  final String? virtualNumber;
  final String? initialText;
  final String? currentUserId;

  const FriendChatScreen({
    super.key,
    required this.recipientId,
    required this.recipientName,
    this.recipientHandle,
    this.recipientAvatar,
    this.recipientProfilePicture,
    this.virtualNumber,
    this.initialText,
    this.currentUserId,
  });

  @override
  State<FriendChatScreen> createState() => _FriendChatScreenState();
}

class _FriendChatScreenState extends State<FriendChatScreen> {
  late final ChatService _chatService;
  final FollowService _followService = FollowService.instance;
  final ScrollController _scrollController = ScrollController();

  String? _currentUserId;
  String? _conversationId;
  List<Message> _messages = [];
  List<dynamic> _chatItems = [];
  bool _loading = true;
  bool _isBlocked = false;
  bool _isMutual = false;
  bool _isFollowing = false;
  String _ephemeralTimer = '24_hours';
  User? _recipientUser;
  Message? _replyToMessage;
  RealtimeChannel? _realtimeChannel;
  RealtimeChannel? _timerSubscription;
  Map<String, dynamic>? _myKeys;
  Map<String, dynamic>? _recipientKeys;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _realtimeChannel?.unsubscribe();
    _timerSubscription?.unsubscribe();
    
    // Safety: we cannot reliably use context.read here because the widget tree 
    // might already be decoupled. We rely on the app-level presence cleanup
    // or next conversation start to clear stale states.
    super.dispose();
  }

  Future<void> _initializeChat() async {
    try {
      // Get current user - Optimize: Use passed ID if available to avoid async block
      String? senderId = widget.currentUserId;
      User? currentUser;
      
      if (senderId == null) {
        currentUser = await UserService.getCurrentUser();
        senderId = currentUser?.id;
      }

      if (senderId == null) {
        throw Exception('No current user found');
      }

      // Initialize chat service
      _chatService = ChatService(
        database: DatabaseManager.instance,
        errorHandler: ErrorHandler(),
      );

      // Create conversation ID synchronously
      final conversationId = _chatService.getConversationId(
        senderId,
        widget.recipientId,
      );

      // CRITICAL: Set user ID BEFORE parallel calls so decryption works
      _currentUserId = senderId;

      // --- FAST PATH: Load local messages to show UI instantly ---
      try {
        final localData = await DatabaseManager.instance.query(
          'SELECT * FROM messages WHERE conversation_id = ? ORDER BY timestamp DESC LIMIT 50',
          [conversationId],
        );
        if (localData.isNotEmpty) {
          final localMessages = localData.map((data) => Message.fromJson(data)).where((m) {
            final deletedFor = m.metadata?['deleted_for'] as List?;
            return deletedFor == null || !deletedFor.contains(senderId);
          }).toList();
          
        if (mounted) {
          setState(() {
            _messages = localMessages.reversed.toList();
            _updateChatItems();
            _loading = false;
          });
          _scrollToBottom();
        }
      } else {
        // Even if local data is empty, stop showing the loader so the empty state appears instantly
        if (mounted) {
          setState(() {
            _loading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading initial local messages: $e');
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }

    // Initialize recipient profile with what we have from widget arguments
    _recipientUser = User(
      id: widget.recipientId,
      virtualNumber: widget.virtualNumber ?? '...',
      handle: widget.recipientHandle ?? '...',
      fullName: widget.recipientName,
      bio: '',
      isDiscoverable: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      profilePicture: widget.recipientProfilePicture,
      avatar: widget.recipientAvatar,
    );

    // --- SECOND PASS: Network operations concurrently ---
    // ── LOCAL-ONLY FOR SELF-CHAT ─────────────────────
    if (widget.recipientId == senderId) {
      debugPrint('🏠 Self-chat detected: Skipping remote sync');
      if (mounted) {
        setState(() => _loading = false);
      }
      return;
    }
    // ──────────────────────────────────────────────────

    // Start listening for realtime events and load fresh messages early.
    _setupRealtimeListener(conversationId);
    _loadMessages(conversationId);
    _markMessagesAsRead();

    // Parallelize initialization calls for profiles and keys in the background
    Future.wait([
      _followService
          .getFollowStatus(
        currentUserId: senderId,
        targetUserId: widget.recipientId,
      )
          .catchError((e) {
        debugPrint('Error checking follow status: $e');
        return 'none';
      }),
      (widget.recipientId != senderId)
          ? SupabaseService.instance
              .getUserProfile(widget.recipientId)
              .catchError((e) {
              debugPrint('Error fetching fresh profile: $e');
              return null;
            })
          : (currentUser != null 
              ? Future.value(currentUser) 
              : UserService.getCurrentUser()),
      SupabaseService.instance
          .getConversationTimer(widget.recipientId)
          .catchError((e) {
        debugPrint('Error fetching timer: $e');
        return 'off';
      }),
      VirgilKeyService().getRecipientKeys(senderId),
      VirgilKeyService().getRecipientKeys(widget.recipientId),
    ]).then((results) {
      if (!mounted) return;
      
      final relationshipStatus = results[0] as String;
      final freshRecipient = results[1] as User?;
      final ephemeralTimer = results[2] as String;
      _myKeys = results[3] as Map<String, dynamic>?;
      _recipientKeys = results[4] as Map<String, dynamic>?;

      // Fallback to cache if remote check failed (returned 'none') but we know they are a friend
      final chatProvider = context.read<ChatProvider>();
      String finalStatus = relationshipStatus;
      if (finalStatus == 'none' && chatProvider.isMutualFriend(widget.recipientId)) {
        finalStatus = 'mutual';
      }

      final isBoofer = widget.recipientId == AppConstants.booferId;
      final isMutual = isBoofer || finalStatus == 'mutual';
      final isFollowing = isBoofer || finalStatus == 'following' || isMutual;

      setState(() {
        _isMutual = isMutual;
        _isFollowing = isFollowing || isMutual;
        _recipientUser = freshRecipient ?? _recipientUser; // Merge fresh data
        _ephemeralTimer = ephemeralTimer;
      });

      _setupTimerListener(conversationId);
      _cleanupExpiredMessages();
    });

    // Update presence with this conversation ID (sync) - Check mounted after async path
    if (mounted) {
      context.read<ChatProvider>().updatePresenceWithConversationId(
            conversationId,
          );

      // Mark Boofer welcome as seen locally
      if (widget.recipientId == AppConstants.booferId) {
        LocalStorageService.setSeenBooferWelcome(senderId);
      }
    }
    } catch (e) {
      debugPrint('Error during chat initialization: $e');
      if (mounted) {
        setState(() {
          _loading = false;
        });
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
          .order('timestamp', ascending: false)
          .limit(30);

      debugPrint('📥 Loaded ${response.length} messages from database');

      final rawMessages =
          (response as List).map((data) => Message.fromJson(data)).where((m) {
        final deletedFor = m.metadata?['deleted_for'] as List?;
        return deletedFor == null || !deletedFor.contains(_currentUserId);
      }).toList();

      // Bulk fetch locally cached plaintext to avoid decrypting over and over
      final messageIds = rawMessages.map((m) => m.id).toList();
      final localTextMap = <String, String>{};
      
      if (messageIds.isNotEmpty) {
        try {
          final placeholders = List.filled(messageIds.length, '?').join(',');
          final localData = await DatabaseManager.instance.query(
            'SELECT id, text FROM messages WHERE id IN ($placeholders)',
            messageIds,
          );
          for (final row in localData) {
            final text = row['text'] as String?;
            if (text != null && text != '[Encrypted]' && text.isNotEmpty) {
              localTextMap[row['id'] as String] = text;
            }
          }
        } catch (e) {
          debugPrint('Bulk fetch error: $e');
        }
      }

      // Decrypt messages in PARALLEL to avoid sequential delay.
      // We pass shouldCache: false to _decryptMessage because we'll batch the updates here
      // to avoid multiple concurrent writes which lock the database.
      final decryptedMessages = await Future.wait(
        rawMessages.map((m) async {
          if (localTextMap.containsKey(m.id)) {
            return m.copyWith(text: localTextMap[m.id]);
          } else {
            return await _decryptMessage(m, localText: null, shouldCache: false);
          }
        }),
      );

      // Batch update the local cache for any messages that were newly decrypted
      _batchUpdateCache(decryptedMessages, localTextMap);

      // Reverse to chronological order (oldest first) for the list
      final sortedMessages = decryptedMessages.reversed.toList();

      if (mounted) {
        setState(() {
          _messages = sortedMessages;
          _updateChatItems();
          _loading = false;
        });
        _scrollToBottom();
      }
      debugPrint('✅ Messages loaded, decrypted, and displayed');
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
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) async {
            debugPrint('🔔 REALTIME MESSAGE EVENT: ${payload.eventType}');

            if (payload.eventType == PostgresChangeEvent.insert) {
              var newMessage = Message.fromJson(payload.newRecord);
              final deletedFor = newMessage.metadata?['deleted_for'] as List?;
              if (deletedFor != null && deletedFor.contains(_currentUserId)) {
                return;
              }

              if (mounted) {
                // Check if this message is already in the list (optimistic update from sender)
                final existingIndex = _messages.indexWhere(
                  (m) => m.id == newMessage.id,
                );

                if (existingIndex != -1) {
                  // We already have this message (we sent it optimistically).
                  // Preserve the plaintext we already have — the server record
                  // only contains the encrypted ciphertext, so decrypting it
                  // here would show [Encrypted] on the sender side.
                  final existingPlaintext = _messages[existingIndex].text;
                  setState(() {
                    _messages[existingIndex] = newMessage.copyWith(
                      text: existingPlaintext,
                    );
                    _updateChatItems();
                  });
                } else {
                  // Genuinely new message from the other person — decrypt normally
                  newMessage = await _decryptMessage(newMessage);
                  if (mounted) {
                    setState(() {
                      _messages.add(newMessage);
                      _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
                      _updateChatItems();
                    });
                    _scrollToBottom();

                    // Mark as read since chat is open
                    if (newMessage.senderId == widget.recipientId) {
                      _markMessagesAsRead();
                    }
                  }
                }
              } // end if (mounted)
            } else if (payload.eventType == PostgresChangeEvent.update) {
              final data = payload.newRecord;
              var updatedMessage = Message.fromJson(data);
              final deletedFor =
                  updatedMessage.metadata?['deleted_for'] as List?;

              // Decrypt if needed
              updatedMessage = await _decryptMessage(updatedMessage);

              if (mounted) {
                if (deletedFor != null && deletedFor.contains(_currentUserId)) {
                  setState(() {
                    _messages.removeWhere((m) => m.id == updatedMessage.id);
                    _updateChatItems();
                  });
                  return;
                }

                setState(() {
                  final index = _messages.indexWhere(
                    (m) => m.id == updatedMessage.id,
                  );
                  if (index != -1) {
                    _messages[index] = updatedMessage;
                  } else {
                    // Add it if it's missing (helps with race conditions)
                    _messages.add(updatedMessage);
                    _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
                  }
                  _updateChatItems();
                });
              }
            } else if (payload.eventType == PostgresChangeEvent.delete) {
              final deletedId = payload.oldRecord['id'];
              if (mounted) {
                setState(() {
                  _messages.removeWhere((m) => m.id == deletedId);
                  _updateChatItems();
                });
              }
            }
          },
        )
        .subscribe();
  }

  void _setupTimerListener(String conversationId) {
    final supabase = Supabase.instance.client;
    _timerSubscription = supabase
        .channel('public:user_conversations:$conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'user_conversations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) {
            final newRecord = payload.newRecord;
            if (newRecord['ephemeral_timer'] != null) {
              if (mounted) {
                // Determine if we should show a snackbar (only if value actually changed)
                final oldTimer = _ephemeralTimer;
                final newTimer = newRecord['ephemeral_timer'] as String;

                setState(() {
                  _ephemeralTimer = newTimer;
                });

                // Only show if it's a change and we are viewing it
                if (oldTimer != newTimer) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Self-destruct timer updated to ${_ephemeralTimer.replaceAll('_', ' ')}',
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }

                _cleanupExpiredMessages();
              }
            }
          },
        )
        .subscribe();
  }

  Future<void> _cleanupExpiredMessages() async {
    if (_ephemeralTimer == 'off' || _messages.isEmpty) return;

    final now = DateTime.now();
    final List<String> idsToDelete = [];

    for (final message in _messages) {
      bool shouldDelete = false;

      if (_ephemeralTimer == 'after_seen') {
        if (message.status == MessageStatus.read) {
          // If it's read, delete it.
          // To be safe, maybe check updated_at, but "after seen" implies immediacy
          shouldDelete = true;
        }
      } else {
        // Parse hours
        int hours = 24;
        if (_ephemeralTimer == '12_hours') {
          hours = 12;
        } else if (_ephemeralTimer == '48_hours') {
          hours = 48;
        } else if (_ephemeralTimer == '72_hours') {
          hours = 72;
        }

        final deleteTime = message.timestamp.add(Duration(hours: hours));
        if (now.isAfter(deleteTime)) {
          shouldDelete = true;
        }
      }

      if (shouldDelete) {
        idsToDelete.add(message.id);
      }
    }

    if (idsToDelete.isNotEmpty) {
      debugPrint('🧹 Cleaning up ${idsToDelete.length} expired messages');
      for (final id in idsToDelete) {
        await _chatService.deleteMessage(id);
      }
      // UI update will happen via realtime listener or we can do it manually
      if (mounted) {
        setState(() {
          _messages.removeWhere((m) => idsToDelete.contains(m.id));
          _updateChatItems();
        });
      }
    }
  }

  Future<void> _markMessagesAsRead() async {
    if (_currentUserId == null || _conversationId == null) return;

    final unreadFromRecipient = _messages.any(
      (m) => m.senderId == widget.recipientId && m.status != MessageStatus.read,
    );

    if (!unreadFromRecipient) return;

    try {
      final supabase = Supabase.instance.client;
      await supabase
          .from('messages')
          .update({'status': MessageStatus.read.name})
          .eq('conversation_id', _conversationId!)
          .eq('sender_id', widget.recipientId)
          .neq('status', MessageStatus.read.name);

      // Local update
      if (mounted) {
        setState(() {
          for (var i = 0; i < _messages.length; i++) {
            if (_messages[i].senderId == widget.recipientId &&
                _messages[i].status != MessageStatus.read) {
              _messages[i] = _messages[i].copyWith(status: MessageStatus.read);
            }
          }
          _updateChatItems();
        });
      }
    } catch (e) {
      debugPrint('Error marking messages as read: $e');
    }
  }

  Future<Message> _decryptMessage(Message message, {String? localText, bool shouldCache = true}) async {
    // 1. If not encrypted, return as is
    if (!message.isEncrypted || message.encryptedContent == null) {
      return message;
    }

    // Fast Path: Check if plaintext already provided (saves a DB query)
    if (localText != null && localText != '[Encrypted]' && localText.isNotEmpty) {
      return message.copyWith(text: localText);
    }

    // Secondary Path: Check local SQLite for cached plaintext if not provided
    try {
      final localResults = await DatabaseManager.instance.query(
        'SELECT text FROM messages WHERE id = ?',
        [message.id],
      );
      if (localResults.isNotEmpty) {
        final cachedText = localResults.first['text'] as String;
        if (cachedText != '[Encrypted]' && cachedText.isNotEmpty) {
          return message.copyWith(text: cachedText);
        }
      }
    } catch (e) {
      debugPrint('Error fetching local plaintext: $e');
    }

    // Ensure E2EE is initialized before decryption (this check is very fast if already init)
    if (!VirgilE2EEService.instance.isInitialized && _currentUserId != null) {
      await SupabaseService.instance.initializeE2EE(_currentUserId!);
    }

    // 2. If we are the SENDER, decrypt using our own encrypted copy.
    if (message.senderId == _currentUserId) {
      if (message.encryptedContentSender != null) {
        try {
          final ourKeys = _myKeys ??
              await VirgilKeyService().getRecipientKeys(_currentUserId!);
          if (ourKeys != null) {
            final decrypted =
                await VirgilE2EEService.instance.decryptThenVerify(
              message.encryptedContentSender!,
              ourKeys['signaturePublicKey'],
            );
            return message.copyWith(text: decrypted);
          }
        } catch (e) {
          debugPrint('⚠️ Sender-copy decryption failed: $e');
        }
      }

      return message; // Old message before fix — show [Encrypted] as last resort
    }

    // 3. If we are the RECIPIENT, proceed with normal decryption
    if (message.receiverId != _currentUserId) {
      return message;
    }

    try {
      final senderKeys = _recipientKeys ??
          await VirgilKeyService().getRecipientKeys(message.senderId);
      if (senderKeys == null) {
        debugPrint('⚠️ Virgil keys not found for sender ${message.senderId}');
        return message.copyWith(status: MessageStatus.decryptionFailed);
      }

      final decrypted = await VirgilE2EEService.instance.decryptThenVerify(
        message.encryptedContent!,
        senderKeys['signaturePublicKey'],
      );

      // Cache the decrypted plaintext locally to prevent future UI freezing!
      if (shouldCache) {
        try {
          await DatabaseManager.instance.update(
            'messages',
            {'text': decrypted},
            where: 'id = ?',
            whereArgs: [message.id],
          );
        } catch (e) {
          debugPrint('⚠️ Failed to cache decrypted text: $e');
        }
      }

      return message.copyWith(text: decrypted);
    } catch (e) {
      debugPrint('⚠️ Message decryption failed: $e');
      return message.copyWith(status: MessageStatus.decryptionFailed);
    }
  }

  Future<void> _batchUpdateCache(List<Message> messages, Map<String, String> existingCache) async {
    final toUpdate = messages.where((m) => 
      m.isEncrypted && 
      m.text != '[Encrypted]' && 
      m.text.isNotEmpty && 
      !existingCache.containsKey(m.id)
    ).toList();

    if (toUpdate.isEmpty) return;

    try {
      final db = await DatabaseManager.instance.database;
      final batch = db.batch();
      for (final m in toUpdate) {
        batch.update(
          'messages',
          {'text': m.text},
          where: 'id = ?',
          whereArgs: [m.id],
        );
      }
      await batch.commit(noResult: true);
      debugPrint('✅ Batched ${toUpdate.length} message decryptions to local cache');
    } catch (e) {
      debugPrint('⚠️ Failed to batch update cache: $e');
    }
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));

    if (_isSameDay(date, now)) {
      return 'Today';
    } else if (_isSameDay(date, yesterday)) {
      return 'Yesterday';
    } else {
      return DateFormat('MMMM d, yyyy').format(date);
    }
  }

  void _updateChatItems() {
    final items = <dynamic>[];
    if (_messages.isEmpty) {
      if (widget.recipientId == AppConstants.booferId) {
        items.add('welcome_note');
        _chatItems = items;
      } else {
        _chatItems = [];
      }
      return;
    }

    // messages are sorted ascending (oldest first)
    for (int i = _messages.length - 1; i >= 0; i--) {
      items.add(_messages[i]);

      if (i == 0 ||
          !_isSameDay(_messages[i].timestamp, _messages[i - 1].timestamp)) {
        items.add(_messages[i].timestamp);
      }
    }

    _chatItems = items;
  }

  // ... (existing code)

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
        child: SmartMaintenance(
          featureName: 'Messaging',
          check: (status) => status.isMessagingActive,
          child: Column(
            children: [
              Expanded(child: _buildMessagesList()),
              _buildModernInputArea(theme),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildModernAppBar(ThemeData theme, bool isOfficial) {
    final chatProvider = context.watch<ChatProvider>();
    final isRecipientOnline = chatProvider.isUserOnline(widget.recipientId);
    final isAppOnline = chatProvider.isAppOnline;

    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight + 8),
      child: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 0, // Reduced spacing
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: InkWell(
          onTap: _navigateToProfile,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 0,
              vertical: 4,
            ), // Reduced horizontal padding
            child: Row(
              children: [
                Hero(
                  tag: 'avatar_${widget.recipientId}',
                  child: UserAvatar(
                    avatar: _recipientUser?.avatar ?? widget.recipientAvatar,
                    profilePicture: _recipientUser?.profilePicture ??
                        widget.recipientProfilePicture,
                    name: _recipientUser?.fullName ?? widget.recipientName,
                    radius: 20,
                    fontSize: 18,
                    isCompany: _recipientUser?.isCompany ?? isOfficial,
                  ),
                ),
                const SizedBox(width: 8), // Reduced from 12
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
                                  ? 'You'
                                  : (_recipientUser?.fullName ??
                                      widget.recipientName),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 16, // Slightly smaller to fit better
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
                              size: 14,
                              color: isOfficial
                                  ? Colors.green
                                  : theme.colorScheme.primary,
                            ),
                          ],
                        ],
                      ),
                      Row(
                        children: [
                          Text(
                            !isAppOnline
                                ? 'Waiting for network...'
                                : (widget.recipientId == _currentUserId
                                    ? 'Message yourself'
                                    : (isRecipientOnline
                                        ? 'Online'
                                        : 'Offline')),
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 10,
                              color: !isAppOnline
                                  ? Colors.orange
                                  : (widget.recipientId == _currentUserId
                                      ? theme.colorScheme.onSurface
                                          .withValues(alpha: 0.6)
                                      : (isRecipientOnline
                                          ? Colors.green
                                          : theme.colorScheme.onSurface
                                              .withValues(alpha: 0.6))),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const SizedBox(width: 4),
                          Text(
                            '•',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 10,
                              color: theme.colorScheme.onSurface.withValues(alpha: 
                                0.4,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            _ephemeralTimer == 'after_seen'
                                ? Icons.visibility_off_outlined
                                : Icons.timer_outlined,
                            size: 10,
                            color: theme.colorScheme.primary.withValues(alpha: 0.7),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            _ephemeralTimer.replaceAll('_', ' '),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary.withValues(alpha: 0.7),
                              fontSize: 9,
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
        actions: [
          if (widget.recipientId != AppConstants.booferId &&
              widget.recipientHandle != 'boofer') ...[
            IconButton(
              icon: SvgIcons.sized(
                SvgIcons.videoCall,
                24,
                color: theme.colorScheme.primary,
              ),
              onPressed: () => _showComingSoon('Video Call'),
            ),
            IconButton(
              icon: SvgIcons.sized(
                SvgIcons.voiceCall,
                24,
                color: theme.colorScheme.primary,
              ),
              onPressed: () => _showComingSoon('Voice Call'),
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
    if (_isBlocked) {
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.block, color: theme.colorScheme.error),
              const SizedBox(width: 8),
              Text(
                'You have blocked this user',
                style: TextStyle(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_replyToMessage != null) _buildReplyPreview(theme),
        ModernChatInput(
          autofocus: true,
          initialText: widget.initialText,
          hideWarning: widget.recipientId == _currentUserId, // Hide warning for self-chat
          onSendMessage: (text) {
            _handleSendMessage(text);
          },
          onAttachmentPressed: _onAttachmentPressed,
        ),
      ],
    );
  }

  Widget _buildMessagesList() {
    if (_loading && _messages.isEmpty) {
      return const SkeletonChatLoading();
    }

    if (_messages.isEmpty && widget.recipientId != AppConstants.booferId) {
      return _buildEmptyState();
    }

    // Find the latest message sent by the current user to show status for
    String? latestMeMessageId;
    try {
      final latestMeMessage = _messages.lastWhere(
        (m) => m.senderId == _currentUserId,
      );
      latestMeMessageId = latestMeMessage.id;
    } catch (_) {
      // No messages sent by current user
    }

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + kToolbarHeight + 20,
        bottom: 20,
      ),
      itemCount: _chatItems.length,
      itemBuilder: (context, index) {
        final item = _chatItems[index];

        if (item is Message) {
          final isMe = item.senderId == _currentUserId;
          final isLatestMe = item.id == latestMeMessageId;
          final showStatus = isMe &&
              (isLatestMe ||
                  item.status == MessageStatus.failed ||
                  item.status == MessageStatus.decryptionFailed ||
                  item.status == MessageStatus.pending);

          return Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              MessageBubble(
                message: item,
                currentUserId: _currentUserId!,
                senderName: isMe ? null : widget.recipientName,
                onTap: () => _handleMessageTap(item),
                onReply: _handleReply,
              ),
              if (showStatus) _buildMessageStatus(item),
            ],
          );
        } else if (item == 'welcome_note') {
          return _buildWelcomeNote();
        } else if (item is DateTime) {
          return _buildDateHeader(item);
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildWelcomeNote() {
    final theme = Theme.of(context);
    final isSelfChat = widget.recipientId == _currentUserId;
    final userName = isSelfChat 
        ? 'You' 
        : (_recipientUser?.fullName ?? widget.recipientName);

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(Icons.rocket_launch, size: 32, color: Colors.blue),
            ),
            const SizedBox(height: 16),
            Text(
              'Welcome to Boofer, $userName! 🚀',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildWelcomePoint(
              Icons.lock_outline,
              'Privacy First',
              'Your chats are end-to-end encrypted. Only you and your friend can read them.',
            ),
            _buildWelcomePoint(
              Icons.timer_outlined,
              'Ephemeral Messages',
              'You can set messages to auto-delete after a chosen time.',
            ),
            _buildWelcomePoint(
              Icons.people_outline,
              'Mutual Connections',
              'You can only message someone once you mutually follow each other.',
            ),
            _buildWelcomePoint(
              Icons.shield_outlined,
              'Safety First',
              'Harassment or harmful content will result in an immediate ban.',
            ),
            const SizedBox(height: 16),
            Text(
              'Enjoy connecting safely.\n— The Boofer Team 🛣️',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomePoint(IconData icon, String title, String description) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageStatus(Message message) {
    String statusText;
    IconData? statusIcon;
    Color statusColor = Colors.grey;

    switch (message.status) {
      case MessageStatus.pending:
        statusText = 'Sending...';
        statusIcon = Icons.access_time;
        break;
      case MessageStatus.sent:
        statusText = 'Sent';
        statusIcon = Icons.check;
        break;
      case MessageStatus.delivered:
        statusText = 'Delivered';
        statusIcon = Icons.done_all;
        break;
      case MessageStatus.read:
        statusText = 'Seen';
        statusIcon = Icons.done_all;
        statusColor = Colors.blue;
        break;
      case MessageStatus.failed:
        statusText = 'Try again';
        statusIcon = Icons.error_outline;
        statusColor = Colors.red;
        break;
      case MessageStatus.decryptionFailed:
        statusText = 'Decryption Failed';
        statusIcon = Icons.lock_reset;
        statusColor = Colors.orange;
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(right: 12, bottom: 4),
      child: GestureDetector(
        onTap: message.status == MessageStatus.failed ||
                message.status == MessageStatus.decryptionFailed
            ? () {
                // Resend logic if available, or just re-add to queue
                _handleSendMessage(message.text);
              }
            : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.status == MessageStatus.failed ||
                message.status == MessageStatus.decryptionFailed)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(statusIcon, size: 12, color: statusColor),
              ),
            Text(
              statusText,
              style: TextStyle(
                fontSize: 10,
                color: statusColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (message.status != MessageStatus.failed &&
                message.status != MessageStatus.decryptionFailed)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(statusIcon, size: 12, color: statusColor),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateHeader(DateTime date) {
    final theme = Theme.of(context);
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 20),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          _formatDateHeader(date),
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
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
            widget.recipientId == _currentUserId
                ? 'Start messaging yourself'
                : 'Start a conversation with ${widget.recipientName}',
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

    // ── Content moderation ────────────────────────────────────────────────────
    final modResult = ModerationService.moderateMessage(text.trim());
    if (!modResult.isAllowed) {
      _showModerationWarning(modResult.reason!);
      return;
    }
    // ─────────────────────────────────────────────────────────────────────────

    debugPrint('📨 Sending message from UI...');
    debugPrint('   Current User: $_currentUserId');
    debugPrint('   Recipient: ${widget.recipientId}');
    debugPrint('   Conversation: $_conversationId');
    debugPrint('   Message: $text');

    Message? optimisticMessage;
    try {
      // Determine initial status based on presence
      final chatProvider = context.read<ChatProvider>();
      MessageStatus initialStatus =
          MessageStatus.sent; // Default: Sent to server

      final recipientPresence = chatProvider.getRecipientPresence(
        widget.recipientId,
      );
      if (recipientPresence != null) {
        final isSameChat =
            recipientPresence['current_conversation_id'] == _conversationId;
        initialStatus =
            isSameChat ? MessageStatus.read : MessageStatus.delivered;
      }

      // Optimistic Update: Add message immediately with pending status
      debugPrint('📝 STEP 1: User sent message: "${text.trim()}"');
      final message = Message.create(
        text: text.trim(),
        senderId: _currentUserId!,
        receiverId: widget.recipientId,
        conversationId: _conversationId!,
        status: MessageStatus.pending, // Show "Sending..." initially
        metadata: _replyToMessage != null
            ? {
                'reply_to': {
                  'id': _replyToMessage!.id,
                  'text': _replyToMessage!.text,
                  'sender_name': _replyToMessage!.senderId == _currentUserId
                      ? 'You'
                      : (widget.recipientId == _currentUserId
                          ? 'You'
                          : widget.recipientName),
                },
              }
            : null,
      );
      optimisticMessage = message;

      if (mounted) {
        setState(() {
          _messages.add(message);
          _replyToMessage = null; // Clear reply
          _updateChatItems();
        });
        _scrollToBottom();
      }

      // CRITICAL: Save plaintext to local SQLite DB BEFORE sending to Supabase.
      // When Supabase realtime fires, _decryptMessage looks up the sender's
      // plaintext from local DB. Without this, it finds nothing and shows [Encrypted].
      try {
        await DatabaseManager.instance.insert(
            'messages',
            {
              'id': message.id,
              'text': message.text, // Original plaintext
              'sender_id': message.senderId,
              'receiver_id': message.receiverId,
              'conversation_id': message.conversationId,
              'timestamp': message.timestamp.toIso8601String(),
              'is_offline': 0,
              'status': message.status.name,
              'message_hash': message.messageHash,
              'is_encrypted': 0,
              'encrypted_content': null,
              'encryption_version': null,
              'created_at': message.timestamp.toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
              'metadata': message.metadata != null
                  ? jsonEncode(message.metadata)
                  : null,
            },
            conflictAlgorithm: ConflictAlgorithm.replace);
        debugPrint('💾 Plaintext saved to local DB for sender recovery');
      } catch (e) {
        debugPrint('⚠️ Failed to save plaintext locally: $e');
      }

      // ── LOCAL-ONLY FOR SELF-CHAT ─────────────────────
      if (widget.recipientId == _currentUserId) {
        debugPrint('🏠 Self-chat detected: Keeping message local only');
        if (mounted) {
          setState(() {
            final index = _messages.indexWhere((m) => m.id == message.id);
            if (index != -1) {
              _messages[index] = message.copyWith(status: MessageStatus.read);
              _updateChatItems();
            }
          });
        }
        return;
      }
      // ──────────────────────────────────────────────────

      final result = await SupabaseService.instance.sendMessage(
        conversationId: _conversationId!,
        senderId: _currentUserId!,
        receiverId: widget.recipientId,
        text: text.trim(),
        messageObject: message.copyWith(status: initialStatus),
        knownTimer: _ephemeralTimer, // Skip extra DB round-trip for timer
      );

      if (result != null) {
        debugPrint('✅ Message sent successfully from UI');
        // Update the message in the list with the confirmed one
        // BUT keep our plaintext if the server returned "[Encrypted]"
        if (mounted) {
          setState(() {
            final index = _messages.indexWhere((m) => m.id == message.id);
            if (index != -1) {
              _messages[index] = result.copyWith(text: message.text);
            }
          });
        }
      } else {
        debugPrint('⚠️ Message send returned null');
        // Mark as failed in UI
        if (mounted) {
          setState(() {
            final index = _messages.indexWhere((m) => m.id == message.id);
            if (index != -1) {
              _messages[index] = message.copyWith(status: MessageStatus.failed);
            }
          });
        }
      }
    } catch (e) {
      debugPrint('❌ Error in UI message handler: $e');

      // Mark as failed in UI so user sees red prompt "Try again"
      if (mounted) {
        setState(() {
          if (optimisticMessage != null) {
            final index = _messages.indexWhere(
              (m) => m.id == optimisticMessage!.id,
            );
            if (index != -1) {
              _messages[index] = optimisticMessage.copyWith(
                status: MessageStatus.failed,
              );
            }
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _onAttachmentPressed() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Share Media',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildAttachmentOption(
                      icon: Icons.image_rounded,
                      label: 'Gallery',
                      color: Colors.purple,
                      onTap: () {
                        Navigator.pop(context);
                        _pickMedia(false, false);
                      },
                    ),
                    _buildAttachmentOption(
                      icon: Icons.camera_alt_rounded,
                      label: 'Camera',
                      color: Colors.blue,
                      onTap: () {
                        Navigator.pop(context);
                        _pickMedia(true, false);
                      },
                    ),
                    _buildAttachmentOption(
                      icon: Icons.videocam_rounded,
                      label: 'Video',
                      color: Colors.red,
                      onTap: () {
                        Navigator.pop(context);
                        _pickMedia(false, true);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: color.withOpacity(isDark ? 0.2 : 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickMedia(bool fromCamera, bool isVideo) async {
    try {
      File? pickedFile;
      if (isVideo) {
        pickedFile =
            await MediaService.instance.pickVideo(fromCamera: fromCamera);
      } else {
        pickedFile =
            await MediaService.instance.pickImage(fromCamera: fromCamera);
      }

      if (pickedFile == null) return;

      // Validate file
      if (!MediaService.instance
          .validateMediaFile(pickedFile, isVideo: isVideo)) {
        return;
      }

      // Open Editor
      if (!mounted) return;
      final result = await Navigator.push<MediaEditResult>(
        context,
        MaterialPageRoute(
          builder: (context) => MediaEditViewer(
            file: pickedFile!,
            isVideo: isVideo,
            recipientName: widget.recipientName,
          ),
        ),
      );

      if (result != null) {
        await _handleSendMedia(result);
      }
    } catch (e) {
      debugPrint('❌ Error picking media: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _handleSendMedia(MediaEditResult result) async {
    if (_currentUserId == null || _conversationId == null) return;

    debugPrint('📤 Preparing media message...');

    // Create optimistic message ID
    final messageId = const Uuid().v4();
    final type = result.isVideo ? MessageType.video : MessageType.image;
    final timestamp = DateTime.now();

    final metadata = {
      'media': {
        'local_media_path': result.file.path,
        'is_video': result.isVideo,
        'original_size': await result.file.length(),
      },
      'reply_to': _replyToMessage != null
          ? {
              'id': _replyToMessage!.id,
              'text': _replyToMessage!.text,
              'sender_name': _replyToMessage!.senderId == _currentUserId
                  ? 'You'
                  : widget.recipientName,
            }
          : null,
    };

    final optimisticMessage = Message(
      id: messageId,
      senderId: _currentUserId!,
      receiverId: widget.recipientId,
      conversationId: _conversationId!,
      text: result.isVideo ? '[Video]' : '[Image]',
      timestamp: timestamp,
      status: MessageStatus.pending,
      type: type,
      isEncrypted: true,
      metadata: metadata,
      messageHash: '${_currentUserId}_${widget.recipientId}_${timestamp.millisecondsSinceEpoch}',
    );

    if (mounted) {
      setState(() {
        _messages.add(optimisticMessage);
        _replyToMessage = null; // Clear reply
        _updateChatItems();
      });
      _scrollToBottom();
    }

    // Save to local DB for recovery
    try {
      await DatabaseManager.instance.insert(
        'messages',
        {
          'id': optimisticMessage.id,
          'text': optimisticMessage.text,
          'sender_id': optimisticMessage.senderId,
          'receiver_id': optimisticMessage.receiverId,
          'conversation_id': optimisticMessage.conversationId,
          'timestamp': optimisticMessage.timestamp.toIso8601String(),
          'is_offline': 0,
          'status': optimisticMessage.status.name,
          'message_hash': optimisticMessage.messageHash,
          'is_encrypted': 1,
          'type': optimisticMessage.type.name,
          'metadata': jsonEncode(optimisticMessage.metadata),
          'created_at': optimisticMessage.timestamp.toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      } catch (e) {
        debugPrint('⚠️ Failed to save media message locally: $e');
      }

      // ── LOCAL-ONLY FOR SELF-CHAT ─────────────────────
      if (widget.recipientId == _currentUserId) {
        debugPrint('🏠 Self-chat detected: Keeping media local only');
        if (mounted) {
          setState(() {
            final index = _messages.indexWhere((m) => m.id == messageId);
            if (index != -1) {
              _messages[index] = optimisticMessage.copyWith(status: MessageStatus.read);
              _updateChatItems();
            }
          });
        }
        return;
      }
      // ──────────────────────────────────────────────────

      try {
      Uint8List mediaBytes;
      int originalSize = await result.file.length();
      int compressedSize;
      String mimeType;

      // Update UI with "Compressing..." stage
      _updateMessageMetadata(messageId, {'upload_stage': 'Compressing...', 'upload_progress': 0.1});

      if (result.isVideo) {
        mediaBytes = await result.file.readAsBytes();
        compressedSize = originalSize;
        mimeType = 'video/mp4';
      } else {
        final compressionResult =
            await MediaService.instance.compressImageToWebp(result.file);
        final File compressedFile = compressionResult['file'];
        mediaBytes = await compressedFile.readAsBytes();
        compressedSize = compressionResult['compressedSize'];
        mimeType = 'image/webp';
      }

      _updateMessageMetadata(messageId, {'upload_stage': 'Encrypting...', 'upload_progress': 0.3});

      // Fetch keys
      final recipientKeys =
          await VirgilKeyService().getRecipientKeys(widget.recipientId);
      final senderKeys =
          await VirgilKeyService().getRecipientKeys(_currentUserId!);

      if (recipientKeys == null) {
        throw Exception(
            'Recipient keys not found. Cannot send encrypted media.');
      }

      _updateMessageMetadata(messageId, {'upload_stage': 'Uploading...', 'upload_progress': 0.5});

      // Send via Supabase
      final sentMessage = await SupabaseService.instance.sendMediaMessage(
        conversationId: _conversationId!,
        senderId: _currentUserId!,
        receiverId: widget.recipientId,
        mediaLocalPath: result.file.path,
        type: type,
        compressedMediaBytes: mediaBytes,
        recipientKeys: recipientKeys,
        senderKeys: senderKeys,
        originalSize: originalSize,
        compressedSize: compressedSize,
        mimeType: mimeType,
        knownTimer: _ephemeralTimer,
      );

      if (sentMessage != null && mounted) {
        setState(() {
          final index = _messages.indexWhere((m) => m.id == messageId);
          if (index != -1) {
            // Keep local_media_path in metadata for UI
            final finalMetadata = Map<String, dynamic>.from(sentMessage.metadata ?? {});
            finalMetadata['media'] ??= {};
            finalMetadata['media']['local_media_path'] = result.file.path;
            
            _messages[index] = sentMessage.copyWith(metadata: finalMetadata);
            _updateChatItems();
          }
        });
      }
    } catch (e) {
      debugPrint('❌ Media send failed: $e');
      if (mounted) {
        setState(() {
          final index = _messages.indexWhere((m) => m.id == messageId);
          if (index != -1) {
            _messages[index] =
                optimisticMessage.copyWith(status: MessageStatus.failed);
            _updateChatItems();
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to send media: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  void _updateMessageMetadata(String messageId, Map<String, dynamic> extraMetadata) {
    if (!mounted) return;
    setState(() {
      final index = _messages.indexWhere((m) => m.id == messageId);
      if (index != -1) {
        final currentMetadata = Map<String, dynamic>.from(_messages[index].metadata ?? {});
        currentMetadata.addAll(extraMetadata);
        _messages[index] = _messages[index].copyWith(metadata: currentMetadata);
      }
    });
  }

  Widget _buildReplyPreview(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 32,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _replyToMessage!.senderId == _currentUserId
                      ? 'Reply to yourself'
                      : (widget.recipientId == _currentUserId
                          ? 'Reply to yourself'
                          : 'Reply to ${widget.recipientName}'),
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _replyToMessage!.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: _cancelReply,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  void _handleMessageTap(Message message) {
    // Basic tap handler
  }

  void _handleReply(Message message) {
    setState(() {
      _replyToMessage = message;
    });
  }

  void _cancelReply() {
    setState(() {
      _replyToMessage = null;
    });
  }

  /// Shows a blocking dialog when the moderation service flags a message.
  void _showModerationWarning(String reason) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.shield_outlined, color: Colors.red, size: 40),
        title: const Text(
          'Message Blocked',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(reason, textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('OK'),
          ),
        ],
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
            content: Text(
              widget.recipientId == _currentUserId
                  ? 'You are now following yourself'
                  : 'You are now following ${widget.recipientName}',
            ),
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
        setState(() {
          _isBlocked = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.recipientId == _currentUserId
                    ? 'You have been unblocked'
                    : '${widget.recipientName} has been unblocked',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Block user (mock implementation for now)
        setState(() {
          _isBlocked = true;
          _isMutual = false;
          _isFollowing = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.recipientId == _currentUserId
                    ? 'You have been blocked'
                    : '${widget.recipientName} has been blocked',
              ),
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

  void _showEphemeralTimerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Self-destruct messages',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            ListTile(
              leading: Icon(
                Icons.visibility_off_outlined,
                color: _ephemeralTimer == 'after_seen'
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
              title: Text(
                'After seen',
                style: TextStyle(
                  fontWeight:
                      _ephemeralTimer == 'after_seen' ? FontWeight.bold : null,
                ),
              ),
              trailing: _ephemeralTimer == 'after_seen'
                  ? const Icon(Icons.check, size: 20)
                  : null,
              onTap: () => _updateEphemeralTimer('after_seen'),
            ),
            ListTile(
              leading: Icon(
                Icons.history,
                color: _ephemeralTimer == '12_hours'
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
              title: Text(
                '12 hours (Default)',
                style: TextStyle(
                  fontWeight:
                      _ephemeralTimer == '12_hours' ? FontWeight.bold : null,
                ),
              ),
              trailing: _ephemeralTimer == '12_hours'
                  ? const Icon(Icons.check, size: 20)
                  : null,
              onTap: () => _updateEphemeralTimer('12_hours'),
            ),
            ListTile(
              leading: Icon(
                Icons.schedule,
                color: _ephemeralTimer == '24_hours'
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
              title: Text(
                '24 hours',
                style: TextStyle(
                  fontWeight:
                      _ephemeralTimer == '24_hours' ? FontWeight.bold : null,
                ),
              ),
              trailing: _ephemeralTimer == '24_hours'
                  ? const Icon(Icons.check, size: 20)
                  : null,
              onTap: () => _updateEphemeralTimer('24_hours'),
            ),
            ListTile(
              leading: Icon(
                Icons.history,
                color: _ephemeralTimer == '48_hours'
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
              title: Text(
                '48 hours',
                style: TextStyle(
                  fontWeight:
                      _ephemeralTimer == '48_hours' ? FontWeight.bold : null,
                ),
              ),
              trailing: _ephemeralTimer == '48_hours'
                  ? const Icon(Icons.check, size: 20)
                  : null,
              onTap: () => _updateEphemeralTimer('48_hours'),
            ),
            ListTile(
              leading: Icon(
                Icons.edit_calendar_outlined,
                color: (![
                  'after_seen',
                  '12_hours',
                  '24_hours',
                  '48_hours',
                ].contains(_ephemeralTimer))
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
              title: Text(
                'Custom (Max 72h)',
                style: TextStyle(
                  fontWeight: (![
                    'after_seen',
                    '12_hours',
                    '24_hours',
                    '48_hours',
                  ].contains(_ephemeralTimer))
                      ? FontWeight.bold
                      : null,
                ),
              ),
              subtitle: (![
                'after_seen',
                '12_hours',
                '24_hours',
                '48_hours',
              ].contains(_ephemeralTimer))
                  ? Text(_ephemeralTimer.replaceAll('_', ' '))
                  : null,
              onTap: () {
                Navigator.pop(context);
                _showCustomTimerDialog();
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showCustomTimerDialog() {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Custom Timer (Hours)'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: 'Enter hours (1-72)',
            suffixText: 'hours',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final hours = int.tryParse(controller.text);
              if (hours != null && hours > 0 && hours <= 72) {
                _updateEphemeralTimer('${hours}_hours');
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter 1-72 hours')),
                );
              }
            },
            child: const Text('Set'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateEphemeralTimer(String timer) async {
    Navigator.pop(context);
    try {
      await SupabaseService.instance.updateConversationTimer(
        widget.recipientId,
        timer,
      );
      if (mounted) {
        setState(() {
          _ephemeralTimer = timer;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Self-destruct set to: ${timer.replaceAll('_', ' ')}',
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  Future<void> _deleteConversation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Chat?'),
        content: const Text(
          'This will remove the chat from your lobby. Your relationship (following) will stay the same.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await SupabaseService.instance.deleteConversation(widget.recipientId);
        if (mounted) {
          Navigator.pop(context); // Close chat screen
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Conversation deleted from lobby')),
          );
        }
      } catch (e) {
        debugPrint('Error deleting conversation: $e');
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
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
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
                    ).colorScheme.surfaceContainerHighest,
                    child: widget.recipientAvatar != null &&
                            widget.recipientAvatar!.startsWith('http')
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
                            (widget.recipientAvatar != null &&
                                    widget.recipientAvatar!.isNotEmpty)
                                ? widget.recipientAvatar!
                                : widget.recipientName[0].toUpperCase(),
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
                          widget.recipientId == _currentUserId
                              ? 'You'
                              : widget.recipientName,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        if (widget.recipientHandle != null)
                          Text(
                            '@${widget.recipientHandle}',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                                    ),
                          )
                        else
                          Text(
                            'Tap to view profile',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface.withValues(alpha: 0.6),
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
            // Ephemeral (Self-destruct) settings
            _buildBottomSheetOption(
              icon: Icons.timer_outlined,
              title: 'Self-destruct timer',
              onTap: () {
                Navigator.pop(context);
                _showEphemeralTimerSheet();
              },
            ),
            // Show block/unblock option
            if (widget.recipientId != AppConstants.booferId &&
                widget.recipientHandle != 'boofer' &&
                widget.recipientId != _currentUserId)
              _buildBottomSheetOption(
                icon: _isBlocked ? Icons.person_add : Icons.block,
                title: _isBlocked ? 'Unblock user' : 'Block user',
                onTap: () {
                  Navigator.pop(context);
                  _toggleBlockUser();
                },
                isDestructive: !_isBlocked,
              ),
            // Delete conversation from lobby
            _buildBottomSheetOption(
              icon: Icons.delete_outline,
              title: 'Delete chat',
              onTap: () {
                Navigator.pop(context);
                _deleteConversation();
              },
              isDestructive: true,
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
              ? Colors.red.withValues(alpha: 0.1)
              : Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
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
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
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
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
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

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature feature coming soon!'),
        duration: const Duration(seconds: 2),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}
