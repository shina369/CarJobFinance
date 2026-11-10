import 'package:flutter_test/flutter_test.dart';
import 'package:carjobfinance/data/datasources/local/app_database.dart';

void main() {
  late AppDatabase db;
  setUp(() async {
    db = AppDatabase.memory();
  });
  tearDown(() async => db.close());

  test('upsert and watch return inserted platforms', () async {
    await db.countryPlatformsDao.upsertCountryPlatforms('BR', ['Uber', '99']);
    final platforms = await db.countryPlatformsDao.getPlatformsFor('BR');
    expect(platforms, equals(['99', 'Uber']));
  });

  test('overwriting platforms replaces old values', () async {
    await db.countryPlatformsDao.upsertCountryPlatforms('BR', ['Old']);
    await db.countryPlatformsDao.upsertCountryPlatforms('BR', ['New1', 'New2']);
    final platforms = await db.countryPlatformsDao.getPlatformsFor('BR');
    expect(platforms, equals(['New1', 'New2']));
  });
}