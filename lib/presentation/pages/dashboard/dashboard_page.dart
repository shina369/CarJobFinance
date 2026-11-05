// Dashboard Page
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // TODO: Refresh data
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // TODO: Implement pull to refresh
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Resumo Financeiro
              _FinancialSummaryCard(),
              const SizedBox(height: 24),

              // Métricas Principais
              Text(
                'Métricas Principais',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              _MetricsGrid(),
              const SizedBox(height: 24),

              // Ações Rápidas
              Text(
                'Ações Rápidas',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              _QuickActions(),
              const SizedBox(height: 24),

              // Últimas Corridas
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Últimas Corridas',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  TextButton(
                    onPressed: () {
                      // Navigate to rides page
                    },
                    child: const Text('Ver todas'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _RecentRidesList(),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // TODO: Navigate to new ride form
        },
        icon: const Icon(Icons.add),
        label: const Text('Nova Corrida'),
      ),
    );
  }
}

/// Card de resumo financeiro
class _FinancialSummaryCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Resumo do Mês',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                _PeriodSelector(),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _SummaryItem(
                    label: 'Ganhos',
                    value: 'R\$ 0,00',
                    color: Theme.of(context).colorScheme.primary,
                    icon: Icons.trending_up,
                  ),
                ),
                Expanded(
                  child: _SummaryItem(
                    label: 'Despesas',
                    value: 'R\$ 0,00',
                    color: Theme.of(context).colorScheme.error,
                    icon: Icons.trending_down,
                  ),
                ),
                Expanded(
                  child: _SummaryItem(
                    label: 'Lucro Líquido',
                    value: 'R\$ 0,00',
                    color: Theme.of(context).colorScheme.tertiary,
                    icon: Icons.account_balance_wallet,
                    isHighlighted: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Seletor de período
class _PeriodSelector extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      initialValue: 'month',
      onSelected: (value) {
        // TODO: Handle period change
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'day', child: Text('Hoje')),
        const PopupMenuItem(value: 'week', child: Text('Esta Semana')),
        const PopupMenuItem(value: 'month', child: Text('Este Mês')),
        const PopupMenuItem(value: 'year', child: Text('Este Ano')),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Este Mês',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.keyboard_arrow_down,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
        ],
      ),
    );
  }
}

/// Item de resumo
class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    this.isHighlighted = false,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: isHighlighted
          ? BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color, width: 2),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isHighlighted
                      ? color
                      : Theme.of(context).colorScheme.onSurface,
                ),
          ),
        ],
      ),
    );
  }
}

/// Grid de métricas
class _MetricsGrid extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _MetricCard(
          title: 'Total de Corridas',
          value: '0',
          icon: Icons.directions_car,
          color: Theme.of(context).colorScheme.primary,
        ),
        _MetricCard(
          title: 'Quilometragem',
          value: '0 km',
          icon: Icons.route,
          color: Theme.of(context).colorScheme.secondary,
        ),
        _MetricCard(
          title: 'Horas Trabalhadas',
          value: '0h 0min',
          icon: Icons.access_time,
          color: Theme.of(context).colorScheme.tertiary,
        ),
        _MetricCard(
          title: 'Média por Corrida',
          value: 'R\$ 0,00',
          icon: Icons.analytics,
          color: Theme.of(context).colorScheme.primary,
        ),
      ],
    );
  }
}

/// Card de métrica
class _MetricCard extends StatelessWidget {
  const _MetricCard({
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Ações rápidas
class _QuickActions extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          child: _QuickActionButton(
            label: 'Nova Corrida',
            icon: Icons.add_circle_outline,
            color: Theme.of(context).colorScheme.primary,
            onTap: () {
              // TODO: Navigate to new ride
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickActionButton(
            label: 'Nova Despesa',
            icon: Icons.receipt_long,
            color: Theme.of(context).colorScheme.secondary,
            onTap: () {
              // TODO: Navigate to new expense
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickActionButton(
            label: 'Exportar',
            icon: Icons.download,
            color: Theme.of(context).colorScheme.tertiary,
            onTap: () {
              // TODO: Export data
            },
          ),
        ),
      ],
    );
  }
}

/// Botão de ação rápida
class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Lista de últimas corridas
class _RecentRidesList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // TODO: Connect to actual data
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ListTile(
              leading: Icon(
                Icons.directions_car,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: const Text('Nenhuma corrida registrada'),
              subtitle: const Text('Toque em "Nova Corrida" para começar'),
              trailing: Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              onTap: () {
                // TODO: Navigate to rides page
              },
            ),
          ],
        ),
      ),
    );
  }
}
