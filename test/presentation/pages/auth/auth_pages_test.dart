import 'package:carjobfinance/core/auth/auth_repository.dart';
import 'package:carjobfinance/core/auth/credential_store.dart';
import 'package:carjobfinance/core/l10n/languages.dart';
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

/// The sign-in button can sit below the fold of the small test window.
Future<void> _submit(WidgetTester tester) async {
  final button = find.byKey(const Key('auth-submit'));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
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
      await _submit(tester);

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
      await _submit(tester);

      expect(h.auth.current, isNull);
      expect(find.byKey(const Key('auth-error')), findsOneWidget);
    });

    testWidgets('does not contact the server with a malformed e-mail',
        (tester) async {
      final h = AuthHarness();
      await tester.pumpWidget(_app(const LoginPage(), h.overrides));

      await _fill(tester, find.byKey(const Key('auth-email')), 'nao-e-email');
      await _fill(tester, find.byKey(const Key('auth-password')), 'senha1234');
      await _submit(tester);

      expect(h.auth.calls, isEmpty);
      expect(h.auth.current, isNull);
    });

    testWidgets('offers the language choice on the sign-in page',
        (tester) async {
      final h = AuthHarness();
      await tester.pumpWidget(_app(const LoginPage(), h.overrides));

      expect(
          find.byType(DropdownButtonFormField<SignInLanguage>), findsOneWidget);
    });

    testWidgets('lists every Spanish variant as a single "Español" entry',
        (tester) async {
      final h = AuthHarness();
      await tester.pumpWidget(_app(const LoginPage(), h.overrides));

      final items = tester
          .widget<DropdownButton<SignInLanguage>>(
              find.byType(DropdownButton<SignInLanguage>))
          .items!;
      final keys =
          items.map((i) => (i.key! as ValueKey<String>).value).toList();

      expect(keys.where((k) => k.startsWith('auth-language-option-es_')),
          ['auth-language-option-es_MX']);

      final spanish = signInLanguages().where((o) => o.family == 'es');
      expect(spanish, hasLength(1));
      expect(spanish.single.label, 'Español');
      expect(spanish.single.flagCountry, 'ES');
    });

    testWidgets('keeps the other languages as they are', (tester) async {
      final h = AuthHarness();
      await tester.pumpWidget(_app(const LoginPage(), h.overrides));

      final keys = tester
          .widget<DropdownButton<SignInLanguage>>(
              find.byType(DropdownButton<SignInLanguage>))
          .items!
          .map((i) => (i.key! as ValueKey<String>).value)
          .toSet();

      expect(
          keys,
          containsAll(<String>{
            'auth-language-option-pt_BR',
            'auth-language-option-pt_PT',
            'auth-language-option-en_US',
          }));
    });

    testWidgets('fills in the login remembered on this device', (tester) async {
      final h = AuthHarness()
        ..credentials.saved = const SavedLogin(
          email: 'ana@example.com',
          password: 'senha1234',
        );
      await tester.pumpWidget(_app(const LoginPage(), h.overrides));
      await tester.pumpAndSettle();

      String textOf(String key) => tester
          .widget<EditableText>(find.descendant(
            of: find.byKey(Key(key)),
            matching: find.byType(EditableText),
          ))
          .controller
          .text;

      expect(textOf('auth-email'), 'ana@example.com');
      expect(textOf('auth-password'), 'senha1234');
      expect(
        tester
            .widget<CheckboxListTile>(find.byKey(const Key('auth-remember')))
            .value,
        isTrue,
      );
    });

    group('remember checkbox', () {
      bool isChecked(WidgetTester tester) => tester
          .widget<CheckboxListTile>(find.byKey(const Key('auth-remember')))
          .value!;

      Future<void> signInWith(WidgetTester tester) async {
        await _fill(
            tester, find.byKey(const Key('auth-email')), 'ana@example.com');
        await _fill(
            tester, find.byKey(const Key('auth-password')), 'senha1234');
        await _submit(tester);
      }

      testWidgets('starts unchecked when nothing is remembered',
          (tester) async {
        final h = AuthHarness();
        await tester.pumpWidget(_app(const LoginPage(), h.overrides));
        await tester.pumpAndSettle();

        expect(isChecked(tester), isFalse);
      });

      testWidgets('ticking it stores the login on sign-in', (tester) async {
        final h = AuthHarness();
        await tester.pumpWidget(_app(const LoginPage(), h.overrides));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('auth-remember')));
        await tester.pump();
        expect(isChecked(tester), isTrue);
        await signInWith(tester);

        expect(h.credentials.saved?.email, 'ana@example.com');
        expect(h.credentials.saved?.password, 'senha1234');
      });

      testWidgets('leaving it unticked stores nothing', (tester) async {
        final h = AuthHarness();
        await tester.pumpWidget(_app(const LoginPage(), h.overrides));
        await tester.pumpAndSettle();

        await signInWith(tester);

        expect(h.credentials.saved, isNull);
      });

      testWidgets('unticking it forgets the stored login', (tester) async {
        final h = AuthHarness()
          ..credentials.saved = const SavedLogin(
            email: 'ana@example.com',
            password: 'senha1234',
          );
        await tester.pumpWidget(_app(const LoginPage(), h.overrides));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('auth-remember')));
        await tester.pump();
        expect(isChecked(tester), isFalse);
        await signInWith(tester);

        expect(h.credentials.saved, isNull);
      });
    });
  });

  group('RegisterPage', () {
    testWidgets('asks for the confirmation code after creating the account',
        (tester) async {
      final h = AuthHarness()..auth.signUpNeedsCode = true;
      await tester.pumpWidget(_app(const RegisterPage(), h.overrides));

      await _fill(tester, find.byKey(const Key('auth-first-name')), 'Ana');
      await _fill(tester, find.byKey(const Key('auth-last-name')), 'Silva');
      await _fill(
          tester, find.byKey(const Key('auth-email')), 'ana@example.com');
      await _fill(tester, find.byKey(const Key('auth-password')), 'senha1234');
      await _fill(tester, find.byKey(const Key('auth-confirm')), 'senha1234');
      await tester.tap(find.byKey(const Key('auth-submit')));
      await tester.pumpAndSettle();

      expect(h.auth.calls, contains('signUp:ana@example.com'));
      expect(h.auth.lastFirstName, 'Ana');
      expect(h.auth.lastLastName, 'Silva');
      expect(find.byKey(const Key('auth-code')), findsOneWidget);
      expect(find.byKey(const Key('auth-resend')), findsOneWidget);
    });

    testWidgets('requires first and last name before contacting the server',
        (tester) async {
      final h = AuthHarness();
      await tester.pumpWidget(_app(const RegisterPage(), h.overrides));

      await _fill(
          tester, find.byKey(const Key('auth-email')), 'ana@example.com');
      await _fill(tester, find.byKey(const Key('auth-password')), 'senha1234');
      await _fill(tester, find.byKey(const Key('auth-confirm')), 'senha1234');
      await tester.tap(find.byKey(const Key('auth-submit')));
      await tester.pumpAndSettle();

      expect(h.auth.calls, isEmpty);
      expect(find.text('Informe este campo'), findsNWidgets(2));
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
