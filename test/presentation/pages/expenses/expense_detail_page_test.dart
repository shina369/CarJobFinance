import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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
import 'package:carjobfinance/presentation/pages/expenses/expense_detail_page.dart';

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

final _expense = Expense(
  id: 'expense-1',
  date: DateTime(2026, 11, 10),
  category: 'Combustível',
  amount: 80,
  description: 'Posto da esquina',
  isRecurring: true,
);

void main() {
  Future<void> pumpDetail(WidgetTester tester, {required String id}) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final br = COUNTRIES.firstWhere((c) => c.code == 'BR');
    final router = GoRouter(
      initialLocation: '/expenses/$id',
      routes: [
        GoRoute(
          path: '/expenses/:expenseId',
          builder: (context, state) => ExpenseDetailPage(
            expenseId: state.pathParameters['expenseId']!,
          ),
        ),
        GoRoute(
          path: '/expenses/edit/:expenseId',
          builder: (context, state) => const Scaffold(body: Text('editing')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSettingsProvider.overrideWith((ref) => _MockAppSettingsNotifier(
              AppSettings.fromCountry(br, br.platforms))),
          languageDaoProvider.overrideWithValue(_InMemoryAppDao()),
          expenseRepositoryProvider
              .overrideWithValue(_FakeExpenseRepository([_expense])),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the expense category, amount, date and details',
      (tester) async {
    await pumpDetail(tester, id: 'expense-1');

    expect(find.text('Detalhes da Despesa'), findsOneWidget);
    expect(find.text('Combustível'), findsWidgets);
    expect(find.textContaining('80'), findsWidgets);
    expect(find.text('10/11/2026'), findsWidgets);
    expect(find.text('Posto da esquina'), findsOneWidget);
    expect(find.text('Informações'), findsOneWidget);
  });

  testWidgets('the edit button opens the expense form', (tester) async {
    await pumpDetail(tester, id: 'expense-1');

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();

    expect(find.text('editing'), findsOneWidget);
  });

  testWidgets('an unknown expense shows the empty message', (tester) async {
    await pumpDetail(tester, id: 'missing');

    expect(find.text('Nenhuma despesa registrada'), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
  });
}
