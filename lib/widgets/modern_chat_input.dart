import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ModernChatInput extends StatefulWidget {
  final Function(String) onSendMessage;
  final VoidCallback? onTypingStarted;
  final VoidCallback? onTypingStopped;
  final bool autofocus;

  const ModernChatInput({
    super.key,
    required this.onSendMessage,
    this.onTypingStarted,
    this.onTypingStopped,
    this.autofocus = false,
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
    _emojiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _emojiAnimation = CurvedAnimation(
      parent: _emojiController,
      curve: Curves.easeOutBack,
    );
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
          margin: const EdgeInsets.fromLTRB(
            16,
            8,
            16,
            16,
          ), // Docked to bottom, standard padding
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: Colors.transparent, width: 0),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Emoji Button
                    IconButton(
                      icon: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        transitionBuilder: (child, anim) =>
                            ScaleTransition(scale: anim, child: child),
                        child: Icon(
                          _showEmojiPicker
                              ? Icons.keyboard
                              : Icons.emoji_emotions_outlined,
                          key: ValueKey(_showEmojiPicker),
                          color: _showEmojiPicker
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                      onPressed: _toggleEmojiPicker,
                    ),

                    // Input Field
                    Expanded(
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 120),
                        child: TextField(
                          controller: _textController,
                          focusNode: _focusNode,
                          autofocus: widget.autofocus,
                          textCapitalization: TextCapitalization.sentences,
                          keyboardType: TextInputType.multiline,
                          maxLines: null,
                          style: theme.textTheme.bodyLarge,
                          decoration: InputDecoration(
                            hintText: 'Type a message...',
                            hintStyle: TextStyle(
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.4,
                              ),
                            ),
                            border: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 14,
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
                    ),

                    // Send Button
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(bottom: 4, right: 4),
                      decoration: BoxDecoration(
                        color: _isComposing
                            ? theme.colorScheme.primary
                            : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.arrow_upward_rounded,
                          size: 28,
                          color: _isComposing
                              ? theme.colorScheme.onPrimary
                              : theme.colorScheme.onSurface.withOpacity(0.3),
                        ),
                        onPressed: _isComposing ? _handleSend : null,
                      ),
                    ),
                  ],
                ),
              ),

              // Emoji Picker Area
              SizeTransition(
                sizeFactor: _emojiAnimation,
                axisAlignment: -1.0,
                child: Container(
                  height: 250,
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: theme.colorScheme.outline.withOpacity(0.1),
                      ),
                    ),
                  ),
                  child: EmojiPicker(
                    onEmojiSelected: (category, emoji) {
                      HapticFeedback.lightImpact();
                      _onEmojiSelected(emoji.emoji);
                    },
                    config: Config(
                      height: 256,
                      checkPlatformCompatibility: true,
                      emojiViewConfig: EmojiViewConfig(
                        emojiSizeMax: 28,
                        columns: 7,
                        verticalSpacing: 0,
                        horizontalSpacing: 0,
                        gridPadding: EdgeInsets.zero,
                        recentsLimit: 28,
                        replaceEmojiOnLimitExceed: false,
                        noRecents: const Text(
                          'No Recents',
                          style: TextStyle(fontSize: 20, color: Colors.black26),
                          textAlign: TextAlign.center,
                        ),
                        backgroundColor: theme.colorScheme.surface,
                        buttonMode: ButtonMode.MATERIAL,
                      ),
                      skinToneConfig: SkinToneConfig(
                        dialogBackgroundColor: theme.colorScheme.surface,
                        indicatorColor: theme.colorScheme.onSurface,
                        enabled: true,
                      ),
                      categoryViewConfig: CategoryViewConfig(
                        initCategory: Category.SMILEYS,
                        backgroundColor: theme.colorScheme.surface,
                        indicatorColor: theme.colorScheme.primary,
                        iconColor: theme.colorScheme.onSurface.withOpacity(0.5),
                        iconColorSelected: theme.colorScheme.primary,
                        backspaceColor: theme.colorScheme.primary,
                        tabIndicatorAnimDuration: kTabScrollDuration,
                        categoryIcons: const CategoryIcons(),
                      ),
                      bottomActionBarConfig: const BottomActionBarConfig(
                        enabled: false,
                      ),
                      searchViewConfig: const SearchViewConfig(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
