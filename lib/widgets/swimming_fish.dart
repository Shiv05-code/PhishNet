import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Loading animation: a circular "whirlpool" with two fish (bird's-eye
/// view) swimming around it, plus rising bubbles. Fully custom-painted —
/// no external animation files or emoji font dependency.
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
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _SwirlPainter(t: _controller.value),
          );
        },
      ),
    );
  }
}

class _SwirlPainter extends CustomPainter {
  final double t; // 0.0 -> 1.0, looping

  _SwirlPainter({required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final swirlAngle = t * 2 * pi;

    // Soft water-circle backdrop.
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = AppColors.highlight.withOpacity(0.35),
    );

    // Rotating current rings.
    final ringPaint = Paint()
      ..color = AppColors.primary.withOpacity(0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 3; i++) {
      final ringRadius = radius * (0.35 + i * 0.22);
      final startAngle = swirlAngle * (i.isEven ? 1 : -1) + i;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: ringRadius),
        startAngle,
        pi * 1.1,
        false,
        ringPaint,
      );
    }

    // Rising bubbles.
    final rnd = Random(7); // fixed seed so bubble positions don't jitter randomly
    for (int i = 0; i < 6; i++) {
      final phase = (t + i / 6) % 1.0;
      final bx = center.dx + (radius * 0.55) * sin(i * 1.7 + rnd.nextDouble());
      final by = size.height - phase * size.height * 0.9;
      final bubbleRadius = 2.5 + (i % 3);
      canvas.drawCircle(
        Offset(bx, by),
        bubbleRadius,
        Paint()..color = AppColors.white.withOpacity((1 - phase).clamp(0.0, 1.0)),
      );
    }

    // Two fish, orbiting 180 degrees apart, each facing its swim direction.
    _drawFish(canvas, center, radius * 0.55, swirlAngle);
    _drawFish(canvas, center, radius * 0.55, swirlAngle + pi);
  }

  void _drawFish(Canvas canvas, Offset center, double orbitRadius, double angle) {
    final pos = Offset(
      center.dx + orbitRadius * cos(angle),
      center.dy + orbitRadius * sin(angle),
    );
    final travelDirection = angle + pi / 2; // tangent to the circle

    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(travelDirection);

    final bodyPaint = Paint()..color = AppColors.primary;
    final tailPaint = Paint()..color = AppColors.primary.withOpacity(0.8);

    // Body — simple bird's-eye teardrop.
    final body = Path()
      ..moveTo(12, 0)
      ..quadraticBezierTo(6, 7, -9, 4)
      ..quadraticBezierTo(-4, 0, -9, -4)
      ..quadraticBezierTo(6, -7, 12, 0)
      ..close();
    canvas.drawPath(body, bodyPaint);

    // Tail fin.
    final tail = Path()
      ..moveTo(-9, 0)
      ..lineTo(-16, 6)
      ..lineTo(-16, -6)
      ..close();
    canvas.drawPath(tail, tailPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SwirlPainter oldDelegate) => oldDelegate.t != t;
}
