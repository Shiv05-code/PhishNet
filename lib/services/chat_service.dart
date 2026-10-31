import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:math';
import 'chat_history_repository.dart';

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

  /// Set only on a scan summary.
  final String? riskLevel;

  Map<String, dynamic> toJson() => {
    'fromUser': fromUser,
    'text': text,
    if (riskLevel != null) 'riskLevel': riskLevel,
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final fromUser = json['fromUser'];
    final text = json['text'];
    final riskLevel = json['riskLevel'];

    if (fromUser is! bool ||
        text is! String ||
        (riskLevel != null && riskLevel is! String)) {
      throw const FormatException('Invalid chat message.');
    }

    return ChatMessage(
      fromUser: fromUser,
      text: text,
      riskLevel: riskLevel as String?,
    );
  }
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

  factory ChatScanContext.fromJson(Map<String, dynamic> json) {
    final message = json['message'];
    final assessment = json['assessment'];

    if (message is! String || (assessment != null && assessment is! Map)) {
      throw const FormatException('Invalid chat scan context.');
    }

    return ChatScanContext(
      message: message,
      assessment: assessment == null
          ? null
          : Map<String, dynamic>.from(assessment),
    );
  }
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

  Map<String, dynamic> toJson() => {
    'title': title,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'messages': messages.map((message) => message.toJson()).toList(),
    'scan': scan?.toJson(),
  };

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final title = json['title'];
    final createdAt = json['createdAt'];
    final updatedAt = json['updatedAt'];
    final rawMessages = json['messages'];
    final rawScan = json['scan'];

    DateTime parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate().toUtc();
      if (value is DateTime) return value.toUtc();

      throw const FormatException('Invalid chat timestamp.');
    }

    final parsedCreatedAt = parseDate(createdAt);
    final parsedUpdatedAt = parseDate(updatedAt);

    if (id is! String ||
        id.isEmpty ||
        title is! String ||
        rawMessages is! List) {
      throw const FormatException('Invalid chat conversation.');
    }

    return ChatConversation(
      id: id,
      title: title,
      createdAt: parsedCreatedAt,
      updatedAt: parsedUpdatedAt,
      messages: rawMessages.map((item) {
        if (item is! Map) {
          throw const FormatException('Invalid conversation message.');
        }

        return ChatMessage.fromJson(Map<String, dynamic>.from(item));
      }).toList(),
      scan: rawScan == null
          ? null
          : ChatScanContext.fromJson(Map<String, dynamic>.from(rawScan as Map)),
    );
  }
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
    this._historyRepository,
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

  static final ChatService instance = ChatService(
    historyRepository: ChatHistoryRepository(),
  );

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
  final ChatHistoryRepository? _historyRepository;

  // Made on first use, so nothing touches Firebase until a photo is sent.
  ScanService? _scanService;
  Future<ScanResult> _analyze(String message) =>
      (_analyzeOverride ?? (_scanService ??= ScanService()).analyzeMessage)(
        message,
      );

  final List<ChatMessage> _messages = [];
  final List<ChatConversation> _conversations = [];

  String? _activeConversationId;

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

  String? _currentUserId;
  int _requestGeneration = 0;

  Future<void> _pendingChatSave = Future<void>.value();

  Future<void> _queueChatSave(ChatConversation conversation) {
    final repository = _historyRepository;
    final uid = _currentUserId;

    if (repository == null || uid == null) {
      return Future<void>.value();
    }

    final conversationId = conversation.id;
    final data = Map<String, dynamic>.from(conversation.toJson());

    final save = _pendingChatSave.then((_) async {
      if (_currentUserId != uid) return;

      await repository.saveChat(
        uid: uid,
        conversationId: conversationId,
        data: data,
      );
    });

    _pendingChatSave = save.catchError((Object error) {
      debugPrint('Could not save chat history: $error');
    });

    return save;
  }

  Future<void> loadSavedChats(String uid) async {
    final repository = _historyRepository;
    if (repository == null || uid.isEmpty) return;

    final generation = _requestGeneration;

    try {
      final saved = await repository.loadChats(uid);

      if (_currentUserId != uid || generation != _requestGeneration) {
        return;
      }

      final loaded = <ChatConversation>[];

      for (final data in saved) {
        try {
          loaded.add(ChatConversation.fromJson(data));
        } on FormatException {
          debugPrint('Skipping invalid saved chat.');
        }
      }

      final existingIds = _conversations.map((chat) => chat.id).toSet();

      for (final conversation in loaded) {
        if (!existingIds.contains(conversation.id)) {
          _conversations.add(conversation);
        }
      }

      _conversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

      notifyListeners();
    } catch (error) {
      debugPrint('Could not load saved chats: $error');
    }
  }

  /// Clears account-specific chat data when the signed-in user changes.
  /// Repeated events for the same user do not clear their conversations.
  void setAuthenticatedUser(String? uid) {
    if (_currentUserId == uid) return;

    _currentUserId = uid;
    _requestGeneration++;
    _sending = false;

    _messages.clear();
    _conversations.clear();
    _activeConversationId = null;
    _scan = null;
    _error = null;
    _pendingQuestion = null;

    notifyListeners();
  }

  String _generateConversationId() {
    final random = Random.secure();

    final bytes = List<int>.generate(16, (_) => random.nextInt(256));

    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  void _saveCurrentConversation() {
    if (_messages.isEmpty) return;

    final now = DateTime.now();

    if (_activeConversationId != null) {
      final index = _conversations.indexWhere(
        (conversation) => conversation.id == _activeConversationId,
      );

      if (index != -1) {
        final conversation = _conversations[index];

        conversation.messages
          ..clear()
          ..addAll(_messages);

        conversation.updatedAt = now;

        _conversations.removeAt(index);
        _conversations.insert(0, conversation);
        unawaited(_queueChatSave(conversation));
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
      id: _generateConversationId(),
      title: title,
      createdAt: now,
      updatedAt: now,
      messages: List.of(_messages),
      scan: _scan,
    );

    _conversations.insert(0, conversation);
    _activeConversationId = conversation.id;
    unawaited(_queueChatSave(conversation));
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

    final conversation = _conversations.firstWhere(
      (conversation) => conversation.id == id,
    );

    _messages
      ..clear()
      ..addAll(conversation.messages);

    _activeConversationId = conversation.id;
    _scan = conversation.scan;
    _error = null;
    _pendingQuestion = null;

    conversation.updatedAt = DateTime.now();

    _conversations.remove(conversation);
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

  void reset() {
    if (_sending) return;

    _saveCurrentConversation();

    _messages.clear();
    _activeConversationId = null;
    _scan = null;
    _error = null;
    _pendingQuestion = null;

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
    _saveCurrentConversation();
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
    final generation = _requestGeneration;

    _sending = true;
    _error = null;
    _pendingQuestion = question;
    notifyListeners();

    try {
      final answer = await _request(question);

      if (generation != _requestGeneration) return;

      _messages.add(ChatMessage(fromUser: false, text: answer));
      _saveCurrentConversation();
      _pendingQuestion = null;
    } on _ChatFailure catch (e) {
      if (generation != _requestGeneration) return;
      _error = e.message;
    } finally {
      if (generation == _requestGeneration) {
        _sending = false;
        notifyListeners();
      }
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
