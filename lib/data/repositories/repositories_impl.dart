// Data - Repositórios (implementações)
import 'package:drift/drift.dart' show Value;

import '../datasources/local/app_database.dart' as db;
import '../datasources/local/daos.dart';
import '../../domain/entities/ride.dart' as entity_ride;
import '../../domain/entities/expense.dart' as entity_expense;
import '../../domain/repositories/repositories.dart';

class RideRepositoryImpl implements RideRepository {
  final AppDao dao;

  RideRepositoryImpl(this.dao);

  @override
  Stream<List<entity_ride.Ride>> watchAll() =>
      dao.watchAllRides().map((rows) => rows.map(_toEntity).toList());

  @override
  Future<List<entity_ride.Ride>> getAll() async {
    final rows = await dao.getAllRides();
    return rows.map(_toEntity).toList();
  }

  @override
  Future<entity_ride.Ride?> getById(String id) async {
    final row = await dao.getRideById(id);
    return row != null ? _toEntity(row) : null;
  }

  @override
  Future<int> insert(entity_ride.Ride ride) async {
    final now = DateTime.now();
    return dao.insertRide(db.RidesCompanion.insert(
      id: ride.id,
      date: ride.date,
      platform: ride.platform,
      earnings: ride.earnings,
      distanceKm: ride.distanceKm,
      durationMinutes: ride.durationMinutes,
      origin: Value(ride.origin),
      destination: Value(ride.destination),
      rideType: ride.rideType,
      isSynced: Value(ride.isSynced),
      createdAt: ride.createdAt ?? now,
      updatedAt: Value(now),
    ));
  }

  @override
  Future<bool> update(entity_ride.Ride ride) async {
    return dao.updateRide(db.RidesCompanion(
      id: Value(ride.id),
      date: Value(ride.date),
      platform: Value(ride.platform),
      earnings: Value(ride.earnings),
      distanceKm: Value(ride.distanceKm),
      durationMinutes: Value(ride.durationMinutes),
      origin: Value(ride.origin),
      destination: Value(ride.destination),
      rideType: Value(ride.rideType),
      isSynced: Value(ride.isSynced),
      createdAt: Value(ride.createdAt ?? DateTime.now()),
      updatedAt: Value(DateTime.now()),
    ));
  }

  @override
  Future<int> delete(String id) => dao.deleteRide(id);

  @override
  Future<double> totalEarnings(DateTime start, DateTime end) =>
      dao.getTotalEarnings(start, end);

  @override
  Future<double> totalDistance(DateTime start, DateTime end) =>
      dao.getTotalKm(start, end);

  @override
  Future<int> countTotal(DateTime start, DateTime end) =>
      dao.getTotalRides(start, end);

  @override
  Future<int> totalDurationMinutes(DateTime start, DateTime end) =>
      dao.getTotalDurationMinutes(start, end);

  @override
  Future<Map<String, double>> earningsByPlatform(
          DateTime start, DateTime end) =>
      dao.getEarningsByPlatform(start, end);

  entity_ride.Ride _toEntity(db.Ride row) => entity_ride.Ride(
        id: row.id,
        date: row.date,
        platform: row.platform,
        earnings: row.earnings,
        distanceKm: row.distanceKm,
        durationMinutes: row.durationMinutes,
        origin: row.origin,
        destination: row.destination,
        rideType: row.rideType,
        isSynced: row.isSynced,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
      );
}

class ExpenseRepositoryImpl implements ExpenseRepository {
  final AppDao dao;

  ExpenseRepositoryImpl(this.dao);

  @override
  Stream<List<entity_expense.Expense>> watchAll() => dao
      .watchAllExpenses()
      .map((rows) => rows.map(_toEntity).toList());

  @override
  Future<List<entity_expense.Expense>> getAll() async {
    final rows = await dao.getAllExpenses();
    return rows.map(_toEntity).toList();
  }

  @override
  Future<entity_expense.Expense?> getById(String id) async {
    final row = await dao.getExpenseById(id);
    return row != null ? _toEntity(row) : null;
  }

  @override
  Future<int> insert(entity_expense.Expense expense) async {
    final now = DateTime.now();
    return dao.insertExpense(db.ExpensesCompanion.insert(
      id: expense.id,
      date: expense.date,
      category: expense.category,
      amount: expense.amount,
      description: Value(expense.description),
      receiptImagePath: Value(expense.receiptImagePath),
      isRecurring: Value(expense.isRecurring),
      isSynced: Value(expense.isSynced),
      createdAt: expense.createdAt ?? now,
      updatedAt: Value(now),
    ));
  }

  @override
  Future<bool> update(entity_expense.Expense expense) async {
    return dao.updateExpense(db.ExpensesCompanion(
      id: Value(expense.id),
      date: Value(expense.date),
      category: Value(expense.category),
      amount: Value(expense.amount),
      description: Value(expense.description),
      receiptImagePath: Value(expense.receiptImagePath),
      isRecurring: Value(expense.isRecurring),
      isSynced: Value(expense.isSynced),
      createdAt: Value(expense.createdAt ?? DateTime.now()),
      updatedAt: Value(DateTime.now()),
    ));
  }

  @override
  Future<int> delete(String id) => dao.deleteExpense(id);

  @override
  Future<double> totalByCategory(DateTime start, DateTime end) async {
    final result = await dao.getExpensesByDateRange(start, end);
    return result.fold<double>(0, (sum, e) => sum + e.amount);
  }

  @override
  Future<Map<String, double>> expensesByCategory(
          DateTime start, DateTime end) =>
      dao.getExpensesByCategoryReport(start, end);

  entity_expense.Expense _toEntity(db.Expense row) => entity_expense.Expense(
        id: row.id,
        date: row.date,
        category: row.category,
        amount: row.amount,
        description: row.description,
        receiptImagePath: row.receiptImagePath,
        isRecurring: row.isRecurring,
        isSynced: row.isSynced,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
      );
}

class SettingsRepositoryImpl implements SettingsRepository {
  final AppDao dao;

  SettingsRepositoryImpl(this.dao);

  static const _monthlyGoalKey = 'monthly_goal';

  @override
  Future<double> getMonthlyGoal() async {
    final value = await dao.getSetting(_monthlyGoalKey);
    if (value != null) {
      return double.tryParse(value) ?? 5000.0;
    }
    return 5000.0;
  }

  @override
  Future<void> setMonthlyGoal(double value) async {
    await dao.setSetting(_monthlyGoalKey, value.toString());
  }
}
