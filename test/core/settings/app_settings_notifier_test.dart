import 'package:flutter_test/flutter_test.dart';
import 'package:carjobfinance/core/settings/app_settings_notifier.dart';
import 'package:carjobfinance/core/settings/country_data.dart';
import 'package:carjobfinance/data/datasources/local/app_database.dart';
import 'package:carjobfinance/data/datasources/local/daos.dart';

void main() {
  late AppDatabase db;
  late AppDao dao;

  setUp(() async {
    db = AppDatabase.memory();
    dao = AppDao(db);
    // Seed country platforms for in-memory database (migration doesn't run on memory DB)
    for (final country in COUNTRIES) {
      await db.countryPlatformsDao.upsertCountryPlatforms(
        country.code,
        country.platforms,
      );
    }
  });
  tearDown(() async => db.close());

  test('initial state returns Brazil defaults when no settings saved',
      () async {
    final notifier = AppSettingsNotifier(dao, db.countryPlatformsDao);
    await notifier.initialize();
    expect(notifier.state.countryCode, 'BR');
    expect(notifier.state.currencyCode, 'BRL');
    expect(notifier.state.currencySymbol, 'R\$');
    expect(notifier.state.localeTag, 'pt_BR');
    expect(notifier.state.platforms, contains('Uber'));
    expect(notifier.state.platforms, contains('99'));
    expect(notifier.state.configured, isFalse);
  });

  test('pre-seeded app_country setting returns configured state', () async {
    await dao.setSetting('app_country', 'PT');
    final notifier = AppSettingsNotifier(dao, db.countryPlatformsDao);
    await notifier.initialize();
    expect(notifier.state.countryCode, 'PT');
    expect(notifier.state.currencyCode, 'EUR');
    expect(notifier.state.currencySymbol, '€');
    expect(notifier.state.localeTag, 'pt_PT');
    expect(notifier.state.platforms, contains('Bolt'));
    expect(notifier.state.configured, isTrue);
  });

  test('setCountry updates state and persists setting', () async {
    final notifier = AppSettingsNotifier(dao, db.countryPlatformsDao);
    await notifier.initialize();
    expect(notifier.state.configured, isFalse);

    await notifier.setCountry('PT');
    expect(notifier.state.countryCode, 'PT');
    expect(notifier.state.currencySymbol, '€');
    expect(notifier.state.platforms, contains('Bolt'));
    expect(notifier.state.configured, isTrue);

    // Verify persistence
    final saved = await dao.getSetting('app_country');
    expect(saved, 'PT');
  });

  test('resetToDefault clears setting and returns to Brazil defaults',
      () async {
    await dao.setSetting('app_country', 'PT');
    final notifier = AppSettingsNotifier(dao, db.countryPlatformsDao);
    await notifier.initialize();
    expect(notifier.state.configured, isTrue);

    await notifier.resetToDefault();
    expect(notifier.state.countryCode, 'BR');
    expect(notifier.state.currencySymbol, 'R\$');
    expect(notifier.state.configured, isFalse);

    // Verify setting was deleted
    final saved = await dao.getSetting('app_country');
    expect(saved, isNull);
  });
}
