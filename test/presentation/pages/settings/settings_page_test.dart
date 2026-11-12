import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carjobfinance/core/l10n/languages.dart';
import 'package:carjobfinance/core/l10n/language_provider.dart';
import 'package:carjobfinance/core/settings/app_settings_notifier.dart';
import 'package:carjobfinance/core/theme/app_theme.dart';
import 'package:carjobfinance/data/datasources/local/app_database.dart'
    show CountryPlatformsDao, PlatformState;
import 'package:carjobfinance/data/datasources/local/daos.dart' show AppDao;
import 'package:carjobfinance/presentation/pages/settings/option_picker_page.dart';
import 'package:carjobfinance/presentation/pages/settings/settings_page.dart';
import 'package:go_router/go_router.dart';

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

void main() {
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
