// Persisted notification preferences and reminders (settings table) kept in
// sync with the notifications scheduled on the device.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/local/daos.dart' show AppDao;
import '../../presentation/controllers/entitlement_controller.dart'
    show isPremiumProvider;
import '../l10n/language_provider.dart';
import '../l10n/strings.dart';
import '../settings/app_settings_notifier.dart';
import 'notification_service.dart';
import 'reminder.dart';

class NotificationPrefs {
  const NotificationPrefs({
    this.enabled = false,
    this.reminders = const [],
  });

  final bool enabled;
  final List<Reminder> reminders;

  int get activeCount =>
      reminders.where((r) => r.enabled && r.days.isNotEmpty).length;
}

/// Default texts used when a reminder has no custom message, resolved by
/// the caller in the user's language.
typedef ReminderText = ({String title, String body});

class NotificationSettingsNotifier extends StateNotifier<NotificationPrefs> {
  /// Without [isPremium] the driver is treated as free.
  NotificationSettingsNotifier(
    this._dao,
    this._service, {
    bool Function() isPremium = _notPremium,
  })  : _isPremium = isPremium,
        super(const NotificationPrefs());

  static const enabledKey = 'notifications_enabled';
  static const remindersKey = 'reminders';

  // Single daily reminder stored by earlier versions.
  static const legacyTimeKey = 'daily_reminder_time';
  static const legacyMessageKey = 'daily_reminder_message';

  /// Reminders a free driver can create; only the first one is scheduled.
  static const freeReminderLimit = 1;

  static bool _notPremium() => false;

  final AppDao _dao;
  final NotificationService _service;
  final bool Function() _isPremium;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> initialize() async {
    final enabled = await _dao.getSetting(enabledKey);
    var reminders = Reminder.decodeList(await _dao.getSetting(remindersKey));
    if (reminders.isEmpty) {
      final migrated = await _migrateLegacy();
      if (migrated != null) reminders = [migrated];
    }
    if (_disposed) return;
    state = NotificationPrefs(enabled: enabled == 'true', reminders: reminders);
  }

  Future<Reminder?> _migrateLegacy() async {
    final time = _parseTime(await _dao.getSetting(legacyTimeKey));
    if (time == null) return null;
    final message = (await _dao.getSetting(legacyMessageKey))?.trim();
    final reminder = Reminder(
      id: 1,
      hour: time.$1,
      minute: time.$2,
      days: Reminder.allDays,
      message: (message == null || message.isEmpty) ? null : message,
    );
    await _dao.setSetting(remindersKey, Reminder.encodeList([reminder]));
    await _dao.deleteSetting(legacyTimeKey);
    await _dao.deleteSetting(legacyMessageKey);
    // The old single reminder used notification id 1.
    await _service.cancelReminder(0);
    return reminder;
  }

  /// Id for a new reminder.
  int nextId() {
    final ids = state.reminders.map((r) => r.id);
    return ids.isEmpty ? 1 : ids.reduce((a, b) => a > b ? a : b) + 1;
  }

  /// Turns notifications on or off. Enabling asks the OS for permission
  /// and returns false (leaving them off) when it is not granted.
  Future<bool> setEnabled(bool enabled, ReminderText text) async {
    if (enabled && !await _service.requestPermission()) return false;
    await _dao.setSetting(enabledKey, '$enabled');
    if (_disposed) return true;
    state = NotificationPrefs(enabled: enabled, reminders: state.reminders);
    await resync(text);
    return true;
  }

  /// Adds or replaces a reminder (matched by id).
  Future<void> save(Reminder reminder, ReminderText text) async {
    final list = [...state.reminders];
    final index = list.indexWhere((r) => r.id == reminder.id);
    if (index >= 0) {
      list[index] = reminder;
    } else {
      list.add(reminder);
    }
    await _persist(list);
    // A free driver's scheduled reminder depends on the whole list.
    if (_isPremium()) {
      await _apply(reminder, text);
    } else {
      await resync(text);
    }
  }

  Future<void> remove(int id, ReminderText text) async {
    await _persist(state.reminders.where((r) => r.id != id).toList());
    await _service.cancelReminder(id);
    if (!_isPremium()) await resync(text);
  }

  /// Re-schedules every reminder, or cancels them all while notifications
  /// are off. Also refreshes texts after a language change.
  ///
  /// A free driver keeps only the active reminder with the lowest id, with
  /// the default text and sound; the others stay saved but unscheduled.
  Future<void> resync(ReminderText text) async {
    for (final reminder in state.reminders) {
      await _apply(reminder, text);
    }
  }

  /// Cancels every scheduled reminder without touching what is stored.
  Future<void> cancelAll() async {
    for (final reminder in state.reminders) {
      await _service.cancelReminder(reminder.id);
    }
  }

  Future<void> _persist(List<Reminder> reminders) async {
    await _dao.setSetting(remindersKey, Reminder.encodeList(reminders));
    if (_disposed) return;
    state = NotificationPrefs(enabled: state.enabled, reminders: reminders);
  }

  Future<void> _apply(Reminder reminder, ReminderText text) async {
    final premium = _isPremium();
    if (!state.enabled ||
        !_isActive(reminder) ||
        (!premium && reminder.id != _freeReminderId())) {
      await _service.cancelReminder(reminder.id);
      return;
    }
    await _service.scheduleReminder(
      id: reminder.id,
      hour: reminder.hour,
      minute: reminder.minute,
      days: reminder.days,
      title: premium ? reminder.message ?? text.title : text.title,
      body: text.body,
      soundUri: premium ? reminder.soundUri : null,
    );
  }

  static bool _isActive(Reminder r) => r.enabled && r.days.isNotEmpty;

  /// The reminder a free driver keeps: the first created that is active.
  int? _freeReminderId() {
    int? id;
    for (final r in state.reminders) {
      if (_isActive(r) && (id == null || r.id < id)) id = r.id;
    }
    return id;
  }

  /// Shows [reminder] right away to preview its text and sound, as they
  /// would be scheduled.
  Future<void> preview(Reminder reminder, ReminderText text) {
    final premium = _isPremium();
    return _service.showNow(
      title: premium ? reminder.message ?? text.title : text.title,
      body: text.body,
      soundUri: premium ? reminder.soundUri : null,
    );
  }

  static (int, int)? _parseTime(String? value) {
    final match = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(value ?? '');
    if (match == null) return null;
    final hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    if (hour > 23 || minute > 59) return null;
    return (hour, minute);
  }
}

/// Default reminder texts in the language resolved by [tr].
ReminderText reminderTextFor(String Function(String) tr) =>
    (title: tr('notif.reminderTitle'), body: tr('notif.reminderBody'));

final notificationSettingsProvider =
    StateNotifierProvider<NotificationSettingsNotifier, NotificationPrefs>(
        (ref) {
  final notifier = NotificationSettingsNotifier(
    ref.watch(appDaoProviderForSettings),
    ref.watch(notificationServiceProvider),
    isPremium: () => ref.read(isPremiumProvider),
  );
  Future<void> resync() =>
      notifier.resync(reminderTextFor(ref.read(appLanguageProvider).tr));
  // Re-schedule on start so reminders survive time-zone changes and
  // pick up the current language.
  final ready = notifier.initialize().then((_) => resync());
  ready.catchError((_) {});
  // Gaining or losing premium changes which reminders are scheduled.
  ref.listen<bool>(isPremiumProvider, (previous, next) {
    if (previous == next) return;
    ready.then((_) => resync()).catchError((_) {});
  });
  return notifier;
});
