// Sort and filter options for the Rides and Expenses lists.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/expense.dart';
import '../../domain/entities/ride.dart';

enum ListSort { newest, oldest, highest, lowest }

/// How a list is shown: its sort order and an optional filter value
/// (a platform for rides, a category for expenses).
class ListViewOptions {
  const ListViewOptions({this.sort = ListSort.newest, this.filter});

  final ListSort sort;
  final String? filter;

  ListViewOptions withSort(ListSort sort) =>
      ListViewOptions(sort: sort, filter: filter);

  ListViewOptions withFilter(String? filter) =>
      ListViewOptions(sort: sort, filter: filter);
}

final ridesViewOptionsProvider =
    StateProvider<ListViewOptions>((ref) => const ListViewOptions());

final expensesViewOptionsProvider =
    StateProvider<ListViewOptions>((ref) => const ListViewOptions());

List<T> _apply<T>(
  List<T> items,
  ListViewOptions options, {
  required DateTime Function(T) date,
  required double Function(T) value,
  required String Function(T) key,
}) {
  final filter = options.filter;
  final result = [
    for (final item in items)
      if (filter == null || key(item) == filter) item,
  ];
  final int Function(T, T) compare = switch (options.sort) {
    ListSort.newest => (a, b) => date(b).compareTo(date(a)),
    ListSort.oldest => (a, b) => date(a).compareTo(date(b)),
    ListSort.highest => (a, b) => value(b).compareTo(value(a)),
    ListSort.lowest => (a, b) => value(a).compareTo(value(b)),
  };
  // List.sort is not stable, so ties fall back to newest first.
  result.sort((a, b) {
    final c = compare(a, b);
    return c != 0 ? c : date(b).compareTo(date(a));
  });
  return result;
}

List<Ride> applyRideView(List<Ride> rides, ListViewOptions options) =>
    _apply(rides, options,
        date: (r) => r.date, value: (r) => r.earnings, key: (r) => r.platform);

List<Expense> applyExpenseView(
        List<Expense> expenses, ListViewOptions options) =>
    _apply(expenses, options,
        date: (e) => e.date, value: (e) => e.amount, key: (e) => e.category);

/// Distinct values offered in a filter menu, sorted case-insensitively.
List<String> filterValues(Iterable<String> values) => values.toSet().toList()
  ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
