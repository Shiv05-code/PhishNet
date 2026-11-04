import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:phishnet_app/services/chat_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phishnet_app/services/chat_history_repository.dart';

class FakeChatHistoryStore implements ChatHistoryStore {
  final Map<String, Map<String, dynamic>> chats = {};

  Completer<void>? pendingSave;
  bool failTitleUpdate = false;
  final titleUpdateAttempted = Completer<void>();

  String _key(String uid, String id) => '$uid/$id';

  @override
  Future<void> saveChat({
    required String uid,
    required String conversationId,
    required Map<String, dynamic> data,
  }) async {
    if (pendingSave != null) {
      await pendingSave!.future;
    }

    chats[_key(uid, conversationId)] = Map<String, dynamic>.from(data);
  }

  @override
  Future<void> updateChatTitle({
    required String uid,
    required String conversationId,
    required String title,
  }) async {
    if (!titleUpdateAttempted.isCompleted) {
      titleUpdateAttempted.complete();
    }
    if (failTitleUpdate) {
      throw Exception('Simulated Firestore title update failure');
    }

    final chat = chats[_key(uid, conversationId)];

    if (chat == null) return;

    chat['title'] = title;
  }

  @override
  Future<List<Map<String, dynamic>>> loadChats(String uid) async {
    return [
      for (final entry in chats.entries)
        if (entry.key.startsWith('$uid/'))
          {'id': entry.key.substring(uid.length + 1), ...entry.value},
    ];
  }

  @override
  Future<void> deleteChat({
    required String uid,
    required String conversationId,
  }) async {
    chats.remove(_key(uid, conversationId));
  }

  Future<void> waitForChatTitle({
    required String uid,
    required String conversationId,
    required String expectedTitle,
  }) async {
    final key = _key(uid, conversationId);

    while (chats[key]?['title'] != expectedTitle) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }
}

void main() {
  test('Failed title update preserves the conversation', () async {
    final store = FakeChatHistoryStore();
    store.failTitleUpdate = true;

    final titleAttempted = Completer<void>();

    final chat = ChatService(
      endpoint: 'https://example.test/',
      idToken: () async => 'test-token',
      historyRepository: store,
      client: MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;

        if (body['action'] == 'chat_title') {
          return http.Response(
            jsonEncode({'title': 'Suspicious USPS Delivery'}),
            200,
          );
        }

        return http.Response(
          jsonEncode({'answer': 'This message may be suspicious.'}),
          200,
        );
      }),
    );

    chat.setAuthenticatedUser('user-a');

    chat.addListener(() {
      if (chat.conversations.isNotEmpty &&
          chat.conversations.first.title == 'Suspicious USPS Delivery' &&
          !titleAttempted.isCompleted) {
        titleAttempted.complete();
      }
    });

    await chat.ask('I received a suspicious USPS delivery text.');

    await titleAttempted.future.timeout(const Duration(seconds: 5));

    await store.titleUpdateAttempted.future.timeout(const Duration(seconds: 5));

    final savedBeforeRollback = (await store.loadChats('user-a')).single;
    final originalTitle = savedBeforeRollback['title'] as String;

    if (chat.conversations.first.title != originalTitle) {
      final rollbackCompleted = Completer<void>();

      void onChatChanged() {
        if (chat.conversations.isNotEmpty &&
            chat.conversations.first.title == originalTitle &&
            !rollbackCompleted.isCompleted) {
          rollbackCompleted.complete();
        }
      }

      chat.addListener(onChatChanged);

      try {
        onChatChanged();

        await rollbackCompleted.future.timeout(const Duration(seconds: 5));
      } finally {
        chat.removeListener(onChatChanged);
      }
    }
    expect(chat.conversations.first.title, isNot('Suspicious USPS Delivery'));

    expect(chat.conversations.length, 1);
    expect(chat.messages.length, 2);
    expect(chat.error, isNull);

    final saved = (await store.loadChats('user-a')).single;

    expect(saved['title'], isNot('Suspicious USPS Delivery'));
    expect((saved['messages'] as List).length, 2);
  });
  test('Title update preserves messages and timestamps', () async {
    final store = FakeChatHistoryStore();

    final createdAt = DateTime.utc(2026, 11, 1, 10);
    final updatedAt = DateTime.utc(2026, 11, 1, 11);

    await store.saveChat(
      uid: 'user-a',
      conversationId: 'chat-1',
      data: {
        'title': 'Original title',
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'messages': [
          {'fromUser': true, 'text': 'USPS delivery message'},
        ],
      },
    );

    await store.updateChatTitle(
      uid: 'user-a',
      conversationId: 'chat-1',
      title: 'Suspicious USPS Delivery',
    );

    final saved = (await store.loadChats('user-a')).single;

    expect(saved['title'], 'Suspicious USPS Delivery');
    expect(saved['updatedAt'], updatedAt);
    expect(saved['createdAt'], createdAt);
    expect((saved['messages'] as List).length, 1);
  });
  test('Generated title survives overlapping conversation saves', () async {
    final store = FakeChatHistoryStore();
    final releaseSave = Completer<void>();
    final titleRequested = Completer<void>();
    final titleResponse = Completer<http.Response>();

    store.pendingSave = releaseSave;

    final chat = ChatService(
      endpoint: 'https://example.test/',
      idToken: () async => 'test-token',
      historyRepository: store,
      client: MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;

        if (body['action'] == 'chat_title') {
          if (!titleRequested.isCompleted) {
            titleRequested.complete();
          }
          return titleResponse.future;
        }

        return http.Response(
          jsonEncode({'answer': 'This message may be suspicious.'}),
          200,
        );
      }),
    );

    chat.setAuthenticatedUser('user-a');

    // Delay the first save.
    store.pendingSave = releaseSave;

    await chat.ask('I received a suspicious USPS delivery text.');
    await titleRequested.future;

    // Another message arrives while title generation is pending.
    await chat.ask('Should I click the link?');

    titleResponse.complete(
      http.Response(
        jsonEncode({'title': 'Suspicious USPS Delivery Text'}),
        200,
      ),
    );

    releaseSave.complete();

    await store.waitForChatTitle(
      uid: 'user-a',
      conversationId: chat.conversations.first.id,
      expectedTitle: 'Suspicious USPS Delivery Text',
    );

    final saved = (await store.loadChats('user-a')).single;

    expect(saved['title'], 'Suspicious USPS Delivery Text');
    expect((saved['messages'] as List).length, 4);
  });
}
