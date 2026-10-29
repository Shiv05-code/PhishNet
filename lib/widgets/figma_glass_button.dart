import 'package:flutter/material.dart';
import '../screens/app_colors.dart';

class FigmaGlassButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onPressed;
  final double width;
  final double height;
  final BorderRadius borderRadius;
  final String? semanticLabel;

  const FigmaGlassButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.width = double.infinity,
    this.height = 48,
    this.borderRadius = const BorderRadius.all(Radius.circular(18)),
    this.semanticLabel,
  });

  @override
  State<FigmaGlassButton> createState() => _FigmaGlassButtonState();
}

class _FigmaGlassButtonState extends State<FigmaGlassButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: const Duration(milliseconds: 120),
        child: InkWell(
          onTap: widget.onPressed,
          onHighlightChanged: (pressed) => setState(() => _pressed = pressed),
          borderRadius: widget.borderRadius,
          child: Container(
            width: widget.width,
            // A minimum height, not a fixed one, so larger system text grows
            // the button instead of clipping its label.
            constraints: BoxConstraints(minHeight: widget.height),
            decoration: BoxDecoration(
              borderRadius: widget.borderRadius,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xF2FFFFFF), Color(0xCFEAF7FA)],
              ),
              border: Border.all(color: Color(0xB8FFFFFF), width: 1.2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x350B718E),
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
                BoxShadow(
                  color: Color(0xA8FFFFFF),
                  blurRadius: 2,
                  offset: Offset(0, -1),
                ),
              ],
            ),
            child: Center(child: widget.child),
          ),
        ),
      ),
    );
  }
}

class FigmaGlassUploadButton extends StatelessWidget {
  final VoidCallback onPressed;

  const FigmaGlassUploadButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FigmaGlassButton(
      width: 230,
      height: 230,
      borderRadius: BorderRadius.circular(100),
      semanticLabel: 'Upload content',
      onPressed: onPressed,
      child: const Icon(
        Icons.file_upload_outlined,
        size: 160,
        color: AppColors.primaryBlue,
      ),
    );
  }
}
