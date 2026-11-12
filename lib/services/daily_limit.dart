import 'dart:convert';

/// Free accounts, including guests, can make a limited number of scans and chat
/// questions each day. The backend answers with a 429 once that limit is used
/// up, and this reads that answer.
class DailyLimitInfo {
  const DailyLimitInfo({this.limit, this.resetsAt});

  /// How many free requests a day, or null if the backend did not say.
  final int? limit;

  /// When the count starts over, or null if the backend did not say.
  final DateTime? resetsAt;

  /// Reads the body of a 429 response. Returns null when the body is not the
  /// daily-limit answer, so other 429s are still treated as ordinary errors.
  static DailyLimitInfo? fromBody(String body) {
    try {
      final data = jsonDecode(body);
      if (data is! Map || data['error'] != 'daily_limit_reached') return null;
      final limit = data['limit'];
      final resetsAt = data['resets_at'];
      return DailyLimitInfo(
        limit: limit is int ? limit : null,
        resetsAt: resetsAt is String ? DateTime.tryParse(resetsAt) : null,
      );
    } on FormatException {
      return null;
    }
  }

  /// Plain-language explanation that says when usage resets, in the phone's
  /// own time zone. [now] is only for tests.
  String message({DateTime? now}) {
    final start = limit == null
        ? 'You\'ve reached today\'s limit of free requests.'
        : 'You\'ve reached today\'s limit of $limit free requests.';
    final reset = resetsAt?.toLocal();
    if (reset == null) return '$start It resets tomorrow.';
    final today = now ?? DateTime.now();
    final sameDay =
        reset.year == today.year &&
        reset.month == today.month &&
        reset.day == today.day;
    return '$start It resets ${sameDay ? 'today' : 'tomorrow'} at ${_clock(reset)}.';
  }

  static String _clock(DateTime time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${time.hour < 12 ? 'AM' : 'PM'}';
  }
}
