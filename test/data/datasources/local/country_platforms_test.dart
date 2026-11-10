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

  test('watchPlatformsFor streams updated platforms', () async {
    // Wait for initial emission (includes seeded data from migration)
    final stream = db.countryPlatformsDao.watchPlatformsFor('BR');
    await stream.first;

    // Now upsert our test data - should emit updated list
    await db.countryPlatformsDao.upsertCountryPlatforms('BR', ['Uber']);
    expect(await stream.first, equals(['Uber']));

    await db.countryPlatformsDao.upsertCountryPlatforms('BR', ['Uber', '99']);
    expect(await stream.first, equals(['99', 'Uber'])); // alphabetical order
  });
}