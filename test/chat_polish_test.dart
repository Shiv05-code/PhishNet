import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:phishnet_app/models/scan_result.dart';
import 'package:phishnet_app/screens/ai_chat_screen.dart';
import 'package:phishnet_app/services/chat_service.dart';
import 'package:phishnet_app/widgets/chat_rich_text.dart';
import 'package:phishnet_app/widgets/chat_thinking.dart';

import 'support/test_helpers.dart';

const _answer = '## Warning signs\n- Do **not** click the link';

ChatService makeService({
  String reply = _answer,
  Future<void>? gate,
  List<String>? sentQuestions,
}) {
  return ChatService(
    endpoint: 'https://example.test/',
    idToken: () async => 'token-123',
    client: MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      sentQuestions?.add(body['question'] as String);
      if (gate != null) await gate;
      return http.Response(jsonEncode({'answer': reply}), 200);
    }),
  );
}

/// Lets the typing effect run to the end. pumpAndSettle can stop between
/// typing steps, so advance a fixed time instead.
Future<void> finishTyping(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
}

void main() {
  group('ChatRichText', () {
    testWidgets('shows headings, bullets and bold text without markers', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        const Scaffold(
          body: ChatRichText(
            text: '## Warning signs\n- Do **not** click\n\nStay calm.',
            color: Colors.black,
          ),
        ),
      );

      expect(find.text('Warning signs'), findsOneWidget);
      expect(find.text('•'), findsOneWidget);
      expect(find.textContaining('**'), findsNothing);
      expect(find.textContaining('##'), findsNothing);
      expect(find.text('Stay calm.'), findsOneWidget);

      final bold = find.byWidgetPredicate(
        (w) =>
            w is RichText &&
            w.text.toPlainText() == 'Do not click' &&
            _hasBoldSpan(w.text),
      );
      expect(bold, findsOneWidget);
    });
  });

  group('typing effect', () {
    testWidgets('reveals the answer progressively and can be skipped', (
      tester,
    ) async {
      final chat = makeService(reply: 'Hello there. This is a longer answer.');
      await pumpScreen(tester, AiChatScreen(service: chat));
      await tester.enterText(find.byType(TextField), 'Hi');
      await tester.tap(find.byTooltip('Send question'));
      // Early in the typing: not the whole answer yet.
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Hello there. This is a longer answer.'), findsNothing);
      expect(find.text('Show all'), findsOneWidget);

      await tapOn(tester, find.text('Show all'));
      expect(
        find.text('Hello there. This is a longer answer.'),
        findsOneWidget,
      );
      expect(find.text('Show all'), findsNothing);
      expect(find.text('Copy answer'), findsOneWidget);
    });

    testWidgets('reduced motion shows the full answer at once', (tester) async {
      final chat = makeService(reply: 'Full answer now.');
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: AiChatScreen(service: chat),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'Hi');
      await tapOn(tester, find.byTooltip('Send question'));
      await tester.pump();

      expect(find.text('Full answer now.'), findsOneWidget);
      expect(find.text('Show all'), findsNothing);
    });

    testWidgets('answer is never duplicated in the conversation', (
      tester,
    ) async {
      final chat = makeService(reply: 'Only once.');
      await pumpScreen(tester, AiChatScreen(service: chat));
      await tester.enterText(find.byType(TextField), 'Hi');
      await tapOn(tester, find.byTooltip('Send question'));
      await finishTyping(tester);

      expect(find.text('Only once.'), findsOneWidget);
      expect(chat.messages.where((m) => !m.fromUser), hasLength(1));
    });
  });

  group('thinking state', () {
    testWidgets('shows changing status phrases, not the fish', (tester) async {
      final gate = Completer<void>();
      final chat = makeService(gate: gate.future);
      await pumpScreen(tester, AiChatScreen(service: chat));
      await tester.enterText(find.byType(TextField), 'Hi');
      await tester.tap(find.byTooltip('Send question'));
      await tester.pump();

      expect(find.byType(ChatThinking), findsOneWidget);
      expect(find.text(ChatThinking.phrases.first), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 2500));
      expect(find.text(ChatThinking.phrases[1]), findsOneWidget);

      gate.complete();
      await finishTyping(tester);
      expect(find.byType(ChatThinking), findsNothing);
    });
  });

  group('follow-up chips and copy', () {
    testWidgets('chips fill the input and do not send', (tester) async {
      final sent = <String>[];
      final chat = makeService(sentQuestions: sent);
      await pumpScreen(tester, AiChatScreen(service: chat));
      await tester.enterText(find.byType(TextField), 'Hi');
      await tapOn(tester, find.byTooltip('Send question'));
      await finishTyping(tester);

      await tapOn(tester, find.text('What should I do next?'));

      expect(sent, hasLength(1));
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'What should I do next?',
      );
    });

    testWidgets('copy puts the full answer on the clipboard', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final chat = makeService(reply: 'Copy me.');
      await pumpScreen(tester, AiChatScreen(service: chat));
      await tester.enterText(find.byType(TextField), 'Hi');
      await tapOn(tester, find.byTooltip('Send question'));
      await finishTyping(tester);

      await tapOn(tester, find.text('Copy answer'));

      expect(copied, 'Copy me.');
      expect(find.text('Copied'), findsOneWidget);
    });
  });

  group('risk verdict strip', () {
    testWidgets('a scan summary shows its verdict in words and icon', (
      tester,
    ) async {
      final chat = ChatService(
        readText: (_) async => 'Pay now at usps-redelivery.top',
        analyze: (_) async => const ScanResult(
          riskLevel: 'high',
          summary: 'Fake delivery notice.',
          scamPercentage: 90,
          redFlags: [],
          redFlagLabels: [],
          nextSteps: [],
        ),
        client: MockClient((_) async => http.Response('{}', 500)),
        endpoint: 'https://example.test/',
        idToken: () async => 'token',
      );
      await pumpScreen(tester, AiChatScreen(service: chat));
      expect(await chat.sendImage('/tmp/photo.png'), isTrue);
      await finishTyping(tester);

      expect(
        find.text('High risk. Do not click links or reply.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.gpp_bad_outlined), findsOneWidget);
    });
  });

  group('scan handoff from Results', () {
    testWidgets('opening Chat from a scan shows the same summary as a photo', (
      tester,
    ) async {
      final chat = makeService();
      const result = ScanResult(
        riskLevel: 'high',
        summary: 'Fake delivery notice.',
        scamPercentage: 90,
        redFlags: ['The link does not match USPS.'],
        redFlagLabels: ['Suspicious link'],
        nextSteps: ['Do not click the link.'],
      );
      await pumpScreen(
        tester,
        AiChatScreen(
          service: chat,
          scan: ChatScanContext.fromResult(
            'Pay at usps-redelivery.top',
            result,
          ),
        ),
      );
      await tester.pump();

      expect(
        find.text('High risk. Do not click links or reply.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('High risk: 90% likely a scam'),
        findsOneWidget,
      );
    });
  });

  group('attach menu', () {
    testWidgets('lists both photo sources with clear labels', (tester) async {
      await pumpScreen(tester, AiChatScreen(service: makeService()));
      await tapOn(tester, find.byTooltip('Add a photo'));

      expect(find.text('Add a photo'), findsOneWidget);
      expect(find.text('Choose from Camera Roll'), findsOneWidget);
      expect(find.text('Take Photo'), findsOneWidget);
    });
  });
}

bool _hasBoldSpan(InlineSpan span) {
  var bold = false;
  span.visitChildren((child) {
    if (child is TextSpan && child.style?.fontWeight == FontWeight.w700) {
      bold = true;
    }
    return !bold;
  });
  return bold;
}
