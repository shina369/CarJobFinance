import 'package:carjobfinance/core/notifications/notification_service.dart';
import 'package:carjobfinance/core/notifications/notification_settings.dart';
import 'package:carjobfinance/core/notifications/reminder.dart';
import 'package:carjobfinance/data/datasources/local/daos.dart' show AppDao;
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

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
  bool grantPermission = true;
  int permissionRequests = 0;
  final List<int> cancelled = [];
  final List<String> scheduled = [];
  final List<String> shown = [];

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return grantPermission;
  }

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
    scheduled
        .add('#$id $hour:$minute [$sorted] $title|$body|${soundUri ?? '-'}');
  }

  @override
  Future<void> cancelReminder(int id) async {
    cancelled.add(id);
  }

  @override
  Future<void> showNow({
    required String title,
    required String body,
    String? soundUri,
  }) async {
    shown.add('$title|$body|${soundUri ?? '-'}');
  }

  @override
  Future<ReminderSound?> pickSound(String? currentUri) async => null;
}

void main() {
  const text = (title: 'Title', body: 'Body');

  group('nextInstanceOf', () {
    late tz.Location saoPaulo;

    setUpAll(() {
      tz_data.initializeTimeZones();
      saoPaulo = tz.getLocation('America/Sao_Paulo');
    });

    test('later today when the time has not passed yet', () {
      final now = tz.TZDateTime(saoPaulo, 2026, 3, 5, 10);
      expect(nextInstanceOf(20, 30, now),
          tz.TZDateTime(saoPaulo, 2026, 3, 5, 20, 30));
    });

    test('tomorrow when the time has already passed', () {
      final now = tz.TZDateTime(saoPaulo, 2026, 3, 5, 21);
      expect(nextInstanceOf(20, 30, now),
          tz.TZDateTime(saoPaulo, 2026, 3, 6, 20, 30));
    });

    test('tomorrow when it is exactly that time', () {
      final now = tz.TZDateTime(saoPaulo, 2026, 3, 5, 20, 30);
      expect(nextInstanceOf(20, 30, now),
          tz.TZDateTime(saoPaulo, 2026, 3, 6, 20, 30));
    });

    // 2026-03-05 is a Thursday.
    test('weekday later today when it matches and has not passed', () {
      final now = tz.TZDateTime(saoPaulo, 2026, 3, 5, 10);
      expect(nextInstanceOf(20, 0, now).weekday, DateTime.thursday);
      expect(nextInstanceOfWeekday(DateTime.thursday, 20, 0, now),
          tz.TZDateTime(saoPaulo, 2026, 3, 5, 20));
    });

    test('same weekday a week later once the time has passed', () {
      final now = tz.TZDateTime(saoPaulo, 2026, 3, 5, 21);
      expect(nextInstanceOfWeekday(DateTime.thursday, 20, 0, now),
          tz.TZDateTime(saoPaulo, 2026, 3, 12, 20));
    });

    test('a later weekday within the same week', () {
      final now = tz.TZDateTime(saoPaulo, 2026, 3, 5, 10);
      expect(nextInstanceOfWeekday(DateTime.sunday, 8, 15, now),
          tz.TZDateTime(saoPaulo, 2026, 3, 8, 8, 15));
    });

    test('an earlier weekday wraps to next week', () {
      final now = tz.TZDateTime(saoPaulo, 2026, 3, 5, 10);
      expect(nextInstanceOfWeekday(DateTime.monday, 8, 0, now),
          tz.TZDateTime(saoPaulo, 2026, 3, 9, 8));
    });

    test('notification ids are unique per reminder and weekday', () {
      expect(notificationIdFor(1, 1), 11);
      expect(notificationIdFor(1, 7), 17);
      expect(notificationIdFor(2, 1), 21);
    });
  });

  group('Reminder', () {
    test('round-trips through JSON', () {
      const reminder = Reminder(
        id: 3,
        hour: 7,
        minute: 5,
        days: {1, 3, 5},
        message: 'Go',
        soundUri: 'content://x/1',
        soundName: 'Chime',
        enabled: false,
      );

      final decoded = Reminder.decodeList(Reminder.encodeList([reminder]));

      expect(decoded, hasLength(1));
      final r = decoded.single;
      expect(r.id, 3);
      expect(r.hour, 7);
      expect(r.minute, 5);
      expect(r.days, {1, 3, 5});
      expect(r.message, 'Go');
      expect(r.soundUri, 'content://x/1');
      expect(r.soundName, 'Chime');
      expect(r.enabled, isFalse);
    });

    test('bad JSON decodes to an empty list', () {
      expect(Reminder.decodeList('not json'), isEmpty);
      expect(Reminder.decodeList(null), isEmpty);
    });
  });

  group('NotificationSettingsNotifier', () {
    late _InMemoryAppDao dao;
    late _FakeNotificationService service;
    late NotificationSettingsNotifier notifier;

    const daily =
        Reminder(id: 1, hour: 20, minute: 0, days: {1, 2, 3, 4, 5, 6, 7});

    setUp(() {
      dao = _InMemoryAppDao();
      service = _FakeNotificationService();
      notifier = NotificationSettingsNotifier(dao, service);
    });

    test('is off with no reminders by default', () async {
      await notifier.initialize();

      expect(notifier.state.enabled, isFalse);
      expect(notifier.state.reminders, isEmpty);
    });

    test('loads the saved preferences', () async {
      dao.storage[NotificationSettingsNotifier.enabledKey] = 'true';
      dao.storage[NotificationSettingsNotifier.remindersKey] =
          Reminder.encodeList([daily]);

      await notifier.initialize();

      expect(notifier.state.enabled, isTrue);
      expect(notifier.state.reminders.single.hour, 20);
      expect(notifier.state.activeCount, 1);
    });

    test('migrates the old single daily reminder', () async {
      dao.storage[NotificationSettingsNotifier.legacyTimeKey] = '07:05';
      dao.storage[NotificationSettingsNotifier.legacyMessageKey] = 'Bora';

      await notifier.initialize();

      final r = notifier.state.reminders.single;
      expect((r.hour, r.minute), (7, 5));
      expect(r.days, Reminder.allDays);
      expect(r.message, 'Bora');
      expect(
          dao.storage.containsKey(NotificationSettingsNotifier.legacyTimeKey),
          isFalse);
      expect(dao.storage[NotificationSettingsNotifier.remindersKey], isNotNull);
      expect(service.cancelled, [0]);
    });

    test('ignores a malformed legacy time', () async {
      dao.storage[NotificationSettingsNotifier.legacyTimeKey] = '25:99';

      await notifier.initialize();

      expect(notifier.state.reminders, isEmpty);
    });

    test('enabling asks for permission and persists the choice', () async {
      expect(await notifier.setEnabled(true, text), isTrue);

      expect(service.permissionRequests, 1);
      expect(notifier.state.enabled, isTrue);
      expect(dao.storage[NotificationSettingsNotifier.enabledKey], 'true');
    });

    test('stays off when permission is denied', () async {
      service.grantPermission = false;

      expect(await notifier.setEnabled(true, text), isFalse);

      expect(notifier.state.enabled, isFalse);
      expect(dao.storage, isEmpty);
      expect(service.scheduled, isEmpty);
    });

    test('a reminder is only scheduled while notifications are on', () async {
      await notifier.save(daily, text);
      expect(service.scheduled, isEmpty);
      expect(notifier.state.reminders, hasLength(1));

      await notifier.setEnabled(true, text);
      expect(service.scheduled, ['#1 20:0 [1,2,3,4,5,6,7] Title|Body|-']);
    });

    test('saving schedules the chosen days, message and sound', () async {
      await notifier.setEnabled(true, text);

      await notifier.save(
        const Reminder(
          id: 1,
          hour: 8,
          minute: 15,
          days: {1, 3},
          message: 'Vamos',
          soundUri: 'content://s/1',
        ),
        text,
      );

      expect(
          service.scheduled.single, '#1 8:15 [1,3] Vamos|Body|content://s/1');
    });

    test('saving an existing id replaces it', () async {
      await notifier.setEnabled(true, text);
      await notifier.save(daily, text);

      await notifier.save(daily.copyWith(hour: 9), text);

      expect(notifier.state.reminders, hasLength(1));
      expect(notifier.state.reminders.single.hour, 9);
    });

    test('a switched-off reminder is cancelled, not scheduled', () async {
      await notifier.setEnabled(true, text);
      service.scheduled.clear();

      await notifier.save(daily.copyWith(enabled: false), text);

      expect(service.scheduled, isEmpty);
      expect(service.cancelled, contains(1));
      expect(notifier.state.activeCount, 0);
    });

    test('a reminder without days is cancelled', () async {
      await notifier.setEnabled(true, text);
      service.scheduled.clear();

      await notifier.save(daily.copyWith(days: {}), text);

      expect(service.scheduled, isEmpty);
      expect(service.cancelled, contains(1));
    });

    test('disabling notifications cancels every reminder but keeps them',
        () async {
      await notifier.setEnabled(true, text);
      await notifier.save(daily, text);
      await notifier.save(
          const Reminder(id: 2, hour: 8, minute: 0, days: {1}), text);
      service.cancelled.clear();

      await notifier.setEnabled(false, text);

      expect(service.cancelled, [1, 2]);
      expect(notifier.state.enabled, isFalse);
      expect(notifier.state.reminders, hasLength(2));
      expect(dao.storage[NotificationSettingsNotifier.enabledKey], 'false');
    });

    test('remove deletes the reminder and cancels its schedule', () async {
      await notifier.setEnabled(true, text);
      await notifier.save(daily, text);

      await notifier.remove(1);

      expect(notifier.state.reminders, isEmpty);
      expect(service.cancelled, contains(1));
      expect(
          Reminder.decodeList(
              dao.storage[NotificationSettingsNotifier.remindersKey]),
          isEmpty);
    });

    test('resync reschedules with the given texts', () async {
      await notifier.setEnabled(true, text);
      await notifier.save(daily, text);
      service.scheduled.clear();

      await notifier.resync((title: 'Titulo', body: 'Corpo'));

      expect(service.scheduled.single, contains('Titulo|Corpo'));
    });

    test('nextId is one past the highest id', () async {
      expect(notifier.nextId(), 1);
      await notifier.save(
          const Reminder(id: 4, hour: 8, minute: 0, days: {1}), text);
      expect(notifier.nextId(), 5);
    });

    test('preview shows the notification right away', () async {
      await notifier.preview(
          daily.copyWith(message: 'Oi', soundUri: 'content://s/2'), text);

      expect(service.shown.single, 'Oi|Body|content://s/2');
    });
  });
}
