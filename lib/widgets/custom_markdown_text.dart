/// custom_markdown_text.dart
///
/// A self-contained rich-text renderer for in-app message styling.
///
/// Supported syntax
/// ─────────────────────────────────────────────────────────────────────
///  INLINE
///    Bold           *text*
///    Italic         _text_
///    Strikethrough  --text--
///    Monospace      ``text``   (disables inner parsing)
///    Inline Code    `text`     (disables inner parsing)
///    Heart symbol   <3         → tilted ♥ glyph (WidgetSpan)
///
///  BLOCK  (detected at the very start of each line)
///    UL bullet      * text     →  •  text
///    UL arrow       - text     →  →  text
///    UL star        + text     →  ★  text
///    UL square      [] text    →  ▪  text
///    OL numeric     1. / 1)    →  1.  text
///    OL roman       i. / i)    →  i.  text
///    OL alpha       a. / a)    →  a.  text
///    Blockquote     !%text%    →  ▌  text  (tinted bg + left border)
///
///  ESCAPE
///    \* \_ \` \- \+ \! \% \\ → literal character
/// ─────────────────────────────────────────────────────────────────────

import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

// ════════════════════════════════════════════════════════════════════════════
//  PUBLIC WIDGET
// ════════════════════════════════════════════════════════════════════════════

class CustomMarkdownText extends StatelessWidget {
  const CustomMarkdownText({
    super.key,
    required this.text,
    required this.isOwnMessage,
    required this.baseStyle,
    this.onUrlTap,
    this.onHandleTap,
    this.codeBackground,
    this.blockquoteBarColor,
    this.blockquoteBackground,
  });

  /// Raw message string (possibly multi-line).
  final String text;

  /// Determines colour for inherited elements (e.g. bubble contrast).
  final bool isOwnMessage;

  /// Base [TextStyle] from which all derived styles inherit.
  final TextStyle baseStyle;

  /// Optional callbacks — forwarded from the bubble layer.
  final void Function(String url)? onUrlTap;
  final void Function(String handle)? onHandleTap;

  /// Overrideable colours.
  final Color? codeBackground;
  final Color? blockquoteBarColor;
  final Color? blockquoteBackground;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = _Palette(
      text: baseStyle.color ?? theme.colorScheme.onSurface,
      primary: theme.colorScheme.primary,
      codeBackground:
          codeBackground ?? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
      blockquoteBar: blockquoteBarColor ??
          (isOwnMessage
              ? Colors.white.withValues(alpha: 0.6)
              : theme.colorScheme.primary.withValues(alpha: 0.7)),
      blockquoteBg: blockquoteBackground ??
          (isOwnMessage
              ? Colors.white.withValues(alpha: 0.08)
              : theme.colorScheme.primary.withValues(alpha: 0.06)),
    );

    final parser = _MdParser();
    final lines = parser.parseLines(text);

    return _LineRenderer(
      lines: lines,
      baseStyle: baseStyle,
      palette: palette,
      isOwnMessage: isOwnMessage,
      onUrlTap: onUrlTap,
      onHandleTap: onHandleTap,
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  COLOUR PALETTE  (internal)
// ════════════════════════════════════════════════════════════════════════════

class _Palette {
  const _Palette({
    required this.text,
    required this.primary,
    required this.codeBackground,
    required this.blockquoteBar,
    required this.blockquoteBg,
  });
  final Color text;
  final Color primary;
  final Color codeBackground;
  final Color blockquoteBar;
  final Color blockquoteBg;
}

// ════════════════════════════════════════════════════════════════════════════
//  ENUMS & DATA MODELS
// ════════════════════════════════════════════════════════════════════════════

enum _BlockType {
  plain,
  ulBullet, // * text  →  •
  ulArrow, //  - text  →  →
  ulStar, //   + text  →  ★
  ulSquare, // [] text  →  ▪
  olNumDot, // 1. text
  olNumPar, // 1) text
  olRomDot, // i. text
  olRomPar, // i) text
  olAlpDot, // a. text
  olAlpPar, // a) text
  blockquote, // !%text%
  emptyLine, // blank line (preserved as spacing)
}

class _LineNode {
  const _LineNode({
    required this.type,
    required this.content,
    this.listLabel,
  });

  final _BlockType type;
  final String content; // stripped of block-marker
  final String? listLabel; // e.g. "1.", "iii)", "c."
}

// ════════════════════════════════════════════════════════════════════════════
//  PASS 1 — LINE PARSER
// ════════════════════════════════════════════════════════════════════════════

class _MdParser {
  // ── Block patterns ──────────────────────────────────────────────────────
  // NOTE: UL bullet must be checked LAST among UL because '*' can also start
  //       a bold marker — the block pass only matches at column 0.

  static final _reUlBullet = RegExp(r'^\s*\* +(.+)');
  static final _reUlArrow = RegExp(r'^\s*- +(.+)');
  static final _reUlStar = RegExp(r'^\s*\+ +(.+)');
  static final _reUlSquare = RegExp(r'^\s*\[\] +(.+)');

  static final _reOlNumDot = RegExp(r'^\s*(\d+)(?:\. |  +)(.+)');
  static final _reOlNumPar = RegExp(r'^\s*(\d+)\) +(.+)');
  // Roman: only pure sequences of i/v/x/l/c/d/m (case-insensitive, ≥1 char)
  static final _reOlRomDot = RegExp(r'^\s*([ivxlcdmIVXLCDM]+)\. +(.+)');
  static final _reOlRomPar = RegExp(r'^\s*([ivxlcdmIVXLCDM]+)\) +(.+)');
  // Alpha: exactly ONE letter to avoid collisions with roman
  static final _reOlAlpDot = RegExp(r'^\s*([a-zA-Z])\. +(.+)');
  static final _reOlAlpPar = RegExp(r'^\s*([a-zA-Z])\) +(.+)');

  static final _reBlockquote = RegExp(r'^!%(.+?)%$');

  List<_LineNode> parseLines(String raw) {
    final nodes = <_LineNode>[];
    for (final line in raw.split('\n')) {
      nodes.add(_parseLine(line));
    }
    return nodes;
  }

  _LineNode _parseLine(String line) {
    if (line.trim().isEmpty) {
      return const _LineNode(type: _BlockType.emptyLine, content: '');
    }

    // ── Blockquote ────────────────────────────────────────────────────────
    final bq = _reBlockquote.firstMatch(line);
    if (bq != null) {
      return _LineNode(type: _BlockType.blockquote, content: bq.group(1)!);
    }

    // ── Ordered lists (check BEFORE UL so "1. " beats "* ") ──────────────
    RegExpMatch? m;

    m = _reOlNumDot.firstMatch(line);
    if (m != null) {
      return _LineNode(type: _BlockType.olNumDot, content: m.group(2)!, listLabel: '${m.group(1)}.');
    }
    m = _reOlNumPar.firstMatch(line);
    if (m != null) {
      return _LineNode(type: _BlockType.olNumPar, content: m.group(2)!, listLabel: '${m.group(1)})');
    }
    m = _reOlRomDot.firstMatch(line);
    if (m != null) {
      return _LineNode(type: _BlockType.olRomDot, content: m.group(2)!, listLabel: '${m.group(1)}.');
    }
    m = _reOlRomPar.firstMatch(line);
    if (m != null) {
      return _LineNode(type: _BlockType.olRomPar, content: m.group(2)!, listLabel: '${m.group(1)})');
    }
    m = _reOlAlpDot.firstMatch(line);
    if (m != null) {
      return _LineNode(type: _BlockType.olAlpDot, content: m.group(2)!, listLabel: '${m.group(1)}.');
    }
    m = _reOlAlpPar.firstMatch(line);
    if (m != null) {
      return _LineNode(type: _BlockType.olAlpPar, content: m.group(2)!, listLabel: '${m.group(1)})');
    }

    // ── Unordered lists ───────────────────────────────────────────────────
    m = _reUlSquare.firstMatch(line);
    if (m != null) return _LineNode(type: _BlockType.ulSquare, content: m.group(1)!);

    m = _reUlArrow.firstMatch(line);
    if (m != null) return _LineNode(type: _BlockType.ulArrow, content: m.group(1)!);

    m = _reUlStar.firstMatch(line);
    if (m != null) return _LineNode(type: _BlockType.ulStar, content: m.group(1)!);

    m = _reUlBullet.firstMatch(line);
    if (m != null) return _LineNode(type: _BlockType.ulBullet, content: m.group(1)!);

    return _LineNode(type: _BlockType.plain, content: line);
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  PASS 2 — INLINE SPAN BUILDER
// ════════════════════════════════════════════════════════════════════════════

/// Private-use Unicode sentinels used to temporarily replace escaped chars.
const _kEscBase = 0xE000;

class _InlineParser {
  // ── Inline patterns (ordered by priority) ──────────────────────────────
  static final _reMono = RegExp(r'``(.+?)``');
  static final _reCode = RegExp(r'`(.+?)`');
  static final _reHeart = RegExp(r'<3');
  // Strikethrough: double-dash, no leading/trailing space inside
  static final _reStrike = RegExp(r'--(\S.*?\S|[^\s])--');
  static final _reBold = RegExp(r'\*(.+?)\*');
  static final _reItalic = RegExp(r'_(.+?)_');
  // URLs & handles (forwarded to parent)
  static final _reUrl = RegExp(r'((https?://|www\.)[^\s]+)', caseSensitive: false);
  static final _reHandle = RegExp(r'(?<!\w)@[a-zA-Z0-9_.]+', caseSensitive: false);
  static final _reEscape = RegExp(r'\\([*_`\\\-+\[\]!%])');

  List<InlineSpan> buildSpans({
    required String text,
    required TextStyle base,
    required _Palette palette,
    required bool isOwnMessage,
    void Function(String)? onUrlTap,
    void Function(String)? onHandleTap,
  }) {
    // ── Step 1: Encode escape sequences ──────────────────────────────────
    final encoded = _encodeEscapes(text);

    // ── Step 2: Claim locked intervals (mono, code) ───────────────────────
    final locked = <_Interval>[];
    final lockedSpans = <_LockedSpan>[];

    for (final m in _reMono.allMatches(encoded)) {
      locked.add(_Interval(m.start, m.end));
      lockedSpans.add(_LockedSpan(
        start: m.start,
        end: m.end,
        text: _decodeEscapes(m.group(1)!),
        isMono: true,
      ));
    }
    for (final m in _reCode.allMatches(encoded)) {
      if (_isLocked(m.start, m.end, locked)) continue;
      locked.add(_Interval(m.start, m.end));
      lockedSpans.add(_LockedSpan(
        start: m.start,
        end: m.end,
        text: _decodeEscapes(m.group(1)!),
        isMono: false,
      ));
    }

    // Sort locked spans by position for the split pass below.
    lockedSpans.sort((a, b) => a.start.compareTo(b.start));

    // ── Step 3: Split remaining text into unlocked segments ───────────────
    final spans = <InlineSpan>[];
    int cursor = 0;

    for (final ls in lockedSpans) {
      if (ls.start > cursor) {
        // Process the gap between cursor and this locked span
        _processUnlocked(
          encoded.substring(cursor, ls.start),
          base,
          palette,
          isOwnMessage,
          offset: cursor,
          locked: locked,
          spans: spans,
          onUrlTap: onUrlTap,
          onHandleTap: onHandleTap,
        );
      }
      // Add the locked span
      final codeBg = palette.codeBackground;
      final codeStyle = base.copyWith(
        fontFamily: 'monospace',
        backgroundColor: codeBg,
        fontSize: ls.isMono ? base.fontSize : (base.fontSize ?? 14) * 0.92,
        color: base.color,
        fontWeight: ls.isMono ? FontWeight.w500 : FontWeight.normal,
      );
      spans.add(TextSpan(text: ls.text, style: codeStyle));
      cursor = ls.end;
    }

    // Process remainder
    if (cursor < encoded.length) {
      _processUnlocked(
        encoded.substring(cursor),
        base,
        palette,
        isOwnMessage,
        offset: cursor,
        locked: locked,
        spans: spans,
        onUrlTap: onUrlTap,
        onHandleTap: onHandleTap,
      );
    }

    return spans;
  }

  // ── Unlocked segment processor ────────────────────────────────────────
  void _processUnlocked(
    String segment,
    TextStyle base,
    _Palette palette,
    bool isOwnMessage, {
    required int offset,
    required List<_Interval> locked,
    required List<InlineSpan> spans,
    void Function(String)? onUrlTap,
    void Function(String)? onHandleTap,
  }) {
    // Build an ordered list of all inline matches + URLs + handles in `segment`
    final items = <_MatchItem>[];

    void addMatches(RegExp re, _MatchKind kind) {
      for (final m in re.allMatches(segment)) {
        if (!_isLocked(offset + m.start, offset + m.end, locked)) {
          items.add(_MatchItem(m.start, m.end, kind, m));
        }
      }
    }

    addMatches(_reHeart, _MatchKind.heart);
    addMatches(_reStrike, _MatchKind.strike);
    addMatches(_reBold, _MatchKind.bold);
    addMatches(_reItalic, _MatchKind.italic);
    addMatches(_reUrl, _MatchKind.url);
    addMatches(_reHandle, _MatchKind.handle);

    // Sort by start position; on tie prefer longer match
    items.sort((a, b) {
      final cmp = a.start.compareTo(b.start);
      if (cmp != 0) return cmp;
      return b.end.compareTo(a.end); // broader first
    });

    // Remove overlapping matches (first-found wins)
    final nonOverlap = <_MatchItem>[];
    for (final item in items) {
      if (nonOverlap.isEmpty || item.start >= nonOverlap.last.end) {
        nonOverlap.add(item);
      }
    }

    int cur = 0;
    for (final item in nonOverlap) {
      if (item.start < cur) continue; // sanity guard
      if (item.start > cur) {
        // Plain text gap
        spans.add(TextSpan(
          text: _decodeEscapes(segment.substring(cur, item.start)),
          style: base,
        ));
      }
      _emitMatchItem(item, segment, base, palette, isOwnMessage, spans, onUrlTap, onHandleTap);
      cur = item.end;
    }

    if (cur < segment.length) {
      final remaining = _decodeEscapes(segment.substring(cur));
      if (remaining.isNotEmpty) {
        spans.add(TextSpan(text: remaining, style: base));
      }
    }
  }

  void _emitMatchItem(
    _MatchItem item,
    String segment,
    TextStyle base,
    _Palette palette,
    bool isOwnMessage,
    List<InlineSpan> spans,
    void Function(String)? onUrlTap,
    void Function(String)? onHandleTap,
  ) {
    switch (item.kind) {
      case _MatchKind.heart:
        // Tilted ♥ — rendered as a WidgetSpan so we can rotate it.
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Transform.rotate(
            angle: -math.pi / 12, // ~15° counter-clockwise tilt
            child: Text(
              '♥',
              style: TextStyle(
                fontSize: (base.fontSize ?? 14) * 1.15,
                color: isOwnMessage
                    ? Colors.white.withValues(alpha: 0.95)
                    : const Color(0xFFE53935),
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ),
        ));

      case _MatchKind.strike:
        final inner = item.match.group(1)!;
        final innerSpans = _buildSimpleInline(
          inner,
          base.copyWith(
            decoration: TextDecoration.lineThrough,
            decorationColor: base.color,
            decorationThickness: 1.5,
          ),
          palette,
          isOwnMessage,
        );
        spans.addAll(innerSpans);

      case _MatchKind.bold:
        final inner = item.match.group(1)!;
        // Recurse so bold can contain italic, etc.
        final innerSpans = _buildSimpleInline(inner, base.copyWith(fontWeight: FontWeight.bold), palette, isOwnMessage);
        spans.addAll(innerSpans);

      case _MatchKind.italic:
        final inner = item.match.group(1)!;
        final innerSpans = _buildSimpleInline(inner, base.copyWith(fontStyle: FontStyle.italic), palette, isOwnMessage);
        spans.addAll(innerSpans);

      case _MatchKind.url:
        String matchText = item.match.group(0)!;
        // Trim trailing punctuation
        final punctRe = RegExp(r'[.,?!:;"]+$');
        String trail = '';
        final trimmed = matchText.replaceFirstMapped(punctRe, (m) {
          trail = m.group(0)!;
          return '';
        });
        final url = trimmed.startsWith('http') ? trimmed : 'https://$trimmed';
        spans.add(TextSpan(
          text: trimmed,
          style: base.copyWith(
            decoration: TextDecoration.underline,
            decorationColor: base.color?.withValues(alpha: 0.6),
          ),
          recognizer: TapGestureRecognizer()..onTap = () => onUrlTap?.call(url),
        ));
        if (trail.isNotEmpty) {
          spans.add(TextSpan(text: trail, style: base));
        }

      case _MatchKind.handle:
        final handle = item.match.group(0)!;
        spans.add(TextSpan(
          text: handle,
          style: base.copyWith(
            fontWeight: FontWeight.bold,
            color: isOwnMessage ? Colors.white : palette.primary,
          ),
          recognizer: TapGestureRecognizer()..onTap = () => onHandleTap?.call(handle),
        ));
    }
  }

  /// Advanced inline parser for nested formatting (bold inside italic inside strike)
  List<InlineSpan> _buildSimpleInline(
    String text,
    TextStyle style,
    _Palette palette,
    bool isOwnMessage,
  ) {
    // To support full nesting, we recursively process the text via _processUnlocked.
    // The `text` here is still encoded.
    final innerSpans = <InlineSpan>[];
    _processUnlocked(
      text,
      style,
      palette,
      isOwnMessage,
      offset: 0,
      locked: const [], // Inner context has no locks by default
      spans: innerSpans,
      // Pass null to prevent double handling of actions within styled blocks if desired
      onUrlTap: null, 
      onHandleTap: null,
    );
    return innerSpans;
  }

  // ── Escape helpers ────────────────────────────────────────────────────
  String _encodeEscapes(String input) {
    return input.replaceAllMapped(_reEscape, (m) {
      final ch = m.group(1)!;
      final code = _kEscBase + ch.codeUnitAt(0);
      return String.fromCharCode(code);
    });
  }

  String _decodeEscapes(String input) {
    final buf = StringBuffer();
    for (final ch in input.runes) {
      if (ch >= _kEscBase && ch < _kEscBase + 0x100) {
        buf.writeCharCode(ch - _kEscBase);
      } else {
        buf.writeCharCode(ch);
      }
    }
    return buf.toString();
  }

  bool _isLocked(int start, int end, List<_Interval> locked) {
    for (final iv in locked) {
      if (start < iv.end && end > iv.start) return true;
    }
    return false;
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  HELPER MODELS
// ════════════════════════════════════════════════════════════════════════════

class _Interval {
  const _Interval(this.start, this.end);
  final int start;
  final int end;
}

class _LockedSpan {
  const _LockedSpan({
    required this.start,
    required this.end,
    required this.text,
    required this.isMono,
  });
  final int start;
  final int end;
  final String text;
  final bool isMono; // true = ``…``, false = `…`
}

enum _MatchKind { heart, strike, bold, italic, url, handle }

class _MatchItem {
  const _MatchItem(this.start, this.end, this.kind, this.match);
  final int start;
  final int end;
  final _MatchKind kind;
  final RegExpMatch match;
}

// ════════════════════════════════════════════════════════════════════════════
//  RENDERER  (converts _LineNode list → widgets)
// ════════════════════════════════════════════════════════════════════════════

class _LineRenderer extends StatelessWidget {
  const _LineRenderer({
    required this.lines,
    required this.baseStyle,
    required this.palette,
    required this.isOwnMessage,
    this.onUrlTap,
    this.onHandleTap,
  });

  final List<_LineNode> lines;
  final TextStyle baseStyle;
  final _Palette palette;
  final bool isOwnMessage;
  final void Function(String)? onUrlTap;
  final void Function(String)? onHandleTap;

  @override
  Widget build(BuildContext context) {
    final parser = _InlineParser();
    final children = <Widget>[];

    for (int i = 0; i < lines.length; i++) {
      final node = lines[i];
      final isLast = i == lines.length - 1;

      if (node.type == _BlockType.emptyLine) {
        if (!isLast) children.add(const SizedBox(height: 4));
        continue;
      }

      final spans = parser.buildSpans(
        text: node.content,
        base: baseStyle,
        palette: palette,
        isOwnMessage: isOwnMessage,
        onUrlTap: onUrlTap,
        onHandleTap: onHandleTap,
      );

      final richText = RichText(
        text: TextSpan(style: baseStyle, children: spans),
      );

      Widget lineWidget;

      switch (node.type) {
        // ── Plain ───────────────────────────────────────────────────────
        case _BlockType.plain:
          lineWidget = richText;

        // ── Blockquote ──────────────────────────────────────────────────
        case _BlockType.blockquote:
          lineWidget = Container(
            margin: const EdgeInsets.symmetric(vertical: 2),
            decoration: BoxDecoration(
              color: palette.blockquoteBg,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(6),
                bottomRight: Radius.circular(6),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 3,
                  constraints: const BoxConstraints(minHeight: 20),
                  decoration: BoxDecoration(
                    color: palette.blockquoteBar,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(2),
                      bottomLeft: Radius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: RichText(
                      text: TextSpan(
                        style: baseStyle.copyWith(
                          fontStyle: FontStyle.italic,
                          color: baseStyle.color?.withValues(alpha: 0.85),
                        ),
                        children: spans,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          );

        // ── Unordered list item ─────────────────────────────────────────
        case _BlockType.ulBullet:
        case _BlockType.ulArrow:
        case _BlockType.ulStar:
        case _BlockType.ulSquare:
          final icon = _ulIcon(node.type, baseStyle);
          lineWidget = _buildListRow(icon: icon, content: richText);

        // ── Ordered list item ───────────────────────────────────────────
        case _BlockType.olNumDot:
        case _BlockType.olNumPar:
        case _BlockType.olRomDot:
        case _BlockType.olRomPar:
        case _BlockType.olAlpDot:
        case _BlockType.olAlpPar:
          final label = node.listLabel ?? '';
          final labelWidget = Text(
            label,
            style: baseStyle.copyWith(fontWeight: FontWeight.w600),
          );
          lineWidget = _buildListRow(icon: labelWidget, content: richText, labelMinWidth: 22);

        case _BlockType.emptyLine:
          lineWidget = const SizedBox.shrink(); // handled above
      }

      children.add(lineWidget);
      if (!isLast && node.type != _BlockType.emptyLine) {
        children.add(const SizedBox(height: 2));
      }
    }

    if (children.isEmpty) return const SizedBox.shrink();
    if (children.length == 1) return children.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  Widget _buildListRow({
    required Widget icon,
    required Widget content,
    double labelMinWidth = 16,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(minWidth: labelMinWidth),
          child: Padding(
            padding: const EdgeInsets.only(top: 1, right: 3),
            child: icon,
          ),
        ),
        Flexible(child: content),
      ],
    );
  }

  Widget _ulIcon(_BlockType type, TextStyle style) {
    final fontSize = (style.fontSize ?? 14);
    final color = style.color;

    switch (type) {
      case _BlockType.ulBullet:
        // •  solid circle
        return Text('•', style: style.copyWith(fontSize: fontSize * 1.4, color: color, height: 1.1));
      case _BlockType.ulArrow:
        // ➔ right arrow
        return Text('➔', style: style.copyWith(fontSize: fontSize * 1.15, color: color, height: 1.2));
      case _BlockType.ulStar:
        // ★  filled star
        return Text('★', style: style.copyWith(fontSize: fontSize * 1.15, color: color, height: 1.2));
      case _BlockType.ulSquare:
        // ■  filled square
        return Text('■', style: style.copyWith(fontSize: fontSize * 1.0, color: color, height: 1.3));
      default:
        return const SizedBox.shrink();
    }
  }
}
