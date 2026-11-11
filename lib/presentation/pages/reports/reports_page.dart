// Reports Page - Relatórios e exportação
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/language_provider.dart';
import '../../../core/l10n/languages.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/l10n/currency_provider.dart' as currency_pkg;
import '../../../core/settings/locale_helper.dart';
import '../../../presentation/controllers/controllers.dart';

enum ReportPeriod { day, week, month, year, custom }

extension ReportPeriodExtension on ReportPeriod {
  String label(AppLanguage lang) {
    switch (this) {
      case ReportPeriod.day:
        return lang.tr('reports.periodToday');
      case ReportPeriod.week:
        return lang.tr('reports.periodWeek');
      case ReportPeriod.month:
        return lang.tr('reports.periodMonth');
      case ReportPeriod.year:
        return lang.tr('reports.periodYear');
      case ReportPeriod.custom:
        return lang.tr('reports.periodCustom');
    }
  }

  DateTimeRange get range {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (this) {
      case ReportPeriod.day:
        return DateTimeRange(
          start: today,
          end: today
              .add(const Duration(days: 1))
              .subtract(const Duration(seconds: 1)),
        );
      case ReportPeriod.week:
        final weekStart = today.subtract(Duration(days: today.weekday - 1));
        return DateTimeRange(
          start: weekStart,
          end: weekStart
              .add(const Duration(days: 7))
              .subtract(const Duration(seconds: 1)),
        );
      case ReportPeriod.month:
        final monthStart = DateTime(now.year, now.month, 1);
        final monthEnd = DateTime(now.year, now.month + 1, 1)
            .subtract(const Duration(seconds: 1));
        return DateTimeRange(start: monthStart, end: monthEnd);
      case ReportPeriod.year:
        final yearStart = DateTime(now.year, 1, 1);
        final yearEnd =
            DateTime(now.year + 1, 1, 1).subtract(const Duration(seconds: 1));
        return DateTimeRange(start: yearStart, end: yearEnd);
      case ReportPeriod.custom:
        return DateTimeRange(start: today, end: today);
    }
  }
}

// Provider para o período selecionado
final selectedReportPeriodProvider =
    StateProvider<ReportPeriod>((ref) => ReportPeriod.month);

class ReportsPage extends ConsumerWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appLanguageProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(lang.tr('reports.title')),
      ),
      body: _ReportsContent(),
    );
  }
}

class _PeriodDropdown extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedPeriod = ref.watch(selectedReportPeriodProvider);
    final lang = ref.watch(appLanguageProvider);

    return MenuAnchor(
      builder: (context, controller, child) {
        return OutlinedButton.icon(
          onPressed: () {
            if (controller.isOpen) {
              controller.close();
            } else {
              controller.open();
            }
          },
          icon: Icon(
            Icons.keyboard_arrow_down,
            size: 20,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          label: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                Icons.date_range,
                size: 20,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  selectedPeriod.label(lang),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            side: BorderSide(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        );
      },
      menuChildren: ReportPeriod.values.map((period) {
        return MenuItemButton(
          onPressed: () {
            ref.read(selectedReportPeriodProvider.notifier).state = period;
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                if (selectedPeriod == period)
                  Icon(
                    Icons.check,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  )
                else
                  const SizedBox(width: 20),
                const SizedBox(width: 12),
                Text(period.label(lang)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _PeriodSelectorCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appLanguageProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lang.tr('reports.period'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            _PeriodDropdown(),
          ],
        ),
      ),
    );
  }
}

class _ReportsContent extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(selectedReportPeriodProvider);
    final ridesAsync = ref.watch(ridesControllerProvider);
    final expensesAsync = ref.watch(expensesControllerProvider);
    final currency = ref.watch(currency_pkg.appCurrencyProvider);
    final lang = ref.watch(appLanguageProvider);

    return ridesAsync.when(
      data: (rides) => expensesAsync.when(
        data: (expenses) {
          // Filter by period
          final range = period.range;
          final filteredRides = rides.where((r) {
            final date = DateTime(r.date.year, r.date.month, r.date.day);
            return !date.isBefore(range.start) && !date.isAfter(range.end);
          }).toList();

          final filteredExpenses = expenses.where((e) {
            final date = DateTime(e.date.year, e.date.month, e.date.day);
            return !date.isBefore(range.start) && !date.isAfter(range.end);
          }).toList();

          // Calculate summaries
          final totalEarnings =
              filteredRides.fold<double>(0, (sum, r) => sum + r.earnings);
          final totalExpenses =
              filteredExpenses.fold<double>(0, (sum, e) => sum + e.amount);
          final netProfit = totalEarnings - totalExpenses;
          final totalKm =
              filteredRides.fold<double>(0, (sum, r) => sum + r.distanceKm);
          final totalMinutes =
              filteredRides.fold<int>(0, (sum, r) => sum + r.durationMinutes);

          String fmt(double v) => LocalizedCurrency.formatFor(v, currency);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Período do Relatório - Dropdown Card
              _PeriodSelectorCard(),
              const SizedBox(height: 16),

              // Resumo Financeiro
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: lang.tr('reports.summary'),
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            TextSpan(
                              text: '\n${period.label(lang)}',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                    fontWeight: FontWeight.normal,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _SummaryRow(
                        label: lang.tr('reports.totalEarnings'),
                        value: fmt(totalEarnings),
                        isPositive: true,
                      ),
                      _SummaryRow(
                        label: lang.tr('reports.totalExpenses'),
                        value: fmt(totalExpenses),
                        isPositive: false,
                      ),
                      const Divider(),
                      _SummaryRow(
                        label: lang.tr('reports.netProfit'),
                        value: fmt(netProfit),
                        isPositive: netProfit >= 0,
                        isTotal: true,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Métricas
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lang.tr('reports.metrics'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      _MetricRow(
                        label: lang.tr('reports.ridesDone'),
                        value: filteredRides.length.toString(),
                      ),
                      _MetricRow(
                        label: lang.tr('reports.totalKm'),
                        value: '${totalKm.toStringAsFixed(1)} km',
                      ),
                      _MetricRow(
                        label: lang.tr('reports.hoursWorked'),
                        value: '${(totalMinutes / 60).toStringAsFixed(1)}h',
                      ),
                      _MetricRow(
                        label: lang.tr('reports.avgPerKm'),
                        value: totalKm > 0
                            ? '${fmt(totalEarnings / totalKm)}/km'
                            : '${fmt(0)}/km',
                      ),
                      _MetricRow(
                        label: lang.tr('reports.avgPerHour'),
                        value: totalMinutes > 0
                            ? '${fmt(totalEarnings / (totalMinutes / 60))}/h'
                            : '${fmt(0)}/h',
                      ),
                      _MetricRow(
                        label: lang.tr('reports.avgPerRide'),
                        value: filteredRides.isNotEmpty
                            ? fmt(totalEarnings / filteredRides.length)
                            : fmt(0),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Ações de Exportação
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lang.tr('reports.export'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        leading: Icon(
                          Icons.table_chart,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        title: Text(lang.tr('reports.exportCsv')),
                        subtitle: Text(lang.tr('reports.exportCsvSub')),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          // TODO: Export CSV
                        },
                      ),
                      const Divider(),
                      ListTile(
                        leading: Icon(
                          Icons.picture_as_pdf,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        title: Text(lang.tr('reports.exportPdf')),
                        subtitle: Text(lang.tr('reports.exportPdfSub')),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          // TODO: Export PDF
                        },
                      ),
                      const Divider(),
                      ListTile(
                        leading: Icon(
                          Icons.backup,
                          color: Theme.of(context).colorScheme.tertiary,
                        ),
                        title: Text(lang.tr('reports.backup')),
                        subtitle: Text(lang.tr('reports.backupSub')),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          // TODO: Export JSON backup
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child:
                Text(lang.tr('reports.loadExpensesError', args: {'e': '$e'}))),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
          child: Text(lang.tr('reports.loadRidesError', args: {'e': '$e'}))),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    required this.isPositive,
    this.isTotal = false,
  });

  final String label;
  final String value;
  final bool isPositive;
  final bool isTotal;

  @override
  Widget build(BuildContext context) {
    final color = isPositive
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.error;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
          ),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}
