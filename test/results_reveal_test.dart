import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phishnet_app/models/scan_result.dart';
import 'package:phishnet_app/screens/results_screen.dart';

import 'support/test_helpers.dart';

const _result = ScanResult(
  riskLevel: 'high',
  summary: 'Several red flags were found.',
  scamPercentage: 85,
  redFlags: ['Urgent language.'],
  redFlagLabels: ['Urgent Language'],
  redFlagIcons: ['schedule'],
  nextSteps: ['Do not click any links.'],
);

Finder _ringPaint() => find.byWidgetPredicate(
  (w) => w is CustomPaint && w.size == const Size.square(86),
);

/// Reads the arc fraction from the score ring painter.
double _ringFraction(WidgetTester tester) {
  final painter = tester.widget<CustomPaint>(_ringPaint()).painter!;
  return (painter as dynamic).fraction as double;
}

void main() {
  testWidgets('reveals content immediately as it arrives', (tester) async {
    await pumpScreen(tester, const ResultsScreen(result: _result));
    await tester.pump();

    // Titles are present from the first frame; body copy types out.
    expect(find.text('This looks like a phishing attempt'), findsOneWidget);
    expect(find.text('Urgent Language'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text('Several red flags were found.'), findsNothing);
    expect(find.textContaining('Several'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('Several red flags were found.'), findsOneWidget);
    expect(find.text('Do not click any links.'), findsOneWidget);
  });

  testWidgets('animates the score ring from empty to the actual score', (
    tester,
  ) async {
    await pumpScreen(tester, const ResultsScreen(result: _result));
    await tester.pump();

    expect(_ringFraction(tester), 0);

    await tester.pumpAndSettle();

    expect(_ringFraction(tester), closeTo(0.85, 0.0001));
    expect(find.text('85/100'), findsOneWidget);
  });

  testWidgets('shows the final state at once when motion is reduced', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: MaterialApp(home: ResultsScreen(result: _result)),
      ),
    );
    await tester.pump();

    expect(_ringFraction(tester), closeTo(0.85, 0.0001));
    final fades = tester.widgetList<FadeTransition>(
      find.byType(FadeTransition),
    );
    expect(fades.every((f) => f.opacity.value == 1), isTrue);
  });
}
