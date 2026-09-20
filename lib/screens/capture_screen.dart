import 'package:flutter/material.dart';
import 'app_colors.dart';
import '../widgets/app_drawer.dart';
import 'results_screen.dart';
import '../widgets/figma_app_bar.dart';
import '../widgets/figma_gradient_background.dart';
import '../widgets/figma_glass_button.dart';

class CaptureScreen extends StatelessWidget {
  final bool isGuest;

  const CaptureScreen({super.key, this.isGuest = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.screenBackground,
      appBar: const FigmaAppBar(title: 'Capture'),
      drawer: AppDrawer(currentPage: 'Capture', isGuest: isGuest),
      body: FigmaGradientBackground(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: LayoutBuilder(
          builder: (context, constraints) => Center(
            child: Container(
              width: double.infinity,
              constraints: BoxConstraints(
                maxWidth: 520,
                minHeight: constraints.maxHeight,
              ),
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 30),
              decoration: BoxDecoration(
                color: const Color(0xD9FDFCF9),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: const Color(0xB8FFFFFF),
                  width: 1.2,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x300B718E),
                    blurRadius: 16,
                    offset: Offset(0, 7),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                children: [
                const Text(
                  'Tap to Upload',
                  style: TextStyle(
                    fontFamily: 'SFProText',
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryBlue,
                  ),
                ),
                const Spacer(),
                FigmaGlassUploadButton(
                  onPressed: () => _openResults(context),
                ),
                const Spacer(),
                FigmaGlassButton(
                  width: double.infinity,
                  height: 58,
                  semanticLabel: 'Scan',
                  onPressed: () => _openResults(context),
                  child: const Text(
                    'Scan',
                    style: TextStyle(
                      fontFamily: 'SFProText',
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                FigmaGlassButton(
                  width: double.infinity,
                  height: 58,
                  semanticLabel: 'Insert text',
                  onPressed: () => _openResults(context),
                  child: const Text(
                    'Insert Text',
                    style: TextStyle(
                      fontFamily: 'SFProText',
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openResults(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ResultsScreen(isGuest: isGuest)),
    );
  }
}
