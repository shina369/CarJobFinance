import 'package:carjobfinance/core/l10n/language_provider.dart';
import 'package:carjobfinance/core/l10n/languages.dart';
import 'package:carjobfinance/core/l10n/strings.dart';
import 'package:carjobfinance/core/notifications/notification_service.dart';
import 'package:carjobfinance/core/notifications/notification_settings.dart';
import 'package:carjobfinance/core/notifications/reminder.dart';
import 'package:carjobfinance/core/settings/app_settings_notifier.dart'
    show appDaoProviderForSettings;
import 'package:carjobfinance/data/datasources/local/daos.dart' show AppDao;
import 'package:carjobfinance/presentation/controllers/entitlement_controller.dart';
import 'package:carjobfinance/presentation/pages/settings/reminders_page.dart';
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
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('InMemoryAppDao');
}

class _FakeNotificationService implements NotificationService {
  int soundPicks = 0;
  final List<String> scheduled = [];

  @override
  Future<bool> requestPermission() async => true;

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
    scheduled.add('#$id $title|${soundUri ?? '-'}');
  }

  @override
  Future<void> cancelReminder(int id) async {}

  @override
  Future<void> showNow({
    required String title,
    required String body,
    String? soundUri,
  }) async {}

  @override
  Future<ReminderSound?> pickSound(String? currentUri) async {
    soundPicks++;
    return const ReminderSound(uri: 'content://s/9', title: 'Sino');
  }
}

void main() {
  final ptBr = languageForTag('pt_BR')!;
  late _InMemoryAppDao dao;
  late _FakeNotificationService service;
  late int paywallOpens;

  const saved = Reminder(id: 1, hour: 20, minute: 0, days: {1, 2, 3});

  Future<void> pumpPage(
    WidgetTester tester, {
    required bool premium,
    List<Reminder> reminders = const [],
    bool buyOnPaywall = false,
  }) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    dao = _InMemoryAppDao();
    service = _FakeNotificationService();
    paywallOpens = 0;
    if (reminders.isNotEmpty) {
      dao.storage[NotificationSettingsNotifier.enabledKey] = 'true';
      dao.storage[NotificationSettingsNotifier.remindersKey] =
          Reminder.encodeList(reminders);
    }
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const RemindersPage()),
      GoRoute(
        path: '/paywall',
        builder: (context, _) {
          paywallOpens++;
          return Scaffold(
            body: TextButton(
              key: const Key('paywall-close'),
              onPressed: () => context.pop(buyOnPaywall),
              child: const Text('paywall'),
            ),
          );
        },
      ),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        appLanguageProvider.overrideWithValue(ptBr),
        premiumOverrideProvider.overrideWithValue(premium),
        appDaoProviderForSettings.overrideWithValue(dao),
        notificationServiceProvider.overrideWithValue(service),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> closePaywall(WidgetTester tester) =>
      tapAndSettle(tester, find.byKey(const Key('paywall-close')));

  List<Reminder> stored() => Reminder.decodeList(
      dao.storage[NotificationSettingsNotifier.remindersKey]);

  group('add button', () {
    testWidgets('without reminders it opens the editor for free users',
        (tester) async {
      await pumpPage(tester, premium: false);

      await tapAndSettle(tester, find.byKey(const Key('reminder-add')));

      expect(paywallOpens, 0);
      expect(find.byType(ReminderEditorPage), findsOneWidget);
    });

    testWidgets('a free user can save the first reminder', (tester) async {
      await pumpPage(tester, premium: false);

      await tapAndSettle(tester, find.byKey(const Key('reminder-add')));
      await tapAndSettle(tester, find.byKey(const Key('reminder-save')));

      expect(stored(), hasLength(1));
      expect(service.scheduled, hasLength(1));
    });

    testWidgets('with one reminder a free user is sent to the paywall',
        (tester) async {
      await pumpPage(tester, premium: false, reminders: [saved]);

      await tapAndSettle(tester, find.byKey(const Key('reminder-add')));

      expect(paywallOpens, 1);
      expect(find.byType(ReminderEditorPage), findsNothing);

      await closePaywall(tester);

      expect(find.byType(ReminderEditorPage), findsNothing);
      expect(find.byType(RemindersPage), findsOneWidget);
    });

    testWidgets('buying on the paywall opens the editor', (tester) async {
      await pumpPage(tester,
          premium: false, reminders: [saved], buyOnPaywall: true);

      await tapAndSettle(tester, find.byKey(const Key('reminder-add')));
      await closePaywall(tester);

      expect(find.byType(ReminderEditorPage), findsOneWidget);
    });

    testWidgets('premium users add more reminders without the paywall',
        (tester) async {
      await pumpPage(tester, premium: true, reminders: [saved]);

      await tapAndSettle(tester, find.byKey(const Key('reminder-add')));

      expect(paywallOpens, 0);
      expect(find.byType(ReminderEditorPage), findsOneWidget);
    });
  });

  group('editor without premium', () {
    Future<void> openEditor(WidgetTester tester) async {
      await pumpPage(tester, premium: false);
      await tapAndSettle(tester, find.byKey(const Key('reminder-add')));
    }

    testWidgets('custom message and sound show a lock', (tester) async {
      await openEditor(tester);

      expect(find.byKey(const Key('reminder-message-custom-lock')),
          findsOneWidget);
      expect(find.byKey(const Key('reminder-sound-lock')), findsOneWidget);
    });

    testWidgets('choosing a custom message opens the paywall and keeps default',
        (tester) async {
      await openEditor(tester);

      await tapAndSettle(
          tester, find.byKey(const Key('reminder-message-custom')));

      expect(paywallOpens, 1);
      await closePaywall(tester);

      expect(
          find.byKey(const Key('reminder-message-custom-field')), findsNothing);
      await tapAndSettle(tester, find.byKey(const Key('reminder-save')));
      expect(stored().single.message, isNull);
    });

    testWidgets('choosing a preset message opens the paywall', (tester) async {
      await openEditor(tester);

      await tapAndSettle(
          tester, find.byKey(const Key('reminder-message-rest')));

      expect(paywallOpens, 1);
      await closePaywall(tester);
      await tapAndSettle(tester, find.byKey(const Key('reminder-save')));
      expect(stored().single.message, isNull);
    });

    testWidgets('tapping the sound opens the paywall and keeps default',
        (tester) async {
      await openEditor(tester);

      await tapAndSettle(tester, find.byKey(const Key('reminder-sound')));

      expect(paywallOpens, 1);
      expect(service.soundPicks, 0);
      await closePaywall(tester);

      expect(find.text(ptBr.tr('reminders.soundDefault')), findsOneWidget);
      await tapAndSettle(tester, find.byKey(const Key('reminder-save')));
      expect(stored().single.soundUri, isNull);
    });
  });

  group('editor with premium', () {
    Future<void> openEditor(WidgetTester tester) async {
      await pumpPage(tester, premium: true);
      await tapAndSettle(tester, find.byKey(const Key('reminder-add')));
    }

    testWidgets('shows no lock', (tester) async {
      await openEditor(tester);

      expect(
          find.byKey(const Key('reminder-message-custom-lock')), findsNothing);
      expect(find.byKey(const Key('reminder-sound-lock')), findsNothing);
    });

    testWidgets('a custom message and sound are saved', (tester) async {
      await openEditor(tester);

      await tapAndSettle(
          tester, find.byKey(const Key('reminder-message-custom')));
      await tester.enterText(
          find.byKey(const Key('reminder-message-custom-field')), 'Bora');
      await tapAndSettle(tester, find.byKey(const Key('reminder-sound')));
      await tapAndSettle(tester, find.byKey(const Key('reminder-save')));

      expect(paywallOpens, 0);
      expect(service.soundPicks, 1);
      final reminder = stored().single;
      expect(reminder.message, 'Bora');
      expect(reminder.soundUri, 'content://s/9');
    });
  });
}
