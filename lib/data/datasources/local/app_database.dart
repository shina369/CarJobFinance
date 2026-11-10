// Database Drift - Schema
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';

import '../../../core/settings/country_data.dart';

part 'app_database.g.dart';

// Tabelas
class Rides extends Table {
  TextColumn get id => text()();
  DateTimeColumn get date => dateTime()();
  TextColumn get platform => text()();
  RealColumn get earnings => real()();
  RealColumn get distanceKm => real()();
  IntColumn get durationMinutes => integer()();
  TextColumn get origin => text().nullable()();
  TextColumn get destination => text().nullable()();
  TextColumn get rideType => text()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Expenses extends Table {
  TextColumn get id => text()();
  DateTimeColumn get date => dateTime()();
  TextColumn get category => text()();
  RealColumn get amount => real()();
  TextColumn get description => text().nullable()();
  TextColumn get receiptImagePath => text().nullable()();
  BoolColumn get isRecurring => boolean().withDefault(const Constant(false))();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {key};
}

/// Table mapping countries to their available ride-hailing platforms.
/// Each row represents a single platform available in a country.
/// Composite primary key: (countryCode, platformName)
class CountryPlatforms extends Table {
  TextColumn get countryCode => text()();
  TextColumn get platformName => text()();

  @override
  Set<Column> get primaryKey => {countryCode, platformName};
}

// Database
@DriftDatabase(tables: [Rides, Expenses, Settings, CountryPlatforms])
class AppDatabase extends _$AppDatabase {
  /// Production constructor using file-based SQLite database.
  AppDatabase() : super(_openConnection());

  /// Test constructor using in-memory SQLite database.
  AppDatabase.memory() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
          await _seedCountryPlatforms();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          if (from == 1 && to == 2) {
            await m.createTable(countryPlatforms);
            await _seedCountryPlatforms();
          }
        },
      );

  /// DAO for accessing country-platform mappings.
  CountryPlatformsDao get countryPlatformsDao => CountryPlatformsDao(this);

  /// Seeds the country_platforms table with platforms from COUNTRIES.
  Future<void> _seedCountryPlatforms() async {
    for (final country in COUNTRIES) {
      for (final platform in country.platforms) {
        await into(countryPlatforms).insert(
          CountryPlatformsCompanion.insert(
            countryCode: country.code,
            platformName: platform,
          ),
        );
      }
    }
  }
}

/// DAO for accessing country-platform mappings.
@DriftAccessor(tables: [CountryPlatforms])
class CountryPlatformsDao extends DatabaseAccessor<AppDatabase> with _$CountryPlatformsDaoMixin {
  CountryPlatformsDao(super.db);

  /// Inserts or replaces all platforms for a given country.
  /// Deletes existing platforms for the country first, then inserts the new list.
  Future<void> upsertCountryPlatforms(String countryCode, List<String> platforms) async {
    await transaction(() async {
      // Delete existing platforms for this country
      await (delete(countryPlatforms)
            ..where((tbl) => tbl.countryCode.equals(countryCode)))
          .go();

      // Insert new platforms
      for (final platform in platforms) {
        await into(countryPlatforms).insert(
          CountryPlatformsCompanion.insert(
            countryCode: countryCode,
            platformName: platform,
          ),
        );
      }
    });
  }

  /// Returns all platforms for a given country code, ordered alphabetically.
  Future<List<String>> getPlatformsFor(String countryCode) async {
    final query = select(countryPlatforms)
      ..where((tbl) => tbl.countryCode.equals(countryCode))
      ..orderBy([(tbl) => OrderingTerm.asc(tbl.platformName)]);
    final rows = await query.get();
    return rows.map((r) => r.platformName).toList();
  }

  /// Watches for changes to platforms for a given country code.
  Stream<List<String>> watchPlatformsFor(String countryCode) {
    final query = select(countryPlatforms)
      ..where((tbl) => tbl.countryCode.equals(countryCode))
      ..orderBy([(tbl) => OrderingTerm.asc(tbl.platformName)]);
    return query.watch().map((rows) => rows.map((r) => r.platformName).toList());
  }
}

// Conexão
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'carjobfinance.db'));
    return NativeDatabase(file);
  });
}