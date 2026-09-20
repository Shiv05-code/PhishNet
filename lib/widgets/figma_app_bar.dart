import 'package:flutter/material.dart';
import '../screens/app_colors.dart';
import 'figma_gradient_background.dart';

class FigmaAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showBackButton;

  const FigmaAppBar({
    super.key,
    required this.title,
    this.showBackButton = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: showBackButton
          ? IconButton(
              tooltip: 'Back',
              icon: const SizedBox(
                width: 26,
                height: 26,
                child: CustomPaint(painter: _BackArrowPainter()),
              ),
              onPressed: () => Navigator.of(context).pop(),
            )
          : Builder(
              builder: (context) => IconButton(
                tooltip: 'Open menu',
                icon: const SizedBox(
                  width: 46,
                  height: 38,
                  child: CustomPaint(painter: _MenuPainter()),
                ),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
      flexibleSpace: const FigmaGradientBackground(child: SizedBox.expand()),
      title: Align(
        alignment: Alignment.centerRight,
        child: Text(
          title,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
            shadows: [
              Shadow(
                color: Color(0x40000000),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
      ),
      centerTitle: false,
    );
  }
}

class _MenuPainter extends CustomPainter {
  const _MenuPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final shadowPaint = Paint()
      ..color = const Color(0x30000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    final paint = Paint()
      ..color = AppColors.primaryBlue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    for (final y in [6.0, 19.0, 32.0]) {
        canvas.drawLine(
          Offset(3, y + 2),
          Offset(size.width - 2, y + 2),
          shadowPaint,
        );
        canvas.drawLine(
          Offset(3, y),
          Offset(size.width - 2, y),
          paint,
        );
      }
  }

  @override
  bool shouldRepaint(covariant _MenuPainter oldDelegate) => false;
}

class _BackArrowPainter extends CustomPainter {
  const _BackArrowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primaryBlue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(size.width * 0.38, size.height * 0.5)
      ..lineTo(size.width * 0.68, size.height * 0.2)
      ..moveTo(size.width * 0.38, size.height * 0.5)
      ..lineTo(size.width * 0.68, size.height * 0.8)
      ..moveTo(size.width * 0.38, size.height * 0.5)
      ..lineTo(size.width * 0.86, size.height * 0.5);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _BackArrowPainter oldDelegate) => false;
}
