import 'package:flutter_test/flutter_test.dart';
import 'package:phishnet_app/services/session_timeout.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('no recorded activity is not treated as expired', () async {
    expect(await SessionTimeout().hasExpired(), isFalse);
  });

  test('recent activity is not expired', () async {
    final session = SessionTimeout();
    await session.markActive();
    expect(await session.hasExpired(), isFalse);
  });

  test('activity older than the idle limit is expired', () async {
    final stale = DateTime.now().subtract(
      SessionTimeout.idleLimit + const Duration(minutes: 1),
    );
    SharedPreferences.setMockInitialValues({
      'session_last_active_ms': stale.millisecondsSinceEpoch,
    });
    expect(await SessionTimeout().hasExpired(), isTrue);
  });

  test('clear removes the recorded activity', () async {
    final stale = DateTime.now().subtract(
      SessionTimeout.idleLimit + const Duration(minutes: 1),
    );
    SharedPreferences.setMockInitialValues({
      'session_last_active_ms': stale.millisecondsSinceEpoch,
    });
    final session = SessionTimeout();
    await session.clear();
    expect(await session.hasExpired(), isFalse);
  });
}
