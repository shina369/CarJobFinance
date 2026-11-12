import 'dart:convert';
import 'dart:typed_data';

import 'package:carjobfinance/core/constants/app_constants.dart';
import 'package:carjobfinance/core/export/file_exporter.dart';
import 'package:carjobfinance/core/l10n/currencies.dart';
import 'package:carjobfinance/core/l10n/currency_provider.dart' as currency_pkg;
import 'package:carjobfinance/core/l10n/language_provider.dart';
import 'package:carjobfinance/core/l10n/languages.dart';
import 'package:carjobfinance/core/l10n/strings.dart';
import 'package:carjobfinance/core/notifications/notification_service.dart';
import 'package:carjobfinance/core/notifications/notification_settings.dart';
import 'package:carjobfinance/core/notifications/reminder.dart';
import 'package:carjobfinance/core/settings/app_settings_notifier.dart';
import 'package:carjobfinance/data/datasources/local/app_database.dart'
    show CountryPlatformsDao, PlatformState;
import 'package:carjobfinance/data/datasources/local/backup_data.dart';
import 'package:carjobfinance/data/datasources/local/daos.dart' show AppDao;
import 'package:carjobfinance/domain/entities/expense.dart';
import 'package:carjobfinance/domain/entities/ride.dart';
import 'package:carjobfinance/domain/repositories/repositories.dart';
import 'package:carjobfinance/presentation/controllers/controllers.dart'
    show expenseRepositoryProvider, rideRepositoryProvider;
import 'package:carjobfinance/presentation/controllers/data_controller.dart';
import 'package:carjobfinance/presentation/pages/settings/backup_page.dart';
import 'package:carjobfinance/presentation/pages/settings/legal_page.dart';
import 'package:carjobfinance/presentation/pages/settings/reminders_page.dart';
import 'package:carjobfinance/presentation/pages/settings/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _InMemoryAppDao implements AppDao {
  final Map<String, String> storage = {};

  @override
  Future<String?> getSetting(String key) async => storage[key];

  @override
  Future<void> setSetting(String key, String value) async {
    storage[key] = value;
  }

  @override
  Future<void> deleteSetting(String key) async {
    storage.remove(key);
  }

  @override
  Future<List<PlatformState>> getPlatformStatesFor(String countryCode) async =>
      [];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('InMemoryAppDao');
}

class _FakeCountryPlatformsDao implements CountryPlatformsDao {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('FakeCountryPlatformsDao');
}

class _FakeNotificationService implements NotificationService {
  _FakeNotificationService({this.grantPermission = true});

  final bool grantPermission;
  final List<String> scheduled = [];

  @override
  Future<bool> requestPermission() async => grantPermission;

  @override
  Future<void> scheduleReminder({
    required int id,
    required int hour,
    required int minute,
    required Set<int> days,
    required String title,
    required String body,
    String? soundUri,
  }) async {
    final sorted = (days.toList()..sort()).join(',');
    scheduled.add('$hour:$minute [$sorted] $title');
  }

  @override
  Future<void> cancelReminder(int id) async {}

  @override
  Future<void> showNow({
    required String title,
    required String body,
    String? soundUri,
  }) async {
    scheduled.add('now $title');
  }

  @override
  Future<ReminderSound?> pickSound(String? currentUri) async => null;
}

class _FakeDataController implements DataController {
  _FakeDataController({this.picked, this.pickError});

  final BackupData? picked;
  final Object? pickError;
  int backupsExported = 0;
  int clears = 0;
  BackupData? restored;

  @override
  Future<bool> exportBackup() async {
    backupsExported++;
    return true;
  }

  @override
  Future<BackupData?> pickBackup() async {
    if (pickError != null) throw pickError!;
    return picked;
  }

  @override
  Future<void> restore(BackupData data) async {
    restored = data;
  }

  @override
  Future<void> clearAll() async {
    clears++;
  }
}

class _RecordingExporter implements FileExporter {
  _RecordingExporter({this.completes = true});

  final bool completes;
  final List<({String fileName, Uint8List bytes, String mimeType})> files = [];

  @override
  Future<bool> export({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    files.add((fileName: fileName, bytes: bytes, mimeType: mimeType));
    return completes;
  }
}

class _FakeRideRepository implements RideRepository {
  _FakeRideRepository(this.rides);
  final List<Ride> rides;

  @override
  Stream<List<Ride>> watchAll() => Stream.value(rides);

  @override
  Future<List<Ride>> getAll() async => rides;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('FakeRideRepository');
}

class _FakeExpenseRepository implements ExpenseRepository {
  _FakeExpenseRepository(this.expenses);
  final List<Expense> expenses;

  @override
  Stream<List<Expense>> watchAll() => Stream.value(expenses);

  @override
  Future<List<Expense>> getAll() async => expenses;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('FakeExpenseRepository');
}

void main() {
  final ptBr = languageForTag('pt_BR')!;

  void useTallScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1000, 5000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  List<Override> baseOverrides() => [
        appLanguageProvider.overrideWithValue(ptBr),
        languageDaoProvider.overrideWithValue(_InMemoryAppDao()),
        appSettingsProvider
            .overrideWith((ref) => AppSettingsNotifier.forTesting(
                  _InMemoryAppDao(),
                  _FakeCountryPlatformsDao(),
                  AppSettings.defaultBrazil(),
                )),
        currency_pkg.appCurrencyProvider
            .overrideWithValue(currencyForCode('BRL')!),
      ];

  group('SettingsPage export actions', () {
    Future<void> pumpReports(
      WidgetTester tester,
      _RecordingExporter exporter,
      _FakeDataController data,
    ) async {
      useTallScreen(tester);
      final ride = Ride(
        id: 'ride-1',
        date: DateTime.now(),
        platform: 'Uber',
        earnings: 80,
        distanceKm: 10,
        durationMinutes: 20,
        rideType: 'Normal',
      );
      final expense = Expense(
        id: 'expense-1',
        date: DateTime.now(),
        category: 'Combustível',
        amount: 30,
      );
      await tester.pumpWidget(ProviderScope(
        overrides: [
          ...baseOverrides(),
          rideRepositoryProvider.overrideWithValue(_FakeRideRepository([ride])),
          expenseRepositoryProvider
              .overrideWithValue(_FakeExpenseRepository([expense])),
          fileExporterProvider.overrideWithValue(exporter),
          dataControllerProvider.overrideWithValue(data),
          appDaoProviderForSettings.overrideWithValue(_InMemoryAppDao()),
          notificationServiceProvider
              .overrideWithValue(_FakeNotificationService()),
        ],
        child: const MaterialApp(home: SettingsPage()),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('Export CSV hands over a CSV with the period records',
        (tester) async {
      final exporter = _RecordingExporter();
      await pumpReports(tester, exporter, _FakeDataController());

      await tester.tap(find.text(ptBr.tr('reports.exportCsv')));
      await tester.pumpAndSettle();

      final file = exporter.files.single;
      expect(
          file.fileName, matches(r'^carjobfinance_report_\d{8}_\d{4}\.csv$'));
      expect(file.mimeType, 'text/csv');
      final csv = utf8.decode(file.bytes);
      expect(csv, contains('Corrida;'));
      expect(csv, contains(';Uber;'));
      expect(csv, contains(';Combustível;'));
      expect(find.text(ptBr.tr('export.done')), findsOneWidget);
    });

    testWidgets('Export PDF hands over a PDF document', (tester) async {
      final exporter = _RecordingExporter();
      await pumpReports(tester, exporter, _FakeDataController());

      await tester.runAsync(() async {
        await tester.tap(find.text(ptBr.tr('reports.exportPdf')));
        for (var i = 0; i < 100 && exporter.files.isEmpty; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
      });
      await tester.pumpAndSettle();

      final file = exporter.files.single;
      expect(file.fileName, endsWith('.pdf'));
      expect(file.mimeType, 'application/pdf');
      expect(ascii.decode(file.bytes.sublist(0, 5)), '%PDF-');
    });

    testWidgets('Full Backup exports the backup', (tester) async {
      final data = _FakeDataController();
      await pumpReports(tester, _RecordingExporter(), data);

      await tester.tap(find.text(ptBr.tr('reports.backup')));
      await tester.pumpAndSettle();

      expect(data.backupsExported, 1);
      expect(find.text(ptBr.tr('export.done')), findsOneWidget);
    });

    testWidgets('a cancelled export shows no message', (tester) async {
      final exporter = _RecordingExporter(completes: false);
      await pumpReports(tester, exporter, _FakeDataController());

      await tester.tap(find.text(ptBr.tr('reports.exportCsv')));
      await tester.pumpAndSettle();

      expect(exporter.files, hasLength(1));
      expect(find.byType(SnackBar), findsNothing);
    });
  });

  group('SettingsPage actions', () {
    Future<void> pumpSettings(
      WidgetTester tester, {
      _FakeNotificationService? service,
      _InMemoryAppDao? dao,
      _FakeDataController? data,
      Future<bool> Function(Uri)? opener,
    }) async {
      useTallScreen(tester);
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, __) => const SettingsPage()),
          GoRoute(
            path: '/settings/backup',
            builder: (_, __) => const BackupPage(),
          ),
          GoRoute(
            path: '/settings/reminders',
            builder: (_, __) => const RemindersPage(),
          ),
          GoRoute(
            path: '/settings/terms',
            builder: (_, __) => const LegalPage.terms(),
          ),
          GoRoute(
            path: '/settings/privacy',
            builder: (_, __) => const LegalPage.privacy(),
          ),
        ],
      );
      await tester.pumpWidget(ProviderScope(
        overrides: [
          ...baseOverrides(),
          appDaoProviderForSettings.overrideWithValue(dao ?? _InMemoryAppDao()),
          notificationServiceProvider
              .overrideWithValue(service ?? _FakeNotificationService()),
          dataControllerProvider
              .overrideWithValue(data ?? _FakeDataController()),
          if (opener != null) urlOpenerProvider.overrideWithValue(opener),
        ],
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('the notifications switch starts off and turns on',
        (tester) async {
      final dao = _InMemoryAppDao();
      await pumpSettings(tester, dao: dao);

      SwitchListTile toggle() =>
          tester.widget<SwitchListTile>(find.byType(SwitchListTile));
      expect(toggle().value, isFalse);

      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();

      expect(toggle().value, isTrue);
      expect(dao.storage[NotificationSettingsNotifier.enabledKey], 'true');
    });

    testWidgets('the switch stays off when permission is denied',
        (tester) async {
      await pumpSettings(
        tester,
        service: _FakeNotificationService(grantPermission: false),
      );

      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();

      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isFalse,
      );
      expect(find.text(ptBr.tr('settings.notificationsUnavailable')),
          findsOneWidget);
    });

    testWidgets('the reminders entry opens the reminders page', (tester) async {
      await pumpSettings(tester);
      expect(find.text(ptBr.tr('reminders.none')), findsOneWidget);

      await tester.tap(find.byKey(const Key('settings-reminders')));
      await tester.pumpAndSettle();

      expect(find.text(ptBr.tr('reminders.empty')), findsOneWidget);
    });

    testWidgets('a reminder takes days, time and message and is scheduled',
        (tester) async {
      final service = _FakeNotificationService();
      final dao = _InMemoryAppDao();
      await pumpSettings(tester, service: service, dao: dao);
      await tester.tap(find.byKey(const Key('settings-reminders')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('reminder-add')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('reminder-days-weekdays')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('reminder-message-custom')));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const Key('reminder-message-custom-field')),
          'Buscar cliente');
      await tester.pump();
      await tester.tap(find.byKey(const Key('reminder-save')));
      await tester.pumpAndSettle();

      expect(service.scheduled, ['20:0 [1,2,3,4,5] Buscar cliente']);
      expect(dao.storage[NotificationSettingsNotifier.enabledKey], 'true');
      expect(find.text(ptBr.tr('reminders.weekdays')), findsOneWidget);
      expect(find.text('Buscar cliente'), findsOneWidget);
    });

    testWidgets('a reminder needs at least one day', (tester) async {
      await pumpSettings(tester);
      await tester.tap(find.byKey(const Key('settings-reminders')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('reminder-add')));
      await tester.pumpAndSettle();

      for (var day = 1; day <= 7; day++) {
        await tester.tap(find.byKey(Key('reminder-day-$day')));
      }
      await tester.pump();

      expect(find.text(ptBr.tr('reminders.noDays')), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('reminder-save')))
            .onPressed,
        isNull,
      );
    });

    testWidgets('a saved reminder can be switched off and deleted',
        (tester) async {
      final dao = _InMemoryAppDao();
      await pumpSettings(tester, dao: dao);
      await tester.tap(find.byKey(const Key('settings-reminders')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('reminder-add')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('reminder-save')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('reminder-switch-1')));
      await tester.pumpAndSettle();
      expect(
          Reminder.decodeList(
                  dao.storage[NotificationSettingsNotifier.remindersKey])
              .single
              .enabled,
          isFalse);

      await tester.tap(find.text(ptBr.tr('reminders.everyDay')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('reminder-delete')));
      await tester.pumpAndSettle();

      expect(find.text(ptBr.tr('reminders.empty')), findsOneWidget);
    });

    testWidgets('the test button shows a notification right away',
        (tester) async {
      final service = _FakeNotificationService();
      await pumpSettings(tester, service: service);
      await tester.tap(find.byKey(const Key('settings-reminders')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('reminder-add')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('reminder-test')));
      await tester.tap(find.byKey(const Key('reminder-test')));
      await tester.pumpAndSettle();

      expect(service.scheduled.single, startsWith('now '));
    });
    testWidgets('Clear All Data wipes only after confirmation', (tester) async {
      final data = _FakeDataController();
      await pumpSettings(tester, data: data);

      await tester.tap(find.text(ptBr.tr('settings.clearData')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ptBr.tr('dash.cancel')));
      await tester.pumpAndSettle();
      expect(data.clears, 0);

      await tester.tap(find.text(ptBr.tr('settings.clearData')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ptBr.tr('settings.deleteAll')));
      await tester.pumpAndSettle();

      expect(data.clears, 1);
      expect(find.text(ptBr.tr('settings.dataCleared')), findsOneWidget);
    });

    testWidgets('Report Issue opens the issue tracker', (tester) async {
      final opened = <Uri>[];
      await pumpSettings(tester, opener: (uri) async {
        opened.add(uri);
        return true;
      });

      await tester.tap(find.text(ptBr.tr('settings.reportIssue')));
      await tester.pumpAndSettle();

      expect(opened, [Uri.parse(AppConstants.issueTrackerUrl)]);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('Report Issue shows the address when it cannot be opened',
        (tester) async {
      await pumpSettings(tester, opener: (uri) async => false);

      await tester.tap(find.text(ptBr.tr('settings.reportIssue')));
      await tester.pumpAndSettle();

      expect(find.textContaining(AppConstants.issueTrackerUrl), findsOneWidget);
    });

    testWidgets('Terms, Privacy and Backup tiles open their pages',
        (tester) async {
      await pumpSettings(tester);

      await tester.tap(find.text(ptBr.tr('settings.terms')));
      await tester.pumpAndSettle();
      expect(find.byType(LegalPage), findsOneWidget);
      expect(find.textContaining('1. Sobre o app'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.text(ptBr.tr('settings.privacy')));
      await tester.pumpAndSettle();
      expect(find.textContaining('1. Dados que o app guarda'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.text(ptBr.tr('settings.backup')));
      await tester.pumpAndSettle();
      expect(find.byType(BackupPage), findsOneWidget);
    });
  });

  group('BackupPage', () {
    const backup = BackupData(
      rides: [],
      expenses: [],
      settings: {'app_country': 'BR'},
      countryPlatforms: [],
    );

    Future<void> pumpBackup(
        WidgetTester tester, _FakeDataController data) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          ...baseOverrides(),
          dataControllerProvider.overrideWithValue(data),
        ],
        child: const MaterialApp(home: BackupPage()),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('exports a backup', (tester) async {
      final data = _FakeDataController();
      await pumpBackup(tester, data);

      await tester.tap(find.text(ptBr.tr('backup.exportTitle')));
      await tester.pumpAndSettle();

      expect(data.backupsExported, 1);
      expect(find.text(ptBr.tr('export.done')), findsOneWidget);
    });

    testWidgets('restores the picked file after confirmation', (tester) async {
      final data = _FakeDataController(picked: backup);
      await pumpBackup(tester, data);

      await tester.tap(find.text(ptBr.tr('backup.restoreTitle')));
      await tester.pumpAndSettle();
      expect(find.textContaining('0 corridas e 0 despesas'), findsOneWidget);
      expect(data.restored, isNull);

      await tester.tap(find.text(ptBr.tr('backup.restore')));
      await tester.pumpAndSettle();

      expect(data.restored, same(backup));
      expect(find.text(ptBr.tr('backup.restored')), findsOneWidget);
    });

    testWidgets('keeps current data when the restore is cancelled',
        (tester) async {
      final data = _FakeDataController(picked: backup);
      await pumpBackup(tester, data);

      await tester.tap(find.text(ptBr.tr('backup.restoreTitle')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ptBr.tr('dash.cancel')));
      await tester.pumpAndSettle();

      expect(data.restored, isNull);
    });

    testWidgets('rejects a file that is not a backup', (tester) async {
      final data = _FakeDataController(
          pickError: const BackupFormatException('not a backup'));
      await pumpBackup(tester, data);

      await tester.tap(find.text(ptBr.tr('backup.restoreTitle')));
      await tester.pumpAndSettle();

      expect(find.text(ptBr.tr('backup.invalid')), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(data.restored, isNull);
    });
  });
}
