import 'package:carjobfinance/core/auth/auth_repository.dart';
import 'package:carjobfinance/core/auth/credential_store.dart';
import 'package:carjobfinance/data/datasources/local/app_database.dart';
import 'package:carjobfinance/data/datasources/local/backup_data.dart';
import 'package:carjobfinance/presentation/controllers/session_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/auth_test_support.dart';

final _expense = Expense(
  id: 'e1',
  date: DateTime(2026, 1, 1),
  category: 'Combustivel',
  amount: 50,
  isRecurring: false,
  isSynced: false,
  createdAt: DateTime(2026, 1, 1),
);

final _withData = BackupData(
  rides: const [],
  expenses: [_expense],
  settings: const {},
  countryPlatforms: const [],
);

void main() {
  late AuthHarness h;

  setUp(() {
    h = AuthHarness();
  });

  SessionController controllerOf(AuthHarness harness) {
    final container = harness.container();
    addTearDown(container.dispose);
    return container.read(sessionProvider.notifier);
  }

  test('signing in on a fresh device claims it and opens the app', () async {
    final session = controllerOf(h);
    await session.signIn('ana@example.com', 'senha1234');

    final state = session.state;
    expect(state.user, testAccount);
    expect(state.gate, LoginGate.none);
    expect(await h.store.read(SessionController.dataOwnerKey), testAccount.id);
  });

  test('signing in with "remember" stores the trimmed e-mail and password',
      () async {
    final session = controllerOf(h);
    await session.signIn('  ana@example.com ', 'senha1234', remember: true);

    expect(h.credentials.saved?.email, 'ana@example.com');
    expect(h.credentials.saved?.password, 'senha1234');
    expect(session.state.gate, LoginGate.none);
  });

  test('signing in without "remember" stores nothing', () async {
    final session = controllerOf(h);
    await session.signIn('ana@example.com', 'senha1234');

    expect(h.credentials.saved, isNull);
  });

  test('signing in without "remember" forgets a login kept earlier', () async {
    h.credentials.saved =
        const SavedLogin(email: 'ana@example.com', password: 'velha');
    final session = controllerOf(h);
    await session.signIn('ana@example.com', 'senha1234');

    expect(h.credentials.saved, isNull);
  });

  test('a refused sign-in leaves the remembered login alone', () async {
    h.credentials.saved =
        const SavedLogin(email: 'ana@example.com', password: 'senha1234');
    h.auth.failure = const AuthFailure(AuthFailureReason.invalidCredentials);
    final session = controllerOf(h);

    await expectLater(
      session.signIn('ana@example.com', 'errada', remember: false),
      throwsA(isA<AuthFailure>()),
    );
    expect(h.credentials.saved?.password, 'senha1234');
  });

  test('sign-up does not touch the remembered login', () async {
    final session = controllerOf(h);
    await session.signUp(
      'ana@example.com',
      'senha1234',
      firstName: 'Ana',
      lastName: 'Silva',
    );

    expect(session.state.gate, LoginGate.none);
    expect(h.credentials.saved, isNull);
    expect(h.auth.lastFirstName, 'Ana');
    expect(h.auth.lastLastName, 'Silva');
  });

  test('an empty device with a cloud backup is offered a restore', () async {
    h.cloud.remoteAt = DateTime.utc(2026, 5, 1, 10);
    final session = controllerOf(h);
    await session.signIn('ana@example.com', 'senha1234');

    expect(session.state.gate, LoginGate.restoreOffer);
    expect(session.state.cloudBackupAt, DateTime.utc(2026, 5, 1, 10));
    expect(session.state.isAuthenticated, isTrue);
  });

  test('data from another account blocks the app until the driver decides',
      () async {
    await h.store.write(SessionController.dataOwnerKey, 'someone-else');
    h.dao.data = _withData;
    final session = controllerOf(h);
    await session.signIn('ana@example.com', 'senha1234');

    expect(session.state.gate, LoginGate.foreignData);
    expect(await h.store.read(SessionController.dataOwnerKey), 'someone-else');
  });

  test('cancelling the foreign-data gate signs out and keeps the data',
      () async {
    await h.store.write(SessionController.dataOwnerKey, 'someone-else');
    h.dao.data = _withData;
    final session = controllerOf(h);
    await session.signIn('ana@example.com', 'senha1234');
    await session.cancelLogin();

    expect(session.state.isAuthenticated, isFalse);
    expect(h.auth.calls, contains('signOut'));
  });

  test('declining the restore offer opens the app', () async {
    h.cloud.remoteAt = DateTime.utc(2026, 5, 1, 10);
    final session = controllerOf(h);
    await session.signIn('ana@example.com', 'senha1234');
    session.declineRestore();

    expect(session.state.gate, LoginGate.none);
    expect(session.state.isAuthenticated, isTrue);
  });

  test('sign-up with a pending code keeps the user signed out', () async {
    h.auth.signUpNeedsCode = true;
    final session = controllerOf(h);

    final created = await session.signUp(
      'ana@example.com',
      'senha1234',
      firstName: 'Ana',
      lastName: 'Silva',
    );

    expect(created, isFalse);
    expect(session.state.isAuthenticated, isFalse);
  });

  test('confirming the code signs the new account in', () async {
    final session = controllerOf(h);
    await session.confirmSignUp('ana@example.com', '123456');

    expect(session.state.user, testAccount);
  });

  test('password reset signs in with the new password', () async {
    final session = controllerOf(h);
    await session.resetPassword('ana@example.com', '123456', 'novaSenha1');

    expect(session.state.user, testAccount);
    expect(h.auth.calls, contains('reset:ana@example.com'));
  });

  test('signing out uploads a backup of the local data first', () async {
    final session = controllerOf(h);
    await session.signIn('ana@example.com', 'senha1234');
    await Future<void>.delayed(Duration.zero);
    h.dao.data = _withData;
    await session.signOut();

    expect(h.cloud.uploads, hasLength(1));
    expect(h.auth.calls.last, 'signOut');
    expect(session.state.isAuthenticated, isFalse);
  });

  test('signing out still works when the backup cannot be sent', () async {
    h.dao.data = _withData;
    final session = controllerOf(h);
    await session.signIn('ana@example.com', 'senha1234');
    h.cloud.error = Exception('offline');
    await session.signOut();

    expect(session.state.isAuthenticated, isFalse);
    expect(h.auth.calls.last, 'signOut');
  });

  test('an empty device signing out does not upload anything', () async {
    final session = controllerOf(h);
    await session.signIn('ana@example.com', 'senha1234');
    await session.signOut();

    expect(h.cloud.uploads, isEmpty);
  });
}
