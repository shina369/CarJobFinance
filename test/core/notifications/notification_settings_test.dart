import 'package:carjobfinance/core/notifications/notification_service.dart';
import 'package:carjobfinance/core/notifications/notification_settings.dart';
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
  int cancellations = 0;
  final List<String> scheduled = [];

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return grantPermission;
  }

  @override
  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    scheduled.add('$hour:$minute $title|$body');
  }

  @override
  Future<void> cancelDailyReminder() async {
    cancellations++;
  }
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
  });

  group('NotificationSettingsNotifier', () {
    late _InMemoryAppDao dao;
    late _FakeNotificationService service;
    late NotificationSettingsNotifier notifier;

    setUp(() {
      dao = _InMemoryAppDao();
      service = _FakeNotificationService();
      notifier = NotificationSettingsNotifier(dao, service);
    });

    test('is off with no reminder by default', () async {
      await notifier.initialize();

      expect(notifier.state.enabled, isFalse);
      expect(notifier.state.hasReminder, isFalse);
    });

    test('loads the saved preferences', () async {
      dao.storage[NotificationSettingsNotifier.enabledKey] = 'true';
      dao.storage[NotificationSettingsNotifier.reminderKey] = '07:05';

      await notifier.initialize();

      expect(notifier.state.enabled, isTrue);
      expect(notifier.state.reminderHour, 7);
      expect(notifier.state.reminderMinute, 5);
    });

    test('ignores a malformed saved time', () async {
      dao.storage[NotificationSettingsNotifier.reminderKey] = '25:99';

      await notifier.initialize();

      expect(notifier.state.hasReminder, isFalse);
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
      await notifier.setReminder(20, 0, text);
      expect(service.scheduled, isEmpty);
      expect(dao.storage[NotificationSettingsNotifier.reminderKey], '20:00');

      await notifier.setEnabled(true, text);
      expect(service.scheduled, ['20:0 Title|Body']);

      await notifier.setReminder(8, 15, text);
      expect(service.scheduled.last, '8:15 Title|Body');
      expect(notifier.state.reminderHour, 8);
    });

    test('disabling cancels the reminder but keeps its time', () async {
      await notifier.setEnabled(true, text);
      await notifier.setReminder(20, 0, text);

      await notifier.setEnabled(false, text);

      expect(service.cancellations, 1);
      expect(notifier.state.enabled, isFalse);
      expect(notifier.state.hasReminder, isTrue);
      expect(dao.storage[NotificationSettingsNotifier.enabledKey], 'false');
    });

    test('clearReminder removes the time and cancels the schedule', () async {
      await notifier.setEnabled(true, text);
      await notifier.setReminder(20, 0, text);

      await notifier.clearReminder();

      expect(service.cancellations, 1);
      expect(notifier.state.hasReminder, isFalse);
      expect(notifier.state.enabled, isTrue);
      expect(dao.storage.containsKey(NotificationSettingsNotifier.reminderKey),
          isFalse);
    });
  });
}
