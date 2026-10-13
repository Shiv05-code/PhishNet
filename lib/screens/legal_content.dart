/// Structured legal content so screens render real headings, paragraphs and
/// bullets instead of parsing formatted text.
class LegalDocument {
  final String heading;
  final String lastUpdated;
  final List<LegalSection> sections;

  const LegalDocument({
    required this.heading,
    required this.lastUpdated,
    required this.sections,
  });
}

class LegalSection {
  final String title;
  final List<LegalBlock> blocks;

  const LegalSection({required this.title, required this.blocks});
}

sealed class LegalBlock {
  final String text;

  const LegalBlock(this.text);
}

class LegalParagraph extends LegalBlock {
  const LegalParagraph(super.text);
}

class LegalBullet extends LegalBlock {
  const LegalBullet(super.text);
}

class LegalSubheading extends LegalBlock {
  const LegalSubheading(super.text);
}
