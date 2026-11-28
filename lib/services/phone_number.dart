/// Converts a phone number to E.164 (for example +15551234567).
///
/// Numbers with a leading "+" are kept as entered. 10-digit numbers and
/// 11-digit numbers starting with 1 are treated as US/Canada. Returns null
/// when the number can't be made valid.
String? normalizePhoneNumber(String? raw) {
  if (raw == null) return null;

  final trimmed = raw.trim();
  final digits = trimmed.replaceAll(RegExp(r'\D'), '');

  final String candidate;
  if (trimmed.startsWith('+')) {
    candidate = '+$digits';
  } else if (digits.length == 10) {
    candidate = '+1$digits';
  } else if (digits.length == 11 && digits.startsWith('1')) {
    candidate = '+$digits';
  } else {
    return null;
  }

  return RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(candidate) ? candidate : null;
}
