// Database Drift - Schema
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';

import 'package:flutter/foundation.dart' show immutable;

import '../../../core/settings/country_data.dart';

part 'app_database.g.dart';

/// Retired platform names that should be purged from older databases on
/// initialize(). COUNTRIES no longer lists them, but pre-existing rows
/// (seeded before the cutover) may remain in the table.
// ignore: constant_identifier_names
const Set<String> OBSOLETE_PLATFORM_NAMES = {'BlaBlaCar', 'Outro'};

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

  /// Whether the user has this platform active (v3+). Built-ins are
  /// seeded active; user-created names are inserted active and can be
  /// toggled or deleted.
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  /// Marks user-created platforms (v3+). Built-ins (isCustom = false)
  /// can be toggled but never deleted; customs can be removed entirely.
  BoolColumn get isCustom => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {countryCode, platformName};
}

/// Plain value object describing one [CountryPlatforms] row, decoupled
/// from the Drift-generated row class so UI/state layers can use it
/// without importing drift internals.
@immutable
class PlatformState {
  const PlatformState({
    required this.name,
    required this.isActive,
    required this.isCustom,
  });

  final String name;
  final bool isActive;
  final bool isCustom;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlatformState &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          isActive == other.isActive &&
          isCustom == other.isCustom;

  @override
  int get hashCode => Object.hash(name, isActive, isCustom);

  @override
  String toString() =>
      'PlatformState($name, active: $isActive, custom: $isCustom)';
}

// Database
@DriftDatabase(tables: [Rides, Expenses, Settings, CountryPlatforms])
class AppDatabase extends _$AppDatabase {
  /// Production constructor using file-based SQLite database.
  AppDatabase() : super(_openConnection());

  /// Test constructor using in-memory SQLite database.
  AppDatabase.memory() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 3;

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
          if (from == 2 && to == 3) {
            // v3: add per-row activation + custom flags to
            // country_platforms. Additive only; existing rows default
            // to active / not-custom.
            await customStatement(
              'ALTER TABLE country_platforms '
              'ADD COLUMN is_active INTEGER NOT NULL DEFAULT 1',
            );
            await customStatement(
              'ALTER TABLE country_platforms '
              'ADD COLUMN is_custom INTEGER NOT NULL DEFAULT 0',
            );
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
  /// Deletes existing platforms for the country first, then inserts the new
  /// list. Rows for platforms that already exist keep their
  /// `isActive`/`isCustom` flags (see [PlatformState]); new rows are
  /// inserted active and non-custom.
  Future<void> upsertCountryPlatforms(
      String countryCode, List<String> platforms,
      {Map<String, PlatformState> existingStates = const {}}) async {
    await transaction(() async {
      // Delete existing rows for this country so stale entries are gone.
      await (delete(countryPlatforms)
            ..where((tbl) => tbl.countryCode.equals(countryCode)))
          .go();

      // Insert new rows, preserving flags from [existingStates] when known.
      for (final platform in platforms) {
        final existing = existingStates[platform];
        await into(countryPlatforms).insert(
          CountryPlatformsCompanion(
            countryCode: Value(countryCode),
            platformName: Value(platform),
            isActive: Value(existing?.isActive ?? true),
            isCustom: Value(existing?.isCustom ?? false),
          ),
        );
      }
    });
  }

  /// Deletes rows whose platform name is in the given set, across all
  /// countries. Used to purge retired platform names (e.g. 'BlaBlaCar',
  /// 'Outro') that remain in older databases.
  Future<void> deleteObsoletePlatforms(Set<String> obsoleteNames) async {
    if (obsoleteNames.isEmpty) return;
    final query = delete(countryPlatforms)
      ..where((tbl) => tbl.platformName.isIn(obsoleteNames));
    await query.go();
  }

  /// Returns the full state (name, isActive, isCustom) of every platform
  /// row for a country, ordered alphabetically.
  Future<List<PlatformState>> getPlatformsFor(String countryCode) async {
    final query = select(countryPlatforms)
      ..where((tbl) => tbl.countryCode.equals(countryCode))
      ..orderBy([(tbl) => OrderingTerm.asc(tbl.platformName)]);
    final rows = await query.get();
    return rows
        .map((r) => PlatformState(
              name: r.platformName,
              isActive: r.isActive,
              isCustom: r.isCustom,
            ))
        .toList();
  }

  /// Returns just the platform names for a country (plain strings), for
  /// use by [AppSettings.fromCountry].
  Future<List<String>> getPlatformNames(String countryCode) async {
    final states = await getPlatformsFor(countryCode);
    return states.map((s) => s.name).toList();
  }

  /// Returns the [PlatformState] of each currently-known row for this
  /// country — used by [upsertCountryPlatforms] to preserve flags on
  /// re-seed.
  Future<Map<String, PlatformState>> getExistingStates(
      String countryCode) async {
    final rows = await getPlatformsFor(countryCode);
    return {for (final r in rows) r.name: r};
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