import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:phishnet_app/screens/forgot_password_screen.dart';
import 'package:phishnet_app/screens/home_screen.dart';
import 'package:phishnet_app/screens/login_screen.dart';
import 'package:phishnet_app/screens/reset_password_screen.dart';

import 'package:phishnet_app/widgets/auth_widgets.dart';

import 'support/fake_auth_service.dart';
import 'support/test_helpers.dart';

void main() {
  group('Password recovery', () {
    testWidgets('same generic confirmation for any address', (tester) async {
      for (final email in ['known@gmail.com', 'unknown@gmail.com']) {
        await pumpScreen(
          tester,
          ForgotPasswordScreen(
            key: UniqueKey(),
            authService: FakeAuthService()
              ..registeredEmails.add('known@gmail.com'),
          ),
        );
        await enterField(tester, 'Email Address', email);
        await tapOn(tester, find.text('Send Reset Link'));
        expect(
          find.text(
            "If an account exists for $email, you'll get a reset link "
            'shortly. Not in your inbox? Check spam.',
          ),
          findsOneWidget,
        );
      }
    });

    testWidgets('expired link shows request-new-link state', (tester) async {
      await pumpScreen(
        tester,
        ResetPasswordScreen(oobCode: 'OLD', authService: FakeAuthService()),
      );
      await tester.pumpAndSettle();
      expect(find.text('Link Expired'), findsOneWidget);
      await tapOn(tester, find.text('Request New Link'));
      expect(find.byType(ForgotPasswordScreen), findsOneWidget);
    });

    testWidgets('pasted invalid link shows inline error', (tester) async {
      await pumpScreen(
        tester,
        ResetPasswordScreen(authService: FakeAuthService()),
      );
      await enterField(tester, 'Reset Link', 'subject.com');
      await tapOn(tester, find.text('Continue'));
      expect(find.text(invalidResetLinkMessage), findsOneWidget);
    });

    testWidgets('successful reset then login with new password', (
      tester,
    ) async {
      final auth = FakeAuthService(verified: true)
        ..passwords['a@gmail.com'] = 'Old!pass1'
        ..resetCodes['GOOD'] = 'a@gmail.com';
      await pumpScreen(
        tester,
        ResetPasswordScreen(oobCode: 'GOOD', authService: auth),
      );
      await tester.pumpAndSettle();
      await enterField(tester, 'New Password', 'New!pass26');
      await enterField(tester, 'Confirm Password', 'New!pass26');
      await tapOn(tester, find.text('Save New Password'));
      expect(find.text('Password Updated'), findsOneWidget);
      await tapOn(tester, find.text('Go to Login'));
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('a@gmail.com'), findsOneWidget);
      await enterField(tester, 'Password', 'New!pass26');
      await tapOn(tester, find.byType(AuthArrowButton));
      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });
}
