import 'package:carjobfinance/domain/entities/expense.dart';
import 'package:carjobfinance/domain/entities/ride.dart';
import 'package:carjobfinance/presentation/controllers/list_view_options.dart';
import 'package:flutter_test/flutter_test.dart';

Ride _ride(String id, DateTime date, double earnings, String platform) => Ride(
      id: id,
      date: date,
      platform: platform,
      earnings: earnings,
      distanceKm: 5,
      durationMinutes: 10,
      rideType: 'Comum',
    );

Expense _expense(String id, DateTime date, double amount, String category) =>
    Expense(id: id, date: date, category: category, amount: amount);

void main() {
  final rides = [
    _ride('a', DateTime(2026, 11, 1), 30, 'Uber'),
    _ride('b', DateTime(2026, 11, 20), 10, '99'),
    _ride('c', DateTime(2026, 11, 10), 50, 'Uber'),
  ];

  final expenses = [
    _expense('a', DateTime(2026, 11, 1), 200, 'Combustível'),
    _expense('b', DateTime(2026, 11, 20), 15, 'Pedágio'),
    _expense('c', DateTime(2026, 11, 10), 40, 'Lavagem'),
  ];

  group('applyRideView', () {
    test('newest first by default', () {
      expect(applyRideView(rides, const ListViewOptions()).map((r) => r.id),
          ['b', 'c', 'a']);
    });

    test('oldest first', () {
      final view =
          applyRideView(rides, const ListViewOptions(sort: ListSort.oldest));
      expect(view.map((r) => r.id), ['a', 'c', 'b']);
    });

    test('highest and lowest earnings', () {
      expect(
          applyRideView(rides, const ListViewOptions(sort: ListSort.highest))
              .map((r) => r.id),
          ['c', 'a', 'b']);
      expect(
          applyRideView(rides, const ListViewOptions(sort: ListSort.lowest))
              .map((r) => r.id),
          ['b', 'a', 'c']);
    });

    test('filters by platform and keeps the chosen order', () {
      final view = applyRideView(
          rides, const ListViewOptions(filter: 'Uber', sort: ListSort.oldest));
      expect(view.map((r) => r.id), ['a', 'c']);
    });

    test('does not mutate the input list', () {
      applyRideView(rides, const ListViewOptions(sort: ListSort.highest));
      expect(rides.map((r) => r.id), ['a', 'b', 'c']);
    });
  });

  group('applyExpenseView', () {
    test('newest first by default', () {
      expect(
          applyExpenseView(expenses, const ListViewOptions()).map((e) => e.id),
          ['b', 'c', 'a']);
    });

    test('highest amount first', () {
      expect(
          applyExpenseView(
                  expenses, const ListViewOptions(sort: ListSort.highest))
              .map((e) => e.id),
          ['a', 'c', 'b']);
    });

    test('filters by category', () {
      expect(
          applyExpenseView(expenses, const ListViewOptions(filter: 'Lavagem'))
              .map((e) => e.id),
          ['c']);
    });
  });

  test('filterValues lists distinct values sorted, ignoring case', () {
    expect(filterValues(['Uber', '99', 'inDrive', 'Uber']),
        ['99', 'inDrive', 'Uber']);
  });

  test('clearing the filter keeps the sort', () {
    const options = ListViewOptions(filter: 'Uber', sort: ListSort.lowest);
    final cleared = options.withFilter(null);
    expect(cleared.filter, isNull);
    expect(cleared.sort, ListSort.lowest);
  });
}
