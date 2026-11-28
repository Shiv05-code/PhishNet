import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:phishnet_app/models/scan_result.dart';
import 'package:phishnet_app/screens/ai_chat_screen.dart';
import 'package:phishnet_app/services/chat_service.dart';

const _result = ScanResult(
  riskLevel: 'high',
  summary: 'This asks you to pay a fee.',
  scamPercentage: 90,
  redFlags: ['Urgent wording'],
  nextSteps: ['Do not click the link.'],
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

/// Opens a chat about [_result] and asks until it is [ChatService.isLong].
Future<ChatService> _longChat({List<Map<String, dynamic>>? sent}) async {
  final chat = _service(sent: sent);
  chat.openFor(
    ChatScanContext.fromResult('Pay the fee at usps-fee.top', _result),
  );
  var n = 0;
  while (!chat.isLong) {
    n++;
    await chat.ask('Question $n');
  }
  return chat;
}

void main() {
  group('long conversations', () {
    test('a chat is long at 30 messages and not before', () async {
      final chat = _service();
      chat.openFor(ChatScanContext.fromResult('Hello there', _result));
      expect(chat.isLong, isFalse);

      while (chat.messages.length < ChatService.longChatLength - 1) {
        await chat.ask('More');
        if (chat.messages.length >= ChatService.longChatLength) break;
      }
      expect(chat.messages.length, greaterThanOrEqualTo(29));
      expect(chat.isLong, chat.messages.length >= ChatService.longChatLength);
    });

    test('a short chat cannot be continued', () {
      final chat = _service();
      chat.openFor(ChatScanContext.fromResult('Hello there', _result));

      expect(chat.continueInNewChat(), isFalse);
      expect(chat.messages, hasLength(1));
    });

    test('continuing keeps the old chat and the scan', () async {
      final chat = await _longChat();
      final oldLength = chat.messages.length;

      expect(chat.continueInNewChat(), isTrue);

      expect(chat.conversations, hasLength(1));
      expect(chat.conversations.single.messages, hasLength(oldLength));
      expect(chat.scan?.message, 'Pay the fee at usps-fee.top');
      expect(chat.messages.first.text, contains('Pay the fee at usps-fee.top'));
      expect(chat.messages, hasLength(2));
      expect(chat.isLong, isFalse);
    });

    test('the note lists the earlier questions and the last one', () async {
      final chat = await _longChat();
      final asked = chat.messages.where((m) => m.fromUser).length;

      chat.continueInNewChat();

      final note = chat.messages.last.text;
      expect(note, contains('Continued from an earlier chat'));
      expect(note, contains('Your last question'));
      expect(note, contains('“Question $asked”'));
      expect(note, contains('Question ${asked - 1}'));
      expect(note, isNot(contains('Question 1\n')));
      expect(note.length, lessThanOrEqualTo(1900));
    });

    test('long questions are shortened in the note', () {
      final note = ChatService.describeEarlierChat([
        ChatMessage(fromUser: true, text: 'q' * 500),
      ]);

      expect(note, contains('...'));
      expect(note.length, lessThan(400));
    });

    test('continuing sends nothing, so the limit is untouched', () async {
      final sent = <Map<String, dynamic>>[];
      final chat = await _longChat(sent: sent);
      final before = sent.length;

      chat.continueInNewChat();

      expect(sent.length, before);
    });

    test('the new chat can be continued with a question', () async {
      final sent = <Map<String, dynamic>>[];
      final chat = await _longChat(sent: sent);
      chat.continueInNewChat();

      await chat.ask('Is it safe now?');

      expect(chat.messages.last.fromUser, isFalse);
      expect(chat.conversations, hasLength(2));
    });
  });

  group('long chat notice', () {
    testWidgets('appears at 30 messages and starts a new chat', (tester) async {
      final chat = await _longChat();
      await tester.pumpWidget(
        MaterialApp(
          home: AiChatScreen(
            scan: ChatScanContext.fromResult(
              'Pay the fee at usps-fee.top',
              _result,
            ),
            service: chat,
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Start a new chat'), findsOneWidget);

      await tester.tap(find.text('Start a new chat'));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Start a new chat'), findsNothing);
      expect(chat.messages, hasLength(2));
    });

    testWidgets('is hidden in a short chat', (tester) async {
      final chat = _service();
      await tester.pumpWidget(
        MaterialApp(
          home: AiChatScreen(
            scan: ChatScanContext.fromResult('Hello there', _result),
            service: chat,
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Start a new chat'), findsNothing);
    });
  });
}
