// A user-defined reminder: which days, what time, what text and sound.
import 'dart:convert';

class Reminder {
  const Reminder({
    required this.id,
    required this.hour,
    required this.minute,
    required this.days,
    this.message,
    this.soundUri,
    this.soundName,
    this.enabled = true,
  });

  static const allDays = {1, 2, 3, 4, 5, 6, 7};

  final int id;
  final int hour;
  final int minute;

  /// Weekdays the reminder fires on: 1 = Monday ... 7 = Sunday.
  final Set<int> days;

  /// Custom notification title; null means the default text.
  final String? message;

  /// System ringtone URI; null means the default notification sound.
  final String? soundUri;
  final String? soundName;
  final bool enabled;

  Reminder copyWith({
    int? hour,
    int? minute,
    Set<int>? days,
    String? message,
    bool clearMessage = false,
    String? soundUri,
    String? soundName,
    bool clearSound = false,
    bool? enabled,
  }) {
    return Reminder(
      id: id,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      days: days ?? this.days,
      message: clearMessage ? null : (message ?? this.message),
      soundUri: clearSound ? null : (soundUri ?? this.soundUri),
      soundName: clearSound ? null : (soundName ?? this.soundName),
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'hour': hour,
        'minute': minute,
        'days': (days.toList()..sort()),
        'message': message,
        'soundUri': soundUri,
        'soundName': soundName,
        'enabled': enabled,
      };

  static Reminder? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final hour = json['hour'];
    final minute = json['minute'];
    final days = json['days'];
    if (id is! int || hour is! int || minute is! int || days is! List) {
      return null;
    }
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    final message = (json['message'] as String?)?.trim();
    final soundUri = json['soundUri'] as String?;
    return Reminder(
      id: id,
      hour: hour,
      minute: minute,
      days: days.whereType<int>().where((d) => d >= 1 && d <= 7).toSet(),
      message: (message == null || message.isEmpty) ? null : message,
      soundUri: (soundUri == null || soundUri.isEmpty) ? null : soundUri,
      soundName: json['soundName'] as String?,
      enabled: json['enabled'] != false,
    );
  }

  static String encodeList(List<Reminder> reminders) =>
      jsonEncode(reminders.map((r) => r.toJson()).toList());

  static List<Reminder> decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded.map(tryFromJson).whereType<Reminder>().toList();
    } on FormatException {
      return const [];
    }
  }
}
