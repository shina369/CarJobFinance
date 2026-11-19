// Part of the day used for the dashboard greeting.
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum PartOfDay {
  /// 05:00–11:59
  morning,

  /// 12:00–17:59
  afternoon,

  /// 18:00–04:59
  night;

  factory PartOfDay.of(DateTime time) {
    final hour = time.hour;
    if (hour >= 5 && hour < 12) return PartOfDay.morning;
    if (hour >= 12 && hour < 18) return PartOfDay.afternoon;
    return PartOfDay.night;
  }

  bool get isDaytime => this != PartOfDay.night;

  String get emoji => isDaytime ? '☀️' : '🌙';

  String get greetingKey => switch (this) {
        PartOfDay.morning => 'dash.greetingMorning',
        PartOfDay.afternoon => 'dash.greetingAfternoon',
        PartOfDay.night => 'dash.greetingNight',
      };
}

/// Source of the current time; overridden in tests.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
