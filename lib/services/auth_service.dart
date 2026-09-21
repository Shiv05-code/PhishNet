import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  AuthService({this._auth});

  final FirebaseAuth? _auth;

  FirebaseAuth get _firebaseAuth => _auth ?? FirebaseAuth.instance;

  User? get currentUser => _firebaseAuth.currentUser;

  Future<UserCredential> createAccount({
    required String email,
    required String password,
  }) {
    return _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) {
    return _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> sendPasswordResetEmail(String email) {
    return _firebaseAuth.sendPasswordResetEmail(email: email);
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

  Future<void> signOut() => _firebaseAuth.signOut();

  static String messageFor(Object error) {
    if (error is! FirebaseAuthException) {
      return 'Something went wrong. Please try again.';
    }

    switch (error.code) {
      case 'email-already-in-use':
        return 'An account with this email already exists.';
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
      default:
        return 'Authentication failed. Please try again.';
    }
  }
}
