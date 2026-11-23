// AuthRepository backed by Supabase Auth.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase/supabase.dart' hide AuthUser;

import '../config/env.dart';
import '../storage/device_store.dart';
import 'auth_repository.dart';

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._auth, this._store, this._functions) {
    _subscription = _auth.onAuthStateChange.listen(
      _onAuthState,
      // Refresh failures are also reported here; callers get them from the
      // awaited call, so the stream copy is ignored.
      onError: (Object _) {},
    );
  }

  static const String sessionKey = 'auth_session';

  /// Edge Function (`supabase/functions/delete-account`) that erases the
  /// signed-in user's data and login with the service role.
  static const String deleteAccountFunction = 'delete-account';

  /// User metadata key read by the e-mail templates (`{{ .Data.lang }}`).
  static const String languageMetadataKey = 'lang';

  final GoTrueClient _auth;
  final DeviceStore _store;
  final FunctionsClient _functions;
  final _userChanges = StreamController<AuthUser?>.broadcast();
  late final StreamSubscription<AuthState> _subscription;

  Future<void> _onAuthState(AuthState state) async {
    final session = state.session;
    if (state.event == AuthChangeEvent.signedOut || session == null) {
      await _store.delete(sessionKey);
      _userChanges.add(null);
    } else {
      await _store.write(sessionKey, jsonEncode(session.toJson()));
    }
  }

  @override
  Stream<AuthUser?> get userChanges => _userChanges.stream;

  @override
  Future<AuthUser?> restoreSession() async {
    final saved = await _store.read(sessionKey);
    if (saved == null) return null;
    final Session? session;
    try {
      session = Session.fromJson(jsonDecode(saved) as Map<String, dynamic>);
    } catch (_) {
      await _store.delete(sessionKey);
      return null;
    }
    if (session == null) {
      await _store.delete(sessionKey);
      return null;
    }
    // Refreshing needs the network; the driver stays logged in offline and
    // a revoked session is reported later through [userChanges].
    unawaited(_auth.recoverSession(saved).then((_) {}, onError: (_) {}));
    return _toUser(session.user);
  }

  @override
  Future<AuthUser> signIn(String email, String password) => _guard(() async {
        final response = await _auth.signInWithPassword(
            email: email.trim(), password: password);
        return _requireUser(response);
      });

  @override
  Future<AuthUser?> signUp(
    String email,
    String password, {
    required String firstName,
    required String lastName,
    required String languageCode,
  }) =>
      _guard(() async {
        final response = await _auth.signUp(
          email: email.trim(),
          password: password,
          data: {
            'first_name': firstName.trim(),
            'last_name': lastName.trim(),
            languageMetadataKey: languageCode,
          },
        );
        final user = response.user;
        // For an address that is already registered the server answers with
        // an obfuscated user that has no identities.
        if (user != null && (user.identities?.isEmpty ?? false)) {
          throw const AuthFailure(AuthFailureReason.emailInUse);
        }
        return response.session == null ? null : _requireUser(response);
      });

  @override
  Future<void> updateLanguage(String languageCode) async {
    if (_auth.currentUser?.userMetadata?[languageMetadataKey] == languageCode) {
      return;
    }
    try {
      await _auth.updateUser(
          UserAttributes(data: {languageMetadataKey: languageCode}));
    } catch (_) {
      // Only affects the language of future e-mails.
    }
  }

  @override
  Future<AuthUser> updateProfile({
    required String firstName,
    required String lastName,
  }) =>
      _guard(() async {
        final response = await _auth.updateUser(UserAttributes(data: {
          'first_name': firstName.trim(),
          'last_name': lastName.trim(),
        }));
        final user = response.user;
        if (user == null) {
          throw const AuthFailure(
              AuthFailureReason.unknown, 'no user returned');
        }
        return _toUser(user);
      });

  @override
  Future<AuthUser> confirmSignUp(String email, String code) => _guard(() async {
        final response = await _auth.verifyOTP(
          email: email.trim(),
          token: code.trim(),
          type: OtpType.signup,
        );
        return _requireUser(response);
      });

  @override
  Future<void> resendSignUpCode(String email) => _guard(() async {
        await _auth.resend(email: email.trim(), type: OtpType.signup);
      });

  @override
  Future<void> sendPasswordResetCode(String email) => _guard(() async {
        await _auth.resetPasswordForEmail(email.trim());
      });

  @override
  Future<AuthUser> resetPassword(
          String email, String code, String newPassword) =>
      _guard(() async {
        final response = await _auth.verifyOTP(
          email: email.trim(),
          token: code.trim(),
          type: OtpType.recovery,
        );
        final user = _requireUser(response);
        try {
          await _auth.updateUser(UserAttributes(password: newPassword));
        } on AuthException catch (e) {
          if (e.code != 'same_password') {
            // The code already opened a session; do not leave the driver
            // logged in with a password that was never changed.
            await _auth.signOut();
            rethrow;
          }
        }
        return user;
      });

  @override
  Future<void> ensureOnlineSession() => _guard(() async {
        final current = _auth.currentSession;
        if (current != null && !current.isExpired) return;
        final saved = await _store.read(sessionKey);
        if (saved == null) {
          throw const AuthFailure(AuthFailureReason.invalidCredentials);
        }
        await _auth.recoverSession(saved);
      });

  @override
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (_) {
      // Offline: the server-side token simply expires on its own.
    }
    await _store.delete(sessionKey);
  }

  @override
  Future<void> deleteAccount() async {
    await ensureOnlineSession();
    await _guard(() async {
      try {
        await _functions.invoke(deleteAccountFunction);
      } on FunctionException catch (e) {
        final reason = e.status == 401
            ? AuthFailureReason.invalidCredentials
            : AuthFailureReason.unknown;
        throw AuthFailure(reason, 'delete-account ${e.status}');
      }
    });
    await signOut();
  }

  Future<void> dispose() async {
    await _subscription.cancel();
    await _userChanges.close();
  }

  AuthUser _requireUser(AuthResponse response) {
    final user = response.session?.user ?? response.user;
    if (user == null) {
      throw const AuthFailure(AuthFailureReason.unknown, 'no user returned');
    }
    return _toUser(user);
  }

  AuthUser _toUser(User user) => toAuthUser(user);

  @visibleForTesting
  static AuthUser toAuthUser(User user) {
    return AuthUser(
      id: user.id,
      email: user.email ?? '',
      firstName: _nameOf(user.userMetadata?['first_name']),
      lastName: _nameOf(user.userMetadata?['last_name']),
    );
  }

  static String? _nameOf(Object? value) {
    final trimmed = value is String ? value.trim() : '';
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on AuthFailure {
      rethrow;
    } on AuthException catch (e) {
      throw AuthFailure(_reasonFor(e), e.message);
    } on SocketException catch (e) {
      throw AuthFailure(AuthFailureReason.network, e.message);
    } on http.ClientException catch (e) {
      throw AuthFailure(AuthFailureReason.network, e.message);
    } on TimeoutException catch (e) {
      throw AuthFailure(AuthFailureReason.network, e.message);
    }
  }

  static AuthFailureReason _reasonFor(AuthException e) {
    if (e is AuthRetryableFetchException) return AuthFailureReason.network;
    if (e is AuthWeakPasswordException) return AuthFailureReason.weakPassword;
    switch (e.code) {
      case 'invalid_credentials':
        return AuthFailureReason.invalidCredentials;
      case 'email_not_confirmed':
        return AuthFailureReason.emailNotConfirmed;
      case 'user_already_exists':
      case 'email_exists':
        return AuthFailureReason.emailInUse;
      case 'weak_password':
        return AuthFailureReason.weakPassword;
      case 'otp_expired':
      case 'otp_disabled':
        return AuthFailureReason.invalidCode;
      case 'over_email_send_rate_limit':
      case 'over_request_rate_limit':
        return AuthFailureReason.rateLimited;
    }
    if (e.statusCode == '429') return AuthFailureReason.rateLimited;
    return AuthFailureReason.unknown;
  }
}

/// Overridden in `main` with the values loaded from `.env`.
final envProvider = Provider<Env>(
  (ref) => throw UnimplementedError('envProvider must be overridden'),
);

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  final env = ref.watch(envProvider);
  final client = SupabaseClient(
    env.supabaseUrl,
    env.supabaseKey,
    // Codes typed into the app replace e-mail links, so no PKCE redirect.
    authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit),
  );
  ref.onDispose(client.dispose);
  return client;
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final repository = SupabaseAuthRepository(
    client.auth,
    ref.watch(deviceStoreProvider),
    client.functions,
  );
  ref.onDispose(repository.dispose);
  return repository;
});
