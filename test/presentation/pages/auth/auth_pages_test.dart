import 'package:carjobfinance/core/auth/auth_repository.dart';
import 'package:carjobfinance/core/l10n/strings.dart';
import 'package:carjobfinance/presentation/controllers/session_controller.dart';
import 'package:carjobfinance/presentation/pages/auth/account_gate_page.dart';
import 'package:carjobfinance/presentation/pages/auth/login_page.dart';
import 'package:carjobfinance/presentation/pages/auth/register_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/auth_test_support.dart';

Widget _app(Widget home, List<Override> overrides) => ProviderScope(
      overrides: overrides,
      child: MaterialApp(home: home),
    );

Future<void> _fill(WidgetTester tester, Finder field, String text) async {
  await tester.enterText(field, text);
  await tester.pump();
}

void main() {
  setUpAll(() async {
    await Strings.initIntlDateFormats();
  });

  group('LoginPage', () {
    testWidgets('offers sign-in, create account and password recovery',
        (tester) async {
      final h = AuthHarness();
      await tester.pumpWidget(_app(const LoginPage(), h.overrides));

      expect(find.byKey(const Key('auth-email')), findsOneWidget);
      expect(find.byKey(const Key('auth-password')), findsOneWidget);
      expect(find.byKey(const Key('auth-submit')), findsOneWidget);
      expect(find.byKey(const Key('auth-create')), findsOneWidget);
      expect(find.byKey(const Key('auth-forgot')), findsOneWidget);
    });

    testWidgets('signs in with valid credentials', (tester) async {
      final h = AuthHarness();
      await tester.pumpWidget(_app(const LoginPage(), h.overrides));

      await _fill(
          tester, find.byKey(const Key('auth-email')), 'ana@example.com');
      await _fill(tester, find.byKey(const Key('auth-password')), 'senha1234');
      await tester.tap(find.byKey(const Key('auth-submit')));
      await tester.pumpAndSettle();

      expect(h.auth.current, testAccount);
      expect(find.byKey(const Key('auth-error')), findsNothing);
    });

    testWidgets('shows the failure when the server refuses the login',
        (tester) async {
      final h = AuthHarness();
      h.auth.failure = const AuthFailure(AuthFailureReason.invalidCredentials);
      await tester.pumpWidget(_app(const LoginPage(), h.overrides));

      await _fill(
          tester, find.byKey(const Key('auth-email')), 'ana@example.com');
      await _fill(tester, find.byKey(const Key('auth-password')), 'errada');
      await tester.tap(find.byKey(const Key('auth-submit')));
      await tester.pumpAndSettle();

      expect(h.auth.current, isNull);
      expect(find.byKey(const Key('auth-error')), findsOneWidget);
    });

    testWidgets('does not contact the server with a malformed e-mail',
        (tester) async {
      final h = AuthHarness();
      await tester.pumpWidget(_app(const LoginPage(), h.overrides));

      await _fill(tester, find.byKey(const Key('auth-email')), 'nao-e-email');
      await _fill(tester, find.byKey(const Key('auth-password')), 'senha1234');
      await tester.tap(find.byKey(const Key('auth-submit')));
      await tester.pumpAndSettle();

      expect(h.auth.calls, isEmpty);
      expect(h.auth.current, isNull);
    });
  });

  group('RegisterPage', () {
    testWidgets('asks for the confirmation code after creating the account',
        (tester) async {
      final h = AuthHarness()..auth.signUpNeedsCode = true;
      await tester.pumpWidget(_app(const RegisterPage(), h.overrides));

      await _fill(
          tester, find.byKey(const Key('auth-email')), 'ana@example.com');
      await _fill(tester, find.byKey(const Key('auth-password')), 'senha1234');
      await _fill(tester, find.byKey(const Key('auth-confirm')), 'senha1234');
      await tester.tap(find.byKey(const Key('auth-submit')));
      await tester.pumpAndSettle();

      expect(h.auth.calls, contains('signUp:ana@example.com'));
      expect(find.byKey(const Key('auth-code')), findsOneWidget);
      expect(find.byKey(const Key('auth-resend')), findsOneWidget);
    });

    testWidgets('confirming the code signs the account in', (tester) async {
      final h = AuthHarness();
      await tester.pumpWidget(_app(
        const RegisterPage(pendingEmail: 'ana@example.com'),
        h.overrides,
      ));

      expect(find.byKey(const Key('auth-code')), findsOneWidget);
      await _fill(tester, find.byKey(const Key('auth-code')), '123456');
      await tester.tap(find.byKey(const Key('auth-submit')));
      await tester.pumpAndSettle();

      expect(h.auth.current, testAccount);
    });

    testWidgets('refuses mismatched passwords without contacting the server',
        (tester) async {
      final h = AuthHarness();
      await tester.pumpWidget(_app(const RegisterPage(), h.overrides));

      await _fill(
          tester, find.byKey(const Key('auth-email')), 'ana@example.com');
      await _fill(tester, find.byKey(const Key('auth-password')), 'senha1234');
      await _fill(tester, find.byKey(const Key('auth-confirm')), 'outra12345');
      await tester.tap(find.byKey(const Key('auth-submit')));
      await tester.pumpAndSettle();

      expect(h.auth.calls, isEmpty);
    });
  });

  group('AccountGatePage', () {
    testWidgets('restore offer can be declined to start empty', (tester) async {
      final h = AuthHarness();
      final container = ProviderContainer(overrides: [
        ...h.overrides,
        sessionProvider.overrideWith((ref) => SessionController(
              ref,
              SessionState(
                user: testAccount,
                gate: LoginGate.restoreOffer,
                cloudBackupAt: DateTime.utc(2026, 5, 1, 10),
              ),
            )),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AccountGatePage()),
      ));
      await tester.tap(find.byKey(const Key('gate-cancel')));
      await tester.pumpAndSettle();

      expect(container.read(sessionProvider).gate, LoginGate.none);
      expect(container.read(sessionProvider).isAuthenticated, isTrue);
    });

    testWidgets('foreign data can be refused, which signs the user out',
        (tester) async {
      final h = AuthHarness();
      final container = ProviderContainer(overrides: [
        ...h.overrides,
        sessionProvider.overrideWith((ref) => SessionController(
              ref,
              const SessionState(
                user: testAccount,
                gate: LoginGate.foreignData,
              ),
            )),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AccountGatePage()),
      ));
      await tester.tap(find.byKey(const Key('gate-cancel')));
      await tester.pumpAndSettle();

      expect(h.auth.current, isNull);
      expect(container.read(sessionProvider).isAuthenticated, isFalse);
    });
  });
}
