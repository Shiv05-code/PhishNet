import 'package:flutter/material.dart';

/// A simple animated fish that swims back and forth horizontally.
/// Placeholder for a fancier Lottie/Rive animation later if you want one —
/// this version needs no external animation files, just Flutter's
/// built-in AnimationController.
class SwimmingFish extends StatefulWidget {
  final double width;

  const SwimmingFish({super.key, this.width = 200});

  @override
  State<SwimmingFish> createState() => _SwimmingFishState();
}

class _SwimmingFishState extends State<SwimmingFish>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _position;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _position = Tween<double>(begin: -1, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: 60,
      child: AnimatedBuilder(
        animation: _position,
        builder: (context, child) {
          // Flip the fish horizontally when swimming back the other way.
          final swimmingRight = _position.value >= 0;
          return Align(
            alignment: Alignment(_position.value, 0),
            child: Transform.flip(
              flipX: !swimmingRight,
              child: const Text('🐟', style: TextStyle(fontSize: 40)),
            ),
          );
        },
      ),
    );
  }
}
