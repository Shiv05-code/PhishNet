/// Shared type scale. Use these instead of raw font sizes so the hierarchy
/// stays consistent across screens. System text scaling still applies on top.
class AppTypography {
  AppTypography._();

  /// Hints, error messages, and footnotes.
  static const caption = 14.0;

  /// Form labels, footers, and links.
  static const label = 16.0;

  /// Paragraph and instructional body copy.
  static const body = 17.0;

  /// Input text, buttons, and prominent prompts.
  static const emphasis = 18.0;

  /// Section titles, cards, and navigation menu items.
  static const title = 22.0;

  /// Page headings and the brand wordmark.
  static const heading = 26.0;
}
