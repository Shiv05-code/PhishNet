import 'package:flutter/material.dart';

import '../theme/app_typography.dart';

/// Shows an AI answer with light structure: `## headings`, `- bullets` and
/// `**bold**`. Anything else is a plain paragraph, so unformatted text still
/// reads the same as before.
///
/// Kept small on purpose: the answers only need these three things, so no
/// Markdown package is required.
class ChatRichText extends StatelessWidget {
  const ChatRichText({super.key, required this.text, required this.color});

  final String text;
  final Color color;

  static final _bullet = RegExp(r'^[-*•]\s+(.*)$');
  static final _heading = RegExp(r'^#{1,3}\s+(.*)$');

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (final raw in text.split('\n')) {
      final line = raw.trimRight();
      final trimmed = line.trimLeft();
      if (trimmed.isEmpty) {
        // A blank line becomes a small gap between blocks.
        if (children.isNotEmpty) children.add(const SizedBox(height: 8));
        continue;
      }
      final heading = _heading.firstMatch(trimmed);
      final bullet = _bullet.firstMatch(trimmed);
      if (heading != null) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 2),
            child: _inline(
              heading.group(1)!,
              TextStyle(
                fontSize: AppTypography.emphasis,
                fontWeight: FontWeight.w700,
                color: color,
                height: 1.3,
              ),
            ),
          ),
        );
      } else if (bullet != null) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4, right: 10),
                  child: Text(
                    '•',
                    style: TextStyle(
                      fontSize: AppTypography.body,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
                Expanded(child: _inline(bullet.group(1)!, _body())),
              ],
            ),
          ),
        );
      } else {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: _inline(line, _body()),
          ),
        );
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  TextStyle _body() =>
      TextStyle(fontSize: AppTypography.body, height: 1.4, color: color);

  /// Turns `**bold**` into bold spans; everything else keeps [style].
  Widget _inline(String source, TextStyle style) {
    final spans = <TextSpan>[];
    var index = 0;
    for (final match in RegExp(r'\*\*(.+?)\*\*').allMatches(source)) {
      if (match.start > index) {
        spans.add(TextSpan(text: source.substring(index, match.start)));
      }
      spans.add(
        TextSpan(
          text: match.group(1),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      );
      index = match.end;
    }
    if (index < source.length) {
      spans.add(TextSpan(text: source.substring(index)));
    }
    return Text.rich(TextSpan(style: style, children: spans));
  }
}
