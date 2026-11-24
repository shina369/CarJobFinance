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
import '../controllers/entitlement_controller.dart';
import '../pages/reports/reports_page.dart';
import 'export_feedback.dart';
import 'premium_gate.dart';

class ExportTiles extends ConsumerWidget {
  const ExportTiles({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appLanguageProvider);
    final cs = Theme.of(context).colorScheme;
    final entitlement = ref.watch(entitlementProvider);
    final locked = entitlement.resolved && !entitlement.isPremium;

    Future<void> gated(Future<bool> Function() export) async {
      if (!await ensurePremium(context, ref)) return;
      if (!context.mounted) return;
      await runExport(context, lang, export);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: Icon(Icons.table_chart, color: cs.primary),
          title: Text(lang.tr('reports.exportCsv')),
          subtitle: Text(lang.tr('reports.exportCsvSub')),
          trailing: _trailing(
            context,
            lang,
            locked: locked,
            lockKey: const Key('export-csv-lock'),
          ),
          onTap: () => gated(() => _exportCsv(ref, lang)),
        ),
        const Divider(height: 1, indent: 72),
        ListTile(
          leading: Icon(Icons.picture_as_pdf, color: cs.error),
          title: Text(lang.tr('reports.exportPdf')),
          subtitle: Text(lang.tr('reports.exportPdfSub')),
          trailing: _trailing(
            context,
            lang,
            locked: locked,
            lockKey: const Key('export-pdf-lock'),
          ),
          onTap: () => gated(() => _exportPdf(ref, lang)),
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

Widget _trailing(
  BuildContext context,
  AppLanguage lang, {
  required bool locked,
  required Key lockKey,
}) {
  if (!locked) return const Icon(Icons.chevron_right);
  final cs = Theme.of(context).colorScheme;
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.lock_outline, key: lockKey, size: 18, color: cs.primary),
      const SizedBox(width: 4),
      Text(
        lang.tr('premium.locked'),
        style: Theme.of(context)
            .textTheme
            .labelMedium
            ?.copyWith(color: cs.primary),
      ),
    ],
  );
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
  final custom = ref.read(customReportRangeProvider);
  final range = period.rangeFor(custom);
  bool inRange(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return !day.isBefore(range.start) && !day.isAfter(range.end);
  }

  final rides = await ref.read(rideRepositoryProvider).getAll();
  final expenses = await ref.read(expenseRepositoryProvider).getAll();
  return ReportData(
    periodLabel: period.labelFor(lang, custom),
    rides: rides.where((r) => inRange(r.date)).toList(),
    expenses: expenses.where((e) => inRange(e.date)).toList(),
  );
}
