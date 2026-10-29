import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phishnet_app/models/scan_result.dart';
import 'package:phishnet_app/screens/results_screen.dart';

// Golden images lock the final Results layout for each risk level. Reduced
// motion is on so the captures are the settled state, not a mid-animation frame.
const _phone = Size(390, 844);

ScanResult _scan(String risk, int? score) => ScanResult(
  riskLevel: risk,
  summary: 'PhishNet checked this message and found the signs shown below.',
  scamPercentage: score,
  redFlags: const ['Uses urgent words to pressure you.'],
  redFlagLabels: const ['Urgent Language'],
  redFlagIcons: const ['schedule'],
  nextSteps: const ['Do not click any links or reply to this message.'],
);

Future<void> _pumpResults(
  WidgetTester tester,
  ScanResult result, {
  double textScale = 1,
}) async {
  tester.view.physicalSize = _phone * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: _phone,
        disableAnimations: true,
        textScaler: TextScaler.linear(textScale),
      ),
      child: MaterialApp(home: ResultsScreen(result: result)),
    ),
  );
  await tester.pump();
}

void main() {
  for (final (risk, score) in [('high', 85), ('medium', 55), ('low', 10)]) {
    testWidgets('results match golden for $risk risk', (tester) async {
      await _pumpResults(tester, _scan(risk, score));
      await expectLater(
        find.byType(ResultsScreen),
        matchesGoldenFile('goldens/results_$risk.png'),
      );
    });
  }

  testWidgets('results stay readable at 2x system text size', (tester) async {
    await _pumpResults(tester, _scan('high', 85), textScale: 2);
    // Overflow errors fail the test; the golden records the layout.
    await expectLater(
      find.byType(ResultsScreen),
      matchesGoldenFile('goldens/results_high_large_text.png'),
    );
  });

  testWidgets('tapping the summary finishes the typed reveal', (tester) async {
    tester.view.physicalSize = _phone * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(home: ResultsScreen(result: _scan('high', 85))),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text(_scan('high', 85).summary), findsNothing);

    await tester.tap(find.text('This looks like a phishing attempt'));
    await tester.pumpAndSettle();
    expect(find.text(_scan('high', 85).summary), findsOneWidget);
  });
}
