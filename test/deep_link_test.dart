import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:phishnet_app/main.dart';
import 'package:phishnet_app/screens/home_screen.dart';
import 'package:phishnet_app/screens/loading_screen.dart';
import 'package:phishnet_app/screens/reset_password_screen.dart';

import 'support/fake_auth_service.dart';

void main() {
  group('Deep links and app launch', () {
    testWidgets('email-verified link opens Home for verified user', (
      tester,
    ) async {
      final auth = FakeAuthService(signedIn: true, verified: true);
      await tester.pumpWidget(PhishNetApp(authService: auth));
      tester
          .state<NavigatorState>(find.byType(Navigator))
          .pushNamed('/email-verified');
      await tester.pump(); // build the pushed splash so its timer starts
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(LoadingScreen), findsNothing);
    });

    testWidgets('reset deep link opens Reset over the splash', (tester) async {
      final auth = FakeAuthService()
        ..resetCodes['CODE12345678'] = 'a@gmail.com';
      await tester.pumpWidget(PhishNetApp(authService: auth));
      tester
          .state<NavigatorState>(find.byType(Navigator))
          .pushNamed('/auth/action?mode=resetPassword&oobCode=CODE12345678');
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(ResetPasswordScreen), findsOneWidget);
      expect(find.text('Create New Password'), findsOneWidget);
    });

    testWidgets('returning signed-in user is greeted after splash', (
      tester,
    ) async {
      await tester.pumpWidget(
        PhishNetApp(
          authService: FakeAuthService(
            signedIn: true,
            verified: true,
            displayName: 'Shivansh Kanda',
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 3, milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Hello, Shivansh'), findsOneWidget);
    });
  });
}
