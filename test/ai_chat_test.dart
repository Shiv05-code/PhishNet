import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:phishnet_app/screens/ai_chat_screen.dart';
import 'package:phishnet_app/services/chat_service.dart';

import 'support/test_helpers.dart';

ChatService makeService(
  Future<http.Response> Function(http.Request) handler, {
  List<Map<String, dynamic>>? sent,
}) {
  return ChatService(
    endpoint: 'https://example.test/',
    idToken: () async => 'token-123',
    client: MockClient((request) async {
      sent?.add(jsonDecode(request.body) as Map<String, dynamic>);
      return handler(request);
    }),
  );
}

http.Response answer(String text) =>
    http.Response(jsonEncode({'answer': text}), 200);

const scan = ChatScanContext(
  message: 'USPS: pay \$1.99 at usps-redelivery.top',
  assessment: {'risk_level': 'high', 'scam_percentage': 85},
);

void main() {
  group('ChatService', () {
    test('sends question, scan and history with the sign-in token', () async {
      final sent = <Map<String, dynamic>>[];
      late http.Request seen;
      final chat = makeService((r) async {
        seen = r;
        return answer('Please do not click it.');
      }, sent: sent);
      chat.openFor(scan);

      expect(await chat.ask('Is it safe?'), isTrue);
      expect(seen.headers['Authorization'], 'Bearer token-123');
      expect(sent.single['action'], 'chat');
      expect(sent.single['question'], 'Is it safe?');
      expect(sent.single['history'], isEmpty);
      expect(sent.single['scan']['message'], contains('usps-redelivery'));
      expect(sent.single['scan']['assessment']['risk_level'], 'high');

      await chat.ask('What if I clicked?');
      expect(sent.last['history'], [
        {'role': 'user', 'content': 'Is it safe?'},
        {'role': 'assistant', 'content': 'Please do not click it.'},
      ]);
      expect(chat.messages.length, 4);
    });

    test('empty question is not sent', () async {
      var calls = 0;
      final chat = makeService((_) async {
        calls++;
        return answer('x');
      });
      expect(await chat.ask('   '), isFalse);
      expect(calls, 0);
      expect(chat.messages, isEmpty);
    });

    test('server error shows a plain message and retry does not duplicate '
        'the question', () async {
      var fail = true;
      final sent = <Map<String, dynamic>>[];
      final chat = makeService((_) async {
        if (fail) return http.Response('{"error":"chat_unavailable"}', 502);
        return answer('Here you go.');
      }, sent: sent);

      await chat.ask('Hello?');
      expect(chat.error, ChatService.genericError);
      expect(chat.canRetry, isTrue);
      expect(chat.messages.length, 1);

      fail = false;
      await chat.retry();
      expect(chat.error, isNull);
      expect(chat.messages.map((m) => m.text), ['Hello?', 'Here you go.']);
      expect(sent.last['history'], isEmpty);
    });

    test('no internet gives the offline message', () async {
      final chat = ChatService(
        endpoint: 'https://example.test/',
        idToken: () async => 't',
        client: MockClient((_) async => throw const SocketException('down')),
      );
      await chat.ask('Hi');
      expect(chat.error, ChatService.offlineError);
    });

    test('401 asks the user to sign in again', () async {
      final chat = makeService((_) async => http.Response('{}', 401));
      await chat.ask('Hi');
      expect(chat.error, ChatService.signInError);
    });

    test('no signed-in user means no request', () async {
      var calls = 0;
      final chat = ChatService(
        endpoint: 'https://example.test/',
        idToken: () async => null,
        client: MockClient((_) async {
          calls++;
          return answer('x');
        }),
      );
      await chat.ask('Hi');
      expect(calls, 0);
      expect(chat.error, ChatService.signInError);
    });

    test('conversation survives, a different scan starts fresh', () async {
      final chat = makeService((_) async => answer('ok'));
      chat.openFor(scan);
      await chat.ask('One');
      chat.openFor(null); // back from the menu
      expect(chat.messages.length, 2);
      chat.openFor(scan); // same scan
      expect(chat.messages.length, 2);
      chat.openFor(const ChatScanContext(message: 'another message'));
      expect(chat.messages, isEmpty);
    });
  });

  group('AiChatScreen', () {
    testWidgets('shows the conversation and labels messages', (tester) async {
      final handle = tester.ensureSemantics();
      final chat = makeService((_) async => answer('Please do not click it.'));
      await pumpScreen(tester, AiChatScreen(scan: scan, service: chat));
      // Let the greeting finish typing out before checking the copy.
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Ask me about this message.'), findsOneWidget);
      expect(find.text('Is it safe to click?'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Is it safe?');
      await tapOn(tester, find.byTooltip('Send question'));

      expect(find.text('Is it safe?'), findsOneWidget);
      expect(find.text('Please do not click it.'), findsOneWidget);
      expect(find.bySemanticsLabel('You asked: Is it safe?'), findsOneWidget);
      expect(
        find.bySemanticsLabel('PhishNet answered: Please do not click it.'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('tapping a starter fills the input and does not send', (
      tester,
    ) async {
      var calls = 0;
      final chat = makeService((_) async {
        calls++;
        return answer('x');
      });
      await pumpScreen(tester, AiChatScreen(service: chat));
      await tester.pump(const Duration(seconds: 2));
      await tapOn(tester, find.text('I clicked a link'));

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(
        field.controller!.text,
        'What should I do if I already clicked a link?',
      );
      expect(calls, 0);
    });

    testWidgets('empty question explains what to do and sends nothing', (
      tester,
    ) async {
      var calls = 0;
      final chat = makeService((_) async {
        calls++;
        return answer('x');
      });
      await pumpScreen(tester, AiChatScreen(service: chat));
      await tapOn(tester, find.byTooltip('Send question'));
      expect(find.text('Please type a question first.'), findsOneWidget);
      expect(calls, 0);
    });

    testWidgets('error shows Try again and recovers', (tester) async {
      var fail = true;
      final chat = makeService((_) async {
        if (fail) return http.Response('{}', 502);
        return answer('Back again.');
      });
      await pumpScreen(tester, AiChatScreen(service: chat));
      await tester.enterText(find.byType(TextField), 'Hello');
      await tapOn(tester, find.byTooltip('Send question'));
      expect(find.text(ChatService.genericError), findsOneWidget);

      fail = false;
      await tapOn(tester, find.text('Try again'));
      expect(find.text(ChatService.genericError), findsNothing);
      expect(find.text('Back again.'), findsOneWidget);
    });

    testWidgets('conversation is still there when returning to Chat', (
      tester,
    ) async {
      final chat = makeService((_) async => answer('Stay calm.'));
      await pumpScreen(tester, AiChatScreen(service: chat));
      await tester.enterText(find.byType(TextField), 'Help');
      await tapOn(tester, find.byTooltip('Send question'));

      await pumpScreen(tester, const SizedBox());
      await pumpScreen(tester, AiChatScreen(service: chat));
      expect(find.text('Help'), findsOneWidget);
      expect(find.text('Stay calm.'), findsOneWidget);
    });

    testWidgets('text is at least 16pt', (tester) async {
      final chat = makeService((_) async => answer('Fine.'));
      await pumpScreen(tester, AiChatScreen(service: chat));
      await tester.enterText(find.byType(TextField), 'Hi');
      await tapOn(tester, find.byTooltip('Send question'));
      for (final t in tester.widgetList<Text>(find.byType(Text))) {
        final size = t.style?.fontSize;
        if (size != null) expect(size, greaterThanOrEqualTo(16));
      }
    });
  });
}
