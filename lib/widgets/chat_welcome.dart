import 'dart:async';

import 'package:flutter/material.dart';
import '../screens/app_colors.dart';
import '../theme/app_typography.dart';

/// Set once the greeting has played, so it only types out on the first visit
/// in this app session. Kept in memory on purpose: no extra storage needed.
bool _introPlayed = false;

/// Empty-state welcome for AI Chat: a greeting that types itself out once,
/// a hero icon, and tappable starter questions that fill the input bar.
class ChatWelcome extends StatefulWidget {
  const ChatWelcome({super.key, required this.hasScan, required this.onPick});

  /// True when Chat was opened from a scan result.
  final bool hasScan;

  /// Called with the starter question the user tapped.
  final ValueChanged<String> onPick;

  @override
  State<ChatWelcome> createState() => _ChatWelcomeState();
}

class _ChatWelcomeState extends State<ChatWelcome>
    with SingleTickerProviderStateMixin {
  static const _typeSpeed = Duration(milliseconds: 40);

  late final AnimationController _heroIn = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );
  Timer? _typer;
  int _typed = 0;
  bool _showChips = false;

  String get _greeting => widget.hasScan
      ? 'Ask me about this message.'
      : "Hi! I'm PhishNet.\nWhat would you like to check?";

  List<_Starter> get _starters => widget.hasScan
      ? const [
          _Starter(
            label: 'Is it safe to click?',
            question: 'Is it safe to click this?',
            icon: Icons.link,
          ),
          _Starter(
            label: 'What should I do now?',
            question: 'What should I do now that I received this message?',
            icon: Icons.help_outline,
          ),
        ]
      : const [
          _Starter(
            label: 'I clicked a link',
            question: 'What should I do if I already clicked a link?',
            icon: Icons.link,
          ),
          _Starter(
            label: 'Is this text message safe?',
            question: 'Is this text message safe?',
            icon: Icons.help_outline,
          ),
          _Starter(
            label: 'Someone asked for my password',
            question: 'Someone asked me for my password. Is that a scam?',
            icon: Icons.lock_outline,
          ),
        ];

  // Started here rather than in initState, because MediaQuery is needed to
  // check the reduce-motion setting.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_typer != null || _showChips) return;
    if (_introPlayed || MediaQuery.disableAnimationsOf(context)) {
      _finishIntro();
      return;
    }
    _heroIn.forward();
    _typer = Timer.periodic(_typeSpeed, (timer) {
      if (_typed >= _greeting.length) {
        _finishIntro();
      } else {
        setState(() => _typed++);
      }
    });
  }

  /// Shows the full greeting and chips. Also used when the user taps to skip.
  void _finishIntro() {
    _typer?.cancel();
    _introPlayed = true;
    if (!_heroIn.isCompleted) _heroIn.value = 1;
    if (!mounted) return;
    setState(() {
      _typed = _greeting.length;
      _showChips = true;
    });
  }

  @override
  void dispose() {
    _typer?.cancel();
    _heroIn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visible = _greeting.substring(0, _typed);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: FadeTransition(
                opacity: _heroIn,
                child: ScaleTransition(
                  scale: Tween(begin: 0.8, end: 1.0).animate(
                    CurvedAnimation(parent: _heroIn, curve: Curves.easeOutBack),
                  ),
                  child: const _Hero(),
                ),
              ),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _showChips ? null : _finishIntro,
              child: Semantics(
                label: _greeting,
                child: ExcludeSemantics(
                  child: Text(
                    visible,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: AppTypography.heading,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                      color: AppColors.text,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            AnimatedOpacity(
              opacity: _showChips ? 1 : 0,
              duration: const Duration(milliseconds: 400),
              child: IgnorePointer(
                ignoring: !_showChips,
                child: Column(
                  children: [
                    for (final starter in _starters)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _StarterChip(
                          starter: starter,
                          onTap: () => widget.onPick(starter.question),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Starter {
  const _Starter({
    required this.label,
    required this.question,
    required this.icon,
  });
  final String label;
  final String question;
  final IconData icon;
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.shield_outlined,
        size: 60,
        color: AppColors.primaryBlue,
      ),
    );
  }
}

class _StarterChip extends StatelessWidget {
  const _StarterChip({required this.starter, required this.onTap});
  final _Starter starter;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cardSurface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 60),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.fieldFill, width: 1.5),
          ),
          child: Row(
            children: [
              Icon(starter.icon, color: AppColors.primaryBlue, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  starter.label,
                  style: const TextStyle(
                    fontSize: AppTypography.title,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
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
