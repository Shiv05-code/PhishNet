import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phishnet_app/services/chat_history_repository.dart';

void main() {
  group('Chat history timestamp protection', () {
    final older = DateTime.utc(2026, 10, 28, 10);
    final newer = DateTime.utc(2026, 10, 29, 10);

    test('Allows saving a new conversation', () {
      expect(
        shouldSaveChat(incomingUpdatedAt: newer, existingUpdatedAt: null),
        isTrue,
      );
    });

    test('Allows newer updates', () {
      expect(
        shouldSaveChat(
          incomingUpdatedAt: newer,
          existingUpdatedAt: Timestamp.fromDate(older),
        ),
        isTrue,
      );
    });

    test('Rejects older updates', () {
      expect(
        shouldSaveChat(
          incomingUpdatedAt: older,
          existingUpdatedAt: Timestamp.fromDate(newer),
        ),
        isFalse,
      );
    });

    test('Rejects equal timestamps', () {
      expect(
        shouldSaveChat(
          incomingUpdatedAt: newer,
          existingUpdatedAt: Timestamp.fromDate(newer),
        ),
        isFalse,
      );
    });

    test('Rejects invalid timestamps', () {
      expect(() => parseChatTimestamp('invalid'), throwsFormatException);
    });
  });
}
