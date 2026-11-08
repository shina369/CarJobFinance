// Reports Page - Relatórios e exportação
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../presentation/controllers/controllers.dart';

enum ReportPeriod { day, week, month, year, custom }

extension ReportPeriodExtension on ReportPeriod {
  String get label {
    switch (this) {
      case ReportPeriod.day:
        return 'Hoje';
      case ReportPeriod.week:
        return 'Esta Semana';
      case ReportPeriod.month:
        return 'Este Mês';
      case ReportPeriod.year:
        return 'Este Ano';
      case ReportPeriod.custom:
        return 'Personalizado';
    }
  }

  DateTimeRange get range {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (this) {
      case ReportPeriod.day:
        return DateTimeRange(
          start: today,
          end: today.add(const Duration(days: 1)).subtract(const Duration(seconds: 1)),
        );
      case ReportPeriod.week:
        final weekStart = today.subtract(Duration(days: today.weekday - 1));
        return DateTimeRange(
          start: weekStart,
          end: weekStart.add(const Duration(days: 7)).subtract(const Duration(seconds: 1)),
        );
      case ReportPeriod.month:
        final monthStart = DateTime(now.year, now.month, 1);
        final monthEnd = DateTime(now.year, now.month + 1, 1).subtract(const Duration(seconds: 1));
        return DateTimeRange(start: monthStart, end: monthEnd);
      case ReportPeriod.year:
        final yearStart = DateTime(now.year, 1, 1);
        final yearEnd = DateTime(now.year + 1, 1, 1).subtract(const Duration(seconds: 1));
        return DateTimeRange(start: yearStart, end: yearEnd);
      case ReportPeriod.custom:
        return DateTimeRange(start: today, end: today);
    }
  }
}

// Provider para o período selecionado
final selectedReportPeriodProvider = StateProvider<ReportPeriod>((ref) => ReportPeriod.month);

class ReportsPage extends ConsumerWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Relatórios'),
      ),
      body: _ReportsContent(),
    );
  }
}

class _PeriodDropdown extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedPeriod = ref.watch(selectedReportPeriodProvider);

    return PopupMenuButton<ReportPeriod>(
      initialValue: selectedPeriod,
      onSelected: (period) {
        ref.read(selectedReportPeriodProvider.notifier).state = period;
      },
      itemBuilder: (context) => ReportPeriod.values.map((period) {
        return PopupMenuItem<ReportPeriod>(
          value: period,
          child: Row(
            children: [
              if (selectedPeriod == period)
                Icon(
                  Icons.check,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                )
              else
                const SizedBox(width: 18),
              const SizedBox(width: 12),
              Text(period.label),
            ],
          ),
        );
      }).toList(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.date_range,
              size: 20,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            const SizedBox(width: 8),
            Text(
              selectedPeriod.label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down,
              size: 20,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodSelectorCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Período do Relatório',
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
          final totalEarnings = filteredRides.fold<double>(0, (sum, r) => sum + r.earnings);
          final totalExpenses = filteredExpenses.fold<double>(0, (sum, e) => sum + e.amount);
          final netProfit = totalEarnings - totalExpenses;
          final totalKm = filteredRides.fold<double>(0, (sum, r) => sum + r.distanceKm);
          final totalMinutes = filteredRides.fold<int>(0, (sum, r) => sum + r.durationMinutes);

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
                      Text(
                        'Resumo Financeiro (${period.label})',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      _SummaryRow(
                        label: 'Total de Ganhos',
                        value: _formatCurrency(totalEarnings),
                        isPositive: true,
                      ),
                      _SummaryRow(
                        label: 'Total de Despesas',
                        value: _formatCurrency(totalExpenses),
                        isPositive: false,
                      ),
                      const Divider(),
                      _SummaryRow(
                        label: 'Lucro Líquido',
                        value: _formatCurrency(netProfit),
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
                        'Métricas de Desempenho',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      _MetricRow(
                        label: 'Corridas Realizadas',
                        value: filteredRides.length.toString(),
                      ),
                      _MetricRow(
                        label: 'Quilometragem Total',
                        value: '${totalKm.toStringAsFixed(1)} km',
                      ),
                      _MetricRow(
                        label: 'Horas Trabalhadas',
                        value: '${(totalMinutes / 60).toStringAsFixed(1)}h',
                      ),
                      _MetricRow(
                        label: 'Média por km',
                        value: totalKm > 0
                            ? '${_formatCurrency(totalEarnings / totalKm)}/km'
                            : '${_formatCurrency(0)}/km',
                      ),
                      _MetricRow(
                        label: 'Média por hora',
                        value: totalMinutes > 0
                            ? '${_formatCurrency(totalEarnings / (totalMinutes / 60))}/h'
                            : '${_formatCurrency(0)}/h',
                      ),
                      _MetricRow(
                        label: 'Média por corrida',
                        value: filteredRides.isNotEmpty
                            ? _formatCurrency(totalEarnings / filteredRides.length)
                            : _formatCurrency(0),
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
                        'Exportar Dados',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        leading: Icon(
                          Icons.table_chart,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        title: const Text('Exportar CSV'),
                        subtitle: const Text('Planilha para Excel/Google Sheets'),
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
                        title: const Text('Exportar PDF'),
                        subtitle: const Text('Relatório formatado para impressão'),
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
                        title: const Text('Backup Completo'),
                        subtitle: const Text('Todos os dados em JSON'),
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
        error: (e, _) => Center(child: Text('Erro ao carregar despesas: $e')),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erro ao carregar corridas: $e')),
    );
  }

  String _formatCurrency(double value) {
    return 'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';
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