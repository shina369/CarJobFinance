import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:carjobfinance/core/l10n/currencies.dart';
import 'package:carjobfinance/core/l10n/currency_provider.dart' as currency_pkg;
import 'package:carjobfinance/core/l10n/language_provider.dart';
import 'package:carjobfinance/core/settings/app_settings_notifier.dart';
import 'package:carjobfinance/core/settings/country_data.dart';
import 'package:carjobfinance/data/datasources/local/app_database.dart'
    show CountryPlatformsDao;
import 'package:carjobfinance/data/datasources/local/daos.dart' show AppDao;
import 'package:carjobfinance/domain/entities/expense.dart';
import 'package:carjobfinance/domain/repositories/repositories.dart';
import 'package:carjobfinance/presentation/controllers/controllers.dart'
    show expenseRepositoryProvider;
import 'package:carjobfinance/presentation/pages/expenses/expenses_page.dart';

class _InMemoryAppDao implements AppDao {
  final Map<String, String> _storage = {};

  @override
  Future<String?> getSetting(String key) async => _storage[key];

  @override
  Future<void> setSetting(String key, String value) async {
    _storage[key] = value;
  }

  @override
  Future<void> deleteSetting(String key) async {
    _storage.remove(key);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('InMemoryAppDao');
}

class _FakeAppDao implements AppDao {
  @override
  noSuchMethod(Invocation invocation) => throw UnimplementedError('FakeAppDao');
}

class _FakeCountryPlatformsDao implements CountryPlatformsDao {
  @override
  noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('FakeCountryPlatformsDao');
}

class _MockAppSettingsNotifier extends AppSettingsNotifier {
  _MockAppSettingsNotifier(AppSettings initialState)
      : super.forTesting(
            _FakeAppDao(), _FakeCountryPlatformsDao(), initialState);
}

class _FakeExpenseRepository implements ExpenseRepository {
  _FakeExpenseRepository(this.expenses);

  final List<Expense> expenses;

  @override
  Stream<List<Expense>> watchAll() => Stream.value(expenses);

  @override
  noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('FakeExpenseRepository');
}

void main() {
  testWidgets(
      'expense amounts use the user-selected currency instead of hardcoded R\$',
      (tester) async {
    final br = COUNTRIES.firstWhere((c) => c.code == 'BR');
    final euro = currencyForCode('EUR')!;
    final expense = Expense(
      id: 'expense-1',
      date: DateTime(2026, 1, 10),
      category: 'Combustível',
      amount: 80.0,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSettingsProvider.overrideWith((ref) => _MockAppSettingsNotifier(
              AppSettings.fromCountry(br, br.platforms))),
          languageDaoProvider.overrideWithValue(_InMemoryAppDao()),
          expenseRepositoryProvider
              .overrideWithValue(_FakeExpenseRepository([expense])),
          currency_pkg.appCurrencyProvider.overrideWithValue(euro),
        ],
        child: const MaterialApp(home: ExpensesPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('€'), findsOneWidget);
    expect(find.textContaining(r'R$'), findsNothing);
  });
}
