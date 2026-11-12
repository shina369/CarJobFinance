import 'package:carjobfinance/data/datasources/local/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

const _v1Tables = [
  'CREATE TABLE rides (id TEXT NOT NULL PRIMARY KEY, date INTEGER NOT NULL, '
      'platform TEXT NOT NULL, earnings REAL NOT NULL, '
      'distance_km REAL NOT NULL, duration_minutes INTEGER NOT NULL, '
      'origin TEXT, destination TEXT, ride_type TEXT NOT NULL, '
      'is_synced INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL, '
      'updated_at INTEGER)',
  'CREATE TABLE expenses (id TEXT NOT NULL PRIMARY KEY, '
      'date INTEGER NOT NULL, category TEXT NOT NULL, amount REAL NOT NULL, '
      'description TEXT, receipt_image_path TEXT, '
      'is_recurring INTEGER NOT NULL DEFAULT 0, '
      'is_synced INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL, '
      'updated_at INTEGER)',
  'CREATE TABLE settings (key TEXT NOT NULL PRIMARY KEY, '
      'value TEXT NOT NULL, updated_at INTEGER NOT NULL)',
  "INSERT INTO rides (id, date, platform, earnings, distance_km, "
      "duration_minutes, ride_type, created_at) "
      "VALUES ('r1', 0, 'Uber', 25.5, 10, 20, 'standard', 0)",
];

const _v2CountryPlatforms = [
  'CREATE TABLE country_platforms (country_code TEXT NOT NULL, '
      'platform_name TEXT NOT NULL, '
      'PRIMARY KEY (country_code, platform_name))',
  "INSERT INTO country_platforms VALUES ('BR', 'Uber')",
];

const _v3Columns = [
  'ALTER TABLE country_platforms '
      'ADD COLUMN is_active INTEGER NOT NULL DEFAULT 1',
  'ALTER TABLE country_platforms '
      'ADD COLUMN is_custom INTEGER NOT NULL DEFAULT 0',
];

/// Opens [AppDatabase] on top of a database left by an older app version.
AppDatabase _openFrom(int version, List<String> statements) {
  final db = AppDatabase.forTesting(NativeDatabase.memory(
    setup: (raw) {
      if (raw.userVersion != 0) return;
      statements.forEach(raw.execute);
      raw.userVersion = version;
    },
  ));
  addTearDown(db.close);
  return db;
}

Future<Set<String>> _columns(AppDatabase db, String table) async {
  final rows = await db.customSelect('PRAGMA table_info($table)').get();
  return rows.map((r) => r.read<String>('name')).toSet();
}

void main() {
  const platformColumns = {
    'country_code',
    'platform_name',
    'is_active',
    'is_custom',
    'commission_type',
    'commission_value',
  };
  const rideCommissionColumns = {
    'commission_type',
    'commission_value',
    'commission_amount',
  };

  test('a v1 database upgrades to the current schema and keeps its rides',
      () async {
    final db = _openFrom(1, _v1Tables);

    final rides = await db.select(db.rides).get();

    expect(rides.single.id, 'r1');
    expect(rides.single.commissionAmount, 0);
    expect(await _columns(db, 'rides'), containsAll(rideCommissionColumns));
    expect(await _columns(db, 'country_platforms'), platformColumns);
    expect(await db.select(db.countryPlatforms).get(), isNotEmpty);
  });

  test('a v1 database left half-upgraded by a crashed migration recovers',
      () async {
    final db = _openFrom(1, [
      ..._v1Tables,
      ..._v2CountryPlatforms,
      ..._v3Columns,
    ]);

    final rows = await db.select(db.countryPlatforms).get();

    expect(await _columns(db, 'country_platforms'), platformColumns);
    expect(rows.where((r) => r.countryCode == 'BR' && r.platformName == 'Uber'),
        hasLength(1));
  });

  test('a v2 database gains the activation and commission columns', () async {
    final db = _openFrom(2, [..._v1Tables, ..._v2CountryPlatforms]);

    final rows = await db.select(db.countryPlatforms).get();

    expect(await _columns(db, 'country_platforms'), platformColumns);
    expect(rows.single.isActive, isTrue);
    expect(rows.single.isCustom, isFalse);
  });

  test('a v3 database gains the commission columns', () async {
    final db =
        _openFrom(3, [..._v1Tables, ..._v2CountryPlatforms, ..._v3Columns]);

    await db.select(db.countryPlatforms).get();

    expect(await _columns(db, 'country_platforms'), platformColumns);
    expect(await _columns(db, 'rides'), containsAll(rideCommissionColumns));
  });
}
