import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phishnet_app/widgets/auth_widgets.dart';
import '../models/scan_result.dart';
import '../widgets/app_drawer.dart';
import '../widgets/figma_app_bar.dart';
import '../widgets/figma_gradient_background.dart';
import '../theme/app_typography.dart';
import 'app_colors.dart';
import 'family_social_screen.dart';
import 'ai_chat_screen.dart';
import '../services/chat_service.dart';

class ResultsScreen extends StatefulWidget {
  final bool isGuest;
  final String message;
  final ScanResult? result;

  const ResultsScreen({
    super.key,
    this.isGuest = false,
    this.message = '',
    this.result,
  });

  static const _sample = ScanResult(
    riskLevel: 'high',
    summary:
        'PhishNet found several red flags in this message. Be very careful.',
    redFlags: [
      'Uses urgent words to pressure you into taking action.',
      'The link goes to a domain known for phishing.',
    ],
    redFlagLabels: ['Urgent Language', 'Suspicious Link'],
    redFlagIcons: ['schedule', 'link'],
    nextSteps: ['Do not click any links or reply to this message.'],
  );

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen>
    with SingleTickerProviderStateMixin {
  // One controller drives every reveal. Each section uses its own interval,
  // so the sections stagger without extra timers and never replay on rebuild.
  late final AnimationController _controller;
  late final Animation<double> _headline;
  late final Animation<double> _summaryText;
  late final Animation<double> _riskLabel;
  late final Animation<double> _score;
  late final Animation<double> _guidance;
  late final Animation<double> _stepsText;
  late final Animation<double> _buttons;
  late final Animation<double> _flags;
  bool _hapticFired = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..forward();
    _controller.addListener(_hapticWhenScored);
    _headline = _interval(0.0, 0.2);
    _summaryText = _interval(0.1, 0.45, curve: Curves.linear);
    _riskLabel = _interval(0.4, 0.6);
    _score = _interval(0.1, 0.6);
    _guidance = _interval(0.42, 0.6);
    _stepsText = _interval(0.5, 0.9, curve: Curves.linear);
    _buttons = _interval(0.7, 0.85);
    _flags = _interval(0.85, 1.0);
  }

  Animation<double> _interval(
    double begin,
    double end, {
    Curve curve = Curves.easeOutCubic,
  }) {
    return CurvedAnimation(
      parent: _controller,
      curve: Interval(begin, end, curve: curve),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Respect reduced motion by showing the final state immediately.
    if (MediaQuery.disableAnimationsOf(context)) _controller.value = 1;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  ScanResult get _r => widget.result ?? ResultsScreen._sample;

  /// Opens AI Chat about this scan. Only a real scan is handed to Chat, not
  /// the sample shown before one exists.
  void _openChat() {
    final result = widget.result;
    final message = widget.message.trim();
    final scan = result == null || message.isEmpty
        ? null
        : ChatScanContext(
            message: message,
            assessment: {
              'risk_level': result.riskLevel,
              'scam_percentage': result.scamPercentage,
              'summary': result.summary,
              'red_flags': [
                for (var i = 0; i < result.redFlags.length; i++)
                  {
                    'label': i < result.redFlagLabels.length
                        ? result.redFlagLabels[i]
                        : '',
                    'description': result.redFlags[i],
                  },
              ],
              'next_steps': result.nextSteps,
            },
          );
    Navigator.of(context).push(fadeRoute(AiChatScreen(scan: scan)));
  }

  /// A light haptic once the score has finished filling, scaled to risk.
  void _hapticWhenScored() {
    if (_hapticFired || _controller.value < 0.6) return;
    _hapticFired = true;
    switch (_r.riskLevel) {
      case 'high':
        HapticFeedback.mediumImpact();
      case 'medium':
        HapticFeedback.lightImpact();
      default:
        HapticFeedback.selectionClick();
    }
  }

  /// Tapping the summary or guidance finishes the reveal straight away.
  void _skipReveal() {
    if (_controller.isCompleted) return;
    _controller.animateTo(1, duration: const Duration(milliseconds: 300));
  }

  IconData _iconFor(String name) => switch (name) {
    'payments' => Icons.payments_outlined,
    'lock' => Icons.lock_outline,
    'person' => Icons.person_outline,
    'schedule' => Icons.schedule,
    'link' => Icons.link,
    'person_search' => Icons.person_search,
    'currency_exchange' => Icons.currency_exchange,
    'attaach_file' => Icons.attach_file,
    'compare_arrows' => Icons.compare_arrows,
    _ => Icons.error_outline,
  };

  List<({String title, String details, IconData icon})> _flagViews() {
    return [
      for (var i = 0; i < _r.redFlags.length; i++)
        (
          title: (i < _r.redFlagLabels.length && _r.redFlagLabels[i].isNotEmpty)
              ? _r.redFlagLabels[i]
              : 'Warning sign ${i + 1}',
          details: _r.redFlags[i],
          icon: _iconFor(i < _r.redFlagIcons.length ? _r.redFlagIcons[i] : ''),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final String headline;
    final String riskLabel;
    final Color riskColor;
    final IconData riskIcon;
    switch (_r.riskLevel) {
      case 'high':
        headline = 'This looks like a phishing attempt';
        riskLabel = 'High Risk';
        riskColor = const Color(0xFFD64545);
        riskIcon = Icons.dangerous_outlined;
      case 'medium':
        headline = 'This message may be a scam';
        riskLabel = 'Medium Risk';
        riskColor = const Color(0xFFE08A1E);
        riskIcon = Icons.warning_amber_rounded;
      default:
        headline = 'No strong warning signs found';
        riskLabel = 'Low Risk';
        riskColor = const Color(0xFF2E9E5B);
        riskIcon = Icons.verified_user_outlined;
    }

    final flags = _flagViews();

    return Scaffold(
      appBar: const FigmaAppBar(title: 'Results'),
      drawer: AppDrawer(currentPage: 'Results', isGuest: widget.isGuest),
      body: FigmaGradientBackground(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _skipReveal,
              child: _SoftCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Reveal(
                          animation: _headline,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 10, top: 2),
                            child: Icon(riskIcon, size: 30, color: riskColor),
                          ),
                        ),
                        Expanded(
                          child: _Reveal(
                            animation: _headline,
                            child: Text(
                              headline,
                              style: const TextStyle(
                                fontSize: AppTypography.title,
                                color: AppColors.primaryBlue,
                                height: 1.15,
                              ),
                            ),
                          ),
                        ),
                        if (_r.scamPercentage != null ||
                            widget.result == null) ...[
                          const SizedBox(width: 12),
                          _ScoreBadge(
                            score: _r.scamPercentage ?? 0,
                            color: riskColor,
                            progress: _score,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),
                    _TypeWriter(
                      text: _r.summary,
                      progress: _summaryText,
                      style: const TextStyle(
                        fontSize: AppTypography.body,
                        height: 1.35,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _Reveal(
                      animation: _riskLabel,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          riskLabel,
                          style: TextStyle(
                            fontSize: AppTypography.label,
                            fontWeight: FontWeight.w600,
                            color: riskColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _Reveal(
              animation: _buttons,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Still unsure?',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: AppTypography.title,
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(
                            context,
                          ).push(fadeRoute(const FamilySocialScreen())),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 2.0),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.share, size: 26),
                                SizedBox(width: 6),
                                Flexible(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      'Share with Family',
                                      style: TextStyle(
                                        fontSize: AppTypography.emphasis + 2,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Flexible(
                        child: OutlinedButton(
                          onPressed: _openChat,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 2.0),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.chat, size: 26),
                                SizedBox(width: 6),
                                Flexible(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      'Ask PhishNet AI',
                                      style: TextStyle(
                                        fontSize: AppTypography.emphasis + 2,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _Reveal(
              animation: _guidance,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _skipReveal,
                child: _SoftCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        size: 44,
                        color: AppColors.primaryBlue,
                      ),
                      SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'What should you do?',
                              style: TextStyle(
                                fontSize: AppTypography.title,
                                color: AppColors.primaryBlue,
                              ),
                            ),
                            SizedBox(height: 8),
                            for (final step in _r.nextSteps)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: _TypeWriter(
                                  text: step,
                                  progress: _stepsText,
                                  style: const TextStyle(
                                    fontSize: AppTypography.body,
                                    height: 1.35,
                                    color: AppColors.text,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _Reveal(
              animation: _flags,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _r.riskLevel == 'low'
                        ? 'What we checked'
                        : 'Why this might be a scam',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: AppTypography.title,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (flags.isEmpty)
                    const Text(
                      'We did not find strong warning signs. Still, only click '
                      'links or share information if you trust the sender.',
                      style: TextStyle(
                        fontSize: AppTypography.body,
                        color: AppColors.text,
                      ),
                    )
                  else
                    for (final f in flags)
                      _RedFlagTile(
                        title: f.title,
                        details: f.details,
                        icon: f.icon,
                      ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SoftCard extends StatelessWidget {
  const _SoftCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xD9FDFCF9),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x300B718E),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _Reveal extends StatelessWidget {
  const _Reveal({required this.animation, required this.child});
  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }
}

/// Types [text] out as [progress] runs from 0 to 1. The full text is exposed
/// to assistive technology so screen readers never hear a partial sentence.
class _TypeWriter extends StatelessWidget {
  const _TypeWriter({
    required this.text,
    required this.style,
    required this.progress,
  });
  final String text;
  final TextStyle style;
  final Animation<double> progress;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: text,
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: progress,
          builder: (context, _) => Text(
            text.substring(0, (text.length * progress.value).round()),
            style: style,
          ),
        ),
      ),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({
    required this.score,
    required this.color,
    required this.progress,
  });
  final int score;
  final Color color;
  final Animation<double> progress;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Risk score $score out of 100',
      child: ExcludeSemantics(
        child: SizedBox(
          width: 86,
          height: 86,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: progress,
                builder: (context, _) => CustomPaint(
                  size: const Size.square(86),
                  painter: _ScoreRingPainter(
                    fraction: score.clamp(0, 100) / 100 * progress.value,
                    color: color,
                  ),
                ),
              ),
              // Scales the score down inside the ring at large text sizes.
              Padding(
                padding: const EdgeInsets.all(12),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '$score/100',
                    style: TextStyle(
                      fontSize: AppTypography.body,
                      fontWeight: FontWeight.w600,
                      color: color,
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

class _ScoreRingPainter extends CustomPainter {
  _ScoreRingPainter({required this.fraction, required this.color});
  final double fraction;
  final Color color;

  static const _strokeWidth = 7.0;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(_strokeWidth / 2);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth
      ..color = color.withValues(alpha: 0.2);
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(rect, 0, 2 * pi, false, track);
    if (fraction > 0) {
      canvas.drawArc(rect, -pi / 2, 2 * pi * fraction, false, arc);
    }
  }

  @override
  bool shouldRepaint(_ScoreRingPainter oldDelegate) {
    return oldDelegate.fraction != fraction || oldDelegate.color != color;
  }
}

class _RedFlagTile extends StatelessWidget {
  const _RedFlagTile({
    required this.title,
    required this.details,
    required this.icon,
  });

  final String title;
  final String details;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xD9FDFCF9),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x300B718E),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        leading: Icon(icon, size: 28, color: AppColors.primaryBlue),
        iconColor: AppColors.primaryBlue,
        collapsedIconColor: AppColors.primaryBlue,
        title: Text(
          title,
          style: const TextStyle(
            fontSize: AppTypography.emphasis,
            color: AppColors.primaryBlue,
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            details,
            style: const TextStyle(
              fontSize: AppTypography.body,
              height: 1.35,
              color: AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}
