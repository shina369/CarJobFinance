// Dashboard Page
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../presentation/controllers/controllers.dart';
import '../../../domain/entities/ride.dart' as entity_ride;
import '../../../domain/entities/expense.dart' as entity_expense;

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ridesState = ref.watch(ridesControllerProvider);
    final expensesState = ref.watch(expensesControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {},
          ),
        ],
      ),
      body: ridesState.when(
        data: (rides) => expensesState.when(
          data: (expenses) => _DashboardContent(
            rides: rides,
            expenses: expenses,
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Erro: $error')),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Erro: $error')),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Nova Corrida (esquerda)
            FloatingActionButton.extended(
              heroTag: 'newRide',
              onPressed: () => context.push('/rides/new'),
              icon: const Icon(Icons.directions_car),
              label: const Text('Nova Corrida'),
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
            // Nova Despesa (direita)
            FloatingActionButton.extended(
              heroTag: 'newExpense',
              onPressed: () => context.push('/expenses/new'),
              icon: const Icon(Icons.receipt_long),
              label: const Text('Nova Despesa'),
              backgroundColor: Colors.orange.shade700,
              foregroundColor: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.rides, required this.expenses});

  final List<entity_ride.Ride> rides;
  final List<entity_expense.Expense> expenses;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1)).subtract(const Duration(seconds: 1));

    final todayRides = rides
        .where((r) => r.date.isAfter(todayStart.subtract(const Duration(seconds: 1))) &&
            r.date.isBefore(todayEnd.add(const Duration(seconds: 1))))
        .toList();
    final todayExpenses = expenses
        .where((e) => e.date.isAfter(todayStart.subtract(const Duration(seconds: 1))) &&
            e.date.isBefore(todayEnd.add(const Duration(seconds: 1))))
        .toList();

    final totalEarnings =
        todayRides.fold<double>(0, (sum, r) => sum + r.earnings);
    final totalExpenses =
        todayExpenses.fold<double>(0, (sum, e) => sum + e.amount);
    final netProfit = totalEarnings - totalExpenses;
    final totalKm =
        todayRides.fold<double>(0, (sum, r) => sum + r.distanceKm);

    // Month data
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 1).subtract(const Duration(seconds: 1));
    final monthRides = rides
        .where((r) => r.date.isAfter(monthStart.subtract(const Duration(seconds: 1))) &&
            r.date.isBefore(monthEnd.add(const Duration(seconds: 1))))
        .toList();
    final monthExpenses = expenses
        .where((e) => e.date.isAfter(monthStart.subtract(const Duration(seconds: 1))) &&
            e.date.isBefore(monthEnd.add(const Duration(seconds: 1))))
        .toList();
    final monthEarnings = monthRides.fold<double>(0, (sum, r) => sum + r.earnings);
    final monthExpensesTotal = monthExpenses.fold<double>(0, (sum, e) => sum + e.amount);

    // Format today's date: "Quinta-feira, 12/10/26"
    final todayLabel =
        '${_weekdayName(now.weekday)}, ${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year.toString().substring(2)}';
    final monthLabel = '${_monthName(now.month)} de ${now.year}';

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CompactFinancialSummary(
            earnings: totalEarnings,
            expenses: totalExpenses,
            netProfit: netProfit,
            dateLabel: todayLabel,
            rideCount: todayRides.length,
            totalKm: totalKm,
          ),
          const SizedBox(height: 8),
          // Resumo do Mês - only Ganhos and Despesas
          _MonthSummaryCard(
            earnings: monthEarnings,
            expenses: monthExpensesTotal,
            dateLabel: monthLabel,
            monthlyGoal: 5000.0, // Meta mensal padrão: R$ 5.000
          ),
          const SizedBox(height: 8),
          if (rides.isNotEmpty) _CompactRecentRides(ride: rides.last),
        ],
      ),
    );
  }

  String _monthName(int month) {
    const names = [
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
    ];
    return names[month - 1];
  }

  String _weekdayName(int weekday) {
    const names = [
      'Segunda-feira',
      'Terça-feira',
      'Quarta-feira',
      'Quinta-feira',
      'Sexta-feira',
      'Sábado',
      'Domingo',
    ];
    return names[weekday - 1];
  }
}

/// Resumo financeiro compacto - horizontal layout
class _CompactFinancialSummary extends StatelessWidget {
  const _CompactFinancialSummary({
    required this.earnings,
    required this.expenses,
    required this.netProfit,
    required this.dateLabel,
    required this.rideCount,
    required this.totalKm,
  });

  final double earnings;
  final double expenses;
  final double netProfit;
  final String dateLabel;
  final int rideCount;
  final double totalKm;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Resumo do Dia',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Text(
                  dateLabel,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Lucro em destaque no topo
            _CompactSummaryItem(
              label: 'Lucro',
              value: netProfit,
              color: netProfit >= 0 ? Colors.green : Colors.red,
              icon: Icons.account_balance_wallet,
              isHighlighted: true,
              fullWidth: true,
            ),
            const SizedBox(height: 12),
            // Ganhos e Despesas lado a lado
            Row(
              children: [
                _CompactSummaryItem(
                  label: 'Ganhos',
                  value: earnings,
                  color: Theme.of(context).colorScheme.primary,
                  icon: Icons.trending_up,
                ),
                const SizedBox(width: 8),
                _CompactSummaryItem(
                  label: 'Despesas',
                  value: expenses,
                  color: Theme.of(context).colorScheme.error,
                  icon: Icons.trending_down,
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Corridas e Km lado a lado
            Row(
              children: [
                _CompactSummaryItem(
                  label: 'Corridas',
                  value: rideCount.toDouble(),
                  color: Theme.of(context).colorScheme.secondary,
                  icon: Icons.directions_car,
                ),
                const SizedBox(width: 8),
                _CompactSummaryItem(
                  label: 'Km',
                  value: totalKm,
                  color: Theme.of(context).colorScheme.tertiary,
                  icon: Icons.route,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Resumo do Mês - apenas Ganhos e Despesas
class _MonthSummaryCard extends StatelessWidget {
  const _MonthSummaryCard({
    required this.earnings,
    required this.expenses,
    required this.dateLabel,
    required this.monthlyGoal,
  });

  final double earnings;
  final double expenses;
  final String dateLabel;
  final double monthlyGoal;

  @override
  Widget build(BuildContext context) {
    final netProfit = earnings - expenses;
    final goalProgress = monthlyGoal > 0 ? (netProfit / monthlyGoal * 100).clamp(0, 100) : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Resumo do Mês',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Text(
                  dateLabel,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Objetivo do mês em destaque (azul)
            _CompactSummaryItem(
              label: 'Objetivo do mês',
              value: monthlyGoal,
              color: Colors.blue,
              icon: Icons.flag,
              isHighlighted: true,
              fullWidth: true,
            ),
            const SizedBox(height: 12),
            // Progresso do objetivo
            if (monthlyGoal > 0)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Progresso',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                      Text(
                        '${goalProgress.toStringAsFixed(0)}%',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: goalProgress / 100,
                    backgroundColor: Colors.blue.withValues(alpha: 0.1),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            Row(
              children: [
                _CompactSummaryItem(
                  label: 'Ganhos',
                  value: earnings,
                  color: Theme.of(context).colorScheme.primary,
                  icon: Icons.trending_up,
                ),
                const SizedBox(width: 8),
                _CompactSummaryItem(
                  label: 'Despesas',
                  value: expenses,
                  color: Theme.of(context).colorScheme.error,
                  icon: Icons.trending_down,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Item de resumo compacto
class _CompactSummaryItem extends StatelessWidget {
  const _CompactSummaryItem({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    this.isHighlighted = false,
    this.fullWidth = false,
  });

  final String label;
  final double value;
  final Color color;
  final IconData icon;
  final bool isHighlighted;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    if (fullWidth) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color, width: 2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
            Text(
              value.toStringAsFixed(2).replaceAll('.', ','),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
          ],
        ),
      );
    }

    // Compact version (side by side)
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: isHighlighted
            ? BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color, width: 1.5),
              )
            : BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Flexible(
              child: Text(
                value.toStringAsFixed(2).replaceAll('.', ','),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isHighlighted
                          ? color
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Últimas corridas compacto
class _CompactRecentRides extends StatelessWidget {
  const _CompactRecentRides({this.ride});

  final entity_ride.Ride? ride;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Última Corrida',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            TextButton(
              onPressed: () => context.push('/rides'),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Ver todas',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (ride != null)
          Card(
            elevation: 0.5,
            child: ListTile(
              dense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              leading: CircleAvatar(
                radius: 18,
                backgroundColor:
                    Theme.of(context).colorScheme.primaryContainer,
                child: Icon(
                  Icons.directions_car,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              title: Text(ride!.platform),
              subtitle: Text(
                '${ride!.formattedDate} • ${ride!.durationMinutes}min',
              ),
              trailing: Text(
                ride!.earnings.toStringAsFixed(2).replaceAll('.', ','),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
              onTap: () => context.push('/rides/${ride!.id}'),
            ),
          )
        else
          Card(
            elevation: 0.5,
            child: ListTile(
              dense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              leading: CircleAvatar(
                radius: 18,
                backgroundColor:
                    Theme.of(context).colorScheme.primaryContainer,
                child: Icon(
                  Icons.directions_car_outlined,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              title: Text(
                'Nenhuma corrida registrada',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              subtitle: Text(
                'Toque em + para adicionar',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          ),
      ],
    );
  }
}