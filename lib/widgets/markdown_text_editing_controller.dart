import 'package:flutter/material.dart';

class MarkdownTextEditingController extends TextEditingController {
  MarkdownTextEditingController({super.text});

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final theme = Theme.of(context);
    final baseStyle = style ?? const TextStyle();

    // Highlighting regex pattern
    final pattern = RegExp(
      r'(``.+?``)' '|'          // Mono
      r'(`.+?`)' '|'            // Code
      r'(--\S.*?\S--|--[^\s]--)' '|' // Strike
      r'(\*.+?\*)' '|'          // Bold
      r'(_.+?_)' '|'            // Italic
      r'(^!%.+?%$)' '|'         // Blockquote
      r'(^\s*(?:\*|-|\+|\[\])\s+.*$)' '|' // Unordered List
      r'(^\s*(\d+|[a-zA-Z]|[ivxlcdmIVXLCDM]{2,}|[ivxIVX])[\.\)]\s+.*$)',  // Ordered List
      dotAll: true,
      multiLine: true,
    );

    List<InlineSpan> buildRecursiveSpans(String text, TextStyle currentStyle) {
      List<InlineSpan> spans = [];
      int cursor = 0;

      for (final match in pattern.allMatches(text)) {
        if (match.start > cursor) {
          spans.add(TextSpan(
            text: text.substring(cursor, match.start),
            style: currentStyle,
          ));
        }

        final matchText = match.group(0)!;
        TextStyle matchStyle = currentStyle;

        if (matchText.startsWith('``') && matchText.endsWith('``')) {
          matchStyle = currentStyle.copyWith(
            fontFamily: 'monospace',
            backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
            color: theme.colorScheme.primary,
          );
          spans.add(TextSpan(text: matchText, style: matchStyle));
        } else if (matchText.startsWith('`') && matchText.endsWith('`')) {
          matchStyle = currentStyle.copyWith(
            fontFamily: 'monospace',
            backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
            color: theme.colorScheme.primary,
          );
          spans.add(TextSpan(text: matchText, style: matchStyle));
        } else if (matchText.startsWith('--') && matchText.endsWith('--')) {
          matchStyle = currentStyle.copyWith(decoration: TextDecoration.lineThrough);
          spans.add(TextSpan(
            text: '--',
            style: currentStyle.copyWith(color: currentStyle.color?.withValues(alpha: 0.5)),
          ));
          spans.addAll(buildRecursiveSpans(matchText.substring(2, matchText.length - 2), matchStyle));
          spans.add(TextSpan(
            text: '--',
            style: currentStyle.copyWith(color: currentStyle.color?.withValues(alpha: 0.5)),
          ));
        } else if (matchText.startsWith('*') && matchText.endsWith('*') && matchText.length > 1 && !matchText.startsWith('* ')) {
          matchStyle = currentStyle.copyWith(fontWeight: FontWeight.bold);
          spans.add(TextSpan(
            text: '*',
            style: currentStyle.copyWith(color: currentStyle.color?.withValues(alpha: 0.5)),
          ));
          spans.addAll(buildRecursiveSpans(matchText.substring(1, matchText.length - 1), matchStyle));
          spans.add(TextSpan(
            text: '*',
            style: currentStyle.copyWith(color: currentStyle.color?.withValues(alpha: 0.5)),
          ));
        } else if (matchText.startsWith('_') && matchText.endsWith('_') && matchText.length > 1) {
          matchStyle = currentStyle.copyWith(fontStyle: FontStyle.italic);
          spans.add(TextSpan(
            text: '_',
            style: currentStyle.copyWith(color: currentStyle.color?.withValues(alpha: 0.5)),
          ));
          spans.addAll(buildRecursiveSpans(matchText.substring(1, matchText.length - 1), matchStyle));
          spans.add(TextSpan(
            text: '_',
            style: currentStyle.copyWith(color: currentStyle.color?.withValues(alpha: 0.5)),
          ));
        } else if (matchText.startsWith('!%') && matchText.endsWith('%')) {
          matchStyle = currentStyle.copyWith(
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
            color: theme.colorScheme.onSurface,
          );
          spans.add(TextSpan(
            text: '!%',
            style: currentStyle.copyWith(color: theme.colorScheme.primary),
          ));
          spans.addAll(buildRecursiveSpans(matchText.substring(2, matchText.length - 1), matchStyle));
          spans.add(TextSpan(
            text: '%',
            style: currentStyle.copyWith(color: theme.colorScheme.primary),
          ));
        } else {
          // It's a list item (ordered or unordered)
          
          // Find the separator (space) between the list marker and the content
          final separatorIndex = matchText.indexOf(' ');
          if (separatorIndex != -1) {
            final markerText = matchText.substring(0, separatorIndex + 1);
            final contentText = matchText.substring(separatorIndex + 1);
            
            // Format the list marker distinctly (e.g., primary color)
            spans.add(TextSpan(
              text: markerText,
              style: currentStyle.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ));
            
            // Format the rest of the list item normally (allowing recursive inline styling)
            spans.addAll(buildRecursiveSpans(contentText, currentStyle));
          } else {
            spans.add(TextSpan(text: matchText, style: currentStyle));
          }
        }

        cursor = match.end;
      }

      if (cursor < text.length) {
        spans.add(TextSpan(
          text: text.substring(cursor),
          style: currentStyle,
        ));
      }

      return spans;
    }

    final result = TextSpan(
      style: baseStyle,
      children: buildRecursiveSpans(text, baseStyle),
    );
    
    // Add composing span directly into the style if IME is active
    if (withComposing && value.composing.isValid && !value.composing.isCollapsed) {
       // Standard fallback or just rely on the system applying composing styles internally.
       // Actually returning the custom split recursive spans works natively for styling.
    }
    
    return result;
  }
}
