import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/scan_result.dart';
import 'image_text_reader.dart';
import 'scan_service.dart';

/// One line in the conversation.
class ChatMessage {
  const ChatMessage({
    required this.fromUser,
    required this.text,
    this.imagePath,
    this.riskLevel,
  });

  final bool fromUser;
  final String text;

  /// A photo the user attached. Kept only on this phone.
  final String? imagePath;

  /// Set only on a scan summary: 'high', 'medium' or 'low'. Null for chat answers.
  final String? riskLevel;
}

/// The scan a conversation is about: the message that was checked and
/// PhishNet's assessment of it. Both are optional on the backend.
class ChatScanContext {
  const ChatScanContext({required this.message, this.assessment, this.result});

  final String message;
  final Map<String, dynamic>? assessment;

  /// The scan itself, when the app has it. Chat uses it to show the summary.
  final ScanResult? result;

  /// The context for a fresh scan, in the shape the backend expects.
  factory ChatScanContext.fromResult(String message, ScanResult result) =>
      ChatScanContext(
        message: message,
        result: result,
        assessment: {
          'risk_level': result.riskLevel,
          'scam_percentage': result.scamPercentage,
          'summary': result.summary,
          'red_flags': [
            for (var i = 0; i < result.redFlags.length; i++)
              {
                'label': i < result.redFlagLabels.length
                    ? result.redFlagLabels[i]
                    : '',
                'description': result.redFlags[i],
              },
          ],
          'next_steps': result.nextSteps,
        },
      );

  Map<String, dynamic> toJson() => {
    'message': message,
    if (assessment != null) 'assessment': assessment,
  };
}

typedef AnalyzeMessage = Future<ScanResult> Function(String message);

typedef IdTokenProvider = Future<String?> Function();

Future<String?> _firebaseIdToken() async =>
    FirebaseAuth.instance.currentUser?.getIdToken();

/// Talks to the PhishNet Lambda (`action: chat`) and keeps the conversation
/// in memory, so it is still there when the user leaves Chat and comes back.
class ChatService extends ChangeNotifier {
  ChatService({
    http.Client? client,
    IdTokenProvider? idToken,
    String? endpoint,
    AnalyzeMessage? analyze,
    TextFromImage? readText,
    this.timeout = const Duration(seconds: 35),
  }) : _client = client ?? http.Client(),
       _idToken = idToken ?? _firebaseIdToken,
       _analyzeOverride = analyze,
       _readText = readText ?? readTextFromImageFile,
       _endpoint =
           endpoint ??
           const String.fromEnvironment(
             'SCAN_API_URL',
             defaultValue:
                 'https://i2wkmhdclm5epiws4k53bcv35e0jcpmb.lambda-url.us-east-2.on.aws/',
           );

  static final ChatService instance = ChatService();

  /// The backend keeps the last 10 turns; sending more is wasted bytes.
  static const maxHistory = 10;
  static const maxQuestionLength = 1000;
  static const genericError =
      'We couldn\'t answer that right now. Please try again.';
  static const offlineError =
      'We couldn\'t reach PhishNet. Check your internet and try again.';
  static const signInError = 'Please sign in again, then try your question.';
  static const noTextError =
      'We couldn\'t find any text in that photo. Try a clearer screenshot.';
  static const imageError =
      'We couldn\'t read that photo. Please try a different one.';

  /// What the user's side of the conversation shows for a photo.
  static const photoText = 'Photo attached';

  /// The scan endpoint accepts at most this many characters.
  static const maxScanLength = 8000;

  final http.Client _client;
  final IdTokenProvider _idToken;
  final String _endpoint;
  final AnalyzeMessage? _analyzeOverride;
  final TextFromImage _readText;
  final Duration timeout;

  // Made on first use, so nothing touches Firebase until a photo is sent.
  ScanService? _scanService;
  Future<ScanResult> _analyze(String message) =>
      (_analyzeOverride ?? (_scanService ??= ScanService()).analyzeMessage)(
        message,
      );

  final List<ChatMessage> _messages = [];
  ChatScanContext? _scan;
  bool _sending = false;
  String? _error;
  String? _pendingQuestion;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  ChatScanContext? get scan => _scan;
  bool get sending => _sending;

  /// Plain-language error for the last failed question, or null.
  String? get error => _error;
  bool get canRetry => _error != null && _pendingQuestion != null;

  /// Call when Chat opens. Opening from a different scan starts a fresh
  /// conversation about it; opening with no scan (e.g. from the menu) keeps
  /// whatever conversation is already there.
  void openFor(ChatScanContext? scan) {
    if (scan == null) return;
    if (_scan?.message == scan.message) return;
    _messages.clear();
    _scan = scan;
    _error = null;
    _pendingQuestion = null;
    final result = scan.result;
    if (result != null) {
      // Same summary as a photo scan, so every scan reads the same way in Chat.
      _messages.add(
        ChatMessage(
          fromUser: false,
          text: describeScan(result),
          riskLevel: result.riskLevel,
        ),
      );
    }
    notifyListeners();
  }

  /// Clears the conversation (e.g. "New chat").
  void reset() {
    _messages.clear();
    _scan = null;
    _error = null;
    _pendingQuestion = null;
    _sending = false;
    notifyListeners();
  }

  /// Returns false, without sending, when the question is empty or an
  /// answer is already on the way.
  Future<bool> ask(String question) async {
    final text = question.trim();
    if (text.isEmpty || _sending) return false;
    final clipped = text.length > maxQuestionLength
        ? text.substring(0, maxQuestionLength)
        : text;
    _messages.add(ChatMessage(fromUser: true, text: clipped));
    await _send(clipped);
    return true;
  }

  /// Reads the text in a photo on this phone, scans it, and makes that scan
  /// what the chat is about. Only the text is sent, never the photo.
  /// Returns false, without doing anything, if an answer is already on the way.
  /// On failure the photo is taken back out of the conversation and [error]
  /// says why, so the user can try again.
  ///
  /// With a [question], the photo and the question are sent together: the scan
  /// becomes the context and the model answers the question once, instead of
  /// the photo getting its own summary first.
  Future<bool> sendImage(String imagePath, {String? question}) async {
    if (_sending) return false;
    var typed = question?.trim() ?? '';
    if (typed.length > maxQuestionLength) {
      typed = typed.substring(0, maxQuestionLength);
    }
    final shown = ChatMessage(
      fromUser: true,
      text: typed.isEmpty ? photoText : typed,
      imagePath: imagePath,
    );
    _messages.add(shown);
    _sending = true;
    _error = null;
    _pendingQuestion = null;
    notifyListeners();
    try {
      String text;
      try {
        text = (await _readText(imagePath)).trim();
      } catch (_) {
        throw const _ChatFailure(imageError);
      }
      if (text.isEmpty) throw const _ChatFailure(noTextError);
      if (text.length > maxScanLength) text = text.substring(0, maxScanLength);
      final ScanResult result;
      try {
        result = await _analyze(text);
      } on ScanException catch (e) {
        throw _ChatFailure(e.message);
      }
      _scan = ChatScanContext.fromResult(text, result);
      if (typed.isEmpty) {
        _messages.add(
          ChatMessage(
            fromUser: false,
            text: describeScan(result),
            riskLevel: result.riskLevel,
          ),
        );
      }
    } on _ChatFailure catch (e) {
      _messages.remove(shown);
      _error = e.message;
    } finally {
      _sending = false;
      notifyListeners();
    }
    if (_error != null) return false;
    if (typed.isNotEmpty) {
      // The question goes to the model now, with the scan as its context.
      await _send(typed);
    }
    return _error == null;
  }

  /// A short plain-language summary of a scan, shown as PhishNet's reply.
  static String describeScan(ScanResult r) {
    final level = switch (r.riskLevel) {
      'high' => 'High risk',
      'medium' => 'Medium risk',
      _ => 'Low risk',
    };
    final icon = switch (r.riskLevel) {
      'high' => '🚨',
      'medium' => '⚠️',
      _ => '✅',
    };
    final pct = r.scamPercentage;
    final headline = pct == null ? level : '$level: $pct% likely a scam';
    final b = StringBuffer('**$icon $headline**');
    b.write('\n\n${r.summary}');
    final flags = r.redFlags.take(3).toList();
    if (flags.isNotEmpty) {
      b.write('\n\n**🚩 Red flags**');
      for (final f in flags) {
        b.write('\n• $f');
      }
    }
    final steps = r.nextSteps.take(2).toList();
    if (steps.isNotEmpty) {
      b.write('\n\n**👉 What to do**');
      for (final step in steps) {
        b.write('\n• $step');
      }
    }
    b.write('\n\n💬 Ask me anything about this message.');
    final out = b.toString();
    // The backend reads at most 2000 characters of each earlier turn.
    return out.length > 1900 ? '${out.substring(0, 1897)}...' : out;
  }

  /// Sends the last question again after an error, without repeating it
  /// in the conversation.
  Future<void> retry() async {
    final question = _pendingQuestion;
    if (question == null || _sending) return;
    await _send(question);
  }

  Future<void> _send(String question) async {
    _sending = true;
    _error = null;
    _pendingQuestion = question;
    notifyListeners();
    try {
      final answer = await _request(question);
      _messages.add(ChatMessage(fromUser: false, text: answer));
      _pendingQuestion = null;
    } on _ChatFailure catch (e) {
      _error = e.message;
    } finally {
      _sending = false;
      notifyListeners();
    }
  }

  // Turns before the question being asked (it is the last message in the
  // list, or the pending one on retry).
  List<Map<String, String>> _history() {
    final earlier = _messages.length > 1
        ? _messages.sublist(0, _messages.length - 1)
        : <ChatMessage>[];
    final recent = earlier.length > maxHistory
        ? earlier.sublist(earlier.length - maxHistory)
        : earlier;
    return [
      for (final m in recent)
        {'role': m.fromUser ? 'user' : 'assistant', 'content': m.text},
    ];
  }

  Future<String> _request(String question) async {
    if (_endpoint.isEmpty) throw const _ChatFailure(genericError);
    final String? token;
    try {
      token = await _idToken();
    } catch (_) {
      throw const _ChatFailure(signInError);
    }
    if (token == null) throw const _ChatFailure(signInError);

    final body = <String, dynamic>{
      'action': 'chat',
      'question': question,
      'history': _history(),
      if (_scan != null) 'scan': _scan!.toJson(),
    };

    final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(body),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const _ChatFailure(offlineError);
    } on SocketException {
      throw const _ChatFailure(offlineError);
    } on http.ClientException {
      throw const _ChatFailure(offlineError);
    }

    if (response.statusCode == 401) throw const _ChatFailure(signInError);
    if (response.statusCode != 200) throw const _ChatFailure(genericError);
    try {
      final data = jsonDecode(response.body);
      final answer = data is Map ? data['answer'] : null;
      if (answer is String && answer.trim().isNotEmpty) return answer.trim();
    } on FormatException {
      // fall through to the generic error
    }
    throw const _ChatFailure(genericError);
  }
}

class _ChatFailure implements Exception {
  const _ChatFailure(this.message);
  final String message;
}
