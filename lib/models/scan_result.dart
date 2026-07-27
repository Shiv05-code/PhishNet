/// Represents the outcome of a scam-detection scan.
/// Kept minimal for now — expand with real fields once
/// the detection logic/backend is wired up.
class ScanResult {
  final int scamConfidence; // e.g. 85 (%)
  final String capturedMessage;
  final List<String> reasons; // "Unknown sender", "Urgent language", etc.

  const ScanResult({
    required this.scamConfidence,
    required this.capturedMessage,
    required this.reasons,
  });
}
