import 'dart:math';
import 'package:flutter/material.dart';

/// Animated splash fish based on the curved fish frames in the Figma Assets board.
class SwimmingFish extends StatefulWidget {
  final double size;

  const SwimmingFish({super.key, this.size = 220});

  @override
  State<SwimmingFish> createState() => _SwimmingFishState();
}

class _SwimmingFishState extends State<SwimmingFish>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
            return CustomPaint(
              painter: _KoiRingPainter(progress: _controller.value),
            );
          },
        ),
      ),
    );
  }
}

class _KoiRingPainter extends CustomPainter {
  final double progress;

  _KoiRingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    // Start on the same diagonal composition as the reference loading ring:
    // one koi in the upper-left arc and the other in the lower-right arc.
    final angle = progress * 2 * pi - (3 * pi / 4);
    // Keep the fish close enough for each head to follow the other fish's
    // trailing tail while maintaining one shared circular path.
    final orbit = size.width * 0.235;
    _drawWater(canvas, center, orbit, angle);
    final radiusVector = Offset(cos(angle), sin(angle));
    final fishPosition = center + radiusVector * orbit;
    // In Flutter's coordinate system, increasing the angle moves clockwise.
    // Rotate each head along the circle's clockwise tangent.
    final clockwiseTangent = angle + pi / 2;
    _placeFish(
      canvas,
      position: fishPosition,
      rotation: clockwiseTangent,
      scale: size.width * 0.0024,
      warm: true,
    );
    _placeFish(
      canvas,
      position: center - radiusVector * orbit,
      rotation: clockwiseTangent + pi,
      scale: size.width * 0.0024,
      warm: false,
    );
  }

  void _drawWater(Canvas canvas, Offset center, double radius, double phase) {
    final swirlPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.15;

    for (var i = 0; i < 3; i++) {
      final pulse = (phase + i * 0.33) % 1;
      final rippleRadius = radius * (0.64 + pulse * 0.42);
      swirlPaint.color = const Color(
        0xFF9CC8D8,
      ).withValues(alpha: 0.16 * (1 - pulse));
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: rippleRadius),
        phase * 2 * pi - 1.1,
        pi * 1.35,
        false,
        swirlPaint,
      );
    }

    swirlPaint.color = const Color(0xFFB6D9E2).withValues(alpha: 0.24);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.82),
      -0.8,
      pi * 0.7,
      false,
      swirlPaint,
    );
  }

  void _placeFish(
    Canvas canvas, {
    required Offset position,
    required double rotation,
    required double scale,
    required bool warm,
  }) {
    canvas.save();
    canvas.translate(position.dx, position.dy);
    canvas.rotate(rotation);
    canvas.scale(scale, -scale);
    // The path origin is at the body-to-tail junction. Offset each fish back
    // along its heading so the body centers, rather than the tail junctions,
    // are the points mirrored around the loading circle.
    canvas.translate(-24, 0);
    _paintFish(canvas, warm);
    canvas.restore();
  }

  void _paintFish(Canvas canvas, bool warm) {
    final body = Paint()
      ..color = warm ? const Color(0xFF82C5D8) : const Color(0xFF67B7D2);
    final bodyLight = Paint()..color = const Color(0xFF9BD2E0);
    final spot = Paint()..color = const Color(0xFF4B9EBD);
    final fin = Paint()
      ..color = const Color(0xFF76BFD3).withValues(alpha: 0.78);
    final darkFin = Paint()
      ..color = const Color(0xFF5AA9C2).withValues(alpha: 0.72);

    final bodyPath = Path()
      ..moveTo(40, 0)
      ..cubicTo(36, -12, 24, -17, 9, -15)
      ..cubicTo(-6, -13, -17, -6, -20, 2)
      ..cubicTo(-16, 11, -4, 16, 11, 17)
      ..cubicTo(26, 17, 38, 11, 40, 0)
      ..close();
    canvas.drawPath(bodyPath, body);

    final tailPath = Path()
      ..moveTo(-16, -4)
      ..cubicTo(-34, -7, -52, -20, -63, -40)
      ..cubicTo(-75, -62, -74, -90, -60, -114)
      ..cubicTo(-67, -86, -60, -65, -48, -49)
      ..cubicTo(-36, -33, -21, -19, -3, -8)
      ..close();
    canvas.drawPath(tailPath, fin);

    final tailFork = Path()
      ..moveTo(-43, -51)
      ..cubicTo(-54, -65, -56, -83, -49, -101)
      ..cubicTo(-46, -82, -38, -66, -29, -57)
      ..cubicTo(-34, -54, -39, -52, -43, -51)
      ..close();
    canvas.drawPath(tailFork, darkFin);

    final topFin = Path()
      ..moveTo(8, -11)
      ..cubicTo(2, -24, -9, -29, -18, -24)
      ..cubicTo(-15, -14, -7, -8, 5, -5)
      ..close();
    final bottomFin = Path()
      ..moveTo(8, 11)
      ..cubicTo(2, 24, -9, 29, -18, 24)
      ..cubicTo(-15, 14, -7, 8, 5, 5)
      ..close();
    canvas.drawPath(topFin, darkFin);
    canvas.drawPath(bottomFin, darkFin);

    canvas.drawOval(
      Rect.fromCenter(center: const Offset(28, -2), width: 18, height: 13),
      bodyLight,
    );
    canvas.drawCircle(const Offset(19, -8), 8, spot);
    canvas.drawCircle(const Offset(5, 6), 9, spot);
    canvas.drawCircle(const Offset(-8, -4), 6, spot);

    final eye = Paint()..color = const Color(0xFF2C84A8);
    final eyeHighlight = Paint()..color = const Color(0xFFBCE5ED);
    canvas.drawCircle(const Offset(32, -7), 2.4, eye);
    canvas.drawCircle(const Offset(32.7, -7.7), 0.7, eyeHighlight);
  }

  @override
  bool shouldRepaint(covariant _KoiRingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
