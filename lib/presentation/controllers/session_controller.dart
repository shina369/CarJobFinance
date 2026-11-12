// Who is logged in, and what must be settled before they reach the app.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_repository.dart';
import '../../core/auth/supabase_auth_repository.dart';
import '../../core/storage/device_store.dart';
import 'cloud_backup_controller.dart';
import 'data_controller.dart';

/// A decision the driver has to make right after logging in.
enum LoginGate {
  none,

  /// The device holds data recorded under a different account.
  foreignData,

  /// The device is empty and the account has a cloud backup.
  restoreOffer,
}

@immutable
class SessionState {
  const SessionState({
    this.user,
    this.gate = LoginGate.none,
    this.cloudBackupAt,
  });

  final AuthUser? user;
  final LoginGate gate;

  /// Date of the cloud backup offered by [LoginGate.restoreOffer].
  final DateTime? cloudBackupAt;

  bool get isAuthenticated => user != null;

  @override
  bool operator ==(Object other) =>
      other is SessionState &&
      other.user == user &&
      other.gate == gate &&
      other.cloudBackupAt == cloudBackupAt;

  @override
  int get hashCode => Object.hash(user, gate, cloudBackupAt);
}

class SessionController extends StateNotifier<SessionState> {
  SessionController(this._ref, [super.initial = const SessionState()]);

  static const String dataOwnerKey = 'data_owner_id';
  static const Duration signOutBackupTimeout = Duration(seconds: 15);

  final Ref _ref;
  StreamSubscription<AuthUser?>? _subscription;

  AuthRepository get _auth => _ref.read(authRepositoryProvider);
  DeviceStore get _store => _ref.read(deviceStoreProvider);
  CloudBackupController get _backup => _ref.read(cloudBackupControllerProvider);

  /// Loads the saved session. Call once before the first frame.
  Future<void> initialize() async {
    _subscription ??= _auth.userChanges.listen((user) {
      if (user == null && mounted) state = const SessionState();
    });
    final user = await _auth.restoreSession();
    state = SessionState(user: user);
    if (user != null) unawaited(_backup.autoBackupIfDue());
  }

  Future<void> signIn(String email, String password) async =>
      _enter(await _auth.signIn(email, password));

  /// Returns false when the account was created but still needs the code
  /// sent by e-mail ([confirmSignUp]).
  Future<bool> signUp(String email, String password) async {
    final user = await _auth.signUp(email, password);
    if (user == null) return false;
    await _enter(user);
    return true;
  }

  Future<void> confirmSignUp(String email, String code) async =>
      _enter(await _auth.confirmSignUp(email, code));

  Future<void> resendSignUpCode(String email) => _auth.resendSignUpCode(email);

  Future<void> sendPasswordResetCode(String email) =>
      _auth.sendPasswordResetCode(email);

  Future<void> resetPassword(
          String email, String code, String newPassword) async =>
      _enter(await _auth.resetPassword(email, code, newPassword));

  Future<void> _enter(AuthUser user) async {
    final owner = await _store.read(dataOwnerKey);
    if (owner != null && owner != user.id && await _backup.hasLocalData()) {
      state = SessionState(user: user, gate: LoginGate.foreignData);
      return;
    }
    await _claimDevice(user);
  }

  Future<void> _claimDevice(AuthUser user) async {
    await _store.write(dataOwnerKey, user.id);
    if (!await _backup.hasLocalData()) {
      DateTime? remote;
      try {
        remote = await _backup.remoteBackupAt();
      } catch (_) {
        // Could not reach the server: the driver can still restore later
        // from the backup page.
      }
      if (remote != null) {
        state = SessionState(
          user: user,
          gate: LoginGate.restoreOffer,
          cloudBackupAt: remote,
        );
        return;
      }
    }
    state = SessionState(user: user);
    unawaited(_backup.autoBackupIfDue());
  }

  /// [LoginGate.foreignData]: erase the other account's data and continue.
  Future<void> discardForeignData() async {
    final user = state.user;
    if (user == null) return;
    await _ref.read(dataControllerProvider).clearAll();
    await _claimDevice(user);
  }

  /// [LoginGate.foreignData]: keep the data and go back to the login page.
  Future<void> cancelLogin() async {
    await _auth.signOut();
    state = const SessionState();
  }

  /// [LoginGate.restoreOffer]: bring the cloud backup onto this device.
  Future<void> acceptRestore() async {
    final user = state.user;
    if (user == null) return;
    await _backup.restoreFromCloud();
    state = SessionState(user: user);
  }

  /// [LoginGate.restoreOffer]: start with an empty device.
  void declineRestore() {
    final user = state.user;
    if (user != null) state = SessionState(user: user);
  }

  /// Saves a last backup when possible, then ends the session. Local data
  /// stays on the device.
  Future<void> signOut() async {
    try {
      if (await _backup.hasLocalData()) {
        await _backup.backupNow().timeout(signOutBackupTimeout);
      }
    } catch (_) {
      // Offline or slow: signing out must still work.
    }
    await _auth.signOut();
    state = const SessionState();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final sessionProvider = StateNotifierProvider<SessionController, SessionState>(
  (ref) => SessionController(ref),
);
