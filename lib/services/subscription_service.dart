import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

class SubscriptionService {
  static const bool allowSandboxSubscriptions =
      kDebugMode &&
      bool.fromEnvironment('ALLOW_APPLE_SANDBOX', defaultValue: false);
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

  DocumentReference<Map<String, dynamic>> get _sandboxSubscriptionRef {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('User must be logged in.');
    }

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('subscriptions')
        .doc('sandbox');
  }

  Stream<Map<String, dynamic>?> watchSandboxSubscription() {
    if (_auth.currentUser == null) {
      return Stream.value(null);
    }

    return _sandboxSubscriptionRef.snapshots().map(
      (snapshot) => snapshot.data(),
    );
  }

  Stream<Map<String, dynamic>?> watchEffectiveSubscription() {
    if (_auth.currentUser == null) {
      return Stream.value(null);
    }

    final controller = StreamController<Map<String, dynamic>?>();
    final productionStream = watchSubscription();

    if (!allowSandboxSubscriptions) {
      return productionStream;
    }

    Map<String, dynamic>? production;
    Map<String, dynamic>? sandbox;
    bool productionLoaded = false;
    bool sandboxLoaded = false;

    bool active(Map<String, dynamic>? data, String environment) {
      final expiresAt = data?['expiresAt'];

      return data?['plan'] == 'plus' &&
          data?['status'] == 'active' &&
          data?['environment'] == environment &&
          expiresAt is Timestamp &&
          expiresAt.toDate().isAfter(DateTime.now());
    }

    void publish() {
      if (!productionLoaded || !sandboxLoaded || controller.isClosed) {
        return;
      }

      if (active(production, 'production')) {
        controller.add(production);
      } else if (active(sandbox, 'sandbox')) {
        controller.add(sandbox);
      } else {
        controller.add(production ?? sandbox);
      }
    }

    late final StreamSubscription<Map<String, dynamic>?> productionSub;
    late final StreamSubscription<Map<String, dynamic>?> sandboxSub;

    controller.onListen = () {
      productionSub = productionStream.listen((value) {
        production = value;
        productionLoaded = true;
        publish();
      }, onError: controller.addError);

      sandboxSub = watchSandboxSubscription().listen((value) {
        sandbox = value;
        sandboxLoaded = true;
        publish();
      }, onError: controller.addError);
    };

    controller.onCancel = () async {
      await productionSub.cancel();
      await sandboxSub.cancel();
    };

    return controller.stream;
  }

  // Retrieve the current subscription.
  Future<Map<String, dynamic>?> getSubscription() async {
    if (_auth.currentUser == null) return null;
    final snapshot = await _subscriptionRef.get();
    return snapshot.data();
  }

  // Listen for subscription changes in real time.
  Stream<Map<String, dynamic>?> watchSubscription() {
    if (_auth.currentUser == null) return Stream.value(null);
    return _subscriptionRef.snapshots().map((snapshot) => snapshot.data());
  }

  // Check whether the user has an active Plus subscription.
  Future<bool> hasPlusAccess() async {
    final subscription = await getSubscription();

    if (subscription == null) return false;

    final isPlus = subscription['plan'] == 'plus';
    final isActive = subscription['status'] == 'active';

    const useEmulators = bool.fromEnvironment(
      'USE_FIREBASE_EMULATORS',
      defaultValue: false,
    );

    final environment = subscription['environment'];

    final validEnvironment =
        environment == 'production' ||
        (kDebugMode && useEmulators && environment == 'local_test');

    final expiresAt = subscription['expiresAt'];

    if (expiresAt is! Timestamp) return false;

    final notExpired = expiresAt.toDate().isAfter(DateTime.now());

    return isPlus && isActive && validEnvironment && notExpired;
  }
}
