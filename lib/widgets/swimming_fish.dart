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
              painter: _KoiRingPainter(
                progress: _controller.value,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _KoiRingPainter extends CustomPainter {
  final double progress;

  _KoiRingPainter({
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final angle = progress * 2 * pi;
    final orbit = size.width * 0.28;
    _drawWater(canvas, center, orbit, angle);
    final fishPosition = center +
        Offset(cos(angle), sin(angle)) * orbit;
    final tangent = angle + pi / 2;
    _placeFish(
      canvas,
      position: fishPosition,
      rotation: tangent,
      scale: size.width * 0.0024,
      warm: false,
    );
    _placeFish(
      canvas,
      position: center + Offset(cos(angle + pi), sin(angle + pi)) * orbit,
      rotation: tangent + pi,
      scale: size.width * 0.0024,
      warm: true,
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
      swirlPaint.color = const Color(0xFF9CC8D8).withValues(
        alpha: 0.16 * (1 - pulse),
      );
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
    canvas.scale(scale);
    _paintFish(canvas, warm);
    canvas.restore();
  }

  void _paintFish(Canvas canvas, bool warm) {
    final body = Paint()..color = const Color(0xFF67B7D2);
    final bodyLight = Paint()..color = const Color(0xFF9BD2E0);
    final spot = Paint()..color = const Color(0xFF4B9EBD);
    final fin = Paint()..color = const Color(0xFF76BFD3).withValues(alpha: 0.78);
    final darkFin = Paint()..color = const Color(0xFF5AA9C2).withValues(alpha: 0.72);

    final bodyPath = Path()
      ..moveTo(38, 0)
      ..cubicTo(34, -10, 23, -14, 10, -12)
      ..cubicTo(-2, -10, -13, -4, -22, 0)
      ..cubicTo(-13, 4, -2, 10, 10, 12)
      ..cubicTo(23, 14, 34, 10, 38, 0)
      ..close();
    canvas.drawPath(bodyPath, body);

    final tailPath = Path()
      ..moveTo(-17, -2)
      ..cubicTo(-33, -8, -43, -20, -49, -27)
      ..cubicTo(-47, -13, -39, -4, -27, 0)
      ..cubicTo(-39, 4, -47, 13, -49, 27)
      ..cubicTo(-41, 19, -32, 8, -17, 2)
      ..close();
    canvas.drawPath(tailPath, fin);

    final topFin = Path()
      ..moveTo(7, -8)
      ..cubicTo(-2, -19, -13, -22, -20, -18)
      ..cubicTo(-17, -8, -7, -3, 5, -2)
      ..close();
    final bottomFin = Path()
      ..moveTo(7, 8)
      ..cubicTo(-2, 19, -13, 22, -20, 18)
      ..cubicTo(-17, 8, -7, 3, 5, 2)
      ..close();
    canvas.drawPath(topFin, darkFin);
    canvas.drawPath(bottomFin, darkFin);

    canvas.drawOval(
      Rect.fromCenter(center: const Offset(28, -1), width: 17, height: 12),
      bodyLight,
    );
    canvas.drawCircle(const Offset(20, -7), 6, spot);
    canvas.drawCircle(const Offset(7, 5), 7, spot);
    canvas.drawCircle(const Offset(-6, -4), 5, spot);
    canvas.drawCircle(const Offset(35, -3), 1.8, spot);
  }

  @override
  bool shouldRepaint(covariant _KoiRingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}