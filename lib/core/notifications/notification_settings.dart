// Persisted notification preferences (settings table) kept in sync with
// the scheduled daily reminder.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/local/daos.dart' show AppDao;
import '../settings/app_settings_notifier.dart';
import 'notification_service.dart';

class NotificationPrefs {
  const NotificationPrefs({
    this.enabled = false,
    this.reminderHour,
    this.reminderMinute,
  });

  final bool enabled;
  final int? reminderHour;
  final int? reminderMinute;

  bool get hasReminder => reminderHour != null && reminderMinute != null;
}

/// Texts shown by the daily reminder, resolved by the caller in the
/// user's language.
typedef ReminderText = ({String title, String body});

class NotificationSettingsNotifier extends StateNotifier<NotificationPrefs> {
  NotificationSettingsNotifier(this._dao, this._service)
      : super(const NotificationPrefs());

  static const enabledKey = 'notifications_enabled';
  static const reminderKey = 'daily_reminder_time';

  final AppDao _dao;
  final NotificationService _service;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> initialize() async {
    final enabled = await _dao.getSetting(enabledKey);
    final reminder = await _dao.getSetting(reminderKey);
    if (_disposed) return;
    final time = _parseTime(reminder);
    state = NotificationPrefs(
      enabled: enabled == 'true',
      reminderHour: time?.$1,
      reminderMinute: time?.$2,
    );
  }

  /// Turns notifications on or off. Enabling asks the OS for permission
  /// and returns false (leaving them off) when it is not granted.
  Future<bool> setEnabled(bool enabled, ReminderText text) async {
    if (enabled && !await _service.requestPermission()) return false;
    await _dao.setSetting(enabledKey, '$enabled');
    if (enabled && state.hasReminder) {
      await _schedule(state.reminderHour!, state.reminderMinute!, text);
    } else if (!enabled) {
      await _service.cancelDailyReminder();
    }
    if (_disposed) return true;
    state = NotificationPrefs(
      enabled: enabled,
      reminderHour: state.reminderHour,
      reminderMinute: state.reminderMinute,
    );
    return true;
  }

  /// Sets the daily reminder time; it only fires while notifications
  /// are enabled.
  Future<void> setReminder(int hour, int minute, ReminderText text) async {
    await _dao.setSetting(reminderKey, _formatTime(hour, minute));
    if (state.enabled) await _schedule(hour, minute, text);
    if (_disposed) return;
    state = NotificationPrefs(
      enabled: state.enabled,
      reminderHour: hour,
      reminderMinute: minute,
    );
  }

  Future<void> clearReminder() async {
    await _dao.deleteSetting(reminderKey);
    await _service.cancelDailyReminder();
    if (_disposed) return;
    state = NotificationPrefs(enabled: state.enabled);
  }

  Future<void> _schedule(int hour, int minute, ReminderText text) {
    return _service.scheduleDailyReminder(
      hour: hour,
      minute: minute,
      title: text.title,
      body: text.body,
    );
  }

  static String _formatTime(int hour, int minute) =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  static (int, int)? _parseTime(String? value) {
    final match = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(value ?? '');
    if (match == null) return null;
    final hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    if (hour > 23 || minute > 59) return null;
    return (hour, minute);
  }
}

final notificationSettingsProvider =
    StateNotifierProvider<NotificationSettingsNotifier, NotificationPrefs>(
        (ref) {
  final notifier = NotificationSettingsNotifier(
    ref.watch(appDaoProviderForSettings),
    ref.watch(notificationServiceProvider),
  );
  notifier.initialize();
  return notifier;
});
