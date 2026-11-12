// Account access: sign in, sign up and password recovery. Passwords are
// only ever sent to the auth server over TLS; the server stores a salted
// hash and the app keeps nothing but the session token.
import 'package:flutter/foundation.dart';

@immutable
class AuthUser {
  const AuthUser({required this.id, required this.email});

  final String id;
  final String email;

  @override
  bool operator ==(Object other) =>
      other is AuthUser && other.id == id && other.email == email;

  @override
  int get hashCode => Object.hash(id, email);

  @override
  String toString() => 'AuthUser($id, $email)';
}

enum AuthFailureReason {
  invalidCredentials,
  emailNotConfirmed,
  emailInUse,
  weakPassword,
  invalidCode,
  rateLimited,
  network,
  unknown,
}

class AuthFailure implements Exception {
  const AuthFailure(this.reason, [this.detail]);

  final AuthFailureReason reason;
  final String? detail;

  @override
  String toString() => 'AuthFailure(${reason.name}, $detail)';
}

abstract class AuthRepository {
  /// The account saved on this device, if any. Works offline.
  Future<AuthUser?> restoreSession();

  /// Emits null when the server ends the session (e.g. revoked token).
  Stream<AuthUser?> get userChanges;

  Future<AuthUser> signIn(String email, String password);

  /// Creates the account. Returns the user when it is usable right away, or
  /// null when a confirmation code was e-mailed and must be passed to
  /// [confirmSignUp] first.
  Future<AuthUser?> signUp(String email, String password);

  Future<AuthUser> confirmSignUp(String email, String code);

  Future<void> resendSignUpCode(String email);

  Future<void> sendPasswordResetCode(String email);

  Future<AuthUser> resetPassword(String email, String code, String newPassword);

  /// Makes sure requests carry a valid token, refreshing it if needed.
  /// Throws [AuthFailure] when that is not possible (e.g. offline).
  Future<void> ensureOnlineSession();

  Future<void> signOut();
}

const int kMinPasswordLength = 8;

final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

bool isValidEmail(String value) => _emailPattern.hasMatch(value.trim());

bool isValidPassword(String value) => value.length >= kMinPasswordLength;

bool isValidCode(String value) => RegExp(r'^\d{6,10}$').hasMatch(value.trim());
