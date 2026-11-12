// Local notifications: permission handling and scheduled reminders.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../constants/app_constants.dart';

/// A ringtone chosen with the system picker.
class ReminderSound {
  const ReminderSound({required this.uri, required this.title});

  final String uri;
  final String title;
}

abstract class NotificationService {
  /// Asks the OS for permission to show notifications. Returns false when
  /// denied or when the platform has no scheduled-notification support.
  Future<bool> requestPermission();

  /// Schedules (or replaces) reminder [id], repeating weekly on each of
  /// [days] (1 = Monday ... 7 = Sunday) at [hour]:[minute] local time.
  Future<void> scheduleReminder({
    required int id,
    required int hour,
    required int minute,
    required Set<int> days,
    required String title,
    required String body,
    String? soundUri,
  });

  Future<void> cancelReminder(int id);

  /// Shows a notification immediately, to preview text and sound.
  Future<void> showNow({
    required String title,
    required String body,
    String? soundUri,
  });

  /// Opens the system ringtone picker. Null when cancelled or unsupported.
  Future<ReminderSound?> pickSound(String? currentUri);
}

/// Next occurrence of [hour]:[minute] strictly after [now].
tz.TZDateTime nextInstanceOf(int hour, int minute, tz.TZDateTime now) {
  var scheduled =
      tz.TZDateTime(now.location, now.year, now.month, now.day, hour, minute);
  if (!scheduled.isAfter(now)) {
    scheduled = scheduled.add(const Duration(days: 1));
  }
  return scheduled;
}

/// Next occurrence of [hour]:[minute] on [weekday] (1 = Monday ... 7 =
/// Sunday) strictly after [now].
tz.TZDateTime nextInstanceOfWeekday(
    int weekday, int hour, int minute, tz.TZDateTime now) {
  var scheduled = nextInstanceOf(hour, minute, now);
  while (scheduled.weekday != weekday) {
    scheduled = tz.TZDateTime(scheduled.location, scheduled.year,
        scheduled.month, scheduled.day + 1, hour, minute);
  }
  return scheduled;
}

/// Notification id for reminder [reminderId] on [weekday] (1..7).
int notificationIdFor(int reminderId, int weekday) => reminderId * 10 + weekday;

class LocalNotificationService implements NotificationService {
  LocalNotificationService([FlutterLocalNotificationsPlugin? plugin])
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _ringtoneChannel = MethodChannel('carjobfinance/ringtone');
  static const _previewId = 9;

  final FlutterLocalNotificationsPlugin _plugin;
  Future<void>? _ready;

  bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  Future<void> _ensureReady() => _ready ??= _init();

  Future<void> _init() async {
    tz_data.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } catch (_) {
      // Unknown zone id: keep the package default (UTC) rather than fail.
    }
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: darwin,
        macOS: darwin,
      ),
    );
    await _android?.createNotificationChannel(_channelFor(null));
  }

  /// Android fixes a channel's sound once created, so each sound gets its
  /// own channel.
  AndroidNotificationChannel _channelFor(String? soundUri) {
    if (soundUri == null || soundUri.isEmpty) {
      return const AndroidNotificationChannel(
        AppConstants.reminderChannelId,
        AppConstants.reminderChannelName,
        importance: Importance.max,
      );
    }
    return AndroidNotificationChannel(
      '${AppConstants.reminderChannelId}_${soundUri.hashCode.toUnsigned(32)}',
      AppConstants.reminderChannelName,
      importance: Importance.max,
      sound: UriAndroidNotificationSound(soundUri),
    );
  }

  Future<NotificationDetails> _details(String? soundUri) async {
    final channel = _channelFor(soundUri);
    await _android?.createNotificationChannel(channel);
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channel.id,
        channel.name,
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'CarJobFinance',
        playSound: true,
        enableVibration: true,
        sound: channel.sound,
        category: AndroidNotificationCategory.reminder,
      ),
      iOS: const DarwinNotificationDetails(presentSound: true),
      macOS: const DarwinNotificationDetails(presentSound: true),
    );
  }

  @override
  Future<bool> requestPermission() async {
    if (!_supported) return false;
    await _ensureReady();
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        final android = _android;
        final granted =
            await android?.requestNotificationsPermission() ?? false;
        if (granted &&
            !(await android?.canScheduleExactNotifications() ?? true)) {
          // Opens the system screen where exact alarms can be allowed;
          // without it reminders can arrive late while the phone is idle.
          await android?.requestExactAlarmsPermission();
        }
        return granted;
      case TargetPlatform.iOS:
        final ios = _plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
        return await ios?.requestPermissions(alert: true, sound: true) ?? false;
      case TargetPlatform.macOS:
        final macos = _plugin.resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin>();
        return await macos?.requestPermissions(alert: true, sound: true) ??
            false;
      default:
        return false;
    }
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
    if (!_supported) return;
    await _ensureReady();
    await cancelReminder(id);
    if (days.isEmpty) return;
    final details = await _details(soundUri);
    final exact = await _android?.canScheduleExactNotifications() ?? false;
    final mode = exact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
    final now = tz.TZDateTime.now(tz.local);
    for (final day in days) {
      await _plugin.zonedSchedule(
        id: notificationIdFor(id, day),
        title: title,
        body: body,
        scheduledDate: nextInstanceOfWeekday(day, hour, minute, now),
        notificationDetails: details,
        androidScheduleMode: mode,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  @override
  Future<void> cancelReminder(int id) async {
    if (!_supported) return;
    await _ensureReady();
    for (var day = 1; day <= 7; day++) {
      await _plugin.cancel(id: notificationIdFor(id, day));
    }
  }

  @override
  Future<void> showNow({
    required String title,
    required String body,
    String? soundUri,
  }) async {
    if (!_supported) return;
    await _ensureReady();
    await _plugin.show(
      id: _previewId,
      title: title,
      body: body,
      notificationDetails: await _details(soundUri),
    );
  }

  @override
  Future<ReminderSound?> pickSound(String? currentUri) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      final picked = await _ringtoneChannel.invokeMapMethod<String, String>(
          'pickSound', {'current': currentUri});
      final uri = picked?['uri'];
      if (uri == null || uri.isEmpty) return null;
      return ReminderSound(uri: uri, title: picked?['title'] ?? '');
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}

final notificationServiceProvider =
    Provider<NotificationService>((ref) => LocalNotificationService());
