import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'legal_content.dart';
import '../widgets/figma_gradient_background.dart';
import '../widgets/figma_app_bar.dart';

/// Shared layout for Terms & Conditions and Privacy Policy.
class LegalScreen extends StatelessWidget {
  final String title;
  final LegalDocument document;

  const LegalScreen({super.key, required this.title, required this.document});

  static const _body = TextStyle(
    fontFamily: 'SFProText',
    fontSize: 18,
    height: 1.5,
    color: AppColors.text,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.screenBackground,
      appBar: FigmaAppBar(title: title, showBackButton: true),
      body: FigmaGradientBackground(
        child: Scrollbar(
          thumbVisibility: true,
          child: SingleChildScrollView(
            primary: true,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            child: Card(
              color: AppColors.surface,
              elevation: 3,
              shadowColor: const Color(0x26000000),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Image.asset(
                          'assets/images/phishnet_logo.png',
                          width: 48,
                          height: 48,
                          excludeFromSemantics: true,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Semantics(
                            header: true,
                            child: Text(
                              document.heading,
                              style: _body.copyWith(
                                fontFamily: 'SFProDisplay',
                                fontSize: 24,
                                height: 1.25,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Last updated: ${document.lastUpdated}',
                      style: _body.copyWith(color: AppColors.muted),
                    ),
                    for (final section in document.sections)
                      _SectionView(section),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionView extends StatelessWidget {
  final LegalSection section;

  const _SectionView(this.section);

  @override
  Widget build(BuildContext context) {
    const body = LegalScreen._body;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 36, color: Color(0x1F101D27)),
        Semantics(
          header: true,
          child: Text(
            section.title,
            style: body.copyWith(fontSize: 20, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 8),
        for (final block in section.blocks)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: switch (block) {
              LegalSubheading() => Text(
                block.text,
                style: body.copyWith(fontWeight: FontWeight.w700),
              ),
              LegalParagraph() => Text(block.text, style: body),
              LegalBullet() => Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 11, right: 12, left: 4),
                    child: CircleAvatar(
                      radius: 3,
                      backgroundColor: AppColors.primaryBlue,
                    ),
                  ),
                  Expanded(child: Text(block.text, style: body)),
                ],
              ),
            },
          ),
      ],
    );
  }
}
