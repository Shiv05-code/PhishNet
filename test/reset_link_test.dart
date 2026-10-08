import 'package:flutter_test/flutter_test.dart';
import 'package:phishnet_app/services/reset_link.dart';

void main() {
  test('parses Firebase action, app scheme, route, and nested links', () {
    expect(
      parseResetCode(
        'https://phishnet-b93e0.web.app/auth/action?mode=resetPassword&oobCode=ABC123xyz_&apiKey=k',
      ),
      'ABC123xyz_',
    );
    expect(
      parseResetCode('phishnet://app/reset-password?oobCode=CODE12345678'),
      'CODE12345678',
    );
    expect(
      parseResetCode('/reset-password?oobCode=CODE12345678'),
      'CODE12345678',
    );
    expect(
      parseResetCode(
        'https://x.page.link/?link=${Uri.encodeComponent('https://a.b/__/auth/action?mode=resetPassword&oobCode=NESTED12345')}',
      ),
      'NESTED12345',
    );
    expect(parseResetCode('BareCode_1234567890'), 'BareCode_1234567890');
  });

  test('ignores non-reset links and junk', () {
    expect(parseResetCode(null), isNull);
    expect(parseResetCode('/'), isNull);
    expect(
      parseResetCode(
        'https://a.b/__/auth/action?mode=verifyEmail&oobCode=X1234567890',
      ),
      isNull,
    );
    expect(parseResetCode('hello'), isNull);
  });
}
