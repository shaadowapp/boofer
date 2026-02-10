import 'package:flutter/material.dart';
import '../models/network_state.dart';
import '../utils/svg_icons.dart';

/// Widget for chat input with mode toggle and send functionality
class ChatInput extends StatefulWidget {
  final Function(String) onSendMessage;
  final VoidCallback? onModeToggle;
  final NetworkMode currentMode;
  final bool isOnlineMode;
  final bool isOfflineMode;
  final int connectedPeers;
  final bool hasInternetConnection;
  final bool isEnabled;

  const ChatInput({
    super.key,
    required this.onSendMessage,
    this.onModeToggle,
    required this.currentMode,
    required this.isOnlineMode,
    required this.isOfflineMode,
    this.connectedPeers = 0,
    this.hasInternetConnection = false,
    this.isEnabled = true,
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isComposing = false;

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildModeIndicator(context),
              const SizedBox(height: 12),
              _buildInputRow(context),
            ],
          ),
        ),
      ),
    );
  }

  /// Build mode indicator showing current connection status
  Widget _buildModeIndicator(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _getModeColor(context).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _getModeColor(context).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getModeIcon(),
            size: 16,
            color: _getModeColor(context),
          ),
          const SizedBox(width: 8),
          Text(
            _getModeText(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _getModeColor(context),
            ),
          ),
          if (widget.onModeToggle != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: widget.onModeToggle,
              child: Icon(
                Icons.swap_horiz,
                size: 16,
                color: _getModeColor(context),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Build input row with text field and send button
  Widget _buildInputRow(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(24),
            ),
            child: TextField(
              controller: _textController,
              focusNode: _focusNode,
              enabled: widget.isEnabled,
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: _getHintText(),
                hintStyle: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              onChanged: (text) {
                setState(() {
                  _isComposing = text.trim().isNotEmpty;
                });
              },
              onSubmitted: _isComposing ? _handleSubmitted : null,
            ),
          ),
        ),
        const SizedBox(width: 12),
        _buildSendButton(context),
      ],
    );
  }

  /// Build send button
  Widget _buildSendButton(BuildContext context) {
    final canSend = _isComposing && widget.isEnabled && _canSendMessage();
    
    return Container(
      decoration: BoxDecoration(
        color: canSend 
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.outline.withOpacity(0.3),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        onPressed: canSend ? () => _handleSubmitted(_textController.text) : null,
        icon: SvgIcons.sized(
          SvgIcons.sendMessage,
          24,
          color: canSend 
              ? Colors.white
              : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
        ),
      ),
    );
  }

  /// Handle message submission
  void _handleSubmitted(String text) {
    if (text.trim().isEmpty || !widget.isEnabled) return;
    
    widget.onSendMessage(text.trim());
    _textController.clear();
    setState(() {
      _isComposing = false;
    });
    _focusNode.requestFocus();
  }

  /// Get mode icon
  IconData _getModeIcon() {
    if (widget.currentMode == NetworkMode.auto) {
      return widget.hasInternetConnection ? Icons.wifi : Icons.wifi_off;
    } else if (widget.isOnlineMode) {
      return Icons.wifi;
    } else {
      return Icons.wifi_off;
    }
  }

  /// Get mode color
  Color _getModeColor(BuildContext context) {
    if (!widget.isEnabled) {
      return Theme.of(context).colorScheme.outline;
    }
    
    if (widget.isOnlineMode && widget.hasInternetConnection) {
      return Colors.green;
    } else if (widget.isOfflineMode && widget.connectedPeers > 0) {
      return Colors.blue;
    } else {
      return Colors.orange;
    }
  }

  /// Get mode text
  String _getModeText() {
    if (!widget.isEnabled) {
      return 'Connecting...';
    }
    
    switch (widget.currentMode) {
      case NetworkMode.online:
        return widget.hasInternetConnection 
            ? 'Online Mode'
            : 'Online Mode (No Internet)';
      case NetworkMode.offline:
        return widget.connectedPeers > 0
            ? 'Offline Mode (${widget.connectedPeers} peers)'
            : 'Offline Mode (No peers)';
      case NetworkMode.auto:
        if (widget.hasInternetConnection) {
          return 'Auto Mode (Online)';
        } else if (widget.connectedPeers > 0) {
          return 'Auto Mode (Offline - ${widget.connectedPeers} peers)';
        } else {
          return 'Auto Mode (Searching...)';
        }
    }
  }

  /// Get hint text for input field
  String _getHintText() {
    if (!widget.isEnabled) {
      return 'Connecting...';
    }
    
    if (widget.isOnlineMode) {
      return widget.hasInternetConnection 
          ? 'Type a message...'
          : 'No internet connection';
    } else if (widget.isOfflineMode) {
      return widget.connectedPeers > 0
          ? 'Type a message...'
          : 'Searching for nearby devices...';
    } else {
      return 'Type a message...';
    }
  }

  /// Check if message can be sent
  bool _canSendMessage() {
    if (widget.isOnlineMode) {
      return widget.hasInternetConnection;
    } else if (widget.isOfflineMode) {
      return widget.connectedPeers > 0;
    } else {
      // Auto mode
      return widget.hasInternetConnection || widget.connectedPeers > 0;
    }
  }
}

/// Widget for mode toggle button
class ModeToggleButton extends StatelessWidget {
  final NetworkMode currentMode;
  final VoidCallback onToggle;
  final bool isEnabled;

  const ModeToggleButton({
    super.key,
    required this.currentMode,
    required this.onToggle,
    this.isEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: _getTooltipText(),
      child: InkWell(
        onTap: isEnabled ? onToggle : null,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _getModeColor(context).withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _getModeColor(context).withOpacity(0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getModeIcon(),
                size: 14,
                color: _getModeColor(context),
              ),
              const SizedBox(width: 4),
              Text(
                currentMode.name.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: _getModeColor(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getModeIcon() {
    switch (currentMode) {
      case NetworkMode.online:
        return Icons.wifi;
      case NetworkMode.offline:
        return Icons.wifi_off;
      case NetworkMode.auto:
        return Icons.autorenew;
    }
  }

  Color _getModeColor(BuildContext context) {
    if (!isEnabled) {
      return Theme.of(context).colorScheme.outline;
    }
    
    switch (currentMode) {
      case NetworkMode.online:
        return Colors.green;
      case NetworkMode.offline:
        return Colors.blue;
      case NetworkMode.auto:
        return Colors.purple;
    }
  }

  String _getTooltipText() {
    switch (currentMode) {
      case NetworkMode.online:
        return 'Online Mode - Using internet connection';
      case NetworkMode.offline:
        return 'Offline Mode - Using mesh network';
      case NetworkMode.auto:
        return 'Auto Mode - Switches automatically';
    }
  }
}

/// Widget for connection status indicator
class ConnectionStatusIndicator extends StatelessWidget {
  final bool hasInternetConnection;
  final int connectedPeers;
  final bool isOnlineMode;
  final bool isOfflineMode;

  const ConnectionStatusIndicator({
    super.key,
    required this.hasInternetConnection,
    required this.connectedPeers,
    required this.isOnlineMode,
    required this.isOfflineMode,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isOnlineMode) ...[
          Icon(
            hasInternetConnection ? Icons.wifi : Icons.wifi_off,
            size: 16,
            color: hasInternetConnection ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 4),
          Text(
            hasInternetConnection ? 'Online' : 'No Internet',
            style: TextStyle(
              fontSize: 12,
              color: hasInternetConnection ? Colors.green : Colors.red,
            ),
          ),
        ] else if (isOfflineMode) ...[
          Icon(
            Icons.device_hub,
            size: 16,
            color: connectedPeers > 0 ? Colors.blue : Colors.orange,
          ),
          const SizedBox(width: 4),
          Text(
            '$connectedPeers peers',
            style: TextStyle(
              fontSize: 12,
              color: connectedPeers > 0 ? Colors.blue : Colors.orange,
            ),
          ),
        ],
      ],
    );
  }
}