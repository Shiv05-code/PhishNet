import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:phishnet_app/models/scan_result.dart';
import 'package:phishnet_app/services/chat_service.dart';

const _result = ScanResult(
  riskLevel: 'high',
  summary: 'This looks like a fake delivery notice.',
  scamPercentage: 90,
  redFlags: ['The link does not match USPS.'],
  redFlagLabels: ['Suspicious link'],
  nextSteps: ['Do not click the link.'],
);

ChatService makeService(List<Map<String, dynamic>> sent) {
  return ChatService(
    endpoint: 'https://example.test/',
    idToken: () async => 'token-123',
    readText: (_) async => 'Pay now at usps-redelivery.top',
    analyze: (_) async => _result,
    client: MockClient((request) async {
      sent.add(jsonDecode(request.body) as Map<String, dynamic>);
      return http.Response(jsonEncode({'answer': 'It looks risky.'}), 200);
    }),
  );
}

void main() {
  group('photo with a typed question', () {
    test('sends the photo text and the question together, once', () async {
      final sent = <Map<String, dynamic>>[];
      final chat = makeService(sent);

      expect(
        await chat.sendImage('/tmp/photo.png', question: 'Is this safe?'),
        isTrue,
      );

      // One request, carrying the question and the scanned text as context.
      expect(sent, hasLength(1));
      expect(sent.single['question'], 'Is this safe?');
      expect(sent.single['scan'], isNotNull);
      expect(sent.single['scan']['message'], 'Pay now at usps-redelivery.top');

      // One user bubble with the photo and the question, one answer, and no
      // separate scan summary before it.
      expect(chat.messages, hasLength(2));
      expect(chat.messages.first.fromUser, isTrue);
      expect(chat.messages.first.text, 'Is this safe?');
      expect(chat.messages.first.imagePath, '/tmp/photo.png');
      expect(chat.messages.last.text, 'It looks risky.');
    });

    test('photo alone still shows the scan summary', () async {
      final sent = <Map<String, dynamic>>[];
      final chat = makeService(sent);

      expect(await chat.sendImage('/tmp/photo.png'), isTrue);

      expect(sent, isEmpty);
      expect(chat.messages.first.text, ChatService.photoText);
      expect(chat.messages.last.riskLevel, 'high');
    });
  });
}
