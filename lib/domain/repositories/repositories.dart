// Domain - Repositórios (contratos)
import 'dart:async';

import '../../../domain/entities/ride.dart';
import '../../../domain/entities/expense.dart';

abstract class RideRepository {
  Stream<List<Ride>> watchAll();
  Future<List<Ride>> getAll();
  Future<Ride?> getById(String id);
  Future<int> insert(Ride ride);
  Future<bool> update(Ride ride);
  Future<int> delete(String id);
  Future<double> totalEarnings(DateTime start, DateTime end);
  Future<double> totalDistance(DateTime start, DateTime end);
  Future<int> countTotal(DateTime start, DateTime end);
  Future<int> totalDurationMinutes(DateTime start, DateTime end);
  Future<Map<String, double>> earningsByPlatform(
      DateTime start, DateTime end);
}

abstract class ExpenseRepository {
  Stream<List<Expense>> watchAll();
  Future<List<Expense>> getAll();
  Future<Expense?> getById(String id);
  Future<int> insert(Expense expense);
  Future<bool> update(Expense expense);
  Future<int> delete(String id);
  Future<double> totalByCategory(DateTime start, DateTime end);
  Future<Map<String, double>> expensesByCategory(
      DateTime start, DateTime end);
}
