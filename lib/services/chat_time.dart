/// How AI Chat shows when a message was sent. Everything is in the phone's
/// local time.
const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// The time of day, like "3:42 PM".
String formatChatTime(DateTime moment) {
  final time = moment.toLocal();
  final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${time.hour < 12 ? 'AM' : 'PM'}';
}

/// True when both moments fall on the same calendar day.
bool isSameChatDay(DateTime a, DateTime b) {
  final first = a.toLocal();
  final second = b.toLocal();
  return first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}

/// The day heading above a group of messages: "Today", "Yesterday", or a
/// date like "Nov 20". The year is added only for another year.
String chatDayLabel(DateTime moment, {DateTime? now}) {
  final day = moment.toLocal();
  final today = (now ?? DateTime.now()).toLocal();
  if (isSameChatDay(day, today)) return 'Today';
  final yesterday = DateTime(today.year, today.month, today.day - 1);
  if (isSameChatDay(day, yesterday)) return 'Yesterday';
  final label = '${_months[day.month - 1]} ${day.day}';
  return day.year == today.year ? label : '$label, ${day.year}';
}
