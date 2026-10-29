import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// One line in the conversation.
class ChatMessage {
  const ChatMessage({required this.fromUser, required this.text});

  final bool fromUser;
  final String text;
}

/// The scan a conversation is about: the message that was checked and
/// PhishNet's assessment of it. Both are optional on the backend.
class ChatScanContext {
  const ChatScanContext({required this.message, this.assessment});

  final String message;
  final Map<String, dynamic>? assessment;

  Map<String, dynamic> toJson() => {
    'message': message,
    if (assessment != null) 'assessment': assessment,
  };
}

class ChatConversation {
  ChatConversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.messages,
    this.scan,
  });

  final String id;
  String title;
  final DateTime createdAt;
  DateTime updatedAt;
  final List<ChatMessage> messages;
  final ChatScanContext? scan;
}

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
    this.timeout = const Duration(seconds: 35),
  }) : _client = client ?? http.Client(),
       _idToken = idToken ?? _firebaseIdToken,
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

  final http.Client _client;
  final IdTokenProvider _idToken;
  final String _endpoint;
  final Duration timeout;

  final List<ChatMessage> _messages = [];
  final List<ChatConversation> _conversations = [];

  String? _activeConversationId;
  int _nextConversationId = 0;

  List<ChatConversation> get conversations => List.unmodifiable(_conversations);

  String? get activeConversationId => _activeConversationId;
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
  void _saveCurrentConversation() {
    if (_messages.isEmpty) return;

    final now = DateTime.now();

    if (_activeConversationId != null) {
      final index = _conversations.indexWhere(
        (conversation) => conversation.id == _activeConversationId,
      );

      if (index != -1) {
        _conversations[index].messages
          ..clear()
          ..addAll(_messages);

        _conversations[index].updatedAt = now;
        return;
      }
    }

    final firstQuestion = _messages
        .where((message) => message.fromUser)
        .map((message) => message.text)
        .firstOrNull;

    final title = firstQuestion == null
        ? 'New Conversation'
        : firstQuestion.length > 40
        ? '${firstQuestion.substring(0, 40)}...'
        : firstQuestion;

    final conversation = ChatConversation(
      id: 'chat-${++_nextConversationId}',
      title: title,
      createdAt: now,
      updatedAt: now,
      messages: List.of(_messages),
      scan: _scan,
    );

    _conversations.insert(0, conversation);
    _activeConversationId = conversation.id;
  }

  bool startNewChat() {
    if (_sending) return false;

    _saveCurrentConversation();

    _messages.clear();
    _activeConversationId = null;
    _scan = null;
    _error = null;
    _pendingQuestion = null;

    notifyListeners();
    return true;
  }

  bool openConversation(String id) {
    if (_sending) return false;

    final index = _conversations.indexWhere(
      (conversation) => conversation.id == id,
    );

    if (index == -1) return false;

    if (_activeConversationId == id) return true;

    _saveCurrentConversation();

    final conversation = _conversations[index];

    _messages
      ..clear()
      ..addAll(conversation.messages);

    _activeConversationId = conversation.id;
    _scan = conversation.scan;
    _error = null;
    _pendingQuestion = null;

    conversation.updatedAt = DateTime.now();

    _conversations.removeAt(index);
    _conversations.insert(0, conversation);

    notifyListeners();
    return true;
  }

  /// Call when Chat opens. Opening from a different scan starts a fresh
  /// conversation about it; opening with no scan (e.g. from the menu) keeps
  /// whatever conversation is already there.
  void openFor(ChatScanContext? scan) {
    if (scan == null) return;
    if (_scan?.message == scan.message) return;
    if (_sending) return;

    _saveCurrentConversation();
    _activeConversationId = null;
    _messages.clear();
    _scan = scan;
    _error = null;
    _pendingQuestion = null;
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
