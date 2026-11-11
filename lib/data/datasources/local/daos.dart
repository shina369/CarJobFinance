// DAOs para acesso ao banco de dados Drift
import 'package:drift/drift.dart';

import 'app_database.dart';

part 'daos.g.dart';

@DriftAccessor(tables: [Rides, Expenses, Settings, CountryPlatforms])
class AppDao extends DatabaseAccessor<AppDatabase> with _$AppDaoMixin {
  AppDao(super.db);

  // ===== RIDES =====

  Future<List<Ride>> getAllRides() => select(rides).get();

  Stream<List<Ride>> watchAllRides() => select(rides).watch();

  Future<List<Ride>> getRidesByDateRange(DateTime start, DateTime end) =>
      (select(rides)
            ..where((r) => r.date.isBetweenValues(start, end))
            ..orderBy([(r) => OrderingTerm.desc(r.date)]))
          .get();

  Stream<List<Ride>> watchRidesByDateRange(DateTime start, DateTime end) =>
      (select(rides)
            ..where((r) => r.date.isBetweenValues(start, end))
            ..orderBy([(r) => OrderingTerm.desc(r.date)]))
          .watch();

  Future<List<Ride>> getRidesByPlatform(String platform) =>
      (select(rides)..where((r) => r.platform.equals(platform))).get();

  Future<int> insertRide(RidesCompanion ride) => into(rides).insert(ride);

  Future<bool> updateRide(RidesCompanion ride) => update(rides).replace(ride);

  Future<int> deleteRide(String id) =>
      (delete(rides)..where((r) => r.id.equals(id))).go();

  Future<int> deleteAllRides() => delete(rides).go();

  Future<Ride?> getRideById(String id) =>
      (select(rides)..where((r) => r.id.equals(id))).getSingleOrNull();

  // ===== EXPENSES =====

  Future<List<Expense>> getAllExpenses() => select(expenses).get();

  Stream<List<Expense>> watchAllExpenses() => select(expenses).watch();

  Future<List<Expense>> getExpensesByDateRange(DateTime start, DateTime end) =>
      (select(expenses)
            ..where((e) => e.date.isBetweenValues(start, end))
            ..orderBy([(e) => OrderingTerm.desc(e.date)]))
          .get();

  Stream<List<Expense>> watchExpensesByDateRange(
          DateTime start, DateTime end) =>
      (select(expenses)
            ..where((e) => e.date.isBetweenValues(start, end))
            ..orderBy([(e) => OrderingTerm.desc(e.date)]))
          .watch();

  Future<List<Expense>> getExpensesByCategory(String category) =>
      (select(expenses)..where((e) => e.category.equals(category))).get();

  Future<int> insertExpense(ExpensesCompanion expense) =>
      into(expenses).insert(expense);

  Future<bool> updateExpense(ExpensesCompanion expense) =>
      update(expenses).replace(expense);

  Future<int> deleteExpense(String id) =>
      (delete(expenses)..where((e) => e.id.equals(id))).go();

  Future<int> deleteAllExpenses() => delete(expenses).go();

  Future<Expense?> getExpenseById(String id) =>
      (select(expenses)..where((e) => e.id.equals(id))).getSingleOrNull();

  // ===== SETTINGS =====

  Future<String?> getSetting(String key) =>
      (select(settings)..where((s) => s.key.equals(key)))
          .map((s) => s.value)
          .getSingleOrNull();

  Future<void> setSetting(String key, String value) =>
      into(settings).insertOnConflictUpdate(SettingsCompanion.insert(
          key: key, value: value, updatedAt: DateTime.now()));

  Future<void> deleteSetting(String key) =>
      (delete(settings)..where((s) => s.key.equals(key))).go();

  Future<Map<String, String>> getAllSettings() async {
    final rows = await select(settings).get();
    return {for (var row in rows) row.key: row.value};
  }

  // ===== COUNTRY PLATFORMS =====

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

  /// Returns the full per-row state (name, isActive, isCustom) of every
  /// platform for a country, ordered alphabetically.
  Future<List<PlatformState>> getPlatformStatesFor(String countryCode) async {
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

  /// Toggles the [isActive] flag for a single platform row.
  Future<void> setActive(
      String countryCode, String platform, bool active) async {
    await (update(countryPlatforms)
          ..where(
            (tbl) =>
                tbl.countryCode.equals(countryCode) &
                tbl.platformName.equals(platform),
          ))
        .write(CountryPlatformsCompanion(isActive: Value(active)));
  }

  /// Inserts a new user-created (custom) platform row for a country.
  /// The caller is responsible for pre-validating that the name does
  /// not already exist (built-in or custom, case-insensitive).
  Future<void> createCustom(String countryCode, String platform) async {
    await into(countryPlatforms).insertOnConflictUpdate(
      CountryPlatformsCompanion(
        countryCode: Value(countryCode),
        platformName: Value(platform),
        isActive: const Value(true),
        isCustom: const Value(true),
      ),
    );
  }

  /// Deletes a custom platform row for a country. No-op for built-ins
  /// (they can only be toggled, not removed).
  Future<void> deleteCustom(String countryCode, String platform) async {
    await (delete(countryPlatforms)
          ..where(
            (tbl) =>
                tbl.countryCode.equals(countryCode) &
                tbl.platformName.equals(platform),
          ))
        .go();
  }

  Future<List<String>> getPlatformsFor(String countryCode) async {
    final query = select(countryPlatforms)
      ..where((tbl) => tbl.countryCode.equals(countryCode))
      ..orderBy([(tbl) => OrderingTerm.asc(tbl.platformName)]);
    final rows = await query.get();
    return rows.map((r) => r.platformName).toList();
  }

  Stream<List<String>> watchPlatformsFor(String countryCode) {
    final query = select(countryPlatforms)
      ..where((tbl) => tbl.countryCode.equals(countryCode))
      ..orderBy([(tbl) => OrderingTerm.asc(tbl.platformName)]);
    return query.watch().map((rows) => rows.map((r) => r.platformName).toList());
  }

  // ===== AGGREGATIONS / RELATÓRIOS =====

  Future<double> getTotalEarnings(DateTime start, DateTime end) async {
    final query = selectOnly(rides)
      ..addColumns([rides.earnings.sum()])
      ..where(rides.date.isBetweenValues(start, end));
    final result = await query.getSingle();
    return result.read(rides.earnings.sum()) ?? 0.0;
  }

  Future<double> getTotalExpenses(DateTime start, DateTime end) async {
    final query = selectOnly(expenses)
      ..addColumns([expenses.amount.sum()])
      ..where(expenses.date.isBetweenValues(start, end));
    final result = await query.getSingle();
    return result.read(expenses.amount.sum()) ?? 0.0;
  }

  Future<int> getTotalRides(DateTime start, DateTime end) async {
    final query = selectOnly(rides)
      ..addColumns([rides.id.count()])
      ..where(rides.date.isBetweenValues(start, end));
    final result = await query.getSingle();
    return result.read(rides.id.count()) ?? 0;
  }

  Future<double> getTotalKm(DateTime start, DateTime end) async {
    final query = selectOnly(rides)
      ..addColumns([rides.distanceKm.sum()])
      ..where(rides.date.isBetweenValues(start, end));
    final result = await query.getSingle();
    return result.read(rides.distanceKm.sum()) ?? 0.0;
  }

  Future<int> getTotalDurationMinutes(DateTime start, DateTime end) async {
    final query = selectOnly(rides)
      ..addColumns([rides.durationMinutes.sum()])
      ..where(rides.date.isBetweenValues(start, end));
    final result = await query.getSingle();
    return result.read(rides.durationMinutes.sum()) ?? 0;
  }

  Future<Map<String, double>> getEarningsByPlatform(
      DateTime start, DateTime end) async {
    final query = selectOnly(rides)
      ..addColumns([rides.platform, rides.earnings.sum()])
      ..where(rides.date.isBetweenValues(start, end))
      ..groupBy([rides.platform]);
    final rows = await query.get();
    return {
      for (var row in rows)
        row.read(rides.platform) ?? '': row.read(rides.earnings.sum()) ?? 0.0
    };
  }

  Future<Map<String, double>> getExpensesByCategoryReport(
      DateTime start, DateTime end) async {
    final query = selectOnly(expenses)
      ..addColumns([expenses.category, expenses.amount.sum()])
      ..where(expenses.date.isBetweenValues(start, end))
      ..groupBy([expenses.category]);
    final rows = await query.get();
    return {
      for (var row in rows)
        row.read(expenses.category) ?? '':
            row.read(expenses.amount.sum()) ?? 0.0
    };
  }
}