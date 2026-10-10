import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SubscriptionService {
  SubscriptionService._();

  static final SubscriptionService instance = SubscriptionService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Reference to the logged-in user's subscription.
  DocumentReference<Map<String, dynamic>> get _subscriptionRef {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('User must be logged in.');
    }

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('subscriptions')
        .doc('current');
  }

  // Retrieve the current subscription.
  Future<Map<String, dynamic>?> getSubscription() async {
    final snapshot = await _subscriptionRef.get();
    return snapshot.data();
  }

  // Listen for subscription changes in real time.
  Stream<Map<String, dynamic>?> watchSubscription() {
    return _subscriptionRef.snapshots().map((snapshot) => snapshot.data());
  }

  // Check whether the user has an active Plus subscription.
  Future<bool> hasPlusAccess() async {
    final subscription = await getSubscription();

    if (subscription == null) return false;

    final isPlus = subscription['plan'] == 'plus';
    final isActive = subscription['status'] == 'active';
    final isProduction = subscription['environment'] == 'production';

    final expiresAt = subscription['expiresAt'];

    if (expiresAt is! Timestamp) return false;

    final notExpired = expiresAt.toDate().isAfter(DateTime.now());

    return isPlus && isActive && isProduction && notExpired;
  }
}
