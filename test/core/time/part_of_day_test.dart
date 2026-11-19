import 'package:carjobfinance/core/time/part_of_day.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime _at(int hour, [int minute = 0]) =>
    DateTime(2026, 11, 19, hour, minute);

void main() {
  test('morning runs from 05:00 to 11:59', () {
    expect(PartOfDay.of(_at(5)), PartOfDay.morning);
    expect(PartOfDay.of(_at(11, 59)), PartOfDay.morning);
  });

  test('afternoon runs from 12:00 to 17:59', () {
    expect(PartOfDay.of(_at(12)), PartOfDay.afternoon);
    expect(PartOfDay.of(_at(17, 59)), PartOfDay.afternoon);
  });

  test('night runs from 18:00 to 04:59', () {
    expect(PartOfDay.of(_at(18)), PartOfDay.night);
    expect(PartOfDay.of(_at(0)), PartOfDay.night);
    expect(PartOfDay.of(_at(4, 59)), PartOfDay.night);
  });

  test('sun by day, moon by night', () {
    expect(PartOfDay.morning.emoji, '☀️');
    expect(PartOfDay.afternoon.emoji, '☀️');
    expect(PartOfDay.night.emoji, '🌙');
  });
}
