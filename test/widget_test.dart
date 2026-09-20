import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:phishnet_app/main.dart';
import 'package:phishnet_app/screens/login_screen.dart';
import 'package:phishnet_app/screens/signup_screen.dart';
import 'package:phishnet_app/widgets/auth_widgets.dart';

void main() {
  testWidgets('splash screen transitions to login', (tester) async {
    await tester.pumpWidget(const PhishNetApp());
    await tester.pump();
    await tester.pump(const Duration(seconds: 3, milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Forgot Password?'), findsOneWidget);
    expect(find.bySemanticsLabel('Sign in'), findsOneWidget);
  });

  testWidgets('login and signup render the circular submit button', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    expect(find.byType(AuthArrowButton), findsOneWidget);

    await tester.pumpWidget(const MaterialApp(home: SignupScreen()));
    expect(find.byType(AuthArrowButton), findsOneWidget);
  });
}
