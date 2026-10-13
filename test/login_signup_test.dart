import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:phishnet_app/screens/email_verification_screen.dart';
import 'package:phishnet_app/screens/home_screen.dart';
import 'package:phishnet_app/screens/login_screen.dart';
import 'package:phishnet_app/screens/signup_screen.dart';
import 'package:phishnet_app/services/auth_service.dart';
import 'package:phishnet_app/theme/auth_theme.dart';
import 'package:phishnet_app/widgets/auth_widgets.dart';

import 'support/fake_auth_service.dart';
import 'support/test_helpers.dart';

void main() {
  group('Login', () {
    testWidgets('single Login heading, arrow submit, and Sign Up link', (
      tester,
    ) async {
      await pumpScreen(tester, LoginScreen(authService: FakeAuthService()));
      expect(find.text('Login'), findsOneWidget); // heading only
      expect(find.byType(AuthArrowButton), findsOneWidget);
      expect(find.text('Sign Up'), findsOneWidget);
    });

    testWidgets('empty fields validate inline without calling auth', (
      tester,
    ) async {
      final auth = FakeAuthService()..nextError = null;
      await pumpScreen(tester, LoginScreen(authService: auth));
      await tapOn(tester, find.byType(AuthArrowButton));
      expect(find.text('Enter your email.'), findsOneWidget);
      expect(find.text('Enter your password.'), findsOneWidget);
      expect(auth.signedIn, isFalse);
    });

    testWidgets('field text is 18pt+ with high-contrast border', (
      tester,
    ) async {
      await pumpScreen(tester, LoginScreen(authService: FakeAuthService()));
      final field = tester.widget<EditableText>(
        find.byType(EditableText).first,
      );
      expect(field.style.fontSize, greaterThanOrEqualTo(18));
      expect(AuthTheme.fieldBorder, const Color(0xFF2E6E8C));
    });

    testWidgets('unverified login goes to verification', (tester) async {
      final auth = FakeAuthService()..passwords['a@gmail.com'] = strongPassword;
      await pumpScreen(tester, LoginScreen(authService: auth));
      await enterField(tester, 'Email', 'a@gmail.com');
      await enterField(tester, 'Password', strongPassword);
      await tapOn(tester, find.byType(AuthArrowButton));
      expect(find.byType(EmailVerificationScreen), findsOneWidget);
    });

    testWidgets('verified login goes to Home', (tester) async {
      final auth = FakeAuthService(verified: true)
        ..passwords['a@gmail.com'] = strongPassword;
      await pumpScreen(tester, LoginScreen(authService: auth));
      await enterField(tester, 'Email', 'a@gmail.com');
      await enterField(tester, 'Password', strongPassword);
      await tapOn(tester, find.byType(AuthArrowButton));
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('wrong password shows inline error', (tester) async {
      await pumpScreen(tester, LoginScreen(authService: FakeAuthService()));
      await enterField(tester, 'Email', 'a@gmail.com');
      await enterField(tester, 'Password', 'nope');
      await tapOn(tester, find.byType(AuthArrowButton));
      expect(find.text('Invalid email or password.'), findsOneWidget);
    });
  });

  group('Signup', () {
    Future<void> fill(
      WidgetTester tester, {
      String confirm = strongPassword,
    }) async {
      await enterField(tester, 'First Name', 'Ada');
      await enterField(tester, 'Last Name', 'Lovelace');
      await enterField(tester, 'Email', 'a@gmail.com');
      await enterField(tester, 'Password', strongPassword);
      await enterField(tester, 'Confirm Password', confirm);
    }

    testWidgets('creates account with name and opens verification', (
      tester,
    ) async {
      final auth = FakeAuthService();
      await pumpScreen(tester, SignupScreen(authService: auth));
      await fill(tester);
      await tapOn(tester, find.byType(AuthArrowButton));
      expect(auth.lastDisplayName, 'Ada Lovelace');
      expect(find.byType(EmailVerificationScreen), findsOneWidget);
    });

    testWidgets('fits a small screen with keyboard open and scrolls', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(640, 1136); // iPhone SE (1st gen)
      tester.view.devicePixelRatio = 2;
      tester.view.viewInsets = const FakeViewPadding(bottom: 432); // keyboard
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(home: SignupScreen(authService: FakeAuthService())),
      );
      expect(tester.takeException(), isNull); // no overflow
      await tester.ensureVisible(find.text('Privacy Policy'));
      await tester.pumpAndSettle();
      expect(find.text('Privacy Policy').hitTestable(), findsOneWidget);
    });

    testWidgets('mismatch keeps both values', (tester) async {
      await pumpScreen(tester, SignupScreen(authService: FakeAuthService()));
      await fill(tester, confirm: 'Different!26');
      await tapOn(tester, find.byType(AuthArrowButton));
      expect(find.text('Passwords do not match.'), findsOneWidget);
      expect(find.text(strongPassword), findsOneWidget);
      expect(find.text('Different!26'), findsOneWidget);
    });

    testWidgets('duplicate account shows inline error with Login link', (
      tester,
    ) async {
      final auth = FakeAuthService()..registeredEmails.add('a@gmail.com');
      await pumpScreen(tester, SignupScreen(authService: auth));
      await fill(tester);
      await tapOn(tester, find.byType(AuthArrowButton));
      expect(find.text(AuthService.duplicateAccountMessage), findsOneWidget);
      await tapOn(tester, find.text('Login instead'));
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('a@gmail.com'), findsOneWidget);
    });
  });

  group('Home greeting', () {
    testWidgets('uses first name from displayName', (tester) async {
      await pumpScreen(
        tester,
        HomeScreen(authService: FakeAuthService(displayName: 'Shivansh Kanda')),
      );
      expect(find.text('Hello, Shivansh'), findsOneWidget);
      final greeting = tester.widget<Text>(find.text('Hello, Shivansh'));
      expect(greeting.style!.fontSize, greaterThanOrEqualTo(22));
    });

    testWidgets('falls back when name is missing or blank', (tester) async {
      for (final name in [null, '   ']) {
        await pumpScreen(
          tester,
          HomeScreen(
            key: UniqueKey(),
            authService: FakeAuthService(displayName: name),
          ),
        );
        expect(find.text('Hello there'), findsOneWidget);
      }
    });
  });
}
