import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:phishnet_app/models/scan_result.dart';
import 'package:phishnet_app/screens/ai_chat_screen.dart';
import 'package:phishnet_app/services/chat_history_repository.dart';
import 'package:phishnet_app/services/chat_service.dart';
import 'package:phishnet_app/services/daily_limit.dart';
import 'package:phishnet_app/services/scan_service.dart';

import 'support/test_helpers.dart';

const _result = ScanResult(
  riskLevel: 'high',
  summary: 'This looks like a fake delivery notice.',
  scamPercentage: 90,
  redFlags: ['The link does not match USPS.'],
  redFlagLabels: ['Suspicious link'],
  nextSteps: ['Do not click the link.'],
);

/// Midnight tomorrow on this phone, as the backend would send it (in UTC).
String _tomorrowMidnight() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day + 1).toUtc().toIso8601String();
}

String _limitBody({String? resetsAt}) => jsonEncode({
  'error': 'daily_limit_reached',
  'message': 'You\'ve reached today\'s limit of 10 free requests.',
  'limit': 10,
  'resets_at': resetsAt ?? _tomorrowMidnight(),
  'retryable': false,
});

http.Response _limitResponse() => http.Response(_limitBody(), 429);
http.Response _answer(String text) =>
    http.Response(jsonEncode({'answer': text}), 200);

class _Store implements ChatHistoryStore {
  final Map<String, Map<String, dynamic>> chats = {};

  @override
  Future<void> saveChat({
    required String uid,
    required String conversationId,
    required Map<String, dynamic> data,
  }) async {
    chats['$uid/$conversationId'] = Map<String, dynamic>.from(data);
  }

  @override
  Future<void> updateChatTitle({
    required String uid,
    required String conversationId,
    required String title,
  }) async {
    chats['$uid/$conversationId']?['title'] = title;
  }

  @override
  Future<List<Map<String, dynamic>>> loadChats(String uid) async => [
    for (final e in chats.entries)
      if (e.key.startsWith('$uid/'))
        {'id': e.key.substring(uid.length + 1), ...e.value},
  ];

  @override
  Future<void> deleteChat({
    required String uid,
    required String conversationId,
  }) async {
    chats.remove('$uid/$conversationId');
  }
}

class _FakeUser extends Fake implements User {
  @override
  Future<String> getIdToken([bool forceRefresh = false]) async => 'token';
}

class _FakeAuth extends Fake implements FirebaseAuth {
  @override
  User? get currentUser => _FakeUser();
}

/// A chat service whose server answers with [reply] for every chat question.
ChatService _chat(
  http.Response Function() reply, {
  _Store? store,
  Future<ScanResult> Function(String)? analyze,
}) {
  final chat = ChatService(
    endpoint: 'https://example.test/',
    idToken: () async => 'token',
    historyRepository: store,
    readText: (_) async => 'Pay now at usps-redelivery.top',
    analyze: analyze ?? (_) async => _result,
    client: MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      if (body['action'] == 'chat_title') {
        return http.Response(jsonEncode({'title': 'Delivery text'}), 200);
      }
      return reply();
    }),
  );
  if (store != null) chat.setAuthenticatedUser('user-a');
  return chat;
}

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 50));

void main() {
  group('DailyLimitInfo', () {
    test('reads the limit answer from the backend', () {
      final info = DailyLimitInfo.fromBody(_limitBody())!;

      expect(info.limit, 10);
      expect(info.resetsAt, isNotNull);
    });

    test('ignores any other answer', () {
      expect(DailyLimitInfo.fromBody('{"error":"server_error"}'), isNull);
      expect(DailyLimitInfo.fromBody('{"Message":"Rate Exceeded"}'), isNull);
      expect(DailyLimitInfo.fromBody('not json'), isNull);
      expect(DailyLimitInfo.fromBody('[]'), isNull);
      expect(DailyLimitInfo.fromBody(''), isNull);
    });

    test('says tomorrow when usage resets after midnight', () {
      final info = DailyLimitInfo(limit: 10, resetsAt: DateTime(2026, 11, 13));

      expect(
        info.message(now: DateTime(2026, 11, 12, 10)),
        'You\'ve reached today\'s limit of 10 free requests. '
        'It resets tomorrow at 12:00 AM.',
      );
    });

    test('says today when the reset is later today', () {
      final info = DailyLimitInfo(
        limit: 10,
        resetsAt: DateTime(2026, 11, 12, 23, 30),
      );

      expect(
        info.message(now: DateTime(2026, 11, 12, 10)),
        endsWith('It resets today at 11:30 PM.'),
      );
    });

    test('shows noon and afternoon times on a 12-hour clock', () {
      final noon = DailyLimitInfo(resetsAt: DateTime(2026, 11, 12, 12, 5));
      final evening = DailyLimitInfo(resetsAt: DateTime(2026, 11, 12, 18, 0));

      expect(
        noon.message(now: DateTime(2026, 11, 12, 8)),
        contains('12:05 PM'),
      );
      expect(
        evening.message(now: DateTime(2026, 11, 12, 8)),
        contains('6:00 PM'),
      );
    });

    test('still explains the limit when the backend sends no details', () {
      const info = DailyLimitInfo();

      expect(
        info.message(),
        'You\'ve reached today\'s limit of free requests. It resets tomorrow.',
      );
    });
  });

  group('ScanService', () {
    ScanService service(http.Response response) => ScanService(
      auth: _FakeAuth(),
      endpoint: 'https://example.test/',
      client: MockClient((_) async => response),
    );

    test('a daily-limit answer becomes a limit error, not a retry', () async {
      try {
        await service(_limitResponse()).analyzeMessage('hello');
        fail('should have thrown');
      } on ScanException catch (e) {
        expect(e.dailyLimit, isNotNull);
        expect(e.dailyLimit!.limit, 10);
        expect(e.retryable, isFalse);
        expect(e.message, contains('10 free requests'));
        expect(e.message, contains('resets'));
      }
    });

    test('any other 429 is an ordinary error', () async {
      try {
        await service(
          http.Response('{"Message":"Rate Exceeded"}', 429),
        ).analyzeMessage('hello');
        fail('should have thrown');
      } on ScanException catch (e) {
        expect(e.dailyLimit, isNull);
        expect(e.message, 'Something went wrong. Please try again.');
      }
    });
  });

  group('ChatService', () {
    test(
      'a refused question leaves the chat and waits to be restored',
      () async {
        final chat = _chat(_limitResponse);

        await chat.ask('Is this safe?');

        expect(chat.dailyLimit, isNotNull);
        expect(chat.error, contains('10 free requests'));
        expect(chat.error, contains('resets'));
        expect(chat.canRetry, isFalse);
        expect(chat.sending, isFalse);
        expect(chat.messages, isEmpty);
        expect(chat.takeUnsentQuestion(), 'Is this safe?');
        expect(chat.takeUnsentQuestion(), isNull);
      },
    );

    test(
      'a refused first question does not leave a saved chat behind',
      () async {
        final store = _Store();
        final chat = _chat(_limitResponse, store: store);

        await chat.ask('Is this safe?');
        await _settle();

        expect(chat.conversations, isEmpty);
        expect(chat.activeConversationId, isNull);
        expect(store.chats, isEmpty);
      },
    );

    test('earlier messages stay when a later question is refused', () async {
      final store = _Store();
      var calls = 0;
      final chat = _chat(
        () => ++calls == 1 ? _answer('Stay calm.') : _limitResponse(),
        store: store,
      );

      await chat.ask('Hello');
      await chat.ask('Is this safe?');
      await _settle();

      expect(chat.messages.map((m) => m.text), ['Hello', 'Stay calm.']);
      expect(chat.takeUnsentQuestion(), 'Is this safe?');
      final saved = store.chats.values.single['messages'] as List;
      expect(saved.length, 2);
    });

    test('asking works again once usage has reset', () async {
      var blocked = true;
      final chat = _chat(
        () => blocked ? _limitResponse() : _answer('Fine now.'),
      );

      await chat.ask('Is this safe?');
      expect(chat.dailyLimit, isNotNull);

      blocked = false;
      await chat.ask(chat.takeUnsentQuestion()!);

      expect(chat.dailyLimit, isNull);
      expect(chat.error, isNull);
      expect(chat.messages.map((m) => m.text), ['Is this safe?', 'Fine now.']);
    });

    test(
      'Try again that hits the limit also hands the question back',
      () async {
        var calls = 0;
        final chat = _chat(
          () => ++calls == 1 ? http.Response('{}', 502) : _limitResponse(),
        );

        await chat.ask('Is this safe?');
        expect(chat.canRetry, isTrue);

        await chat.retry();

        expect(chat.dailyLimit, isNotNull);
        expect(chat.canRetry, isFalse);
        expect(chat.messages, isEmpty);
        expect(chat.takeUnsentQuestion(), 'Is this safe?');
      },
    );

    test('another 429 is just a generic error', () async {
      final chat = _chat(
        () => http.Response('{"Message":"Rate Exceeded"}', 429),
      );

      await chat.ask('Is this safe?');

      expect(chat.dailyLimit, isNull);
      expect(chat.error, ChatService.genericError);
      expect(chat.canRetry, isTrue);
      expect(chat.messages.length, 1);
      expect(chat.takeUnsentQuestion(), isNull);
    });

    test('a photo refused at the scan leaves no bubble', () async {
      final chat = _chat(
        () => _answer('unused'),
        analyze: (_) async => throw ScanException(
          DailyLimitInfo.fromBody(_limitBody())!.message(),
          dailyLimit: DailyLimitInfo.fromBody(_limitBody()),
        ),
      );

      expect(await chat.sendImage('/tmp/photo.png'), isFalse);

      expect(chat.dailyLimit, isNotNull);
      expect(chat.error, contains('10 free requests'));
      expect(chat.canRetry, isFalse);
      expect(chat.messages, isEmpty);
      expect(chat.scan, isNull);
    });

    test('a photo scanned just before the limit keeps its scan', () async {
      final chat = _chat(_limitResponse);

      final sent = await chat.sendImage(
        '/tmp/photo.png',
        question: 'Is this safe?',
      );

      expect(sent, isFalse);
      expect(chat.dailyLimit, isNotNull);
      // The scan already happened, so it and the photo's message are kept.
      expect(chat.scan!.message, 'Pay now at usps-redelivery.top');
      expect(chat.messages.single.imagePath, '/tmp/photo.png');
      expect(chat.takeUnsentQuestion(), isNull);
    });

    test('signing out clears the limit message', () async {
      final chat = _chat(_limitResponse);
      chat.setAuthenticatedUser('user-a');

      await chat.ask('Is this safe?');
      expect(chat.dailyLimit, isNotNull);

      chat.setAuthenticatedUser(null);

      expect(chat.dailyLimit, isNull);
      expect(chat.error, isNull);
      expect(chat.takeUnsentQuestion(), isNull);
    });
  });

  group('AiChatScreen', () {
    testWidgets('a refused question explains the reset and stays in the box', (
      tester,
    ) async {
      final chat = _chat(_limitResponse);
      await pumpScreen(tester, AiChatScreen(service: chat));

      await tester.enterText(find.byType(TextField), 'Is this safe?');
      await tapOn(tester, find.byTooltip('Send question'));

      expect(find.textContaining('10 free requests'), findsOneWidget);
      expect(
        find.textContaining('resets tomorrow at 12:00 AM'),
        findsOneWidget,
      );
      expect(find.text('Try again'), findsNothing);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'Is this safe?');
      expect(find.text('Is this safe?'), findsOneWidget);
    });
  });
}
