import 'package:firebase_auth/firebase_auth.dart';
import 'package:phishnet_app/services/auth_service.dart';

/// In-memory [AuthService] so widget tests never touch Firebase.
class FakeAuthService extends AuthService {
  FakeAuthService({
    this.signedIn = false,
    this.verified = false,
    this.displayName,
  });

  String? displayName;

  @override
  String? get firstName => AuthService.firstNameFrom(displayName);

  bool signedIn;
  bool verified;
  final registeredEmails = <String>{};
  final passwords = <String, String>{};
  final resetCodes = <String, String>{}; // code -> email
  String? lastDisplayName;
  int resetEmailsSent = 0;
  FirebaseAuthException? nextError;

  void _throwIfQueued() {
    final error = nextError;
    nextError = null;
    if (error != null) throw error;
  }

  @override
  bool get hasVerifiedSession => signedIn && verified;

  @override
  bool get hasUnverifiedSession => signedIn && !verified;

  @override
  Future<void> createAccount({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    _throwIfQueued();
    if (registeredEmails.contains(email)) {
      throw FirebaseAuthException(code: 'email-already-in-use');
    }
    registeredEmails.add(email);
    passwords[email] = password;
    lastDisplayName = '$firstName $lastName';
    displayName = lastDisplayName;
    signedIn = true;
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    _throwIfQueued();
    if (passwords[email] != password) {
      throw FirebaseAuthException(code: 'invalid-credential');
    }
    signedIn = true;
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    _throwIfQueued();
    resetEmailsSent++;
  }

  @override
  Future<String> verifyPasswordResetCode(String code) async {
    _throwIfQueued();
    final email = resetCodes[code];
    if (email == null) throw FirebaseAuthException(code: 'expired-action-code');
    return email;
  }

  @override
  Future<void> confirmPasswordReset({
    required String code,
    required String newPassword,
  }) async {
    _throwIfQueued();
    final email = resetCodes.remove(code);
    if (email == null) throw FirebaseAuthException(code: 'invalid-action-code');
    passwords[email] = newPassword;
  }

  @override
  Future<void> sendVerificationEmail() async => _throwIfQueued();

  @override
  Future<bool> refreshEmailVerification() async {
    _throwIfQueued();
    return verified;
  }

  /// Simulates an account deleted in the Firebase Console.
  bool accountDeleted = false;

  @override
  Future<void> refreshSession() async {
    if (accountDeleted) signedIn = false;
  }

  @override
  Future<void> signOut() async => signedIn = false;
}
