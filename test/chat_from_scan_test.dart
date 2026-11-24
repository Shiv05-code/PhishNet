import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:phishnet_app/models/saved_scan.dart';
import 'package:phishnet_app/models/scan_result.dart';
import 'package:phishnet_app/screens/ai_chat_screen.dart';
import 'package:phishnet_app/screens/family_social_screen.dart';
import 'package:phishnet_app/services/chat_service.dart';
import 'package:phishnet_app/services/trusted_contacts_store.dart';

const _result = ScanResult(
  riskLevel: 'high',
  summary: 'This asks you to pay a fee.',
  scamPercentage: 90,
  redFlags: ['Urgent wording'],
  nextSteps: ['Do not click the link.'],
);

const _otherResult = ScanResult(
  riskLevel: 'low',
  summary: 'A normal reminder.',
  scamPercentage: 4,
  redFlags: [],
  nextSteps: [],
);

SavedScan _saved(String id, String description, ScanResult result) => SavedScan(
  id: id,
  description: description,
  createdAt: DateTime(2026, 11, 20),
  result: result,
);

ChatService _service({List<Map<String, dynamic>>? sent}) {
  return ChatService(
    endpoint: 'https://example.test/',
    idToken: () async => 'token-123',
    client: MockClient((request) async {
      sent?.add(jsonDecode(request.body) as Map<String, dynamic>);
      return http.Response(jsonEncode({'answer': 'ok'}), 200);
    }),
  );
}

class _EmptyContacts implements TrustedContactsStore {
  @override
  Future<List<TrustedContact>> load(String uid) async => const [];

  @override
  Future<void> save(String uid, List<TrustedContact> next) async {}
}

void main() {
  group('opening Chat about a scan', () {
    test('shows the original message above the assessment', () {
      final chat = _service();
      chat.openFor(
        ChatScanContext.fromResult('Pay \$1.99 at usps-fee.top', _result),
      );

      final text = chat.messages.single.text;
      expect(chat.messages.single.fromUser, isFalse);
      expect(text, contains('Your message'));
      expect(text, contains('Pay \$1.99 at usps-fee.top'));
      expect(
        text.indexOf('usps-fee.top'),
        lessThan(text.indexOf('90% likely a scam')),
      );
    });

    test('a saved scan shows its description, not made-up message text', () {
      final chat = _service();
      chat.openFor(
        ChatScanContext.fromSaved(
          _saved('a1', 'A bank text asks you.', _result),
        ),
      );

      final text = chat.messages.single.text;
      expect(text, contains('About this message'));
      expect(text, contains('A bank text asks you.'));
      expect(text, isNot(contains('Your message')));
    });

    test('a long message is shortened in the thread', () {
      final chat = _service();
      chat.openFor(ChatScanContext.fromResult('x' * 900, _result));

      expect(chat.messages.single.text.length, lessThanOrEqualTo(1900));
      expect(chat.messages.single.text, contains('...'));
    });

    test('opening Chat sends nothing, so it never counts toward the limit', () {
      final sent = <Map<String, dynamic>>[];
      final chat = _service(sent: sent);
      chat.openFor(ChatScanContext.fromSaved(_saved('a1', 'A text.', _result)));
      chat.openFor(ChatScanContext.fromResult('Hello there', _otherResult));

      expect(sent, isEmpty);
    });

    test('a scan already discussed continues the same conversation', () async {
      final chat = _service();
      final first = ChatScanContext.fromSaved(_saved('a1', 'A text.', _result));
      chat.openFor(first);
      await chat.ask('Is it safe?');
      final id = chat.conversations.single.id;

      // Look at a different scan, then come back to the first one.
      chat.openFor(
        ChatScanContext.fromSaved(_saved('b2', 'Another.', _otherResult)),
      );
      expect(chat.messages.length, 1);
      chat.openFor(ChatScanContext.fromSaved(_saved('a1', 'A text.', _result)));

      expect(chat.messages.length, 3); // summary, question, answer
      expect(chat.messages[1].text, 'Is it safe?');
      expect(chat.conversations.where((c) => c.id == id), hasLength(1));
      expect(chat.conversations.length, 2); // one per scan, no duplicates
    });

    test('the same message scanned again reopens its conversation', () async {
      final chat = _service();
      chat.openFor(ChatScanContext.fromResult('Pay the fee now', _result));
      await chat.ask('Is it safe?');
      chat.openFor(ChatScanContext.fromResult('Something else', _otherResult));
      chat.openFor(ChatScanContext.fromResult('Pay the fee now', _result));

      expect(chat.messages.length, 3);
      expect(chat.conversations.length, 2);
    });

    test('two saved scans with the same description stay separate', () {
      final chat = _service();
      chat.openFor(ChatScanContext.fromSaved(_saved('a1', 'A text.', _result)));
      chat.openFor(ChatScanContext.fromSaved(_saved('b2', 'A text.', _result)));

      expect(chat.scan?.scanId, 'b2');
      expect(chat.messages.length, 1);
    });
  });

  group('ChatScanContext', () {
    test('keeps the scan id and message kind when saved and loaded', () {
      final context = ChatScanContext.fromSaved(
        _saved('a1', 'A text.', _result),
      );
      final loaded = ChatScanContext.fromJson(
        Map<String, dynamic>.from(context.toJson()),
      );

      expect(loaded.scanId, 'a1');
      expect(loaded.messageIsOriginal, isFalse);
      expect(loaded.message, 'A text.');
    });

    test('older saved chats still load as original messages', () {
      final loaded = ChatScanContext.fromJson({'message': 'Old text'});

      expect(loaded.scanId, isNull);
      expect(loaded.messageIsOriginal, isTrue);
    });
  });

  group('Family/Social', () {
    testWidgets('Ask AI Chat is hidden until a message is chosen', (
      tester,
    ) async {
      await _pumpFamily(tester);

      expect(find.text('Ask AI Chat'), findsNothing);
    });

    testWidgets('Ask AI Chat opens Chat about the shown message', (
      tester,
    ) async {
      final chat = _service();
      await _pumpFamily(
        tester,
        result: _result,
        message: 'Pay the fee at usps-fee.top',
        chat: chat,
      );

      expect(find.text('Ask AI Chat'), findsOneWidget);
      await tester.ensureVisible(find.text('Ask AI Chat'));
      await tester.tap(find.text('Ask AI Chat'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(AiChatScreen), findsOneWidget);
      expect(chat.scan?.message, 'Pay the fee at usps-fee.top');
      expect(chat.messages.first.text, contains('Pay the fee at usps-fee.top'));
    });
  });
}

Future<void> _pumpFamily(
  WidgetTester tester, {
  ScanResult? result,
  String message = '',
  ChatService? chat,
}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: FamilySocialScreen(
        result: result,
        message: message,
        userId: 'user-1',
        contactsStore: _EmptyContacts(),
        pickContact: () async => null,
        chatService: chat,
      ),
    ),
  );
  await tester.pumpAndSettle();
}
