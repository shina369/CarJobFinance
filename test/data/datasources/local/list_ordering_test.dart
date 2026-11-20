import 'package:carjobfinance/data/datasources/local/app_database.dart';
import 'package:carjobfinance/data/datasources/local/daos.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late AppDao dao;

  setUp(() {
    db = AppDatabase.memory();
    dao = AppDao(db);
  });
  tearDown(() async => db.close());

  Future<void> insertRide(String id, DateTime date) => dao.insertRide(
        RidesCompanion.insert(
          id: id,
          date: date,
          platform: 'Uber',
          earnings: 20,
          distanceKm: 5,
          durationMinutes: 10,
          rideType: 'Comum',
          createdAt: date,
        ),
      );

  Future<void> insertExpense(String id, DateTime date) => dao.insertExpense(
        ExpensesCompanion.insert(
          id: id,
          date: date,
          category: 'Combustível',
          amount: 50,
          createdAt: date,
        ),
      );

  test('watchAllRides lists the newest ride first, whatever the insert order',
      () async {
    await insertRide('old', DateTime(2026, 11, 1, 8));
    await insertRide('new', DateTime(2026, 11, 20, 9));
    await insertRide('mid', DateTime(2026, 11, 10, 12));

    final rides = await dao.watchAllRides().first;

    expect(rides.map((r) => r.id), ['new', 'mid', 'old']);
  });

  test('watchAllExpenses lists the newest expense first', () async {
    await insertExpense('old', DateTime(2026, 11, 1));
    await insertExpense('new', DateTime(2026, 11, 20));
    await insertExpense('mid', DateTime(2026, 11, 10));

    final expenses = await dao.watchAllExpenses().first;

    expect(expenses.map((e) => e.id), ['new', 'mid', 'old']);
  });
}
