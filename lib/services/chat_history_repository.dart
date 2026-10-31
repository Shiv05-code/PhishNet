import 'package:cloud_firestore/cloud_firestore.dart';

DateTime parseChatTimestamp(Object? value) {
  if (value is Timestamp) {
    return value.toDate().toUtc();
  }

  if (value is DateTime) {
    return value.toUtc();
  }

  throw const FormatException('Invalid chat timestamp.');
}

bool shouldSaveChat({
  required Object? incomingUpdatedAt,
  required Object? existingUpdatedAt,
}) {
  final incoming = parseChatTimestamp(incomingUpdatedAt);

  if (existingUpdatedAt == null) {
    return true;
  }

  final existing = parseChatTimestamp(existingUpdatedAt);

  return incoming.isAfter(existing);
}

class ChatHistoryRepository {
  ChatHistoryRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _chats(String uid) {
    if (uid.isEmpty || uid.contains('/')) {
      throw ArgumentError('Invalid user ID.');
    }

    return _firestore.collection('users').doc(uid).collection('chats');
  }

  Future<void> saveChat({
    required String uid,
    required String conversationId,
    required Map<String, dynamic> data,
  }) async {
    if (conversationId.isEmpty || conversationId.contains('/')) {
      throw ArgumentError('Invalid conversation ID.');
    }

    final updatedAt = data['updatedAt'];
    parseChatTimestamp(updatedAt);

    final ref = _chats(uid).doc(conversationId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);

      if (snapshot.exists) {
        final existingTime = snapshot.data()?['updatedAt'];

        if (!shouldSaveChat(
          incomingUpdatedAt: updatedAt,
          existingUpdatedAt: existingTime,
        )) {
          return;
        }
      }

      transaction.set(ref, data);
    });
  }

  Future<List<Map<String, dynamic>>> loadChats(String uid) async {
    final snapshot = await _chats(
      uid,
    ).orderBy('updatedAt', descending: true).get();

    return snapshot.docs.map((document) {
      return {'id': document.id, ...document.data()};
    }).toList();
  }

  Future<void> deleteChat({
    required String uid,
    required String conversationId,
  }) async {
    if (conversationId.isEmpty || conversationId.contains('/')) {
      throw ArgumentError('Invalid conversation ID.');
    }

    await _chats(uid).doc(conversationId).delete();
  }
}
