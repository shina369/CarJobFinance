// PDF version of the Reports page: summary, metrics, rides and expenses.
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../l10n/currencies.dart';
import '../l10n/languages.dart';
import '../l10n/strings.dart';
import 'report_data.dart';

final DateFormat _pdfDate = DateFormat('yyyy-MM-dd');

bool _isLatin1(String s) => s.runes.every((r) => r <= 0xFF);

/// The built-in PDF fonts only cover Latin-1. Languages written in other
/// scripts fall back to English labels so the report stays readable.
AppLanguage pdfLanguageFor(AppLanguage lang) {
  if (_isLatin1(lang.tr('export.reportTitle'))) return lang;
  return languageForTag('en_US') ?? lang;
}

String _safe(String s) =>
    String.fromCharCodes(s.runes.map((r) => r <= 0xFF ? r : 0x3F));

Future<Uint8List> buildReportPdf(
  ReportData data, {
  required AppLanguage lang,
  required AppCurrency currency,
  DateTime? generatedAt,
}) {
  final l = pdfLanguageFor(lang);
  String tr(String key, {Map<String, String>? args}) =>
      _safe(l.tr(key, args: args));

  final amount = NumberFormat('#,##0.00', currency.formatTag);
  final unit = _isLatin1(currency.symbol) ? currency.symbol : currency.code;
  String money(double v) => _safe('$unit ${amount.format(v)}');

  final hours = data.totalMinutes / 60;
  final summary = <List<String>>[
    [tr('reports.totalEarnings'), money(data.totalEarnings)],
    [tr('reports.commissions'), money(data.totalCommissions)],
    [tr('reports.otherExpenses'), money(data.otherExpenses)],
    [tr('reports.totalExpenses'), money(data.totalExpenses)],
    [tr('reports.netProfit'), money(data.netProfit)],
  ];
  final metrics = <List<String>>[
    [tr('reports.ridesDone'), '${data.rides.length}'],
    [tr('reports.totalKm'), '${data.totalKm.toStringAsFixed(1)} km'],
    [tr('reports.hoursWorked'), '${hours.toStringAsFixed(1)} h'],
    [
      tr('reports.avgPerKm'),
      money(data.totalKm > 0 ? data.totalEarnings / data.totalKm : 0),
    ],
    [
      tr('reports.avgPerHour'),
      money(hours > 0 ? data.totalEarnings / hours : 0),
    ],
    [
      tr('reports.avgPerRide'),
      money(data.rides.isNotEmpty ? data.totalEarnings / data.rides.length : 0),
    ],
  ];

  pw.Widget section(String title) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 18, bottom: 6),
        child: pw.Text(
          title,
          style:
              const pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
      );

  pw.Widget keyValueTable(List<List<String>> rows) =>
      pw.TableHelper.fromTextArray(
        data: rows,
        headerCount: 0,
        cellStyle: const pw.TextStyle(fontSize: 10),
        cellAlignments: const {1: pw.Alignment.centerRight},
        border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      );

  pw.Widget dataTable(List<String> headers, List<List<String>> rows,
          Map<int, pw.Alignment> alignments) =>
      pw.TableHelper.fromTextArray(
        headers: headers,
        data: rows,
        headerStyle:
            const pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
        cellStyle: const pw.TextStyle(fontSize: 9),
        cellAlignments: alignments,
        border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      );

  final doc = pw.Document(title: tr('export.reportTitle'));
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      footer: (context) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          '${context.pageNumber} / ${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
        ),
      ),
      build: (context) => [
        pw.Text(
          'CarJobFinance - ${tr('export.reportTitle')}',
          style:
              const pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          '${_safe(data.periodLabel)}'
          '  -  ${tr('export.generatedAt', args: {
                'date': _pdfDate.format(generatedAt ?? DateTime.now())
              })}',
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
        ),
        section(tr('reports.summary')),
        keyValueTable(summary),
        section(tr('reports.metrics')),
        keyValueTable(metrics),
        if (data.rides.isNotEmpty) ...[
          section(tr('export.rides')),
          dataTable(
            [
              tr('export.date'),
              tr('export.platform'),
              tr('export.distanceKm'),
              tr('export.durationMin'),
              tr('export.earnings'),
              tr('export.commission'),
            ],
            [
              for (final r in data.rides)
                [
                  _pdfDate.format(r.date),
                  _safe(r.platform),
                  r.distanceKm.toStringAsFixed(1),
                  '${r.durationMinutes}',
                  money(r.earnings),
                  money(r.commissionAmount),
                ],
            ],
            const {
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
              4: pw.Alignment.centerRight,
              5: pw.Alignment.centerRight,
            },
          ),
        ],
        if (data.expenses.isNotEmpty) ...[
          section(tr('export.expenses')),
          dataTable(
            [
              tr('export.date'),
              tr('export.category'),
              tr('export.description'),
              tr('export.amount'),
            ],
            [
              for (final e in data.expenses)
                [
                  _pdfDate.format(e.date),
                  _safe(e.category),
                  _safe(e.description ?? ''),
                  money(e.amount),
                ],
            ],
            const {3: pw.Alignment.centerRight},
          ),
        ],
      ],
    ),
  );
  return doc.save();
}
