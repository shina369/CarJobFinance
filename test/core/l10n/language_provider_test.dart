// Unit tests for the language provider and strings bundle.
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:carjobfinance/core/l10n/language_provider.dart';
import 'package:carjobfinance/core/l10n/languages.dart';
import 'package:carjobfinance/core/l10n/strings.dart';
import 'package:carjobfinance/core/settings/app_settings_notifier.dart';
import 'package:carjobfinance/data/datasources/local/app_database.dart'
    show CountryPlatformsDao;
import 'package:carjobfinance/data/datasources/local/daos.dart' show AppDao;

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

void main() {
  group('LanguageNotifier', () {
    test('defaults to country language when no preference is stored', () async {
      final dao = _InMemoryAppDao();
      final notifier = LanguageNotifier(dao, AppLanguagePref.defaultFor('MX'));
      await notifier.initialize();

      expect(notifier.state.language.tag, 'es_MX');
      expect(notifier.state.locale, isNotNull);
    });

    test('setLanguage persists the chosen language', () async {
      final dao = _InMemoryAppDao();
      final notifier = LanguageNotifier(dao, AppLanguagePref.defaultFor('BR'));
      await notifier.initialize();

      final enUs = SUPPORTED_LANGUAGES.firstWhere((l) => l.tag == 'en_US');
      await notifier.setLanguage(enUs);

      expect(notifier.state.language.tag, 'en_US');
      expect(dao._storage['app_language'], 'en_US');
    });

    test('resetToCountryDefault removes the persisted preference', () async {
      final dao = _InMemoryAppDao();
      final notifier = LanguageNotifier(dao, AppLanguagePref.defaultFor('BR'));
      await notifier.initialize();

      final esEs = SUPPORTED_LANGUAGES.firstWhere((l) => l.tag == 'es_ES');
      await notifier.setLanguage(esEs);
      expect(dao._storage.containsKey('app_language'), isTrue);

      await notifier.resetToCountryDefault();
      expect(notifier.state.language.tag, 'pt_BR');
      expect(dao._storage.containsKey('app_language'), isFalse);
    });

    test('initialize loads a stored preference when present', () async {
      final dao = _InMemoryAppDao();
      await dao.setSetting('app_language', 'id_ID');
      final notifier = LanguageNotifier(dao, AppLanguagePref.defaultFor('BR'));
      await notifier.initialize();

      expect(notifier.state.language.tag, 'id_ID');
    });
  });

  group('AppLanguage', () {
    test('defaultLanguageForCountry maps each country to its language', () {
      expect(defaultLanguageForCountry('BR').tag, 'pt_BR');
      expect(defaultLanguageForCountry('PT').tag, 'pt_PT');
      expect(defaultLanguageForCountry('MX').tag, 'es_MX');
      expect(defaultLanguageForCountry('CO').tag, 'es_CO');
      expect(defaultLanguageForCountry('CL').tag, 'es_CL');
      expect(defaultLanguageForCountry('AR').tag, 'es_AR');
      expect(defaultLanguageForCountry('ES').tag, 'es_ES');
      expect(defaultLanguageForCountry('US').tag, 'en_US');
      expect(defaultLanguageForCountry('ID').tag, 'id_ID');
      expect(defaultLanguageForCountry('IN').tag, 'hi_IN');
    });

    test('falls back to pt_BR for unknown countries', () {
      expect(defaultLanguageForCountry('ZZ').tag, 'pt_BR');
    });

    test('locale is derived from the tag', () {
      final enUs = SUPPORTED_LANGUAGES.firstWhere((l) => l.tag == 'en_US');
      expect(enUs.locale.toString(), 'en_US');
    });

    test('languageForTag returns null for unknown tags', () {
      expect(languageForTag('xx_XX'), isNull);
      expect(languageForTag('pt_BR')?.tag, 'pt_BR');
    });
  });

  group('Strings bundle', () {
    test('resolves keys per language with pt_BR fallback', () {
      expect(Strings.t('nav.home', 'en_US'), 'Home');
      expect(Strings.t('nav.rides', 'en_US'), 'Rides');
      // pt_PT falls back to pt_BR for keys it does not override
      expect(Strings.t('nav.settings', 'pt_PT'), 'Config');
      // Unknown tag falls back to pt_BR
      expect(Strings.t('nav.home', 'xx_XX'), 'Home');
      // Unknown key returns the key itself
      expect(Strings.t('nope.nope', 'en_US'), 'nope.nope');
    });

    test('AppLanguage.tr substitutes args', () {
      final lang = SUPPORTED_LANGUAGES.firstWhere((l) => l.tag == 'pt_BR');
      final result = lang.tr('dash.goalValue', args: {'symbol': 'R\$'});
      expect(result, 'Valor do objetivo (R\$)');
    });

    test('all supported bundles contain the required nav keys', () {
      for (final lang in SUPPORTED_LANGUAGES) {
        for (final key in [
          'nav.home',
          'nav.rides',
          'nav.expenses',
          'nav.reports',
          'nav.settings',
          'settings.title',
          'onboarding.welcome',
        ]) {
          expect(Strings.t(key, lang.tag), isNot(key),
              reason: '$key missing in ${lang.tag}');
        }
      }
    });
  });

  group('languageProvider', () {
    test('appLanguageProvider reflects the notifier state', () async {
      final dao = _InMemoryAppDao();
      final container = ProviderContainer(
        overrides: [
          languageDaoProvider.overrideWithValue(dao),
          appSettingsProvider.overrideWith(
            (ref) => LanguageSettingsNotifier(),
          ),
        ],
      );

      await container.read(languageProvider.notifier).initialize();
      expect(container.read(appLanguageProvider).tag, 'pt_BR');

      // Read the final state before disposing — the notifier's async
      // initialize() is already awaited above, so it is safe to dispose.
      container.dispose();
    });
  });
}

/// Minimal settings notifier without a database, for provider tests.
class LanguageSettingsNotifier extends AppSettingsNotifier {
  LanguageSettingsNotifier()
      : super.forTesting(
            _InMemoryAppDao(), _FakeCountryDao(), AppSettings.defaultBrazil());
}

class _FakeCountryDao implements CountryPlatformsDao {
  @override
  noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('FakeCountryDao');
}
