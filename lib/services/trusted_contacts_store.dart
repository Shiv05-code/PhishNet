import 'package:cloud_firestore/cloud_firestore.dart';

import 'phone_number.dart';

/// Maximum number of favorites a user can keep.
const int trustedContactsLimit = 5;

/// Longest name we store, matched by the Firestore rules.
const int trustedContactNameMaxLength = 40;

class TrustedContact {
  const TrustedContact({required this.id, required this.name, this.phone});

  final String id;
  final String name;

  /// E.164 phone number (for example +15551234567). Null when not saved.
  final String? phone;
}

abstract interface class TrustedContactsStore {
  /// Returns the user's favorites in saved order.
  Future<List<TrustedContact>> load(String uid);

  /// Replaces the user's favorites with [contacts], in order.
  Future<void> save(String uid, List<TrustedContact> contacts);
}

class TrustedContactsRepository implements TrustedContactsStore {
  TrustedContactsRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _contacts(String uid) {
    if (uid.isEmpty || uid.contains('/')) {
      throw ArgumentError('Invalid user ID.');
    }

    return _firestore
        .collection('users')
        .doc(uid)
        .collection('trustedContacts');
  }

  @override
  Future<List<TrustedContact>> load(String uid) async {
    final snapshot = await _contacts(
      uid,
    ).orderBy('order').limit(trustedContactsLimit).get();

    return snapshot.docs
        .map(
          (doc) => TrustedContact(
            id: doc.id,
            name: (doc.data()['name'] as String?) ?? '',
            phone: doc.data()['phone'] as String?,
          ),
        )
        .where((contact) => contact.name.isNotEmpty)
        .toList();
  }

  @override
  Future<void> save(String uid, List<TrustedContact> contacts) async {
    if (contacts.length > trustedContactsLimit) {
      throw ArgumentError('Too many trusted contacts.');
    }

    final collection = _contacts(uid);
    final existing = await collection.get();
    final keptIds = contacts.map((contact) => contact.id).toSet();

    final batch = _firestore.batch();

    for (final doc in existing.docs) {
      if (!keptIds.contains(doc.id)) {
        batch.delete(doc.reference);
      }
    }

    for (var i = 0; i < contacts.length; i++) {
      final contact = contacts[i];
      final name = contact.name.trim();
      if (name.isEmpty || name.length > trustedContactNameMaxLength) {
        throw ArgumentError('Invalid contact name.');
      }

      final phone = contact.phone == null
          ? null
          : normalizePhoneNumber(contact.phone);
      if (contact.phone != null && phone == null) {
        throw ArgumentError('Invalid phone number.');
      }

      batch.set(collection.doc(contact.id), {
        'name': name,
        'order': i,
        if (phone != null) 'phone': phone,
      });
    }

    await batch.commit();
  }
}
