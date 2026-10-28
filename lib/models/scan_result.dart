class ScanResult {
  final String riskLevel;
  final String summary;
  final List<String> redFlags;
  final List<String> nextSteps;

  const ScanResult({
    required this.riskLevel,
    required this.summary,
    required this.redFlags,
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

    List<String> parseList(String key) {
      final value = json[key];

      if (value is! List || value.any((item) => item is! String)) {
        throw FormatException('Invalid $key');
      }

      return List<String>.from(value);
    }

    return ScanResult(
      riskLevel: risk,
      summary: summary,
      redFlags: parseList('red_flags'),
      nextSteps: parseList('next_steps'),
    );
  }
}
