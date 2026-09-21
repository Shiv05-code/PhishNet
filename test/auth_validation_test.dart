import 'package:flutter_test/flutter_test.dart';
import 'package:phishnet_app/services/auth_validation.dart';

void main() {
  group('signup email validation', () {
    test('accepts Gmail and Yahoo addresses', () {
      expect(validateSignupEmail('person@gmail.com'), isNull);
      expect(validateSignupEmail('person@yahoo.com'), isNull);
    });

    test('rejects malformed and unsupported addresses', () {
      expect(validateSignupEmail('persongmail.com'), isNotNull);
      expect(validateSignupEmail('person@gmaik.com'), contains('Gmail'));
    });
  });

  group('signup password validation', () {
    test('reports length before strength requirements', () {
      expect(validateSignupPassword('1234567'), 'Use at least 8 characters.');
    });

    test('reports missing strength requirements', () {
      expect(
        validateSignupPassword('12345678'),
        'Weak password. Add a letter and symbol.',
      );
      expect(
        validateSignupPassword('Abcdefgh'),
        'Weak password. Add a number and symbol.',
      );
    });

    test('accepts a strong password', () {
      expect(validateSignupPassword('PhishNet!26'), isNull);
    });
  });

  test('confirm password distinguishes empty and mismatch', () {
    expect(
      validateConfirmPassword('', 'PhishNet!26'),
      'Re-enter your password.',
    );
    expect(
      validateConfirmPassword('Different!26', 'PhishNet!26'),
      'Passwords do not match.',
    );
    expect(validateConfirmPassword('PhishNet!26', 'PhishNet!26'), isNull);
  });
}
