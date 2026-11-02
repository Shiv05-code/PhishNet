import 'dart:async';

import 'package:flutter/material.dart';

import '../screens/app_colors.dart';
import '../theme/app_typography.dart';
import 'swimming_fish.dart';

/// Status shown while PhishNet prepares an answer: the swimming fish from the
/// splash and Capture screens, with a short phrase that changes beside it.
///
/// The phrases are not backend milestones. The fish respects reduced motion
/// on its own; the phrase fades, or changes instantly under reduced motion.
/// It sits on the left like an AI reply, so it reads as part of the chat.
class ChatThinking extends StatefulWidget {
  const ChatThinking({super.key});

  static const phrases = [
    'Reading your question…',
    'Checking for warning signs…',
    'Looking at the details…',
    'Putting together a clear answer…',
  ];

  @override
  State<ChatThinking> createState() => _ChatThinkingState();
}

class _ChatThinkingState extends State<ChatThinking> {
  static const _phraseInterval = Duration(milliseconds: 2400);

  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_phraseInterval, (_) {
      setState(() {
        _index = (_index + 1) % ChatThinking.phrases.length;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      liveRegion: true,
      label: 'PhishNet is preparing an answer',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              const SwimmingFish(size: 48),
              const SizedBox(width: 10),
              Expanded(
                child: AnimatedSwitcher(
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 400),
                  child: Text(
                    ChatThinking.phrases[_index],
                    key: ValueKey(_index),
                    style: const TextStyle(
                      fontFamily: 'SFProText',
                      fontSize: AppTypography.label,
                      fontWeight: FontWeight.w500,
                      color: AppColors.muted,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
