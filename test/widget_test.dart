import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:carjobfinance/main.dart';
import 'package:carjobfinance/core/l10n/language_provider.dart';
import 'package:carjobfinance/core/settings/app_settings_notifier.dart';
import 'package:carjobfinance/data/datasources/local/app_database.dart'
    show CountryPlatformsDao, PlatformState;
import 'package:carjobfinance/data/datasources/local/daos.dart' show AppDao;

/// In-memory settings DAO so the app's settings/language providers can load
/// without a real database.
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

/// Real [CountryPlatformsDao] interface with a no-op upsert/delete so
/// [AppSettingsNotifier.initialize] can run without a database.
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
  testWidgets('App loads correctly', (WidgetTester tester) async {
    final settingsNotifier = AppSettingsNotifier.forTesting(
      _InMemoryAppDao(),
      _StubCountryPlatformsDao(),
      AppSettings.defaultBrazil(),
    );
    final languageNotifier = LanguageNotifier(
      _InMemoryAppDao(),
      AppLanguagePref.defaultFor('BR'),
    );
    await languageNotifier.initialize();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSettingsProvider.overrideWith((ref) => settingsNotifier),
          languageProvider.overrideWith((ref) => languageNotifier),
        ],
        child: const CarJobFinanceApp(),
      ),
    );
    await tester.pumpAndSettle();

    // The MaterialApp title is not rendered on screen — verify the app
    // rendered a Material widget instead.
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
