import 'package:carjobfinance/core/l10n/currencies.dart';
import 'package:carjobfinance/core/l10n/currency_provider.dart' as currency_pkg;
import 'package:carjobfinance/core/l10n/language_provider.dart';
import 'package:carjobfinance/core/l10n/languages.dart';
import 'package:carjobfinance/domain/repositories/repositories.dart';
import 'package:carjobfinance/presentation/controllers/controllers.dart';
import 'package:carjobfinance/presentation/pages/goals/my_goals_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

class _FakeSettingsRepository implements SettingsRepository {
  _FakeSettingsRepository(this.goalsByYear);

  final Map<int, Map<int, double?>> goalsByYear;
  final List<(int, Map<int, double?>)> saves = [];

  @override
  Future<double> getMonthlyGoal() async => 5000;

  @override
  Future<void> setMonthlyGoal(double value) async {}

  @override
  Future<Map<int, double?>> getGoalsForYear(int year) async => {
        for (var month = 1; month <= 12; month++)
          month: goalsByYear[year]?[month],
      };

  @override
  Future<void> setGoalsForYear(int year, Map<int, double?> goals) async {
    saves.add((year, goals));
    goalsByYear.putIfAbsent(year, () => {}).addAll(goals);
  }
}

void main() {
  final year = DateTime.now().year;

  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
  });

  Future<_FakeSettingsRepository> pumpPage(
    WidgetTester tester, {
    Map<int, Map<int, double?>> goals = const {},
  }) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    final repository = _FakeSettingsRepository({
      for (final entry in goals.entries) entry.key: {...entry.value},
    });
    final language = SUPPORTED_LANGUAGES.firstWhere((l) => l.tag == 'pt_BR');
    final currency = SUPPORTED_CURRENCIES.firstWhere((c) => c.code == 'BRL');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(repository),
          appLanguageProvider.overrideWithValue(language),
          appLocaleProvider.overrideWithValue(const Locale('pt', 'BR')),
          currency_pkg.appCurrencyProvider.overrideWithValue(currency),
        ],
        child: const MaterialApp(home: MyGoalsPage()),
      ),
    );
    await tester.pumpAndSettle();
    return repository;
  }

  Finder monthField(String label) => find.widgetWithText(TextField, label);

  String textOf(WidgetTester tester, String label) =>
      tester.widget<TextField>(monthField(label)).controller!.text;

  testWidgets('lists the twelve months with their saved goals', (tester) async {
    await pumpPage(tester, goals: {
      year: {3: 6500},
    });

    expect(find.text('$year'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(12));
    expect(textOf(tester, 'Março'), '6500,00');
    expect(textOf(tester, 'Janeiro'), '');
  });

  testWidgets('saves only the months the user changed', (tester) async {
    final repository = await pumpPage(tester, goals: {
      year: {3: 6500},
    });

    await tester.enterText(monthField('Julho'), '7000');
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.pumpAndSettle();

    expect(repository.saves.length, 1);
    final (savedYear, changes) = repository.saves.single;
    expect(savedYear, year);
    expect(changes, {7: 7000.0});
    expect(find.text('Objetivos salvos'), findsOneWidget);
  });

  testWidgets('clearing a saved month removes its goal', (tester) async {
    final repository = await pumpPage(tester, goals: {
      year: {3: 6500},
    });

    await tester.enterText(monthField('Março'), '');
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.pumpAndSettle();

    expect(repository.saves.single.$2, {3: null});
  });

  testWidgets('an invalid amount is flagged and nothing is saved',
      (tester) async {
    final repository = await pumpPage(tester);

    await tester.enterText(monthField('Abril'), 'abc');
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.pumpAndSettle();

    expect(find.text('Valor inválido'), findsOneWidget);
    expect(repository.saves, isEmpty);
  });

  testWidgets('the year arrows change the year shown', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();

    expect(find.text('${year + 1}'), findsOneWidget);
  });
}
