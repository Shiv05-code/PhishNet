// Preview the AI Chat with sample answers, without Firebase or the backend.
//
//   flutter run -t lib/dev/chat_preview_main.dart
//
// Each question gets the next sample from mock_chat_responses.dart. The real
// ChatService runs; only its network call is replaced.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../screens/ai_chat_screen.dart';
import '../services/chat_service.dart';
import 'mock_chat_responses.dart';

void main() {
  var answered = 0;
  final client = MockClient((request) async {
    // Make the thinking state visible for a moment.
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    final sample = mockChatResponses[answered++ % mockChatResponses.length];
    return http.Response(jsonEncode({'answer': sample.answer}), 200);
  });

  runApp(
    MaterialApp(
      title: 'PhishNet chat preview',
      debugShowCheckedModeBanner: false,
      home: AiChatScreen(
        service: ChatService(
          endpoint: 'preview://mock',
          idToken: () async => 'preview',
          client: client,
        ),
      ),
    ),
  );
}
