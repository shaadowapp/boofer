import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/message_model.dart';
import '../models/network_state.dart';
import '../services/chat_service.dart';
import '../core/database/database_manager.dart';
import '../core/error/error_handler.dart';
import '../widgets/message_bubble.dart';
import '../widgets/chat_input.dart';
import '../providers/theme_provider.dart';
import '../providers/appearance_provider.dart';

/// Main chat screen that displays messages and handles user input
class ChatScreen extends StatefulWidget {
  final String userId;
  final String? conversationId;

  const ChatScreen({
    super.key,
    required this.userId,
    this.conversationId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final ChatService _chatService;
  final ScrollController _scrollController = ScrollController();
  bool _isInitialized = false;
  String _initializationError = '';

  @override
  void initState() {
    super.initState();
    _chatService = ChatService(
      database: DatabaseManager.instance,
      errorHandler: ErrorHandler(),
    );
    _initializeChatService();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Initialize the chat service
  Future<void> _initializeChatService() async {
    try {
      // Chat service is ready to use immediately
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      setState(() {
        _initializationError = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      body: _isInitialized 
          ? _buildChatBody(context)
          : _buildInitializationScreen(context),
    );
  }

  /// Build app bar with connection status
  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      title: const Text('Chat'),
      backgroundColor: Theme.of(context).colorScheme.surface,
      foregroundColor: Theme.of(context).colorScheme.onSurface,
      elevation: 1,
      actions: [
        Consumer<ThemeProvider>(
          builder: (context, themeProvider, child) {
            return IconButton(
              icon: Icon(
                themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode,
              ),
              onPressed: () => themeProvider.toggleTheme(),
              tooltip: themeProvider.isDarkMode ? 'Switch to Light Mode' : 'Switch to Dark Mode',
            );
          },
        ),
        if (_isInitialized) _buildConnectionStatusIndicator(context),
        const SizedBox(width: 16),
      ],
    );
  }

  /// Build connection status indicator for app bar
  Widget _buildConnectionStatusIndicator(BuildContext context) {
    return StreamBuilder<NetworkState>(
      stream: _chatService.networkState,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(width: 24, height: 24);
        }

        final networkState = snapshot.data!;
        final isOnline = networkState.isOnlineMode && networkState.hasInternetConnection;
        final isOffline = networkState.isOfflineMode && networkState.connectedPeers > 0;
        
        Color statusColor;
        IconData statusIcon;
        String statusText;

        if (isOnline) {
          statusColor = Colors.green;
          statusIcon = Icons.wifi;
          statusText = 'Online';
        } else if (isOffline) {
          statusColor = Colors.blue;
          statusIcon = Icons.device_hub;
          statusText = '${networkState.connectedPeers} peers';
        } else {
          statusColor = Colors.orange;
          statusIcon = Icons.wifi_off;
          statusText = 'Connecting...';
        }

        return Tooltip(
          message: statusText,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: statusColor.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusIcon, size: 16, color: statusColor),
                const SizedBox(width: 4),
                Text(
                  networkState.mode.name.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Build initialization screen
  Widget _buildInitializationScreen(BuildContext context) {
    if (_initializationError.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to initialize chat',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _initializationError,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _initializationError = '';
                });
                _initializeChatService();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Initializing chat...'),
        ],
      ),
    );
  }

  /// Build main chat body
  Widget _buildChatBody(BuildContext context) {
    final appearanceProvider = Provider.of<AppearanceProvider>(context);
    final wallpaperDecoration = appearanceProvider.getWallpaperDecoration();
    
    return Container(
      decoration: wallpaperDecoration,
      child: Column(
        children: [
          Expanded(
            child: _buildMessagesList(context),
          ),
          _buildChatInput(context),
        ],
      ),
    );
  }

  /// Build messages list
  Widget _buildMessagesList(BuildContext context) {
    return StreamBuilder<List<Message>>(
      stream: _chatService.messagesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'Error loading messages',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  snapshot.error.toString(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ),
          );
        }

        final messages = snapshot.data ?? [];

        if (messages.isEmpty) {
          return _buildEmptyState(context);
        }

        // Auto-scroll to bottom when new messages arrive
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[index];
            return MessageBubble(
              message: message,
              currentUserId: widget.userId,
              onTap: () => _handleMessageTap(message),
              onLongPress: () => _handleMessageLongPress(message),
            );
          },
        );
      },
    );
  }

  /// Build empty state
  Widget _buildEmptyState(BuildContext context) {
    return StreamBuilder<NetworkState>(
      stream: _chatService.networkState,
      builder: (context, snapshot) {
        final networkState = snapshot.data;
        final isConnected = networkState?.hasInternetConnection == true || 
                           (networkState?.connectedPeers ?? 0) > 0;

        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isConnected ? Icons.chat_bubble_outline : Icons.wifi_off,
                size: 64,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text(
                isConnected 
                    ? 'No messages yet'
                    : 'Waiting for connection...',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isConnected
                    ? 'Start a conversation by sending a message'
                    : 'Connect to internet or find nearby devices',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Build chat input
  Widget _buildChatInput(BuildContext context) {
    return StreamBuilder<NetworkState>(
      stream: _chatService.networkState,
      builder: (context, snapshot) {
        final networkState = snapshot.data ?? NetworkState(
          mode: NetworkMode.auto,
          hasInternetConnection: false,
          connectedPeers: 0,
          lastSync: DateTime.now(),
          isOnlineServiceActive: false,
          isMeshActive: false,
        );

        return ChatInput(
          onSendMessage: _handleSendMessage,
          onModeToggle: _handleModeToggle,
          currentMode: networkState.mode,
          isOnlineMode: networkState.isOnlineMode,
          isOfflineMode: networkState.isOfflineMode,
          connectedPeers: networkState.connectedPeers,
          hasInternetConnection: networkState.hasInternetConnection,
          isEnabled: _isInitialized,
        );
      },
    );
  }

  /// Handle sending a message
  Future<void> _handleSendMessage(String text) async {
    if (!_isInitialized || text.trim().isEmpty) return;

    try {
      await _chatService.sendMessage(
        conversationId: widget.conversationId ?? 'default',
        senderId: widget.userId,
        content: text.trim(),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => _handleSendMessage(text),
            ),
          ),
        );
      }
    }
  }

  /// Handle mode toggle (deprecated - chat service doesn't support mode switching)
  Future<void> _handleModeToggle() async {
    if (!_isInitialized) return;

    // Mode switching is not supported in current ChatService implementation
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mode switching is not available'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /// Handle message tap
  void _handleMessageTap(Message message) {
    // Could show message details or perform other actions
    print('Message tapped: ${message.id}');
  }

  /// Handle message long press
  void _handleMessageLongPress(Message message) {
    // Show context menu for message actions
    showModalBottomSheet(
      context: context,
      builder: (context) => _buildMessageContextMenu(context, message),
    );
  }

  /// Build message context menu
  Widget _buildMessageContextMenu(BuildContext context, Message message) {
    final isOwnMessage = message.senderId == widget.userId;
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.copy),
            title: const Text('Copy text'),
            onTap: () {
              // Copy message text to clipboard
              Navigator.pop(context);
            },
          ),
          // Retry functionality not yet implemented
          // if (isOwnMessage && message.status == MessageStatus.failed)
          //   ListTile(
          //     leading: const Icon(Icons.refresh),
          //     title: const Text('Retry sending'),
          //     onTap: () {
          //       Navigator.pop(context);
          //       // _chatService.retryFailedMessages();
          //     },
          //   ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Message info'),
            onTap: () {
              Navigator.pop(context);
              _showMessageInfo(context, message);
            },
          ),
        ],
      ),
    );
  }

  /// Show message information dialog
  void _showMessageInfo(BuildContext context, Message message) {
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
            _buildInfoRow('Mode', message.isOffline ? 'Offline' : 'Online'),
            _buildInfoRow('Time', message.timestamp.toString()),
            _buildInfoRow('ID', message.id.toString()),
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

  /// Build info row for message details
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
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}