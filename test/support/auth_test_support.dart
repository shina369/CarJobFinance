import 'dart:async';

import 'package:carjobfinance/core/auth/auth_repository.dart';
import 'package:carjobfinance/core/auth/supabase_auth_repository.dart';
import 'package:carjobfinance/core/backup/cloud_backup_repository.dart';
import 'package:carjobfinance/core/storage/device_store.dart';
import 'package:carjobfinance/data/datasources/local/backup_data.dart';
import 'package:carjobfinance/data/datasources/local/daos.dart';
import 'package:carjobfinance/presentation/controllers/controllers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const BackupData emptyBackup = BackupData(
  rides: [],
  expenses: [],
  settings: {},
  countryPlatforms: [],
);

const AuthUser testAccount = AuthUser(id: 'user-1', email: 'ana@example.com');

class FakeAuth implements AuthRepository {
  final StreamController<AuthUser?> _changes =
      StreamController<AuthUser?>.broadcast();

  AuthUser? current;
  AuthUser account = testAccount;
  bool signUpNeedsCode = false;

  /// Thrown by the next call that can fail, then cleared.
  AuthFailure? failure;
  final List<String> calls = [];

  void _maybeFail() {
    final pending = failure;
    if (pending != null) {
      failure = null;
      throw pending;
    }
  }

  @override
  Future<AuthUser?> restoreSession() async => current;

  @override
  Stream<AuthUser?> get userChanges => _changes.stream;

  @override
  Future<AuthUser> signIn(String email, String password) async {
    _maybeFail();
    calls.add('signIn:$email');
    return current = account;
  }

  @override
  Future<AuthUser?> signUp(String email, String password) async {
    _maybeFail();
    calls.add('signUp:$email');
    if (signUpNeedsCode) return null;
    return current = account;
  }

  @override
  Future<AuthUser> confirmSignUp(String email, String code) async {
    _maybeFail();
    calls.add('confirm:$email');
    return current = account;
  }

  @override
  Future<void> resendSignUpCode(String email) async {
    _maybeFail();
    calls.add('resend:$email');
  }

  @override
  Future<void> sendPasswordResetCode(String email) async {
    _maybeFail();
    calls.add('reset-code:$email');
  }

  @override
  Future<AuthUser> resetPassword(
      String email, String code, String newPassword) async {
    _maybeFail();
    calls.add('reset:$email');
    return current = account;
  }

  @override
  Future<void> ensureOnlineSession() async {}

  @override
  Future<void> signOut() async {
    calls.add('signOut');
    current = null;
    _changes.add(null);
  }
}

class FakeCloud implements CloudBackupRepository {
  DateTime? remoteAt;
  String? content;
  Object? error;
  final List<String> uploads = [];

  void _maybeThrow() {
    final pending = error;
    if (pending != null) throw pending;
  }

  @override
  Future<DateTime?> lastBackupAt() async {
    _maybeThrow();
    return remoteAt;
  }

  @override
  Future<DateTime> upload(String backupJson) async {
    _maybeThrow();
    uploads.add(backupJson);
    return remoteAt = DateTime.now().toUtc();
  }

  @override
  Future<String?> download() async {
    _maybeThrow();
    return content;
  }
}

class FakeDao extends Fake implements AppDao {
  BackupData data = emptyBackup;

  @override
  Future<BackupData> readBackupData() async => data;
}

/// Everything the auth and backup controllers talk to, replaced by fakes.
class AuthHarness {
  final FakeAuth auth = FakeAuth();
  final FakeCloud cloud = FakeCloud();
  final FakeDao dao = FakeDao();
  final MemoryDeviceStore store = MemoryDeviceStore();

  List<Override> get overrides => [
        authRepositoryProvider.overrideWithValue(auth),
        cloudBackupRepositoryProvider.overrideWithValue(cloud),
        appDaoProvider.overrideWithValue(dao),
        deviceStoreProvider.overrideWithValue(store),
      ];

  ProviderContainer container() => ProviderContainer(overrides: overrides);
}
