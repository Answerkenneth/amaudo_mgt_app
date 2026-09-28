import 'package:firebase_auth/firebase_auth.dart' show AuthCredential;

/// Thrown for any auth/registration/recovery failure with a message
/// already safe to show directly in the UI.
class AuthException implements Exception {
  final String message;
  const AuthException(this.message);

  @override
  String toString() => message;
}

/// Thrown by AuthService.signInWithGoogle() when the Google account's
/// email already belongs to an existing phone+password account.
class GoogleLinkRequiredException implements Exception {
  final AuthCredential pendingGoogleCredential;
  final String authEmail;
  const GoogleLinkRequiredException({
    required this.pendingGoogleCredential,
    required this.authEmail,
  });
}