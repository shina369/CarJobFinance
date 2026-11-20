import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carjobfinance/core/l10n/languages.dart';
import 'package:carjobfinance/core/l10n/language_provider.dart';
import 'package:carjobfinance/core/l10n/strings.dart';
import 'package:carjobfinance/core/settings/app_settings_notifier.dart';
import 'package:carjobfinance/core/theme/app_theme.dart';
import 'package:carjobfinance/data/datasources/local/app_database.dart'
    show CountryPlatformsDao, PlatformState;
import 'package:carjobfinance/data/datasources/local/daos.dart' show AppDao;
import 'package:carjobfinance/core/auth/auth_repository.dart';
import 'package:carjobfinance/presentation/controllers/data_controller.dart';
import 'package:carjobfinance/presentation/controllers/session_controller.dart';
import 'package:carjobfinance/presentation/pages/settings/option_picker_page.dart';
import 'package:carjobfinance/presentation/pages/settings/settings_page.dart';
import 'package:go_router/go_router.dart';

import '../../../support/auth_test_support.dart';

class _InMemoryAppDao implements AppDao {
  final Map<String, String> _storage = {};

  @override
  Future<String?> getSetting(String key) async => _storage[key];

  @override
  Future<void> setSetting(String key, String value) async {
    _storage[key] = value;
  }

  @override
  Future<void> deleteSetting(String key) async {
    _storage.remove(key);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('InMemoryAppDao');
}

class _StubCountryPlatformsDao implements CountryPlatformsDao {
  @override
  Future<void> upsertCountryPlatforms(
      String countryCode, List<String> platforms,
      {Map<String, PlatformState> existingStates = const {}}) async {}

  @override
  Future<void> deleteObsoletePlatforms(Set<String> names) async {}

  @override
  Future<List<PlatformState>> getPlatformsFor(String countryCode) async => [];

  @override
  Future<List<String>> getPlatformNames(String countryCode) async => [];

  @override
  Future<Map<String, PlatformState>> getExistingStates(
          String countryCode) async =>
      {};

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('StubCountryPlatformsDao');
}

class _CountingDataController implements DataController {
  int clears = 0;

  @override
  Future<void> clearAll() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    clears++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('CountingDataController');
}

void main() {
  group('SettingsPage account deletion', () {
    late AuthHarness h;
    late _CountingDataController data;
    late ProviderContainer container;

    Future<void> pumpSettings(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 5000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      h = AuthHarness();
      h.auth.current = testAccount;
      data = _CountingDataController();
      final ptBr = languageForTag('pt_BR')!;
      container = ProviderContainer(overrides: [
        ...h.overrides,
        dataControllerProvider.overrideWithValue(data),
        appLanguageProvider.overrideWithValue(ptBr),
        languageDaoProvider.overrideWithValue(_InMemoryAppDao()),
        appSettingsProvider
            .overrideWith((ref) => AppSettingsNotifier.forTesting(
                  _InMemoryAppDao(),
                  _StubCountryPlatformsDao(),
                  AppSettings.defaultBrazil(),
                )),
        sessionProvider.overrideWith((ref) =>
            SessionController(ref, const SessionState(user: testAccount))),
      ]);
      addTearDown(container.dispose);
      await container.read(sessionProvider.notifier).initialize();

      final refresh = ValueNotifier<int>(0);
      container.listen(sessionProvider, (_, __) => refresh.value++);
      final router = GoRouter(
        refreshListenable: refresh,
        redirect: (_, state) =>
            container.read(sessionProvider).isAuthenticated ||
                    state.matchedLocation == '/login'
                ? null
                : '/login',
        routes: [
          ShellRoute(
            builder: (_, __, child) => Scaffold(body: child),
            routes: [
              GoRoute(path: '/', builder: (_, __) => const SettingsPage()),
            ],
          ),
          GoRoute(
            path: '/login',
            builder: (_, __) => const Scaffold(body: Text('login-page')),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(theme: lightTheme, routerConfig: router),
      ));
      await tester.pumpAndSettle();
    }

    Future<void> openDialog(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('settings-delete-account')));
      await tester.pumpAndSettle();
    }

    Future<void> confirmWith(WidgetTester tester, String password) async {
      await tester.enterText(
          find.byKey(const Key('settings-delete-account-password')), password);
      await tester
          .tap(find.byKey(const Key('settings-delete-account-confirm')));
      await tester.pumpAndSettle();
    }

    testWidgets('cancelling the confirmation keeps the account',
        (tester) async {
      await pumpSettings(tester);
      await openDialog(tester);
      expect(find.byKey(const Key('settings-delete-account-password')),
          findsOneWidget);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(h.auth.calls, isEmpty);
      expect(container.read(sessionProvider).isAuthenticated, isTrue);
    });

    testWidgets('an empty password is rejected without calling the server',
        (tester) async {
      await pumpSettings(tester);
      await openDialog(tester);

      await confirmWith(tester, '');

      final lang = container.read(appLanguageProvider);
      expect(find.text(lang.tr('settings.deleteAccountWrongPassword')),
          findsOneWidget);
      expect(h.auth.calls, isEmpty);
      expect(container.read(sessionProvider).isAuthenticated, isTrue);
    });

    testWidgets('a wrong password keeps the account and the dialog open',
        (tester) async {
      await pumpSettings(tester);
      h.auth.requiredPassword = 'correct-horse';
      await openDialog(tester);

      await confirmWith(tester, 'wrong-password');

      final lang = container.read(appLanguageProvider);
      expect(find.byKey(const Key('settings-delete-account-error')),
          findsOneWidget);
      expect(find.text(lang.tr('settings.deleteAccountWrongPassword')),
          findsOneWidget);
      expect(h.auth.calls, isNot(contains('deleteAccount')));
      expect(data.clears, 0);
      expect(container.read(sessionProvider).isAuthenticated, isTrue);
    });

    testWidgets('the right password erases the account and shows the login',
        (tester) async {
      await pumpSettings(tester);
      h.auth.requiredPassword = 'correct-horse';
      await openDialog(tester);

      await confirmWith(tester, 'correct-horse');

      expect(h.auth.calls, contains('deleteAccount'));
      expect(data.clears, 1);
      expect(container.read(sessionProvider).isAuthenticated, isFalse);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('login-page'), findsOneWidget);
    });

    testWidgets('a network failure shows a message and keeps everything',
        (tester) async {
      await pumpSettings(tester);
      h.auth.failure = const AuthFailure(AuthFailureReason.network);
      await openDialog(tester);

      await confirmWith(tester, 'any-password');

      final lang = container.read(appLanguageProvider);
      expect(find.text(lang.tr('auth.err.network')), findsOneWidget);
      expect(data.clears, 0);
      expect(container.read(sessionProvider).isAuthenticated, isTrue);
      expect(find.byType(AlertDialog), findsOneWidget);
    });
  });

  group('SettingsPage clear all data', () {
    late AuthHarness h;
    late _CountingDataController data;
    late ProviderContainer container;

    Future<void> pumpSettings(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 5000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      h = AuthHarness();
      h.auth.current = testAccount;
      data = _CountingDataController();
      final ptBr = languageForTag('pt_BR')!;
      container = ProviderContainer(overrides: [
        ...h.overrides,
        dataControllerProvider.overrideWithValue(data),
        appLanguageProvider.overrideWithValue(ptBr),
        languageDaoProvider.overrideWithValue(_InMemoryAppDao()),
        appSettingsProvider
            .overrideWith((ref) => AppSettingsNotifier.forTesting(
                  _InMemoryAppDao(),
                  _StubCountryPlatformsDao(),
                  AppSettings.defaultBrazil(),
                )),
        sessionProvider.overrideWith((ref) =>
            SessionController(ref, const SessionState(user: testAccount))),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: SettingsPage())),
      ));
      await tester.pumpAndSettle();
    }

    Future<void> confirmClearWith(WidgetTester tester, String password) async {
      final lang = container.read(appLanguageProvider);
      await tester.tap(find.text(lang.tr('settings.clearData')));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const Key('settings-clear-data-password')), password);
      await tester.tap(find.byKey(const Key('settings-clear-data-confirm')));
      await tester.pumpAndSettle();
    }

    testWidgets('a wrong password erases nothing and keeps the dialog open',
        (tester) async {
      await pumpSettings(tester);
      h.auth.requiredPassword = 'correct-horse';

      await confirmClearWith(tester, 'wrong-password');

      final lang = container.read(appLanguageProvider);
      expect(
          find.byKey(const Key('settings-clear-data-error')), findsOneWidget);
      expect(find.text(lang.tr('settings.clearDataWrongPassword')),
          findsOneWidget);
      expect(data.clears, 0);
      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('the right password erases all data once', (tester) async {
      await pumpSettings(tester);
      h.auth.requiredPassword = 'correct-horse';

      await confirmClearWith(tester, 'correct-horse');

      final lang = container.read(appLanguageProvider);
      expect(data.clears, 1);
      expect(find.byType(AlertDialog), findsNothing);
      expect(container.read(sessionProvider).isAuthenticated, isTrue);
      expect(find.text(lang.tr('settings.dataCleared')), findsOneWidget);
    });
  });

  group('SettingsPage language dialog', () {
    Future<ProviderContainer> buildSettingsPage(
        WidgetTester tester, AppLanguage lang) async {
      final settingsNotifier = AppSettingsNotifier.forTesting(
        _InMemoryAppDao(),
        _StubCountryPlatformsDao(),
        AppSettings.defaultBrazil(),
      );
      final languageDao = _InMemoryAppDao();
      final languageNotifier = LanguageNotifier(
        languageDao,
        AppLanguagePref(
            language: lang, countryCode: lang.defaultForCountries.first),
      );
      await languageNotifier.initialize();

      final container = ProviderContainer(
        overrides: [
          appSettingsProvider.overrideWith((ref) => settingsNotifier),
          languageProvider.overrideWith((ref) => languageNotifier),
          languageDaoProvider.overrideWithValue(languageDao),
        ],
      );

      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, __) => const SettingsPage()),
          GoRoute(
            path: '/settings/language',
            builder: (_, __) => const LanguagePickerPage(),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            theme: lightTheme,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      return container;
    }

    testWidgets('opens the language page and selects a language with a check',
        (WidgetTester tester) async {
      final ptBr = SUPPORTED_LANGUAGES.firstWhere((l) => l.tag == 'pt_BR');
      final container = await buildSettingsPage(tester, ptBr);
      addTearDown(container.dispose);

      await tester.tap(find.byType(ListTile).at(1)); // language tile
      await tester.pumpAndSettle();

      expect(find.byType(LanguagePickerPage), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);

      final english = find.text('🇺🇸  English (US)');
      await tester.scrollUntilVisible(english, 100);
      await tester.tap(english);
      await tester.pumpAndSettle();
      expect(container.read(appLanguageProvider).tag, 'en_US');
    });
  });
}
