import 'package:cloud_firestore/cloud_firestore.dart';

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

    await _chats(uid).doc(conversationId).set(data);
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
