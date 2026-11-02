import 'package:firebase_auth/firebase_auth.dart';
import 'payment_backend_service.dart';
import 'session_timeout.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  AuthService({this._auth, SessionTimeout? sessionTimeout})
    : _sessionTimeout = sessionTimeout ?? SessionTimeout();

  final FirebaseAuth? _auth;
  final SessionTimeout _sessionTimeout;

  FirebaseAuth get _firebaseAuth => _auth ?? FirebaseAuth.instance;

  User? get currentUser => _firebaseAuth.currentUser;

  /// True when a signed-in user exists and has verified their email.
  bool get hasVerifiedSession => currentUser?.emailVerified ?? false;

  /// True when a signed-in user exists but has not verified their email.
  bool get hasUnverifiedSession =>
      currentUser != null && !currentUser!.emailVerified;

  /// First name for greetings, from the `displayName` saved at signup as
  /// "First Last". Returns null when no usable name is stored.
  String? get firstName => firstNameFrom(currentUser?.displayName);

  static String? firstNameFrom(String? displayName) {
    final parts = (displayName ?? '').trim().split(RegExp(r'\s+'));
    return parts.first.isEmpty ? null : parts.first;
  }

  Future<void> createAccount({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    final credential = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await credential.user?.updateDisplayName(
      '${firstName.trim()} ${lastName.trim()}'.trim(),
    );

    await credential.user?.reload();

    try {
      await PaymentBackendService.instance.initializeSubscription();
    } catch (error) {
      debugPrint('Subscription initialization deferred: $error');
    }
  }

  /// Re-checks a restored session with Firebase. Signs out if the account
  /// was deleted, disabled, or its session revoked; keeps it when offline.
  Future<void> refreshSession() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return;
    // Sessions left idle past the limit (including while the app was closed)
    // end here rather than being restored.
    if (await _sessionTimeout.hasExpired()) {
      await _sessionTimeout.clear();
      await signOut();
      return;
    }
    try {
      await user.reload();
    } on FirebaseAuthException catch (error) {
      if (error.code != 'network-request-failed') await signOut();
    }
  }

  Future<void> signIn({required String email, required String password}) {
    return _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Sends a reset email without revealing whether the account exists.
  /// Only errors unrelated to account existence (network, rate limits,
  /// malformed email) are rethrown.
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (error) {
      if (error.code == 'user-not-found' || error.code == 'user-disabled') {
        return;
      }
      rethrow;
    }
  }

  /// Validates a reset code and returns the email it belongs to.
  Future<String> verifyPasswordResetCode(String code) {
    return _firebaseAuth.verifyPasswordResetCode(code);
  }

  Future<void> confirmPasswordReset({
    required String code,
    required String newPassword,
  }) {
    return _firebaseAuth.confirmPasswordReset(
      code: code,
      newPassword: newPassword,
    );
  }

  Future<void> sendVerificationEmail() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw StateError('No signed-in user is available for verification.');
    }
    await user.sendEmailVerification();
  }

  Future<bool> refreshEmailVerification() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return false;
    await user.reload();
    return _firebaseAuth.currentUser?.emailVerified ?? false;
  }

  Future<void> deleteAccountAndData() async {
    final user = _firebaseAuth.currentUser;

    if (user == null) {
      throw StateError('No signed-in user is available.');
    }

    final db = FirebaseFirestore.instance;
    final userRef = db.collection('users').doc(user.uid);
    final batch = db.batch();

    for (final collectionName in ['scans', 'subscriptions', 'chats']) {
      final documents = await userRef.collection(collectionName).get();

      for (final document in documents.docs) {
        batch.delete(document.reference);
      }
    }

    batch.delete(userRef);

    await batch.commit();

    // Firebase may require the user to have signed in recently.
    await user.delete();
  }

  Future<void> signOut() => _firebaseAuth.signOut();

  static String messageFor(Object error) {
    if (error is! FirebaseAuthException) {
      return 'Something went wrong. Please try again.';
    }

    switch (error.code) {
      case 'email-already-in-use':
        return duplicateAccountMessage;
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'weak-password':
        return 'Choose a stronger password with at least 8 characters.';
      case 'invalid-credential':
      case 'user-not-found':
      case 'wrong-password':
        return 'Invalid email or password.';
      case 'user-disabled':
        return 'This account has been disabled. Contact support for help.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait and try again.';
      case 'network-request-failed':
        return 'No internet connection. Check your connection and try again.';
      case 'expired-action-code':
        return 'This reset link has expired. Request a new one.';
      case 'invalid-action-code':
        return 'This reset link is invalid or was already used. '
            'Request a new one.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }

  static const duplicateAccountMessage =
      'An account with this email already exists.';
}
