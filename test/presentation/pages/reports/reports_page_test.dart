import 'dart:async';

import 'package:carjobfinance/core/l10n/currencies.dart';
import 'package:carjobfinance/core/l10n/currency_provider.dart' as currency_pkg;
import 'package:carjobfinance/core/l10n/strings.dart';
import 'package:carjobfinance/domain/entities/expense.dart';
import 'package:carjobfinance/domain/entities/ride.dart';
import 'package:carjobfinance/domain/repositories/repositories.dart';
import 'package:carjobfinance/presentation/controllers/controllers.dart';
import 'package:carjobfinance/presentation/controllers/entitlement_controller.dart';
import 'package:carjobfinance/presentation/controllers/session_controller.dart';
import 'package:carjobfinance/presentation/pages/reports/reports_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/auth_test_support.dart';

const _brl = AppCurrency(
  code: 'BRL',
  symbol: 'R\$',
  displayName: 'Real',
  formatTag: 'pt_BR',
);

class _SpyRideRepository implements RideRepository {
  int watchCalls = 0;

  @override
  Stream<List<Ride>> watchAll() {
    watchCalls++;
    return Stream.value([
      Ride(
        id: 'r1',
        date: DateTime.now(),
        platform: 'uber',
        earnings: 98765.43,
        distanceKm: 10,
        durationMinutes: 30,
        rideType: 'x',
      ),
    ]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _SpyExpenseRepository implements ExpenseRepository {
  int watchCalls = 0;

  @override
  Stream<List<Expense>> watchAll() {
    watchCalls++;
    return Stream.value([
      Expense(
        id: 'e1',
        date: DateTime.now(),
        category: 'fuel',
        amount: 4321.09,
      ),
    ]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  late AuthHarness h;
  late _SpyRideRepository rides;
  late _SpyExpenseRepository expenses;

  final locked = find.byKey(const Key('reports-locked'));
  final upgrade = find.byKey(const Key('reports-upgrade'));

  setUp(() {
    h = AuthHarness();
    rides = _SpyRideRepository();
    expenses = _SpyExpenseRepository();
  });

  Future<ProviderContainer> pumpReports(
    WidgetTester tester, {
    bool? premium,
    bool signedIn = false,
  }) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    if (signedIn) h.auth.current = testAccount;
    final container = ProviderContainer(overrides: [
      ...h.overrides,
      if (premium != null) premiumOverrideProvider.overrideWithValue(premium),
      rideRepositoryProvider.overrideWithValue(rides),
      expenseRepositoryProvider.overrideWithValue(expenses),
      currency_pkg.appCurrencyProvider.overrideWithValue(_brl),
    ]);
    addTearDown(container.dispose);
    if (signedIn) {
      await tester
          .runAsync(container.read(sessionProvider.notifier).initialize);
    }

    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const ReportsPage()),
      GoRoute(
        path: '/paywall',
        builder: (_, __) => const Scaffold(body: Text('paywall-stub')),
      ),
    ]);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ));
    return container;
  }

  group('free user', () {
    testWidgets('sees the blurred sample and never the real data',
        (tester) async {
      await pumpReports(tester, premium: false);
      await tester.pumpAndSettle();

      expect(locked, findsOneWidget);
      expect(find.byKey(const Key('reports-sample-banner')), findsOneWidget);
      expect(find.text(h.language.tr('premium.reports.sampleBanner')),
          findsOneWidget);
      expect(upgrade, findsOneWidget);
      expect(find.byType(MenuAnchor), findsNothing);
      expect(find.text(h.language.tr('reports.period')), findsNothing);
      expect(find.textContaining('98.765'), findsNothing);
      expect(find.textContaining('4.321'), findsNothing);
      expect(rides.watchCalls, 0);
      expect(expenses.watchCalls, 0);
    });

    testWidgets('sample is blurred and cannot be interacted with',
        (tester) async {
      await pumpReports(tester, premium: false);
      await tester.pumpAndSettle();

      final sample = find.byKey(const Key('reports-sample'));
      expect(sample, findsOneWidget);
      expect(
        find.descendant(of: locked, matching: find.byType(ImageFiltered)),
        findsOneWidget,
      );
      expect(
        find.ancestor(of: sample, matching: find.byType(IgnorePointer)),
        findsWidgets,
      );
    });

    testWidgets('upgrade button opens the paywall', (tester) async {
      await pumpReports(tester, premium: false);
      await tester.pumpAndSettle();

      await tester.tap(upgrade);
      await tester.pumpAndSettle();

      expect(find.text('paywall-stub'), findsOneWidget);
    });
  });

  group('premium user', () {
    testWidgets('sees the real reports unchanged', (tester) async {
      await pumpReports(tester, premium: true);
      await tester.pumpAndSettle();

      expect(locked, findsNothing);
      expect(find.byType(MenuAnchor), findsOneWidget);
      expect(find.text(h.language.tr('reports.period')), findsOneWidget);
      expect(find.textContaining('98.765,43'), findsWidgets);
    });
  });

  group('cold start', () {
    testWidgets('premium never flashes the sample while the store answers',
        (tester) async {
      h.purchases.delay = const Duration(milliseconds: 500);
      await pumpReports(tester, signedIn: true);

      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(locked, findsNothing);
      expect(find.byType(MenuAnchor), findsNothing);
      expect(rides.watchCalls, 0);

      await tester
          .runAsync(() => Future<void>.delayed(const Duration(seconds: 2)));
      await tester.pumpAndSettle();

      expect(locked, findsNothing);
      expect(find.byType(MenuAnchor), findsOneWidget);
    });

    testWidgets('free user gets the sample once the store answers',
        (tester) async {
      h.premium = false;
      h.purchases.delay = const Duration(milliseconds: 500);
      await pumpReports(tester, signedIn: true);

      await tester.pump();
      expect(locked, findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester
          .runAsync(() => Future<void>.delayed(const Duration(seconds: 2)));
      await tester.pumpAndSettle();

      expect(locked, findsOneWidget);
      expect(rides.watchCalls, 0);
    });
  });
}
