import 'package:flutter/material.dart';
import '../screens/app_colors.dart';
import 'figma_gradient_background.dart';
import '../theme/app_typography.dart';

class FigmaAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final double titleFontSize;
  final bool showBackButton;
  final bool showChatHistoryButton;
  final VoidCallback? onChatHistoryPressed;

  const FigmaAppBar({
    super.key,
    required this.title,
    this.titleFontSize = AppTypography.heading,
    this.showBackButton = false,
    this.showChatHistoryButton = false,
    this.onChatHistoryPressed,
  });

  @override
  Size get preferredSize => Size.fromHeight(showChatHistoryButton ? 112 : 64);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      automaticallyImplyActions: !showChatHistoryButton,
      // Default leading width (56) is narrower than the 53pt icon plus its
      // button padding, which squeezed the menu icon on app bar screens.
      leadingWidth: 72,

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
                  width: 53,
                  height: 44,
                  child: CustomPaint(painter: _MenuPainter()),
                ),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),

      flexibleSpace: FigmaGradientBackground(
        child: showChatHistoryButton && !showBackButton
            ? SafeArea(
                bottom: false,
                child: Align(
                  alignment: Alignment.bottomRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12, bottom: 4),
                    child: IconButton(
                      tooltip: 'Recent Chats',
                      icon: const Icon(
                        Icons.history,
                        size: 32,
                        weight: 700,
                        color: AppColors.primaryBlue,
                      ),
                      onPressed: onChatHistoryPressed,
                    ),
                  ),
                ),
              )
            : const SizedBox.expand(),
      ),
      title: Align(
        alignment: Alignment.centerRight,
        child: Text(
          title,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: titleFontSize,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
            shadows: const [
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
    // Draw in the 46x38 design space and scale uniformly, so the bars keep their
    // spacing and stroke weight when the icon box is enlarged.
    final k = size.height / 38;
    final w = size.width / k;
    canvas.save();
    canvas.scale(k);
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
      canvas.drawLine(Offset(3, y + 2), Offset(w - 2, y + 2), shadowPaint);
      canvas.drawLine(Offset(3, y), Offset(w - 2, y), paint);
    }
    canvas.restore();
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
