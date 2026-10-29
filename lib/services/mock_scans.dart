import '../models/scan_result.dart';

/// Turn on with `flutter run --dart-define=MOCK_SCANS=true`. When on, Capture
/// skips the real scan service and cycles through the mock results below, so
/// each risk level's Results layout can be reviewed. Off by default.
const bool kMockScans = bool.fromEnvironment('MOCK_SCANS');

class MockScans {
  MockScans._();

  static const _results = [
    ScanResult(
      riskLevel: 'high',
      summary:
          'This message uses pressure tactics and a link to a known phishing domain.',
      scamPercentage: 92,
      redFlags: [
        'It demands action within 24 hours or your account will be closed.',
        'The link goes to a domain that imitates a delivery company.',
      ],
      redFlagLabels: ['Urgent Language', 'Suspicious Link'],
      redFlagIcons: ['schedule', 'link'],
      nextSteps: [
        'Do not click any links or reply to this message.',
        'Delete the message and report it as phishing.',
      ],
    ),
    ScanResult(
      riskLevel: 'medium',
      summary:
          'Parts of this message look like a scam, but a few details are unclear.',
      scamPercentage: 55,
      redFlags: ['It asks for payment details to release a package.'],
      redFlagLabels: ['Payment Request'],
      redFlagIcons: ['payments'],
      nextSteps: [
        'Contact the company using a number from their official website.',
      ],
    ),
    ScanResult(
      riskLevel: 'low',
      summary: 'No strong warning signs were found in this message.',
      scamPercentage: 8,
      redFlags: [],
      nextSteps: [
        'Still, only click links or share information if you trust the sender.',
      ],
    ),
  ];

  static int _next = 0;

  /// Returns the next mock result, cycling high → medium → low.
  static ScanResult next() {
    final result = _results[_next % _results.length];
    _next++;
    return result;
  }
}
