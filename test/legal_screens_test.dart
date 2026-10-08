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
      ('Privacy Policy', PrivacyPolicyScreen, 'October 7, 2026'),
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
    test('Privacy Policy describes account deletion and retained content', () {
      final bullets = privacyPolicyDocument.sections
          .expand((section) => section.blocks)
          .map((block) => block.text)
          .join('\n');
      expect(bullets, contains('Delete My Account'));
      expect(bullets, contains('your name, email address, and password'));
      expect(bullets, contains('AI Chat conversations, is retained'));
      expect(bullets, isNot(contains('Delete My Data')));
      expect(bullets, isNot(contains('Delete my Data')));
    });
  });
}
