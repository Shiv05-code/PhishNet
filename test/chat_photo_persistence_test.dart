import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:phishnet_app/models/scan_result.dart';
import 'package:phishnet_app/services/chat_history_repository.dart';
import 'package:phishnet_app/services/chat_service.dart';

const _result = ScanResult(
  riskLevel: 'high',
  summary: 'This looks like a fake delivery notice.',
  scamPercentage: 90,
  redFlags: ['The link does not match USPS.'],
  redFlagLabels: ['Suspicious link'],
  nextSteps: ['Do not click the link.'],
);

const _photoText = 'Pay now at usps-redelivery.top';

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

ChatService _service(_Store store, {List<Map<String, dynamic>>? sent}) {
  return ChatService(
    endpoint: 'https://example.test/',
    idToken: () async => 'token',
    historyRepository: store,
    readText: (_) async => _photoText,
    analyze: (_) async => _result,
    client: MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      sent?.add(body);
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

Map<String, dynamic>? _saved(_Store store) =>
    store.chats.values.isEmpty ? null : store.chats.values.first;

void main() {
  test('a photo scanned in a new chat is saved right away', () async {
    final store = _Store();
    final chat = _service(store)..setAuthenticatedUser('user-a');

    expect(await chat.sendImage('/tmp/photo.png'), isTrue);

    await _until(() => _saved(store)?['scan'] != null);
    final saved = _saved(store)!;
    expect(saved['scan']['message'], _photoText);
    expect(saved['scan']['assessment']['risk_level'], 'high');
  });

  test('a photo scanned in an existing chat updates its saved scan', () async {
    final store = _Store();
    final chat = _service(store)..setAuthenticatedUser('user-a');

    await chat.ask('Hello, is this safe?');
    await _until(() => _saved(store) != null);
    expect(_saved(store)!['scan'], isNull);

    expect(await chat.sendImage('/tmp/photo.png'), isTrue);

    await _until(() => _saved(store)?['scan'] != null);
    expect(_saved(store)!['scan']['message'], _photoText);
    expect(_saved(store)!['scan']['assessment']['risk_level'], 'high');
  });

  test('the photo itself is never saved', () async {
    final store = _Store();
    final chat = _service(store)..setAuthenticatedUser('user-a');

    await chat.sendImage('/tmp/photo.png');
    await _until(() => _saved(store)?['scan'] != null);

    final messages = _saved(store)!['messages'] as List;
    expect(messages, isNotEmpty);
    expect(jsonEncode(messages), isNot(contains('/tmp/photo.png')));
    expect(jsonEncode(messages), isNot(contains('imagePath')));
  });

  test('reopening a saved photo chat sends its text and assessment', () async {
    final store = _Store();
    final first = _service(store)..setAuthenticatedUser('user-a');
    await first.ask('Hello, is this safe?');
    await first.sendImage('/tmp/photo.png');
    await _until(() => _saved(store)?['scan'] != null);

    final sent = <Map<String, dynamic>>[];
    final second = _service(store, sent: sent)..setAuthenticatedUser('user-a');
    await second.loadSavedChats('user-a');
    expect(second.conversations, hasLength(1));
    expect(second.openConversation(second.conversations.first.id), isTrue);

    await second.ask('What should I do now?');

    final request = sent.firstWhere((body) => body['action'] == 'chat');
    expect(request['scan']['message'], _photoText);
    expect(request['scan']['assessment']['risk_level'], 'high');
  });
}
