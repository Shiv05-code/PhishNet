import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:phishnet_app/screens/privacy_policy_screen.dart';
import 'package:phishnet_app/screens/signup_screen.dart';
import 'package:phishnet_app/screens/terms_conditions_screen.dart';

import 'support/fake_auth_service.dart';
import 'support/test_helpers.dart';

void main() {
  group('Legal screens', () {
    for (final (label, screen, updated) in [
      ('Terms & Conditions', TermsConditionsScreen, 'September 5, 2026'),
      ('Privacy Policy', PrivacyPolicyScreen, 'October 20, 2026'),
    ]) {
      testWidgets('$label scrolls, is 18pt, and Back keeps form', (
        tester,
      ) async {
        await pumpScreen(tester, SignupScreen(authService: FakeAuthService()));
        await enterField(tester, 'First Name', 'Ada');
        await tapOn(tester, find.text(label));
        expect(find.byType(screen), findsOneWidget);
        expect(find.byType(Image), findsOneWidget); // PhishNet logo
        final texts = tester.widgetList<Text>(
          find.descendant(of: find.byType(Card), matching: find.byType(Text)),
        );
        expect(texts.length, greaterThan(10));
        for (final text in texts) {
          expect(text.style!.fontSize, greaterThanOrEqualTo(18));
          expect(text.data, isNot(contains('-----')));
        }
        expect(find.textContaining('Last updated: $updated'), findsOneWidget);
        await tester.drag(find.byType(Card), const Offset(0, -600));
        await tester.pumpAndSettle();
        await tapOn(tester, find.byTooltip('Back'));
        expect(find.byType(SignupScreen), findsOneWidget);
        expect(find.text('Ada'), findsOneWidget);
      });
    }
    test('Privacy Policy separates transient input from stored results', () {
      final bullets = privacyPolicyDocument.sections
          .expand((section) => section.blocks)
          .map((block) => block.text)
          .join('\n');
      expect(bullets, contains('Transient processing:'));
      expect(bullets, contains('does not save the message text'));
      expect(bullets, contains('Stored results:'));
      expect(bullets, contains('timestamp are saved to your account'));
      expect(bullets, contains('brief description, scam-risk score'));
      expect(bullets, contains('Delete My Account'));
      expect(bullets, contains('your name, email address, and password'));
      expect(bullets, contains('the scan records linked to your account'));
      expect(
        bullets,
        contains(
          'Copies of each scan\'s derived assessment remain after deletion',
        ),
      );
      expect(bullets, contains('may still contain identifying information'));
      expect(bullets, contains('The full message text is not stored'));
      expect(bullets, contains('Model training is not currently implemented'));
      expect(
        bullets,
        isNot(contains('permanently delete your stored results')),
      );
      expect(bullets, isNot(contains('Delete My Data')));
      expect(bullets, isNot(contains('Delete my Data')));
    });

    test('Privacy Policy has no contradictory retention claims', () {
      final bullets = privacyPolicyDocument.sections
          .expand((section) => section.blocks)
          .map((block) => block.text)
          .join('\n');
      // Old wording that contradicted the verified backend behavior.
      expect(bullets.toLowerCase(), isNot(contains('nothing is stored')));
      // Assessment copies are unlinked but not anonymous.
      expect(bullets.toLowerCase(), isNot(contains('anonymi')));
      expect(bullets.toLowerCase(), isNot(contains('anonymous')));
      expect(bullets, isNot(contains('may be stored and used to train')));
      expect(bullets, isNot(contains('AI Chat conversations, is retained')));
      expect(bullets, isNot(contains('Claude Haiku 3.5')));
      expect(bullets, isNot(contains('Claude Sonnet 4')));
      expect(bullets, isNot(contains('scanned messages, links')));
      // Email retention must be stated as undefined, not implied.
      expect(bullets, contains('have not yet set how long email content'));
      // Any bullet that mentions training must say it is not in place or future.
      for (final text in bullets.split('\n')) {
        if (text.contains('train')) {
          expect(
            text.contains('future') ||
                text.contains('not yet') ||
                text.contains('in place yet') ||
                text.contains('not currently implemented'),
            isTrue,
            reason: 'Training claim without qualification: $text',
          );
        }
      }
    });
  });
}
