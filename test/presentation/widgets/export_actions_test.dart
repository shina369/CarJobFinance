import 'dart:async';
import 'dart:typed_data';

import 'package:carjobfinance/core/export/file_exporter.dart';
import 'package:carjobfinance/core/l10n/currencies.dart';
import 'package:carjobfinance/core/l10n/currency_provider.dart' as currency_pkg;
import 'package:carjobfinance/core/l10n/language_provider.dart';
import 'package:carjobfinance/core/l10n/languages.dart';
import 'package:carjobfinance/core/l10n/strings.dart';
import 'package:carjobfinance/data/datasources/local/backup_data.dart';
import 'package:carjobfinance/domain/entities/expense.dart';
import 'package:carjobfinance/domain/entities/ride.dart';
import 'package:carjobfinance/domain/repositories/repositories.dart';
import 'package:carjobfinance/presentation/controllers/controllers.dart'
    show expenseRepositoryProvider, rideRepositoryProvider;
import 'package:carjobfinance/presentation/controllers/data_controller.dart';
import 'package:carjobfinance/presentation/controllers/entitlement_controller.dart';
import 'package:carjobfinance/presentation/controllers/session_controller.dart';
import 'package:carjobfinance/presentation/widgets/export_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/auth_test_support.dart';

class _FakeDataController implements DataController {
  int backupsExported = 0;

  @override
  Future<bool> exportBackup() async {
    backupsExported++;
    return true;
  }

  @override
  Future<BackupData?> pickBackup() async => null;

  @override
  Future<void> restore(BackupData data) async {}

  @override
  Future<void> clearAll() async {}
}

class _RecordingExporter implements FileExporter {
  final List<String> fileNames = [];

  @override
  Future<bool> export({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    fileNames.add(fileName);
    return true;
  }
}

class _FakeRideRepository implements RideRepository {
  @override
  Future<List<Ride>> getAll() async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('FakeRideRepository');
}

class _FakeExpenseRepository implements ExpenseRepository {
  @override
  Future<List<Expense>> getAll() async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('FakeExpenseRepository');
}

void main() {
  final ptBr = languageForTag('pt_BR')!;
  late _RecordingExporter exporter;
  late _FakeDataController data;
  late int paywallOpens;

  GoRouter buildRouter() {
    return GoRouter(routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const Scaffold(body: ExportTiles()),
      ),
      GoRoute(
        path: '/paywall',
        builder: (context, _) {
          paywallOpens++;
          return Scaffold(
            body: TextButton(
              onPressed: () => context.pop(),
              child: const Text('paywall'),
            ),
          );
        },
      ),
    ]);
  }

  Future<void> pumpTiles(WidgetTester tester, {required bool premium}) async {
    exporter = _RecordingExporter();
    data = _FakeDataController();
    paywallOpens = 0;
    final router = GoRouter(routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const Scaffold(body: ExportTiles()),
      ),
      GoRoute(
        path: '/paywall',
        builder: (context, _) {
          paywallOpens++;
          return Scaffold(
            body: TextButton(
              onPressed: () => context.pop(),
              child: const Text('paywall'),
            ),
          );
        },
      ),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        appLanguageProvider.overrideWithValue(ptBr),
        currency_pkg.appCurrencyProvider
            .overrideWithValue(currencyForCode('BRL')!),
        premiumOverrideProvider.overrideWithValue(premium),
        fileExporterProvider.overrideWithValue(exporter),
        dataControllerProvider.overrideWithValue(data),
        rideRepositoryProvider.overrideWithValue(_FakeRideRepository()),
        expenseRepositoryProvider.overrideWithValue(_FakeExpenseRepository()),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
  }

  group('without the subscription', () {
    testWidgets('CSV and PDF show a lock and the premium label',
        (tester) async {
      await pumpTiles(tester, premium: false);

      expect(find.byKey(const Key('export-csv-lock')), findsOneWidget);
      expect(find.byKey(const Key('export-pdf-lock')), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsNWidgets(2));
      expect(find.text(ptBr.tr('premium.locked')), findsNWidgets(2));
    });

    testWidgets('the backup tile never shows a lock', (tester) async {
      await pumpTiles(tester, premium: false);

      final backupTile = find.ancestor(
        of: find.text(ptBr.tr('reports.backup')),
        matching: find.byType(ListTile),
      );
      expect(
        find.descendant(
            of: backupTile, matching: find.byIcon(Icons.lock_outline)),
        findsNothing,
      );
    });

    testWidgets('tapping CSV opens the paywall and exports nothing',
        (tester) async {
      await pumpTiles(tester, premium: false);

      await tester.tap(find.text(ptBr.tr('reports.exportCsv')));
      await tester.pumpAndSettle();

      expect(paywallOpens, greaterThan(0));
      expect(exporter.fileNames, isEmpty);
      expect(data.backupsExported, 0);
    });

    testWidgets('tapping PDF opens the paywall and exports nothing',
        (tester) async {
      await pumpTiles(tester, premium: false);

      await tester.tap(find.text(ptBr.tr('reports.exportPdf')));
      await tester.pumpAndSettle();

      expect(paywallOpens, greaterThan(0));
      expect(exporter.fileNames, isEmpty);
      expect(data.backupsExported, 0);
    });

    testWidgets('the JSON backup opens without the paywall', (tester) async {
      await pumpTiles(tester, premium: false);

      await tester.tap(find.text(ptBr.tr('reports.backup')));
      await tester.pumpAndSettle();

      expect(paywallOpens, 0);
      expect(data.backupsExported, 1);
      expect(exporter.fileNames, isEmpty);
    });
  });

  group('with the subscription', () {
    testWidgets('no lock is shown', (tester) async {
      await pumpTiles(tester, premium: true);

      expect(find.byKey(const Key('export-csv-lock')), findsNothing);
      expect(find.byKey(const Key('export-pdf-lock')), findsNothing);
      expect(find.byIcon(Icons.lock_outline), findsNothing);
      expect(find.text(ptBr.tr('premium.locked')), findsNothing);
    });

    testWidgets('CSV exports without the paywall', (tester) async {
      await pumpTiles(tester, premium: true);

      await tester.tap(find.text(ptBr.tr('reports.exportCsv')));
      await tester.pumpAndSettle();

      expect(paywallOpens, 0);
      expect(exporter.fileNames.single, endsWith('.csv'));
    });

    testWidgets('PDF exports without the paywall', (tester) async {
      await pumpTiles(tester, premium: true);

      await tester.runAsync(() async {
        await tester.tap(find.text(ptBr.tr('reports.exportPdf')));
        for (var i = 0; i < 100 && exporter.fileNames.isEmpty; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
      });
      await tester.pumpAndSettle();

      expect(paywallOpens, 0);
      expect(exporter.fileNames.single, endsWith('.pdf'));
    });

    testWidgets('the JSON backup exports', (tester) async {
      await pumpTiles(tester, premium: true);

      await tester.tap(find.text(ptBr.tr('reports.backup')));
      await tester.pumpAndSettle();

      expect(paywallOpens, 0);
      expect(data.backupsExported, 1);
    });
  });

  group('while the entitlement is unresolved', () {
    testWidgets('a premium driver sees no lock and is not sent to the paywall',
        (tester) async {
      exporter = _RecordingExporter();
      data = _FakeDataController();
      paywallOpens = 0;
      final h = AuthHarness()..auth.current = testAccount;
      final store = Completer<void>();
      h.purchases.stallCurrentInfo = store;
      final container = ProviderContainer(overrides: [
        ...h.overrides,
        currency_pkg.appCurrencyProvider
            .overrideWithValue(currencyForCode('BRL')!),
        fileExporterProvider.overrideWithValue(exporter),
        dataControllerProvider.overrideWithValue(data),
        rideRepositoryProvider.overrideWithValue(_FakeRideRepository()),
        expenseRepositoryProvider.overrideWithValue(_FakeExpenseRepository()),
      ]);
      addTearDown(container.dispose);
      await tester
          .runAsync(container.read(sessionProvider.notifier).initialize);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: buildRouter()),
      ));
      await tester.pump();

      expect(container.read(entitlementProvider).resolved, isFalse);
      expect(find.byKey(const Key('export-csv-lock')), findsNothing);
      expect(find.byKey(const Key('export-pdf-lock')), findsNothing);
      expect(find.text(ptBr.tr('premium.locked')), findsNothing);

      await tester.tap(find.text(ptBr.tr('reports.exportCsv')));
      await tester.pump();
      store.complete();
      await tester.pumpAndSettle();

      expect(paywallOpens, 0);
      expect(exporter.fileNames.single, endsWith('.csv'));
    });
  });
}
