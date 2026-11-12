// Export actions (CSV, PDF, full backup) for the period selected in Relatórios.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/export/file_exporter.dart';
import '../../core/export/report_data.dart';
import '../../core/export/report_pdf.dart';
import '../../core/l10n/currency_provider.dart' as currency_pkg;
import '../../core/l10n/language_provider.dart';
import '../../core/l10n/languages.dart';
import '../../core/l10n/strings.dart';
import '../controllers/controllers.dart';
import '../controllers/data_controller.dart';
import '../pages/reports/reports_page.dart';
import 'export_feedback.dart';

class ExportTiles extends ConsumerWidget {
  const ExportTiles({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appLanguageProvider);
    final cs = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: Icon(Icons.table_chart, color: cs.primary),
          title: Text(lang.tr('reports.exportCsv')),
          subtitle: Text(lang.tr('reports.exportCsvSub')),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => runExport(context, lang, () => _exportCsv(ref, lang)),
        ),
        const Divider(height: 1, indent: 72),
        ListTile(
          leading: Icon(Icons.picture_as_pdf, color: cs.error),
          title: Text(lang.tr('reports.exportPdf')),
          subtitle: Text(lang.tr('reports.exportPdfSub')),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => runExport(context, lang, () => _exportPdf(ref, lang)),
        ),
        const Divider(height: 1, indent: 72),
        ListTile(
          leading: Icon(Icons.backup, color: cs.tertiary),
          title: Text(lang.tr('reports.backup')),
          subtitle: Text(lang.tr('reports.backupSub')),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => runExport(
            context,
            lang,
            ref.read(dataControllerProvider).exportBackup,
          ),
        ),
      ],
    );
  }
}

Future<bool> _exportCsv(WidgetRef ref, AppLanguage lang) async {
  final period = ref.read(selectedReportPeriodProvider);
  final data = await _periodData(ref, period, lang);
  return ref.read(fileExporterProvider).export(
        fileName: exportFileName('report', 'csv'),
        bytes: Uint8List.fromList(utf8.encode(buildReportCsv(data, lang))),
        mimeType: 'text/csv',
      );
}

Future<bool> _exportPdf(WidgetRef ref, AppLanguage lang) async {
  final period = ref.read(selectedReportPeriodProvider);
  final currency = ref.read(currency_pkg.appCurrencyProvider);
  final data = await _periodData(ref, period, pdfLanguageFor(lang));
  final bytes = await buildReportPdf(data, lang: lang, currency: currency);
  return ref.read(fileExporterProvider).export(
        fileName: exportFileName('report', 'pdf'),
        bytes: bytes,
        mimeType: 'application/pdf',
      );
}

Future<ReportData> _periodData(
    WidgetRef ref, ReportPeriod period, AppLanguage lang) async {
  final range = period.range;
  bool inRange(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return !day.isBefore(range.start) && !day.isAfter(range.end);
  }

  final rides = await ref.read(rideRepositoryProvider).getAll();
  final expenses = await ref.read(expenseRepositoryProvider).getAll();
  return ReportData(
    periodLabel: period.label(lang),
    rides: rides.where((r) => inRange(r.date)).toList(),
    expenses: expenses.where((e) => inRange(e.date)).toList(),
  );
}
