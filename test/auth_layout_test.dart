import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:phishnet_app/screens/forgot_password_screen.dart';
import 'package:phishnet_app/screens/login_screen.dart';
import 'package:phishnet_app/screens/signup_screen.dart';

import 'support/fake_auth_service.dart';

/// Narrow phone (320pt wide) with larger system text, so layouts that only fit
/// at default sizes fail here as overflow errors.
Future<void> pumpNarrow(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = const Size(640, 1200);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: const TextScaler.linear(1.5)),
        child: child!,
      ),
      home: home,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('Auth layouts at narrow width and large text', () {
    testWidgets('Forgot Password fits and scrolls', (tester) async {
      await pumpNarrow(tester, const ForgotPasswordScreen());
      expect(find.text('Forgot Password'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Login fits and scrolls', (tester) async {
      await pumpNarrow(tester, LoginScreen(authService: FakeAuthService()));
      expect(find.text('Email'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Signup fits and scrolls', (tester) async {
      await pumpNarrow(tester, SignupScreen(authService: FakeAuthService()));
      expect(find.text('Email'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });
}
