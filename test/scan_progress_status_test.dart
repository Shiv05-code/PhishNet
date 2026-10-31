import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phishnet_app/widgets/scan_progress_status.dart';
import 'package:phishnet_app/widgets/swimming_fish.dart';

void main() {
  test('has several unique reassuring phrases', () {
    final phrases = ScanProgressStatus.phrases;
    expect(phrases.length, greaterThanOrEqualTo(6));
    expect(phrases.toSet().length, phrases.length);
  });

  testWidgets('shows the fish and changes phrases over time', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ScanProgressStatus())),
    );

    expect(find.byType(SwimmingFish), findsOneWidget);
    expect(find.text(ScanProgressStatus.phrases[0]), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(ScanProgressStatus.phrases[1]), findsOneWidget);
  });

  testWidgets('cancels the phrase timer and sweep when removed', (
    tester,
  ) async {
    // Mirrors Capture: the widget is only mounted while a scan is running.
    Widget host(bool scanning) => MaterialApp(
      home: Scaffold(
        body: scanning ? const ScanProgressStatus() : const SizedBox(),
      ),
    );

    await tester.pumpWidget(host(true));
    await tester.pumpWidget(host(false));

    // A still-active timer or ticker would fail the test on teardown.
    await tester.pump(const Duration(seconds: 5));
    expect(find.byType(ScanProgressStatus), findsNothing);
  });
}
