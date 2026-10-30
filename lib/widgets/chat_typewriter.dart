import 'dart:async';

import 'package:flutter/material.dart';

import 'chat_rich_text.dart';

/// Reveals an AI answer a few characters at a time, like a typing effect.
///
/// The full text is always in the chat's state; this only changes how much of
/// it is drawn. Setting [skip] to true shows everything at once, and reduced
/// motion starts already finished. [onDone] runs once, when the full answer
/// is on screen. [onProgress] runs after each step, so the caller can keep
/// the newest text in view.
class ChatTypewriter extends StatefulWidget {
  const ChatTypewriter({
    super.key,
    required this.text,
    required this.color,
    required this.onDone,
    this.skip = false,
    this.onProgress,
  });

  final String text;
  final Color color;
  final VoidCallback onDone;
  final bool skip;
  final VoidCallback? onProgress;

  @override
  State<ChatTypewriter> createState() => _ChatTypewriterState();
}

class _ChatTypewriterState extends State<ChatTypewriter> {
  static const _tick = Duration(milliseconds: 30);

  // About this many ticks for a typical answer, so long ones speed up.
  static const _targetTicks = 90;

  Timer? _timer;
  int _shown = 0;
  bool _started = false;
  bool _done = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _shown = widget.text.length;
      _done = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onDone());
    } else {
      _timer = Timer.periodic(_tick, (_) => _advance());
    }
  }

  @override
  void didUpdateWidget(ChatTypewriter oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Finish after this build: finishing now would change the parent's state
    // in the middle of its own rebuild.
    if (widget.skip && !oldWidget.skip && !_done) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_done) _finish();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _advance() {
    final text = widget.text;
    final step = (text.length / _targetTicks).ceil().clamp(1, 1 << 20);
    var next = (_shown + step).clamp(0, text.length);
    // Never stop between the two halves of an emoji.
    if (next < text.length && _isLowSurrogate(text.codeUnitAt(next))) {
      next++;
    }
    setState(() => _shown = next);
    if (_shown >= text.length) {
      _finish();
    } else {
      widget.onProgress?.call();
    }
  }

  void _finish() {
    _timer?.cancel();
    _timer = null;
    setState(() => _shown = widget.text.length);
    if (_done) return;
    _done = true;
    widget.onDone();
  }

  static bool _isLowSurrogate(int unit) => unit >= 0xDC00 && unit <= 0xDFFF;

  @override
  Widget build(BuildContext context) {
    return ChatRichText(
      text: widget.text.substring(0, _shown),
      color: widget.color,
    );
  }
}
