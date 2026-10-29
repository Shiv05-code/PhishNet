class ScanResult {
  final String riskLevel;
  final String summary;
  final int? scamPercentage;
  final List<String> redFlags;
  final List<String> redFlagLabels;
  final List<String> redFlagIcons;
  final List<String> nextSteps;

  const ScanResult({
    required this.riskLevel,
    required this.summary,
    this.scamPercentage,
    required this.redFlags,
    this.redFlagLabels = const [],
    this.redFlagIcons = const [],
    required this.nextSteps,
  });

  factory ScanResult.fromJson(Map<String, dynamic> json) {
    final risk = json['risk_level'];
    final summary = json['summary'];

    if (risk is! String || !['low', 'medium', 'high'].contains(risk)) {
      throw const FormatException('Invalid risk level');
    }

    if (summary is! String || summary.trim().isEmpty) {
      throw const FormatException('Invalid summary');
    }

    final score = json['scam_percentage'];

    final flags = json['red_flags'];
    if (flags is! List) throw const FormatException('Invalid red_flags');
    final descriptions = <String>[];
    final labels = <String>[];
    final icons = <String>[];
    for (final f in flags) {
      if (f is String) {
        descriptions.add(f);
        labels.add('');
        icons.add('');
      } else if (f is Map && f['description'] is String) {
        descriptions.add(f['description'] as String);
        labels.add(f['label'] is String ? f['label'] as String : '');
        icons.add(f['icon'] is String ? f['icon'] as String : '');
      } else {
        throw const FormatException('Invalid red_flags');
      }
    }

    final steps = json['next_steps'];
    if (steps is! List || steps.any((s) => s is! String)) {
      throw const FormatException('Invalid next_steps');
    }

    return ScanResult(
      riskLevel: risk,
      summary: summary,
      scamPercentage: score is int ? score : null,
      redFlags: descriptions,
      redFlagLabels: labels,
      redFlagIcons: icons,
      nextSteps: List<String>.from(steps),
    );
  }
}
