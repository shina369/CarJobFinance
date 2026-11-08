// Presentation - Controllers (Riverpod StateNotifiers)
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/local/app_database.dart' as db;
import '../../data/datasources/local/daos.dart';
import '../../data/repositories/repositories_impl.dart';
import '../../domain/entities/ride.dart' as entity_ride;
import '../../domain/entities/expense.dart' as entity_expense;
import '../../domain/repositories/repositories.dart';

// ===== PROVIDERS =====
final appDatabaseProvider = Provider<db.AppDatabase>((ref) {
  return db.AppDatabase();
});

final appDaoProvider = Provider<AppDao>((ref) {
  return AppDao(ref.watch(appDatabaseProvider));
});

final rideRepositoryProvider = Provider<RideRepository>((ref) {
  return RideRepositoryImpl(ref.watch(appDaoProvider));
});

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepositoryImpl(ref.watch(appDaoProvider));
});

// ===== RIDES =====
final ridesControllerProvider =
    StateNotifierProvider<RidesController, AsyncValue<List<entity_ride.Ride>>>((ref) {
  return RidesController(ref.watch(rideRepositoryProvider));
});

class RidesController extends StateNotifier<AsyncValue<List<entity_ride.Ride>>> {
  final RideRepository _repository;
  StreamSubscription? _subscription;

  RidesController(this._repository) : super(const AsyncValue.loading()) {
    _subscription = _repository.watchAll().listen(
      (rides) => state = AsyncValue.data(rides),
      onError: (error) => state = AsyncValue.error(error, StackTrace.current),
    );
  }

  Future<void> add(entity_ride.Ride ride) async {
    state = const AsyncValue.loading();
    try {
      await _repository.insert(ride);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> edit(entity_ride.Ride ride) async {
    state = const AsyncValue.loading();
    try {
      await _repository.update(ride);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> remove(String id) async {
    state = const AsyncValue.loading();
    try {
      await _repository.delete(id);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

// ===== EXPENSES =====
final expensesControllerProvider =
    StateNotifierProvider<ExpensesController, AsyncValue<List<entity_expense.Expense>>>(
        (ref) {
  return ExpensesController(ref.watch(expenseRepositoryProvider));
});

class ExpensesController
    extends StateNotifier<AsyncValue<List<entity_expense.Expense>>> {
  final ExpenseRepository _repository;
  StreamSubscription? _subscription;

  ExpensesController(this._repository)
      : super(const AsyncValue.loading()) {
    _subscription = _repository.watchAll().listen(
      (expenses) => state = AsyncValue.data(expenses),
      onError: (error) =>
          state = AsyncValue.error(error, StackTrace.current),
    );
  }

  Future<void> add(entity_expense.Expense expense) async {
    state = const AsyncValue.loading();
    try {
      await _repository.insert(expense);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> edit(entity_expense.Expense expense) async {
    state = const AsyncValue.loading();
    try {
      await _repository.update(expense);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> remove(String id) async {
    state = const AsyncValue.loading();
    try {
      await _repository.delete(id);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
