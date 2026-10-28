import 'package:flutter/material.dart';
import '../widgets/app_drawer.dart';
import '../widgets/figma_app_bar.dart';
import '../widgets/figma_gradient_background.dart';
import '../theme/app_typography.dart';
import 'dart:math' as math;

class ResultsScreen extends StatefulWidget {
  final bool isGuest;
  final bool isLoading;

  const ResultsScreen({
    super.key,
    this.isGuest = false,
    this.isLoading = false,
  });

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen>
    with TickerProviderStateMixin {
  late final AnimationController _waveController;
  late final AnimationController _scoreController;

  bool _loading = false;

  @override
  void initState() {
    super.initState();

    _loading = widget.isLoading;

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _scoreController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    if (_loading) {
      _scoreController.forward();

      Future.delayed(const Duration(seconds: 4), () {
        if (!mounted) return;

        setState(() {
          _loading = false;
        });

        _waveController.stop();
      });
    } else {
      _waveController.stop();
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    _scoreController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const FigmaAppBar(title: 'Results'),
      drawer: AppDrawer(currentPage: 'Results', isGuest: widget.isGuest),
      body: FigmaGradientBackground(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          child: _loading
              ? _LoadingContent(
                  waveAnimation: _waveController,
                  scoreAnimation: _scoreController,
                )
              : const _ResultsContent(),
        ),
      ),
    );
  }
}

class _LoadingContent extends StatelessWidget {
  final Animation<double> waveAnimation;
  final Animation<double> scoreAnimation;

  const _LoadingContent({
    required this.waveAnimation,
    required this.scoreAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const ValueKey('loading'),
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: Colors.white.withValues(alpha: 0.9),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Analyzing...',
                          style: TextStyle(
                            fontSize: AppTypography.emphasis,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        AnimatedBuilder(
                          animation: waveAnimation,
                          builder: (context, child) {
                            return Row(
                              children: List.generate(5, (index) {
                                final height =
                                    10 +
                                    ((math.sin(
                                                  waveAnimation.value *
                                                          math.pi *
                                                          2 +
                                                      index,
                                                ) +
                                                1) /
                                            2) *
                                        20;

                                return Container(
                                  width: 5,
                                  height: height,
                                  margin: const EdgeInsets.only(right: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade400,
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                );
                              }),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                AnimatedBuilder(
                  animation: scoreAnimation,
                  builder: (context, child) {
                    final score = scoreAnimation.value;

                    return SizedBox(
                      width: 110,
                      height: 110,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: score,
                            strokeWidth: 10,
                            backgroundColor: Colors.grey.shade300,
                            color: Colors.red,
                          ),
                          Text(
                            score >= 1 ? '85%' : '...',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ResultsContent extends StatelessWidget {
  const _ResultsContent();

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const ValueKey('results'),
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: Colors.red.shade50,
          child: const ListTile(
            leading: Icon(Icons.cancel, color: Colors.red),
            title: Text(
              'Scam Detected',
              style: TextStyle(fontSize: AppTypography.emphasis),
            ),
            subtitle: Text(
              '85% confidence',
              style: TextStyle(fontSize: AppTypography.body),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Why this might be a scam',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: AppTypography.title,
          ),
        ),
        const SizedBox(height: 8),
        const Wrap(
          spacing: 8,
          children: [
            Chip(
              labelStyle: TextStyle(fontSize: AppTypography.label),
              label: Text('Unknown Sender'),
            ),
            Chip(
              labelStyle: TextStyle(fontSize: AppTypography.label),
              label: Text('Urgent Language'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'What should you do?',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: AppTypography.title,
          ),
        ),
        const SizedBox(height: 8),
        const Wrap(
          spacing: 8,
          children: [
            Chip(
              labelStyle: TextStyle(fontSize: AppTypography.label),
              label: Text('Do Not Click Links'),
            ),
            Chip(
              labelStyle: TextStyle(fontSize: AppTypography.label),
              label: Text('Block Sender'),
            ),
            Chip(
              labelStyle: TextStyle(fontSize: AppTypography.label),
              label: Text('Report Message'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'Still unsure?',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: AppTypography.title,
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () {},
          child: const Text(
            'Get a second opinion',
            style: TextStyle(fontSize: AppTypography.emphasis),
          ),
        ),
      ],
    );
  }
}
