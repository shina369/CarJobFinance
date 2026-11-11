import 'package:flutter_test/flutter_test.dart';
import 'package:carjobfinance/data/datasources/local/app_database.dart';

void main() {
  late AppDatabase db;
  setUp(() async {
    db = AppDatabase.memory();
  });
  tearDown(() async => db.close());

  test('upsert and get return inserted platforms with default flags', () async {
    await db.countryPlatformsDao.upsertCountryPlatforms(
        'BR', ['Uber', '99']);
    final platforms = await db.countryPlatformsDao.getPlatformsFor('BR');
    expect(platforms, hasLength(2));
    final names = platforms.map((p) => p.name).toList()
      ..sort();
    expect(names, equals(['99', 'Uber']));
    // Defaults: new rows are active and non-custom
    for (final p in platforms) {
      expect(p.isActive, isTrue);
      expect(p.isCustom, isFalse);
    }
  });

  test('upsert preserves flags when existingStates is provided', () async {
    await db.countryPlatformsDao.upsertCountryPlatforms('BR', ['Uber']);
    const state = PlatformState(
        name: 'Uber', isActive: false, isCustom: true);
    await db.countryPlatformsDao.upsertCountryPlatforms(
        'BR', ['Uber', '99'],
        existingStates: {'Uber': state});
    final platforms = await db.countryPlatformsDao.getPlatformsFor('BR');
    final uber = platforms.firstWhere((p) => p.name == 'Uber');
    expect(uber.isActive, isFalse);
    expect(uber.isCustom, isTrue);
  });

  test('overwriting platforms replaces old values', () async {
    await db.countryPlatformsDao.upsertCountryPlatforms('BR', ['Old']);
    await db.countryPlatformsDao.upsertCountryPlatforms('BR', ['New1', 'New2']);
    final names = (await db.countryPlatformsDao.getPlatformsFor('BR'))
        .map((p) => p.name)
        .toList();
    expect(names, equals(['New1', 'New2']));
  });
}