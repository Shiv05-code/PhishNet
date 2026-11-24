import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:phishnet_app/screens/ai_chat_screen.dart';
import 'package:phishnet_app/services/chat_history_repository.dart';
import 'package:phishnet_app/services/chat_service.dart';
import 'package:phishnet_app/services/chat_time.dart';

import 'support/test_helpers.dart';

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

ChatService _service(_Store store) {
  return ChatService(
    endpoint: 'https://example.test/',
    idToken: () async => 'token',
    historyRepository: store,
    client: MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      if (body['action'] == 'chat_title') {
        return http.Response(jsonEncode({'title': 'Delivery text'}), 200);
      }
      return http.Response(jsonEncode({'answer': 'Stay away from it.'}), 200);
    }),
  );
}

/// Saves are queued in the background, so wait for one to land.
Future<void> _until(bool Function() done) async {
  for (var i = 0; i < 300 && !done(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(done(), isTrue, reason: 'timed out waiting for the saved chat');
}

void main() {
  group('formatChatTime', () {
    test('uses a 12-hour clock', () {
      expect(formatChatTime(DateTime(2026, 11, 24, 15, 42)), '3:42 PM');
      expect(formatChatTime(DateTime(2026, 11, 24, 9, 7)), '9:07 AM');
    });

    test('shows midnight and noon as 12', () {
      expect(formatChatTime(DateTime(2026, 11, 24, 0, 5)), '12:05 AM');
      expect(formatChatTime(DateTime(2026, 11, 24, 12, 0)), '12:00 PM');
    });
  });

  group('chatDayLabel', () {
    final now = DateTime(2026, 11, 24, 10, 30);

    test('says Today and Yesterday', () {
      expect(chatDayLabel(DateTime(2026, 11, 24, 0, 1), now: now), 'Today');
      expect(
        chatDayLabel(DateTime(2026, 11, 23, 23, 59), now: now),
        'Yesterday',
      );
    });

    test('uses the date for older days in the same year', () {
      expect(chatDayLabel(DateTime(2026, 11, 20, 8), now: now), 'Nov 20');
      expect(chatDayLabel(DateTime(2026, 1, 3, 8), now: now), 'Jan 3');
    });

    test('adds the year for another year', () {
      expect(chatDayLabel(DateTime(2025, 12, 31, 8), now: now), 'Dec 31, 2025');
    });

    test('Yesterday still works across a month boundary', () {
      final firstOfMonth = DateTime(2026, 12, 1, 9);
      expect(
        chatDayLabel(DateTime(2026, 11, 30, 20), now: firstOfMonth),
        'Yesterday',
      );
    });
  });

  group('ChatMessage sentAt', () {
    test('is saved as UTC text and read back', () {
      final sent = DateTime.utc(2026, 11, 24, 18, 42, 5);
      final json = ChatMessage(
        fromUser: true,
        text: 'Hi',
        sentAt: sent,
      ).toJson();

      expect(json['sentAt'], '2026-11-24T18:42:05.000Z');
      final back = ChatMessage.fromJson(json);
      expect(back.sentAt, sent);
    });

    test('is left out when a message has no time', () {
      final json = const ChatMessage(fromUser: true, text: 'Hi').toJson();
      expect(json.containsKey('sentAt'), isFalse);
    });

    test('a message saved before times were kept still loads', () {
      final message = ChatMessage.fromJson({'fromUser': false, 'text': 'Old'});
      expect(message.text, 'Old');
      expect(message.sentAt, isNull);
    });

    test('an unreadable time becomes null instead of failing', () {
      for (final bad in <Object>['not a time', 42, true, <String>[]]) {
        final message = ChatMessage.fromJson({
          'fromUser': true,
          'text': 'Hi',
          'sentAt': bad,
        });
        expect(message.sentAt, isNull, reason: '$bad');
      }
    });

    test('reads a Firestore timestamp', () {
      final sent = DateTime.utc(2026, 11, 24, 18, 42);
      final message = ChatMessage.fromJson({
        'fromUser': true,
        'text': 'Hi',
        'sentAt': Timestamp.fromDate(sent),
      });
      expect(message.sentAt, sent);
    });
  });

  group('ChatService', () {
    test('stamps messages and keeps the times on reopen', () async {
      final store = _Store();
      final before = DateTime.now().toUtc();
      final chat = _service(store)..setAuthenticatedUser('user-a');

      await chat.ask('Is this safe?');
      await _until(() => store.chats.values.isNotEmpty);
      await _until(
        () =>
            (store.chats.values.first['messages'] as List).length == 2 &&
            (store.chats.values.first['messages'] as List).every(
              (m) => (m as Map).containsKey('sentAt'),
            ),
      );

      for (final message in chat.messages) {
        expect(message.sentAt, isNotNull);
        expect(message.sentAt!.isBefore(before), isFalse);
      }

      final second = _service(store)..setAuthenticatedUser('user-a');
      await second.loadSavedChats('user-a');
      expect(second.openConversation(second.conversations.first.id), isTrue);

      expect(second.messages, hasLength(2));
      for (var i = 0; i < 2; i++) {
        expect(
          second.messages[i].sentAt!.isAtSameMomentAs(chat.messages[i].sentAt!),
          isTrue,
        );
      }
    });
  });

  group('AiChatScreen', () {
    Map<String, dynamic> saved(List<Map<String, dynamic>> messages) => {
      'title': 'Delivery text',
      'createdAt': DateTime.utc(2026, 1, 1),
      'updatedAt': DateTime.utc(2026, 1, 2),
      'messages': messages,
      'scan': null,
    };

    Future<ChatService> openSaved(
      WidgetTester tester,
      List<Map<String, dynamic>> messages,
    ) async {
      final store = _Store()..chats['user-a/chat-1'] = saved(messages);
      final chat = _service(store)..setAuthenticatedUser('user-a');
      await chat.loadSavedChats('user-a');
      expect(chat.openConversation('chat-1'), isTrue);
      await pumpScreen(tester, AiChatScreen(service: chat));
      await tester.pumpAndSettle();
      return chat;
    }

    testWidgets('shows a time on each message and a heading for each day', (
      tester,
    ) async {
      final now = DateTime.now();
      DateTime at(int daysAgo, int hour, int minute) =>
          DateTime(now.year, now.month, now.day - daysAgo, hour, minute);

      await openSaved(tester, [
        {
          'fromUser': true,
          'text': 'Is this a scam?',
          'sentAt': at(1, 9, 5).toUtc().toIso8601String(),
        },
        {
          'fromUser': false,
          'text': 'Yes, avoid it.',
          'sentAt': at(1, 9, 6).toUtc().toIso8601String(),
        },
        {
          'fromUser': true,
          'text': 'Any update?',
          'sentAt': at(0, 8, 30).toUtc().toIso8601String(),
        },
        {
          'fromUser': false,
          'text': 'Still no.',
          'sentAt': at(0, 8, 31).toUtc().toIso8601String(),
        },
      ]);

      expect(find.text('9:05 AM'), findsOneWidget);
      expect(find.text('9:06 AM'), findsOneWidget);
      expect(find.text('8:30 AM'), findsOneWidget);
      expect(find.text('8:31 AM'), findsOneWidget);
      expect(find.text('Yesterday'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
    });

    testWidgets('a chat saved before times were kept opens without them', (
      tester,
    ) async {
      await openSaved(tester, [
        {'fromUser': true, 'text': 'Is this a scam?'},
        {'fromUser': false, 'text': 'Yes, avoid it.'},
      ]);

      expect(find.text('Is this a scam?'), findsOneWidget);
      expect(find.text('Today'), findsNothing);
      expect(find.text('Yesterday'), findsNothing);
      expect(find.textContaining(RegExp(r'\d+:\d\d (AM|PM)')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a new question shows the time it was sent', (tester) async {
      final chat = _service(_Store())..setAuthenticatedUser('user-a');
      await pumpScreen(tester, AiChatScreen(service: chat));

      await tester.enterText(find.byType(TextField), 'Is this safe?');
      await tapOn(tester, find.byTooltip('Send question'));

      final sent = chat.messages.first.sentAt!;
      expect(find.text(formatChatTime(sent)), findsWidgets);
      expect(find.text('Today'), findsOneWidget);
    });
  });
}
