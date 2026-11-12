// E-mail and password the driver chose to remember on this device. They live
// in the OS keystore (Keychain, Keystore, Credential Manager), never in the
// plain device-state file.
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

@immutable
class SavedLogin {
  const SavedLogin({required this.email, required this.password});

  final String email;
  final String password;

  @override
  bool operator ==(Object other) =>
      other is SavedLogin && other.email == email && other.password == password;

  @override
  int get hashCode => Object.hash(email, password);
}

abstract class CredentialStore {
  Future<SavedLogin?> read();

  Future<void> write(SavedLogin login);

  Future<void> clear();
}

class SecureCredentialStore implements CredentialStore {
  SecureCredentialStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  static const String _emailKey = 'saved_login_email';
  static const String _passwordKey = 'saved_login_password';

  final FlutterSecureStorage _storage;

  @override
  Future<SavedLogin?> read() async {
    final email = await _storage.read(key: _emailKey);
    final password = await _storage.read(key: _passwordKey);
    if (email == null || password == null) return null;
    return SavedLogin(email: email, password: password);
  }

  @override
  Future<void> write(SavedLogin login) async {
    await _storage.write(key: _emailKey, value: login.email);
    await _storage.write(key: _passwordKey, value: login.password);
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _emailKey);
    await _storage.delete(key: _passwordKey);
  }
}

final credentialStoreProvider = Provider<CredentialStore>(
  (ref) => SecureCredentialStore(),
);
