// Data set behind the Reports page exports (CSV and PDF).
import 'package:intl/intl.dart';

import '../../domain/entities/expense.dart';
import '../../domain/entities/ride.dart';
import '../constants/app_constants.dart';
import '../l10n/languages.dart';
import '../l10n/strings.dart';

class ReportData {
  ReportData({
    required this.periodLabel,
    required List<Ride> rides,
    required List<Expense> expenses,
  })  : rides = [...rides]..sort((a, b) => a.date.compareTo(b.date)),
        expenses = [...expenses]..sort((a, b) => a.date.compareTo(b.date));

  final String periodLabel;
  final List<Ride> rides;
  final List<Expense> expenses;

  double get totalEarnings => rides.fold(0, (sum, r) => sum + r.earnings);
  double get totalCommissions =>
      rides.fold(0, (sum, r) => sum + r.commissionAmount);
  double get otherExpenses => expenses.fold(0, (sum, e) => sum + e.amount);
  double get totalExpenses => otherExpenses + totalCommissions;
  double get netProfit => totalEarnings - totalExpenses;
  double get totalKm => rides.fold(0, (sum, r) => sum + r.distanceKm);
  int get totalMinutes => rides.fold(0, (sum, r) => sum + r.durationMinutes);
}

final DateFormat _csvDate = DateFormat('yyyy-MM-dd HH:mm');

/// Builds a spreadsheet-friendly CSV with one row per ride and expense.
///
/// Uses `;` as the delimiter and a UTF-8 BOM so Excel opens it with the
/// right columns and accents. Numbers follow the language's decimal mark.
String buildReportCsv(ReportData data, AppLanguage lang) {
  final number = NumberFormat('0.00', lang.tag);
  const d = AppConstants.csvDelimiter;

  final rows = <List<String>>[
    [
      lang.tr('export.type'),
      lang.tr('export.date'),
      lang.tr('export.platformOrCategory'),
      lang.tr('export.description'),
      lang.tr('export.earnings'),
      lang.tr('export.commission'),
      lang.tr('export.typeExpense'),
      lang.tr('export.distanceKm'),
      lang.tr('export.durationMin'),
    ],
    for (final r in data.rides)
      [
        lang.tr('export.typeRide'),
        _csvDate.format(r.date),
        r.platform,
        [r.origin, r.destination]
            .where((s) => s != null && s.isNotEmpty)
            .join(' → '),
        number.format(r.earnings),
        number.format(r.commissionAmount),
        '',
        number.format(r.distanceKm),
        '${r.durationMinutes}',
      ],
    for (final e in data.expenses)
      [
        lang.tr('export.typeExpense'),
        _csvDate.format(e.date),
        e.category,
        e.description ?? '',
        '',
        '',
        number.format(e.amount),
        '',
        '',
      ],
  ];

  final body = rows.map((row) => row.map(_csvField).join(d)).join('\r\n');
  return '﻿$body\r\n';
}

String _csvField(String value) {
  var field = value;
  // Neutralise spreadsheet formula injection from user-typed text.
  if (field.isNotEmpty && '=+@\t\r'.contains(field[0])) {
    field = "'$field";
  }
  final needsQuotes = field.contains(AppConstants.csvDelimiter) ||
      field.contains('"') ||
      field.contains('\n') ||
      field.contains('\r');
  return needsQuotes ? '"${field.replaceAll('"', '""')}"' : field;
}
