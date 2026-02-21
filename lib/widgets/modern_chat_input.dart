import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ModernChatInput extends StatefulWidget {
  final Function(String) onSendMessage;
  final VoidCallback? onTypingStarted;
  final VoidCallback? onTypingStopped;
  final bool autofocus;
  final String? initialText;

  const ModernChatInput({
    super.key,
    required this.onSendMessage,
    this.onTypingStarted,
    this.onTypingStopped,
    this.autofocus = false,
    this.initialText,
  });

  @override
  State<ModernChatInput> createState() => _ModernChatInputState();
}

class _ModernChatInputState extends State<ModernChatInput>
    with SingleTickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool _isComposing = false;
  bool _showEmojiPicker = false;
  late AnimationController _emojiController;
  late Animation<double> _emojiAnimation;

  @override
  void initState() {
    super.initState();
    _textController.addListener(_handleTextChanged);
    _focusNode.addListener(() => setState(() {})); // Rebuild on focus change
    _emojiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _emojiAnimation = CurvedAnimation(
      parent: _emojiController,
      curve: Curves.easeOutBack,
    );

    if (widget.initialText != null && widget.initialText!.isNotEmpty) {
      _textController.text = widget.initialText!;
      _isComposing = true;
    }
  }

  @override
  void dispose() {
    _textController.removeListener(_handleTextChanged);
    _textController.dispose();
    _focusNode.dispose();
    _emojiController.dispose();
    super.dispose();
  }

  void _handleTextChanged() {
    final isComposing = _textController.text.trim().isNotEmpty;
    if (isComposing != _isComposing) {
      setState(() {
        _isComposing = isComposing;
      });
      if (isComposing) {
        widget.onTypingStarted?.call();
      } else {
        widget.onTypingStopped?.call();
      }
    }
  }

  void _toggleEmojiPicker() {
    setState(() {
      _showEmojiPicker = !_showEmojiPicker;
      if (_showEmojiPicker) {
        _focusNode.unfocus();
        _emojiController.forward();
      } else {
        _emojiController.reverse();
        _focusNode.requestFocus();
      }
    });
  }

  void _onEmojiSelected(String emoji) {
    final text = _textController.text;
    final selection = _textController.selection;
    final newText = text.replaceRange(selection.start, selection.end, emoji);
    final newSelectionIndex = selection.start + emoji.length;

    _textController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newSelectionIndex),
    );
  }

  void _handleSend() {
    if (_textController.text.trim().isEmpty) return;
    HapticFeedback.lightImpact();
    widget.onSendMessage(_textController.text.trim());
    _textController.clear();
    setState(() {
      _isComposing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // 1. Emoji Button
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: IconButton(
                  icon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, anim) =>
                        ScaleTransition(scale: anim, child: child),
                    child: Icon(
                      _showEmojiPicker
                          ? Icons.keyboard
                          : Icons.emoji_emotions_outlined,
                      key: ValueKey(_showEmojiPicker),
                      size: 26,
                      color: _showEmojiPicker
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  onPressed: _toggleEmojiPicker,
                ),
              ),

              // 2. Input Field (Transparent, no border)
              Expanded(
                child: TextField(
                  controller: _textController,
                  focusNode: _focusNode,
                  autofocus: widget.autofocus,
                  textCapitalization: TextCapitalization.sentences,
                  keyboardType: TextInputType.multiline,
                  maxLines: 6,
                  minLines: 1,
                  style: theme.textTheme.bodyLarge,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(0.4),
                    ),
                    border: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 12,
                    ),
                  ),
                  onTap: () {
                    if (_showEmojiPicker) {
                      setState(() {
                        _showEmojiPicker = false;
                        _emojiController.reverse();
                      });
                    }
                  },
                ),
              ),

              // 3. Modern Send Button
              AnimatedScale(
                scale: _isComposing ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutBack,
                child: AnimatedOpacity(
                  opacity: _isComposing ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 4, right: 4),
                    child: InkWell(
                      onTap: _isComposing ? _handleSend : null,
                      borderRadius: BorderRadius.circular(32),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.send_rounded,
                          size: 20,
                          color: theme.colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Safety warning hidden when keyboard, emoji library, or focus is active
        if (MediaQuery.viewInsetsOf(context).bottom <= 0 &&
            !_showEmojiPicker &&
            !_focusNode.hasFocus)
          Padding(
            padding: const EdgeInsets.only(bottom: 6, top: 0),
            child: Text(
              'Be careful of fake profiles and fraud. Stay safe.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.4),
                fontSize: 10,
              ),
            ),
          ),

        // 3. Emoji Picker Area - Placed at the very bottom
        SizeTransition(
          sizeFactor: _emojiAnimation,
          axisAlignment: -1.0,
          child: Container(
            height: 320, // Increased height for better library view
            color: theme.colorScheme.surface,
            child: EmojiPicker(
              onEmojiSelected: (category, emoji) {
                HapticFeedback.lightImpact();
                _onEmojiSelected(emoji.emoji);
              },
              config: Config(
                height: 320,
                checkPlatformCompatibility: false, // Performance improvement
                emojiViewConfig: EmojiViewConfig(
                  emojiSizeMax: 28,
                  columns: 8, // Wider grid for library feel
                  verticalSpacing: 4,
                  horizontalSpacing: 4,
                  gridPadding: const EdgeInsets.all(8),
                  recentsLimit: 28,
                  backgroundColor: theme.colorScheme.surface,
                  buttonMode: ButtonMode.MATERIAL,
                  loadingIndicator: const Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
                skinToneConfig: SkinToneConfig(
                  dialogBackgroundColor: theme.colorScheme.surface,
                  indicatorColor: theme.colorScheme.onSurface,
                  enabled: true,
                ),
                categoryViewConfig: CategoryViewConfig(
                  backgroundColor: theme.colorScheme.surface,
                  indicatorColor: theme.colorScheme.primary,
                  iconColor: theme.colorScheme.onSurface.withOpacity(0.5),
                  iconColorSelected: theme.colorScheme.primary,
                  backspaceColor: theme.colorScheme.primary,
                  categoryIcons: const CategoryIcons(),
                ),
                bottomActionBarConfig: const BottomActionBarConfig(
                  enabled: false,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
