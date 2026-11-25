import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phishnet_app/services/subscription_service.dart';
import 'package:phishnet_app/widgets/plus_badge.dart';

Map<String, dynamic> _sub({
  String plan = 'plus',
  String status = 'active',
  String environment = 'production',
  DateTime? expires,
}) => {
  'plan': plan,
  'status': status,
  'environment': environment,
  'expiresAt': Timestamp.fromDate(
    expires ?? DateTime.now().add(const Duration(days: 30)),
  ),
};

void main() {
  group('SubscriptionService.isActivePlus', () {
    test('active production Plus is active', () {
      expect(SubscriptionService.isActivePlus(_sub()), isTrue);
    });

    test('free, expired, inactive, or missing records are not Plus', () {
      expect(SubscriptionService.isActivePlus(null), isFalse);
      expect(SubscriptionService.isActivePlus(_sub(plan: 'free')), isFalse);
      expect(
        SubscriptionService.isActivePlus(_sub(status: 'canceled')),
        isFalse,
      );
      expect(
        SubscriptionService.isActivePlus(
          _sub(expires: DateTime.now().subtract(const Duration(days: 1))),
        ),
        isFalse,
      );
      expect(
        SubscriptionService.isActivePlus(_sub(environment: 'sandbox')),
        isFalse,
      );
    });
  });

  group('PlusBadge', () {
    testWidgets('shows PLUS for an active Plus member', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PlusBadge(stream: Stream.value(_sub()))),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('PLUS'), findsOneWidget);
      expect(find.bySemanticsLabel('PhishNet Plus member'), findsOneWidget);
    });

    testWidgets('shows nothing for a free account', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlusBadge(stream: Stream.value(_sub(plan: 'free'))),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('PLUS'), findsNothing);
    });
  });
}
