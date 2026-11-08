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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/rides/new'),
        icon: const Icon(Icons.add),
        label: const Text('Nova Corrida'),
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
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    final monthRides = rides
        .where((r) => r.date.isAfter(monthStart.subtract(const Duration(days: 1))) &&
            r.date.isBefore(monthEnd.add(const Duration(days: 1))))
        .toList();
    final monthExpenses = expenses
        .where((e) => e.date.isAfter(monthStart.subtract(const Duration(days: 1))) &&
            e.date.isBefore(monthEnd.add(const Duration(days: 1))))
        .toList();

    final totalEarnings =
        monthRides.fold<double>(0, (sum, r) => sum + r.earnings);
    final totalExpenses =
        monthExpenses.fold<double>(0, (sum, e) => sum + e.amount);
    final netProfit = totalEarnings - totalExpenses;
    final totalKm =
        monthRides.fold<double>(0, (sum, r) => sum + r.distanceKm);
    final totalMinutes =
        monthRides.fold<int>(0, (sum, r) => sum + r.durationMinutes);
    final avgPerRide = monthRides.isNotEmpty
        ? totalEarnings / monthRides.length
        : 0.0;

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
          ),
          const SizedBox(height: 8),
          _CompactMetricsGrid(
            rideCount: monthRides.length,
            totalKm: totalKm,
            totalHours: (totalMinutes / 60).roundToDouble(),
            avgPerRide: avgPerRide,
          ),
          const SizedBox(height: 8),
          if (rides.isNotEmpty) _CompactRecentRides(ride: rides.last),
        ],
      ),
    );
  }
}

/// Resumo financeiro compacto - horizontal layout
class _CompactFinancialSummary extends StatelessWidget {
  const _CompactFinancialSummary({
    required this.earnings,
    required this.expenses,
    required this.netProfit,
  });

  final double earnings;
  final double expenses;
  final double netProfit;

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
                  'Resumo do Mês',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Text(
                  'Este Mês',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
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
                const SizedBox(width: 8),
                _CompactSummaryItem(
                  label: 'Lucro',
                  value: netProfit,
                  color: Theme.of(context).colorScheme.tertiary,
                  icon: Icons.account_balance_wallet,
                  isHighlighted: true,
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
  });

  final String label;
  final double value;
  final Color color;
  final IconData icon;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
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

/// Grid de métricas compacto
class _CompactMetricsGrid extends StatelessWidget {
  const _CompactMetricsGrid({
    required this.rideCount,
    required this.totalKm,
    required this.totalHours,
    required this.avgPerRide,
  });

  final int rideCount;
  final double totalKm;
  final double totalHours;
  final double avgPerRide;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const minCardWidth = 140.0;
        final crossAxisCount =
            (constraints.maxWidth / minCardWidth).floor().clamp(2, 4);

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 6,
          mainAxisSpacing: 6,
          childAspectRatio: 2.2,
          children: [
            _CompactMetricCard(
              title: 'Corridas',
              value: rideCount.toString(),
              icon: Icons.directions_car,
              color: Theme.of(context).colorScheme.primary,
            ),
            _CompactMetricCard(
              title: 'Km',
              value: totalKm.toStringAsFixed(1),
              icon: Icons.route,
              color: Theme.of(context).colorScheme.secondary,
            ),
            _CompactMetricCard(
              title: 'Horas',
              value: totalHours.toStringAsFixed(1),
              icon: Icons.access_time,
              color: Theme.of(context).colorScheme.tertiary,
            ),
            _CompactMetricCard(
              title: 'Média/Corrida',
              value: avgPerRide.toStringAsFixed(2),
              icon: Icons.analytics,
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        );
      },
    );
  }
}

/// Card de métrica compacto
class _CompactMetricCard extends StatelessWidget {
  const _CompactMetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0.5,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 1),
            Flexible(
              child: Text(
                value,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Flexible(
              child: Text(
                title,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
                maxLines: 1,
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
