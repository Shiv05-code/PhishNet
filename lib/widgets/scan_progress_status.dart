import 'dart:async';

import 'package:flutter/material.dart';

import '../screens/app_colors.dart';
import '../theme/app_typography.dart';
import 'swimming_fish.dart';

/// Reassuring status shown while a message is being checked.
///
/// The phrases are not backend milestones. A soft highlight sweeps left to
/// right across the current phrase, which then fades out for the next one.
/// The timer and animation live only as long as this widget is in the tree,
/// so removing it on success, failure, or disposal stops both.
class ScanProgressStatus extends StatefulWidget {
  const ScanProgressStatus({super.key});

  static const phrases = [
    'Reviewing your message…',
    'Looking for warning signs…',
    'Checking for urgent language…',
    'Scanning links and senders…',
    'Comparing against known scams…',
    'Weighing the risk…',
    'Preparing your results…',
  ];

  @override
  State<ScanProgressStatus> createState() => _ScanProgressStatusState();
}

/// Fish and a short label shown while a photo's text is being read.
class ReadingImageStatus extends StatelessWidget {
  const ReadingImageStatus({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Reading text from image',
      child: ExcludeSemantics(
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwimmingFish(size: 104),
            SizedBox(height: 8),
            Text(
              'Reading text from image…',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'SFProText',
                fontSize: AppTypography.emphasis,
                fontWeight: FontWeight.w500,
                color: AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanProgressStatusState extends State<ScanProgressStatus>
    with SingleTickerProviderStateMixin {
  static const _phraseInterval = Duration(milliseconds: 2400);

  late final AnimationController _sweep;
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _sweep = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _timer = Timer.periodic(_phraseInterval, (_) {
      setState(() {
        _index = (_index + 1) % ScanProgressStatus.phrases.length;
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Respect reduced motion by holding the highlight still.
    if (MediaQuery.disableAnimationsOf(context)) {
      _sweep.stop();
    } else if (!_sweep.isAnimating) {
      _sweep.repeat();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const baseColor = AppColors.muted;
    final phrase = ScanProgressStatus.phrases[_index];

    return Semantics(
      label: 'Checking message',
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SwimmingFish(size: 104),
            const SizedBox(height: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: AnimatedBuilder(
                key: ValueKey(_index),
                animation: _sweep,
                builder: (context, child) {
                  // The highlight band moves from off-screen left to right.
                  final t = _sweep.value;
                  return ShaderMask(
                    blendMode: BlendMode.srcIn,
                    shaderCallback: (bounds) => LinearGradient(
                      begin: Alignment(-1.5 + 3 * t, 0),
                      end: Alignment(-0.5 + 3 * t, 0),
                      colors: const [
                        baseColor,
                        AppColors.primaryBlue,
                        baseColor,
                      ],
                    ).createShader(bounds),
                    child: child,
                  );
                },
                child: Text(
                  phrase,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'SFProText',
                    fontSize: AppTypography.emphasis,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
