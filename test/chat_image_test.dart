import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:phishnet_app/models/scan_result.dart';
import 'package:phishnet_app/services/chat_service.dart';
import 'package:phishnet_app/services/scan_service.dart';

const _result = ScanResult(
  riskLevel: 'high',
  summary: 'This looks like a fake delivery notice.',
  scamPercentage: 90,
  redFlags: ['The link does not match USPS.'],
  redFlagLabels: ['Suspicious link'],
  nextSteps: ['Do not click the link.'],
);

ChatService makeService({
  required Future<String> Function(String) readText,
  Future<ScanResult> Function(String)? analyze,
  List<Map<String, dynamic>>? sent,
}) {
  return ChatService(
    endpoint: 'https://example.test/',
    idToken: () async => 'token',
    readText: readText,
    analyze: analyze ?? (_) async => _result,
    client: MockClient((request) async {
      sent?.add(jsonDecode(request.body) as Map<String, dynamic>);
      return http.Response(jsonEncode({'answer': 'Stay away from it.'}), 200);
    }),
  );
}

void main() {
  group('ChatService.sendImage', () {
    test('scans the text in the photo and chats about that scan', () async {
      final sent = <Map<String, dynamic>>[];
      final chat = makeService(
        readText: (_) async => '  Pay now at usps-redelivery.top  ',
        sent: sent,
      );

      expect(await chat.sendImage('/tmp/photo.png'), isTrue);

      expect(chat.messages.length, 2);
      expect(chat.messages.first.fromUser, isTrue);
      expect(chat.messages.first.imagePath, '/tmp/photo.png');
      expect(chat.messages.last.fromUser, isFalse);
      expect(chat.messages.last.text, contains('High risk: 90% likely a scam'));
      expect(chat.messages.last.text, contains('Do not click the link.'));
      expect(chat.scan!.message, 'Pay now at usps-redelivery.top');

      await chat.ask('Is it safe?');
      expect(sent.single['scan']['message'], 'Pay now at usps-redelivery.top');
      expect(sent.single['scan']['assessment']['risk_level'], 'high');
      expect(sent.single['history'].first, {
        'role': 'user',
        'content': ChatService.photoText,
      });
    });

    test('a photo with no text shows a message and leaves no bubble', () async {
      final chat = makeService(readText: (_) async => '   ');

      expect(await chat.sendImage('/tmp/photo.png'), isFalse);

      expect(chat.error, ChatService.noTextError);
      expect(chat.messages, isEmpty);
      expect(chat.sending, isFalse);
    });

    test('a photo that cannot be read shows a message', () async {
      final chat = makeService(readText: (_) async => throw Exception('bad'));

      expect(await chat.sendImage('/tmp/photo.png'), isFalse);

      expect(chat.error, ChatService.imageError);
      expect(chat.messages, isEmpty);
    });

    test('a failed scan shows its message and leaves no bubble', () async {
      final chat = makeService(
        readText: (_) async => 'hello',
        analyze: (_) async =>
            throw const ScanException('Please sign in before scanning.'),
      );

      expect(await chat.sendImage('/tmp/photo.png'), isFalse);

      expect(chat.error, 'Please sign in before scanning.');
      expect(chat.messages, isEmpty);
    });
  });
}
