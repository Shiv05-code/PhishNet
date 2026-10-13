import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Shared widget-test helpers for auth screens.
const strongPassword = 'PhishNet!26';

Future<void> pumpScreen(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: home));
}

Future<void> tapOn(WidgetTester tester, Finder finder) async {
  // Settle first so a focused field can't scroll the target back out of view.
  await tester.pumpAndSettle();
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Finder fieldFor(String label) => find.descendant(
  of: find.ancestor(of: find.text(label), matching: find.byType(Column)).first,
  matching: find.byType(TextFormField),
);

Future<void> enterField(WidgetTester tester, String label, String text) async {
  await tester.ensureVisible(fieldFor(label));
  await tester.enterText(fieldFor(label), text);
}
