import 'package:flutter/material.dart';
import '../models/network_state.dart';
import '../utils/svg_icons.dart';
import 'markdown_text_editing_controller.dart';

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
  final TextEditingController _textController = MarkdownTextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isComposing = false;
  String _previousText = '';

  @override
  void initState() {
    super.initState();
    _textController.addListener(_handleTextChanged);
  }

  void _handleTextChanged() {
    final currentText = _textController.text;
    if (currentText == _previousText) return;

    final isComposing = currentText.trim().isNotEmpty;
    if (isComposing != _isComposing) {
      setState(() {
        _isComposing = isComposing;
      });
    }

    // Markdown list auto-continuation logic
    if (currentText.length > _previousText.length) {
      final cursor = _textController.selection.baseOffset;
      if (cursor > 0 && cursor <= currentText.length) {
        if (currentText[cursor - 1] == '\n' && _previousText.length < currentText.length) {
          int prevLineStart = currentText.lastIndexOf('\n', cursor - 2) + 1;
          if (prevLineStart == -1) prevLineStart = 0;
          String prevLine = currentText.substring(prevLineStart, cursor - 1);

          final bulletMatch = RegExp(r'^(\s*(?:\*|-|\+|\[\])\s+)(.*)$').firstMatch(prevLine);
          final numberMatch = RegExp(r'^(\s*(\d+)([\.\)])\s+)(.*)$').firstMatch(prevLine);
          final romanMatch = RegExp(r'^(\s*([ivxlcdmIVXLCDM]{2,}|[ivxIVX])([\.\)])\s+)(.*)$').firstMatch(prevLine);
          final alphaMatch = RegExp(r'^(\s*([a-zA-Z])([\.\)])\s+)(.*)$').firstMatch(prevLine);

          String prefixToAdd = '';
          bool removeEmptyList = false;

          if (bulletMatch != null) {
            if (bulletMatch.group(2)!.isEmpty) {
              removeEmptyList = true;
            } else {
              prefixToAdd = bulletMatch.group(1)!;
            }
          } else if (numberMatch != null) {
            if (numberMatch.group(4)!.isEmpty) {
              removeEmptyList = true;
            } else {
              String prefix = numberMatch.group(1)!;
              int num = int.parse(numberMatch.group(2)!);
              String sep = numberMatch.group(3)!;
              prefixToAdd = prefix.replaceFirst('$num$sep', '${num + 1}$sep');
            }
          } else if (romanMatch != null) {
            if (romanMatch.group(4)!.isEmpty) {
              removeEmptyList = true;
            } else {
              String prefix = romanMatch.group(1)!;
              String roman = romanMatch.group(2)!;
              String sep = romanMatch.group(3)!;
              String next = _incrementRoman(roman);
              prefixToAdd = prefix.replaceFirst('$roman$sep', '$next$sep');
            }
          } else if (alphaMatch != null) {
            if (alphaMatch.group(4)!.isEmpty) {
              removeEmptyList = true;
            } else {
              String prefix = alphaMatch.group(1)!;
              String alpha = alphaMatch.group(2)!;
              String sep = alphaMatch.group(3)!;
              String next = _incrementAlpha(alpha);
              prefixToAdd = prefix.replaceFirst('$alpha$sep', '$next$sep');
            }
          }

          if (removeEmptyList) {
            String newText = currentText.substring(0, prevLineStart) + currentText.substring(cursor);
            int newCursor = prevLineStart;
            _previousText = newText;
            _textController.value = TextEditingValue(
              text: newText,
              selection: TextSelection.collapsed(offset: newCursor),
            );
            return;
          } else if (prefixToAdd.isNotEmpty) {
            String newText = currentText.substring(0, cursor) + prefixToAdd + currentText.substring(cursor);
            int newCursor = cursor + prefixToAdd.length;
            _previousText = newText;
            _textController.value = TextEditingValue(
              text: newText,
              selection: TextSelection.collapsed(offset: newCursor),
            );
            return;
          }
        }
      }
    }

    _previousText = currentText;
  }

  @override
  void dispose() {
    _textController.removeListener(_handleTextChanged);
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
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
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
        color: _getModeColor(context).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _getModeColor(context).withValues(alpha: 0.3),
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
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              onSubmitted: _isComposing ? _handleSubmitted : null,
              contextMenuBuilder: (BuildContext context, EditableTextState editableTextState) {
                final List<ContextMenuButtonItem> buttonItems = editableTextState.contextMenuButtonItems;

                void addFormatting(String prefix, String suffix) {
                  final textEditingValue = editableTextState.textEditingValue;
                  final selection = textEditingValue.selection;
                  if (!selection.isValid || selection.isCollapsed) return;

                  final text = textEditingValue.text;
                  final selectedText = selection.textInside(text);
                  final newText = text.replaceRange(selection.start, selection.end, '$prefix$selectedText$suffix');

                  editableTextState.userUpdateTextEditingValue(
                    TextEditingValue(
                      text: newText,
                      selection: TextSelection.collapsed(
                          offset: selection.start + prefix.length + selectedText.length + suffix.length),
                    ),
                    null,
                  );
                }

                buttonItems.addAll([
                  ContextMenuButtonItem(
                    label: 'Bold',
                    onPressed: () {
                      ContextMenuController.removeAny();
                      addFormatting('*', '*');
                    },
                  ),
                  ContextMenuButtonItem(
                    label: 'Italic',
                    onPressed: () {
                      ContextMenuController.removeAny();
                      addFormatting('_', '_');
                    },
                  ),
                  ContextMenuButtonItem(
                    label: 'Strike',
                    onPressed: () {
                      ContextMenuController.removeAny();
                      addFormatting('--', '--');
                    },
                  ),
                  ContextMenuButtonItem(
                    label: 'Mono',
                    onPressed: () {
                      ContextMenuController.removeAny();
                      addFormatting('``', '``');
                    },
                  ),
                ]);

                return AdaptiveTextSelectionToolbar.buttonItems(
                  anchors: editableTextState.contextMenuAnchors,
                  buttonItems: buttonItems,
                );
              },
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
            : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        onPressed: canSend ? () => _handleSubmitted(_textController.text) : null,
        icon: SvgIcons.sized(
          SvgIcons.sendMessage,
          24,
          color: canSend 
              ? Colors.white
              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  /// Handle message submission
  void _handleSubmitted(String text) {
    if (text.trim().isEmpty || !widget.isEnabled) return;
    
    widget.onSendMessage(text.trim());
    _textController.clear();
    _previousText = '';
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
    if (!widget.isEnabled) return Theme.of(context).colorScheme.outline;
    
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
    if (!widget.isEnabled) return 'Connecting...';
    
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
    if (!widget.isEnabled) return 'Connecting...';
    
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
            color: _getModeColor(context).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _getModeColor(context).withValues(alpha: 0.3),
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
    if (!isEnabled) return Theme.of(context).colorScheme.outline;
    
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

  String _incrementRoman(String s) {
    final romanMap = {'i': 1, 'v': 5, 'x': 10, 'l': 50, 'c': 100, 'd': 500, 'm': 1000};
    int total = 0, prev = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      int current = romanMap[s[i].toLowerCase()] ?? 0;
      if (current >= prev) {
        total += current;
      } else {
        total -= current;
      }
      prev = current;
    }
    
    if (total == 0) return s;
    
    int num = total + 1;
    final values = [1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1];
    final symbols = ['m', 'cm', 'd', 'cd', 'c', 'xc', 'l', 'xl', 'x', 'ix', 'v', 'iv', 'i'];
    String result = '';
    for (int i = 0; i < values.length; i++) {
      while (num >= values[i]) {
        num -= values[i];
        result += symbols[i];
      }
    }
    return s.isNotEmpty && s[0] == s[0].toUpperCase() ? result.toUpperCase() : result;
  }

  String _incrementAlpha(String s) {
    int code = s.codeUnitAt(0);
    if (code == 122) return 'a'; // z -> a
    if (code == 90) return 'A'; // Z -> A
    return String.fromCharCode(code + 1);
  }
}