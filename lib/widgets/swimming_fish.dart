import 'dart:math';
import 'package:flutter/material.dart';
import '../screens/app_colors.dart';

/// Animated koi-ring loading indicator reproducing the exact vector illustration.
///
/// Features two koi whose bodies are mathematically drawn along concentric arcs
/// to align precisely with their circular swim track. Water ripple lines appear
/// exclusively during the active clockwise rotation phase and fade out during
/// the seesaw pause.
class SwimmingFish extends StatefulWidget {
  final double size;

  const SwimmingFish({super.key, this.size = 220});

  @override
  State<SwimmingFish> createState() => _SwimmingFishState();
}

class _SwimmingFishState extends State<SwimmingFish>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  // Rotation phase is 72% of the full duration (clockwise sweep).
  // The remaining 28% handles the brief pause and counter-clockwise seesaw wobble.
  static const double _rotationPhase = 0.72;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _angleFor(double t) {
    const twoPi = 2 * pi;
    if (t < _rotationPhase) {
      // Phase 1: Eased 360-degree clockwise spin
      final p = t / _rotationPhase;
      final eased = Curves.easeInOutSine.transform(p);
      return eased * twoPi;
    } else {
      // Phase 2: Halt and brief counter-clockwise seesaw wobble
      final p = (t - _rotationPhase) / (1 - _rotationPhase);
      final wobble = sin(p * pi) * -0.22;
      return twoPi + wobble;
    }
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value;
            final isMovingClockwise = t < _rotationPhase;
            // Progressive progress factor (0.0 to 1.0) during active swimming
            final swimProgress = isMovingClockwise ? (t / _rotationPhase) : 0.0;

            return CustomPaint(
              painter: _KoiRingPainter(
                angle: _angleFor(t),
                isMovingClockwise: isMovingClockwise,
                swimProgress: swimProgress,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _KoiRingPainter extends CustomPainter {
  final double angle;
  final bool isMovingClockwise;
  final double swimProgress;

  _KoiRingPainter({
    required this.angle,
    required this.isMovingClockwise,
    required this.swimProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final placementRadius = size.width * 0.32;
    final fishScale = size.width * 0.0022;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);

    // Render active water ripple wake ONLY when fish are rotating clockwise
    if (isMovingClockwise) {
      _drawDynamicWaterWake(canvas, placementRadius);
    }

    // Fish 1: Top-Left quadrant (facing tangential clockwise)
    _placeFish(canvas, positionDeg: -135, placementRadius: placementRadius, scale: fishScale);

    // Fish 2: Bottom-Right quadrant (facing tangential clockwise)
    _placeFish(canvas, positionDeg: 45, placementRadius: placementRadius, scale: fishScale);

    canvas.restore();
  }

  void _placeFish(
    Canvas canvas, {
    required double positionDeg,
    required double placementRadius,
    required double scale,
  }) {
    final posRad = positionDeg * pi / 180;
    final pos = Offset(cos(posRad), sin(posRad)) * placementRadius;
    final facingRad = (positionDeg + 90) * pi / 180;

    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(facingRad);
    canvas.scale(scale);
    _paintKoiShape(canvas);
    canvas.restore();
  }

  void _drawDynamicWaterWake(Canvas canvas, double radius) {
    // Fades water in at start of movement and gently fades out as rotation completes
    final double fadeAlpha = sin(swimProgress * pi);

    final wakeArcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..color = AppColors.lightCyan.withValues(alpha: 0.28 * fadeAlpha);

    // Concentric inner/outer water motion tracks trailing behind the swimming fish
    canvas.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: radius * 0.96),
      -pi * 0.8,
      pi * 0.5,
      false,
      wakeArcPaint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: radius * 1.04),
      pi * 0.2,
      pi * 0.5,
      false,
      wakeArcPaint,
    );

    // Swirling water particle bubbles trailing along the swim arc
    final particlePaint = Paint()..style = PaintingStyle.fill;
    final List<double> particleAngles = [-pi * 0.85, -pi * 0.65, -pi * 0.45, pi * 0.15, pi * 0.35, pi * 0.55];

    for (int i = 0; i < particleAngles.length; i++) {
      final a = particleAngles[i];
      final offsetRadius = radius + ((i % 2 == 0 ? 1 : -1) * 4.0);
      final p = Offset(cos(a) * offsetRadius, sin(a) * offsetRadius);
      
      particlePaint.color = AppColors.lightCyan.withValues(alpha: (0.35 - (i % 3) * 0.08) * fadeAlpha);
      canvas.drawCircle(p, i % 2 == 0 ? 1.4 : 2.0, particlePaint);
    }
  }

  /// Recreates the vector koi silhouette from the reference image.
  /// Coordinates are mapped with head pointing toward +x (east) and tail curving
  /// along -x (west) and +y (south), aligning with the circular track.
  void _paintKoiShape(Canvas canvas) {
    // Exact color palette matched to reference vector
    final bodyBase = const Color(0xFF132B3E).withValues(alpha: 0.95);
    final headCapColor = const Color(0xFF5A819D).withValues(alpha: 0.70);
    final spotPrimary = const Color(0xFF1B628A).withValues(alpha: 0.75);
    final spotSecondary = const Color(0xFF2275A1).withValues(alpha: 0.60);
    final finPrimary = const Color(0xFF154B6E).withValues(alpha: 0.55);
    final finSecondary = const Color(0xFF276D97).withValues(alpha: 0.40);
    final eyeColor = const Color(0xFF7FE2FF).withValues(alpha: 0.95);
    final mouthColor = const Color(0xFF091622).withValues(alpha: 0.85);

    // --- 1. PECTORAL FINS ---
    // Smooth outer fin curves extending symmetrically from the forward torso
    final topPectoral = Path()
      ..moveTo(16, -8)
      ..cubicTo(24, -24, 6, -28, -2, -14)
      ..quadraticBezierTo(7, -10, 16, -8)
      ..close();

    final bottomPectoral = Path()
      ..moveTo(12, 8)
      ..cubicTo(20, 24, 2, 28, -6, 14)
      ..quadraticBezierTo(3, 10, 12, 8)
      ..close();

    canvas.drawPath(topPectoral, Paint()..color = finPrimary);
    canvas.drawPath(bottomPectoral, Paint()..color = finPrimary);

    // --- 2. BIFURCATED FLOWING TAIL ---
    // Upper flame-like trailing tendril
    final upperTailTendril = Path()
      ..moveTo(-32, -2)
      ..cubicTo(-44, -12, -56, -24, -68, -38)
      ..cubicTo(-62, -20, -50, -10, -38, -2)
      ..close();

    // Main lower flowing tail ribbon with inner serrations matching reference image
    final mainTailRibbon = Path()
      ..moveTo(-32, 2)
      ..cubicTo(-42, 10, -50, 24, -58, 40)
      ..cubicTo(-54, 28, -48, 22, -44, 18)
      ..cubicTo(-50, 26, -58, 38, -66, 52)
      ..cubicTo(-58, 34, -46, 18, -34, 4)
      ..close();

    // Translucent mid-tail accent overlay
    final tailOverlay = Path()
      ..moveTo(-30, 0)
      ..cubicTo(-40, 6, -48, 18, -54, 12)
      ..cubicTo(-48, 4, -38, -2, -30, 0)
      ..close();

    canvas.drawPath(upperTailTendril, Paint()..color = finPrimary);
    canvas.drawPath(mainTailRibbon, Paint()..color = finPrimary);
    canvas.drawPath(tailOverlay, Paint()..color = finSecondary);

    // --- 3. CURVED MAIN BODY ---
    // Body silhouette arched continuously along the circular swimming track
    final body = Path()
      ..moveTo(38, -1) // Rounded snout tip
      ..cubicTo(32, -14, 14, -15, -8, -10) // Outer spine arc
      ..cubicTo(-22, -6, -30, -1, -34, 2) // Narrowing tail stem
      ..cubicTo(-28, 5, -18, 8, -6, 8) // Inner belly arc
      ..cubicTo(10, 8, 28, 11, 38, -1) // Head transition
      ..close();

    canvas.drawPath(body, Paint()..color = bodyBase);

    // --- 4. HEAD CAP & SPOTS ---
    // Translucent grey-blue head cap patch
    final headCap = Path()
      ..moveTo(38, -1)
      ..quadraticBezierTo(32, -11, 20, -7)
      ..quadraticBezierTo(15, 0, 20, 6)
      ..quadraticBezierTo(30, 9, 38, -1)
      ..close();
    canvas.drawPath(headCap, Paint()..color = headCapColor);

    // Layered circular spot patterns over back & body
    canvas.drawCircle(const Offset(8, -2), 10.5, Paint()..color = spotPrimary);
    canvas.drawCircle(const Offset(-8, -1), 7.0, Paint()..color = spotSecondary);
    canvas.drawCircle(const Offset(22, -1), 4.5, Paint()..color = spotPrimary);

    // --- 5. HEAD DETAILS ---
    // Dark mouth cap at front snout
    canvas.drawCircle(const Offset(37, -1), 2.0, Paint()..color = mouthColor);

    // Outer bright cyan eyes
    canvas.drawCircle(const Offset(27, -8), 1.6, Paint()..color = eyeColor);
    canvas.drawCircle(const Offset(27, 7), 1.6, Paint()..color = eyeColor);
  }

  @override
  bool shouldRepaint(covariant _KoiRingPainter oldDelegate) {
    return oldDelegate.angle != angle ||
        oldDelegate.isMovingClockwise != isMovingClockwise ||
        oldDelegate.swimProgress != swimProgress;
  }
}