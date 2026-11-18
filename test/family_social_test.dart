import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phishnet_app/models/scan_result.dart';
import 'package:phishnet_app/screens/family_social_screen.dart';
import 'package:phishnet_app/services/message_composer.dart';
import 'package:phishnet_app/services/phone_number.dart';
import 'package:phishnet_app/services/trusted_contacts_store.dart';

class FakeMessageComposer implements MessageComposer {
  FakeMessageComposer({this.result = MessageComposeResult.sent});

  MessageComposeResult result;
  int calls = 0;
  String? recipient;
  String? body;

  @override
  Future<MessageComposeResult> compose({
    required String recipient,
    required String body,
    Uint8List? logo,
  }) async {
    calls++;
    this.recipient = recipient;
    this.body = body;
    return result;
  }
}

class FakeTrustedContactsStore implements TrustedContactsStore {
  FakeTrustedContactsStore({
    List<TrustedContact> initial = const [],
    this.loadError = false,
    this.saveError = false,
  }) : contacts = [...initial];

  List<TrustedContact> contacts;
  bool loadError;
  bool saveError;
  int saveCalls = 0;

  @override
  Future<List<TrustedContact>> load(String uid) async {
    if (loadError) throw Exception('load failed');
    return [...contacts];
  }

  @override
  Future<void> save(String uid, List<TrustedContact> next) async {
    saveCalls++;
    if (saveError) throw Exception('save failed');
    contacts = [...next];
  }
}

const _highRisk = ScanResult(
  riskLevel: 'high',
  summary: 'Suspicious',
  scamPercentage: 85,
  redFlags: [],
  nextSteps: [],
);

const _lowRisk = ScanResult(
  riskLevel: 'low',
  summary: 'Sunday dinner plans and a 5:30 pickup.',
  scamPercentage: 4,
  redFlags: [],
  nextSteps: [],
);

Future<void> _pump(
  WidgetTester tester, {
  ScanResult? result,
  String message = '',
  DateTime? receivedAt,
  String? userId = 'user-1',
  FakeTrustedContactsStore? store,
  Future<({String name, String? phone})?> Function()? pickContact,
  FakeMessageComposer? composer,
}) async {
  // Tall viewport so the lazy list builds every favorite row.
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: FamilySocialScreen(
        result: result,
        message: message,
        receivedAt: receivedAt,
        userId: userId,
        contactsStore: store ?? FakeTrustedContactsStore(),
        pickContact: pickContact ?? () async => null,
        messageComposer: composer ?? FakeMessageComposer(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

TrustedContact _contact(String id, String name, {String? phone}) =>
    TrustedContact(id: id, name: name, phone: phone);

void main() {
  group('phone numbers', () {
    test('normalizes common formats to E.164', () {
      expect(normalizePhoneNumber('(555) 123-4567'), '+15551234567');
      expect(normalizePhoneNumber('1 555 123 4567'), '+15551234567');
      expect(normalizePhoneNumber('+44 20 7946 0958'), '+442079460958');
    });

    test('rejects numbers that cannot be messaged', () {
      expect(normalizePhoneNumber(null), isNull);
      expect(normalizePhoneNumber('123'), isNull);
      expect(normalizePhoneNumber('hello'), isNull);
    });
  });

  test('defangLinks makes addresses non-clickable', () {
    expect(
      defangLinks('Go to citibank-verification.com now'),
      'Go to citibank-verification[.]com now',
    );
    expect(
      defangLinks('Visit https://evil.test/login?x=1'),
      'Visit hxxps[://]evil[.]test/login?x=1',
    );
    expect(defangLinks('Shared from PhishNet.'), 'Shared from PhishNet.');
  });

  test('shared text contains no live links', () {
    final text = buildFamilyShareText(
      result: const ScanResult(
        riskLevel: 'high',
        summary: 'Fake bank site at citibank-verification.com',
        scamPercentage: 95,
        redFlags: ['Link goes to citibank-verification.com'],
        nextSteps: [],
      ),
      message: 'Verify at https://citibank-verification.com/login',
      isOriginalText: true,
    );

    expect(text, isNot(contains('citibank-verification.com')));
    expect(text, isNot(contains('https://')));
    expect(text, contains('citibank-verification[.]com'));
  });

  test('boldUnicode converts letters only', () {
    expect(boldUnicode('HIGH RISK'), '𝐇𝐈𝐆𝐇 𝐑𝐈𝐒𝐊');
    expect(boldUnicode('85/100'), '85/100');
  });

  group('share text', () {
    test('low risk includes the verdict, score, and original text', () {
      final text = buildFamilyShareText(
        result: _lowRisk,
        message: 'Dinner is at 6, pickup at 5:30.',
        isOriginalText: true,
      );

      expect(
        text,
        contains('✅ ${boldUnicode('LOW RISK')} · 4/100 likely scam'),
      );
      expect(text, contains('PhishNet found no strong warning signs'));
      expect(text, contains('💬 ${boldUnicode('Message:')}'));
      expect(text, contains('"Dinner is at 6, pickup at 5:30."'));
      expect(text, isNot(contains('flagged this message')));
      expect(text, contains('🛡️ ${boldUnicode('PhishNet Scan Result')}'));
    });

    test('summary-only scans are labelled as a summary', () {
      final text = buildFamilyShareText(
        result: _lowRisk,
        message: 'A family member confirms Sunday dinner plans.',
        isOriginalText: false,
      );

      expect(text, contains('📝 ${boldUnicode('Summary:')}'));
      expect(text, isNot(contains('💬 ${boldUnicode('Message:')}')));
    });

    test('lists warning signs for risky messages', () {
      const risky = ScanResult(
        riskLevel: 'high',
        summary: 'Asks for payment.',
        scamPercentage: 90,
        redFlags: ['Urgent deadline', 'Odd link'],
        nextSteps: [],
      );

      final text = buildFamilyShareText(
        result: risky,
        message: '',
        isOriginalText: false,
      );

      expect(
        text,
        contains('🚨 ${boldUnicode('HIGH RISK')} · 90/100 likely scam'),
      );
      expect(text, contains('• Urgent deadline'));
      expect(text, contains('• Odd link'));
      expect(text, isNot(contains('💬 ${boldUnicode('Message:')}')));
    });

    test('no scan result says PhishNet did not score it', () {
      final text = buildFamilyShareText(message: 'Hi', isOriginalText: true);

      expect(text, contains('PhishNet has not scored this message.'));
    });
  });

  group('scan summary', () {
    testWidgets('shows no scan state instead of a fabricated score', (
      tester,
    ) async {
      await _pump(tester);

      expect(find.textContaining('No scan selected'), findsOneWidget);
      expect(find.text('85% likely scam'), findsNothing);
      expect(find.text('85/100'), findsNothing);
      expect(find.text('Date unavailable'), findsNothing);
    });

    testWidgets('shows unavailable score when scan has no percentage', (
      tester,
    ) async {
      const noScore = ScanResult(
        riskLevel: 'medium',
        summary: 'Unclear',
        redFlags: [],
        nextSteps: [],
      );

      await _pump(tester, result: noScore, message: 'Hi there');

      expect(find.text('Score unavailable'), findsOneWidget);
      expect(find.text('--/100'), findsOneWidget);
      expect(find.text('Date unavailable'), findsOneWidget);
      expect(find.text('“Hi there”'), findsOneWidget);
    });

    testWidgets('shows real score, risk label, and received time', (
      tester,
    ) async {
      final received = DateTime(2026, 11, 14, 13, 5);

      await _pump(
        tester,
        result: _highRisk,
        message: 'Verify your account now',
        receivedAt: received,
      );

      expect(find.text('85% likely scam'), findsOneWidget);
      expect(find.text('85/100'), findsOneWidget);
      expect(find.text('High Risk'), findsOneWidget);
      expect(
        find.text('Received ${formatReceivedAt(received)}'),
        findsOneWidget,
      );
    });

    testWidgets('shows up to three flagged reasons', (tester) async {
      const flagged = ScanResult(
        riskLevel: 'high',
        summary: 'Urgent',
        scamPercentage: 85,
        redFlags: [],
        redFlagLabels: ['Urgency', 'Suspicious Link', 'Payment', 'Extra'],
        nextSteps: [],
      );

      await _pump(tester, result: flagged, message: 'Act now');

      expect(find.text('PhishNet has flagged this message:'), findsOneWidget);
      expect(find.text('Urgency'), findsOneWidget);
      expect(find.text('Suspicious Link'), findsOneWidget);
      expect(find.text('Payment'), findsOneWidget);
      expect(find.text('Extra'), findsNothing);
    });

    testWidgets('hides flagged reasons when the scan has none', (tester) async {
      await _pump(tester, result: _lowRisk, message: 'Dinner at 6');

      expect(find.text('PhishNet has flagged this message:'), findsNothing);
    });

    testWidgets('Share with Family is an icon button', (tester) async {
      await _pump(tester, result: _lowRisk, message: 'Dinner at 6');

      expect(find.text('Share with Family'), findsOneWidget);
      expect(find.byIcon(Icons.ios_share_rounded), findsOneWidget);
    });
  });

  group('trusted contacts', () {
    testWidgets('empty state offers Add favorite', (tester) async {
      await _pump(tester);

      expect(find.textContaining('No favorites yet'), findsOneWidget);
      expect(find.text('Add favorite'), findsOneWidget);
    });

    testWidgets('signed-out users see a sign-in prompt, not a store call', (
      tester,
    ) async {
      final store = FakeTrustedContactsStore(initial: [_contact('a', 'Ada')]);
      await _pump(tester, userId: null, store: store);

      expect(find.textContaining('Sign in to save'), findsOneWidget);
      expect(find.text('Ada'), findsNothing);
      expect(find.text('Add favorite'), findsNothing);
    });

    testWidgets('loads and shows saved favorites with initials', (
      tester,
    ) async {
      final store = FakeTrustedContactsStore(
        initial: [_contact('a', 'Jack Feria'), _contact('b', 'Dhara')],
      );
      await _pump(tester, store: store);

      expect(find.text('Jack Feria'), findsOneWidget);
      expect(find.text('Dhara'), findsOneWidget);
      expect(find.text('JF'), findsOneWidget);
      expect(find.text('D'), findsOneWidget);
    });

    testWidgets('load failure shows retry', (tester) async {
      final store = FakeTrustedContactsStore(loadError: true);
      await _pump(tester, store: store);

      expect(find.text('Couldn’t load your favorites.'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('picking a contact adds it as a favorite', (tester) async {
      final store = FakeTrustedContactsStore();
      await _pump(
        tester,
        store: store,
        pickContact: () async =>
            (name: '  Payton Curry  ', phone: '(555) 123-4567'),
      );

      await tester.tap(find.text('Add favorite'));
      await tester.pumpAndSettle();

      expect(store.contacts.map((c) => c.name), ['Payton Curry']);
      expect(store.contacts.first.phone, '+15551234567');
      expect(find.text('Payton Curry'), findsOneWidget);
    });

    testWidgets('cancelling the picker changes nothing', (tester) async {
      final store = FakeTrustedContactsStore();
      await _pump(tester, store: store, pickContact: () async => null);

      await tester.tap(find.text('Add favorite'));
      await tester.pumpAndSettle();

      expect(store.saveCalls, 0);
    });

    testWidgets('picked contact without a name is rejected', (tester) async {
      final store = FakeTrustedContactsStore();
      await _pump(
        tester,
        store: store,
        pickContact: () async => (name: '   ', phone: '+15551234567'),
      );

      await tester.tap(find.text('Add favorite'));
      await tester.pumpAndSettle();

      expect(store.saveCalls, 0);
      expect(find.text('That contact has no name to save.'), findsOneWidget);
    });

    testWidgets('duplicate names are not added twice', (tester) async {
      final store = FakeTrustedContactsStore(initial: [_contact('a', 'Dhara')]);
      await _pump(
        tester,
        store: store,
        pickContact: () async => (name: 'dhara', phone: '+15551234567'),
      );

      await tester.tap(find.text('Add favorite'));
      await tester.pumpAndSettle();

      expect(store.saveCalls, 0);
      expect(find.text('That person is already in favorites.'), findsOneWidget);
    });

    testWidgets('list is capped at 5 and hides Add favorite', (tester) async {
      final store = FakeTrustedContactsStore(
        initial: [
          for (var i = 0; i < trustedContactsLimit; i++)
            _contact('$i', 'Person $i'),
        ],
      );
      await _pump(tester, store: store);

      expect(find.text('Add favorite'), findsNothing);
      expect(
        find.textContaining('reached $trustedContactsLimit'),
        findsOneWidget,
      );
    });

    testWidgets('Move down with the arrow reorders and saves', (tester) async {
      final store = FakeTrustedContactsStore(
        initial: [_contact('a', 'Ada'), _contact('b', 'Ben')],
      );
      await _pump(tester, store: store);

      await tester.tap(find.byTooltip('Move Ada down'));
      await tester.pumpAndSettle();

      expect(store.contacts.map((c) => c.name), ['Ben', 'Ada']);
    });

    testWidgets('swipe left, confirm Remove, deletes and shows a message', (
      tester,
    ) async {
      final store = FakeTrustedContactsStore(
        initial: [_contact('a', 'Ada'), _contact('b', 'Ben')],
      );
      await _pump(tester, store: store);

      await tester.drag(find.text('Ada'), const Offset(-600, 0));
      await tester.pumpAndSettle();
      expect(
        find.text('Would you like to remove this Contact?'),
        findsOneWidget,
      );

      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();

      expect(store.contacts.map((c) => c.name), ['Ben']);
      expect(find.text('Removed Ada from favorites.'), findsOneWidget);
    });

    testWidgets('swipe left then Cancel keeps the contact', (tester) async {
      final store = FakeTrustedContactsStore(initial: [_contact('a', 'Ada')]);
      await _pump(tester, store: store);

      await tester.drag(find.text('Ada'), const Offset(-600, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(store.saveCalls, 0);
      expect(find.text('Ada'), findsOneWidget);
    });

    testWidgets('failed save rolls back and shows an error', (tester) async {
      final store = FakeTrustedContactsStore(
        initial: [_contact('a', 'Ada')],
        saveError: true,
      );
      await _pump(tester, store: store);

      await tester.drag(find.text('Ada'), const Offset(-600, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();

      expect(find.text('Ada'), findsOneWidget);
      expect(
        find.text('Couldn’t save favorites. Please try again.'),
        findsOneWidget,
      );
    });

    testWidgets('Message is disabled until a scan message is selected', (
      tester,
    ) async {
      final store = FakeTrustedContactsStore(initial: [_contact('a', 'Ada')]);
      await _pump(tester, store: store);

      final button = tester.widget<TextButton>(
        find.ancestor(
          of: find.text('Message'),
          matching: find.byType(TextButton),
        ),
      );
      expect(button.onPressed, isNull);
    });
  });

  group('messaging a trusted contact', () {
    testWidgets('a contact with a number is messaged with the scan', (
      tester,
    ) async {
      final composer = FakeMessageComposer();
      await _pump(
        tester,
        result: _highRisk,
        message: 'Verify now',
        store: FakeTrustedContactsStore(
          initial: [_contact('a', 'Ada', phone: '+15551234567')],
        ),
        composer: composer,
      );

      await tester.tap(find.text('Message'));
      await tester.pumpAndSettle();

      expect(composer.calls, 1);
      expect(composer.recipient, '+15551234567');
      expect(composer.body, contains(boldUnicode('PhishNet Scan Result')));
      expect(composer.body, contains('Verify now'));
    });

    testWidgets('after sending, the row shows Resend and a checkmark', (
      tester,
    ) async {
      await _pump(
        tester,
        result: _highRisk,
        message: 'Verify now',
        store: FakeTrustedContactsStore(
          initial: [_contact('a', 'Ada', phone: '+15551234567')],
        ),
        composer: FakeMessageComposer(),
      );

      await tester.tap(find.text('Message'));
      await tester.pumpAndSettle();

      expect(find.text('Resend'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('cancelling Messages leaves the row unchanged', (tester) async {
      await _pump(
        tester,
        result: _highRisk,
        message: 'Verify now',
        store: FakeTrustedContactsStore(
          initial: [_contact('a', 'Ada', phone: '+15551234567')],
        ),
        composer: FakeMessageComposer(result: MessageComposeResult.cancelled),
      );

      await tester.tap(find.text('Message'));
      await tester.pumpAndSettle();

      expect(find.text('Message'), findsOneWidget);
      expect(find.text('Resend'), findsNothing);
    });

    testWidgets('a contact without a number cannot be messaged', (
      tester,
    ) async {
      final composer = FakeMessageComposer();
      await _pump(
        tester,
        result: _highRisk,
        message: 'Verify now',
        store: FakeTrustedContactsStore(initial: [_contact('a', 'Ada')]),
        composer: composer,
      );

      await tester.tap(find.text('Message'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(composer.calls, 0);
    });

    testWidgets('picking a contact with no number is rejected', (tester) async {
      final store = FakeTrustedContactsStore();
      await _pump(
        tester,
        store: store,
        pickContact: () async => (name: 'Ada', phone: null),
      );

      await tester.tap(find.text('Add favorite'));
      await tester.pumpAndSettle();

      expect(store.saveCalls, 0);
      expect(
        find.text('That contact needs a valid phone number to message.'),
        findsOneWidget,
      );
    });
  });
}
