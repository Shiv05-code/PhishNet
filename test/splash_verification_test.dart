import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:phishnet_app/screens/email_verification_screen.dart';
import 'package:phishnet_app/screens/home_screen.dart';
import 'package:phishnet_app/screens/loading_screen.dart';
import 'package:phishnet_app/screens/login_screen.dart';
import 'package:phishnet_app/screens/settings_screen.dart';
import 'package:phishnet_app/widgets/app_drawer.dart';

import 'support/fake_auth_service.dart';
import 'support/test_helpers.dart';

void main() {
  group('Splash routing', () {
    Future<void> boot(WidgetTester tester, FakeAuthService auth) async {
      await tester.pumpWidget(
        MaterialApp(home: LoadingScreen(authService: auth)),
      );
      // Step frame by frame so the fade-in and fade-out each get to finish.
      for (var i = 0; i < 100; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets('no session opens Login', (tester) async {
      await boot(tester, FakeAuthService());
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('verified session opens Home', (tester) async {
      await boot(tester, FakeAuthService(signedIn: true, verified: true));
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('deleted account session opens Login', (tester) async {
      await boot(
        tester,
        FakeAuthService(signedIn: true, verified: true)..accountDeleted = true,
      );
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('unverified session opens Login', (tester) async {
      await boot(tester, FakeAuthService(signedIn: true));
      expect(find.byType(LoginScreen), findsOneWidget);
    });
  });

  group('Email verification', () {
    testWidgets('unverified check shows guidance', (tester) async {
      await pumpScreen(
        tester,
        EmailVerificationScreen(
          email: 'a@gmail.com',
          authService: FakeAuthService(signedIn: true),
        ),
      );
      await tapOn(tester, find.text("I've Verified My Email"));
      expect(find.textContaining("couldn't confirm"), findsOneWidget);
      expect(find.textContaining('resend in'), findsOneWidget);
    });

    testWidgets('verified check shows success then Home', (tester) async {
      final auth = FakeAuthService(signedIn: true, verified: true);
      await pumpScreen(
        tester,
        EmailVerificationScreen(email: 'a@gmail.com', authService: auth),
      );
      await tapOn(tester, find.text("I've Verified My Email"));
      expect(find.text('Email Verified'), findsOneWidget);
      await tapOn(tester, find.text('Continue to PhishNet'));
      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });

  testWidgets('Log Out signs out of Firebase and opens Login', (tester) async {
    // The test font renders every glyph as a full square, so the fixed-width
    // "Log Out" button overflows only in tests; ignore that layout warning.
    final onError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (!details.toString().contains('overflowed')) onError?.call(details);
    };
    addTearDown(() => FlutterError.onError = onError);
    final auth = FakeAuthService(signedIn: true, verified: true);
    await pumpScreen(tester, SettingsScreen(authService: auth));
    await tapOn(tester, find.text('Log Out'));
    expect(auth.signedIn, isFalse);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('Settings displays the signed-in user full name', (tester) async {
    await pumpScreen(
      tester,
      SettingsScreen(
        authService: FakeAuthService(
          signedIn: true,
          verified: true,
          displayName: 'Jordan Lee',
          email: 'jordan.lee@example.com',
        ),
      ),
    );

    expect(find.text('Jordan Lee'), findsOneWidget);
    expect(find.text('jordan.lee@example.com'), findsOneWidget);
  });

  testWidgets('Menu Logout signs out of Firebase and opens Login', (
    tester,
  ) async {
    final auth = FakeAuthService(signedIn: true, verified: true);
    final scaffoldKey = GlobalKey<ScaffoldState>();
    await pumpScreen(
      tester,
      Scaffold(
        key: scaffoldKey,
        drawer: AppDrawer(currentPage: 'Home', authService: auth),
        body: const SizedBox.expand(),
      ),
    );
    scaffoldKey.currentState!.openDrawer();
    await tester.pumpAndSettle();
    await tapOn(tester, find.text('Logout'));
    expect(auth.signedIn, isFalse);
    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
