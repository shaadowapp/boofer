import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'markdown_text_editing_controller.dart';

class ModernChatInput extends StatefulWidget {
  final Function(String) onSendMessage;
  final VoidCallback? onTypingStarted;
  final VoidCallback? onTypingStopped;
  final VoidCallback? onAttachmentPressed;
  final bool autofocus;
  final String? initialText;
  final bool hideWarning;

  const ModernChatInput({
    super.key,
    required this.onSendMessage,
    this.onTypingStarted,
    this.onTypingStopped,
    this.onAttachmentPressed,
    this.autofocus = false,
    this.initialText,
    this.hideWarning = false,
  });

  @override
  State<ModernChatInput> createState() => _ModernChatInputState();
}

class _ModernChatInputState extends State<ModernChatInput>
    with SingleTickerProviderStateMixin {
  final TextEditingController _textController = MarkdownTextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool _isComposing = false;
  bool _showEmojiPicker = false;
  late AnimationController _emojiController;
  late Animation<double> _emojiAnimation;
  String _previousText = '';

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
      _previousText = widget.initialText!;
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
    final currentText = _textController.text;
    if (currentText == _previousText) return;

    final isComposing = currentText.trim().isNotEmpty;
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
    _previousText = '';
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
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Chat Input Box (Expanded to fill space)
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color:
                            Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // 1. Emoji Button (Left)
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                        icon: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          transitionBuilder: (child, anim) =>
                              ScaleTransition(scale: anim, child: child),
                          child: Icon(
                            _showEmojiPicker
                                ? Icons.keyboard
                                : Icons.emoji_emotions_outlined,
                            key: ValueKey(_showEmojiPicker),
                            size: 24,
                            color: _showEmojiPicker
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface
                                    .withValues(alpha: 0.6),
                          ),
                        ),
                        onPressed: _toggleEmojiPicker,
                      ),

                      // 2. Input Field (Transparent, no border) - Takes remaining space
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
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.4),
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

                      // 3. Attachment Button (Right)
                      if (widget.onAttachmentPressed != null)
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: widget.onAttachmentPressed,
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary
                                    .withValues(alpha: 0.08),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.attach_file_rounded,
                                size: 24,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // 4. Modern Send Button (Outside the box) - Only takes space when composing
              if (_isComposing)
                AnimatedScale(
                  scale: _isComposing ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutBack,
                  child: AnimatedOpacity(
                    opacity: _isComposing ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: InkWell(
                        onTap: _isComposing ? _handleSend : null,
                        borderRadius: BorderRadius.circular(32),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: theme.colorScheme.primary
                                    .withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.send_rounded,
                            size: 24,
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
        if (!widget.hideWarning &&
            MediaQuery.viewInsetsOf(context).bottom <= 0 &&
            !_showEmojiPicker &&
            !_focusNode.hasFocus)
          Padding(
            padding: const EdgeInsets.only(bottom: 6, top: 0),
            child: Text(
              'Be careful of fake profiles and fraud. Stay safe.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
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
                  iconColor: theme.colorScheme.onSurface.withValues(alpha: 0.5),
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
