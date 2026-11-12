// Domain - UseCases
import '../entities/ride.dart';
import '../entities/expense.dart';
import '../entities/financial_summary.dart';
import '../repositories/repositories.dart';

abstract class UseCase<T, Params> {
  T call(Params params);
}

class NoParams {}

// ===== RIDES =====
class GetRidesUseCase implements UseCase<Stream<List<Ride>>, NoParams> {
  final RideRepository repository;
  GetRidesUseCase(this.repository);
  @override
  Stream<List<Ride>> call(NoParams _) => repository.watchAll();
}

class GetRideByIdUseCase implements UseCase<Future<Ride?>, String> {
  final RideRepository repository;
  GetRideByIdUseCase(this.repository);
  @override
  Future<Ride?> call(String id) => repository.getById(id);
}

class CreateRideUseCase implements UseCase<Future<int>, Ride> {
  final RideRepository repository;
  CreateRideUseCase(this.repository);
  @override
  Future<int> call(Ride ride) => repository.insert(ride);
}

class UpdateRideUseCase implements UseCase<Future<bool>, Ride> {
  final RideRepository repository;
  UpdateRideUseCase(this.repository);
  @override
  Future<bool> call(Ride ride) => repository.update(ride);
}

class DeleteRideUseCase implements UseCase<Future<int>, String> {
  final RideRepository repository;
  DeleteRideUseCase(this.repository);
  @override
  Future<int> call(String id) => repository.delete(id);
}

// ===== EXPENSES =====
class GetExpensesUseCase implements UseCase<Stream<List<Expense>>, NoParams> {
  final ExpenseRepository repository;
  GetExpensesUseCase(this.repository);
  @override
  Stream<List<Expense>> call(NoParams _) => repository.watchAll();
}

class GetExpenseByIdUseCase implements UseCase<Future<Expense?>, String> {
  final ExpenseRepository repository;
  GetExpenseByIdUseCase(this.repository);
  @override
  Future<Expense?> call(String id) => repository.getById(id);
}

class CreateExpenseUseCase implements UseCase<Future<int>, Expense> {
  final ExpenseRepository repository;
  CreateExpenseUseCase(this.repository);
  @override
  Future<int> call(Expense expense) => repository.insert(expense);
}

class UpdateExpenseUseCase implements UseCase<Future<bool>, Expense> {
  final ExpenseRepository repository;
  UpdateExpenseUseCase(this.repository);
  @override
  Future<bool> call(Expense expense) => repository.update(expense);
}

class DeleteExpenseUseCase implements UseCase<Future<int>, String> {
  final ExpenseRepository repository;
  DeleteExpenseUseCase(this.repository);
  @override
  Future<int> call(String id) => repository.delete(id);
}

// ===== SUMMARY =====
class GetFinancialSummaryUseCase
    implements UseCase<Future<FinancialSummary>, SummaryParams> {
  final RideRepository rideRepo;
  final ExpenseRepository expenseRepo;
  GetFinancialSummaryUseCase(this.rideRepo, this.expenseRepo);

  @override
  Future<FinancialSummary> call(SummaryParams params) async {
    final earnings = await rideRepo.totalEarnings(params.start, params.end);
    final expenses =
        await expenseRepo.totalByCategory(params.start, params.end);
    // totalByCategory returns a single total, not map — see repository impl
    final distance = await rideRepo.totalDistance(params.start, params.end);
    final count = await rideRepo.countTotal(params.start, params.end);
    final hours = await rideRepo.totalDurationMinutes(params.start, params.end);

    final netProfit = earnings - expenses;
    final avgPerKm = distance > 0 ? (netProfit / distance).toDouble() : 0.0;
    final avgPerHour = hours > 0 ? (netProfit / (hours / 60)).toDouble() : 0.0;
    final avgPerRide = count > 0 ? (earnings / count).toDouble() : 0.0;

    return FinancialSummary(
      totalEarnings: earnings,
      totalExpenses: expenses,
      netProfit: netProfit,
      totalKm: distance,
      totalRides: count,
      avgPerKm: avgPerKm,
      avgPerHour: avgPerHour,
      avgPerRide: avgPerRide,
      periodStart: params.start,
      periodEnd: params.end,
    );
  }
}

class SummaryParams {
  final DateTime start;
  final DateTime end;
  SummaryParams(this.start, this.end);
}
