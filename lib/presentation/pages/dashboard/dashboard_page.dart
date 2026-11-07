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
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Resumo Financeiro - Compact horizontal layout
                  _CompactFinancialSummary(),
                  const SizedBox(height: 8),

                  // Métricas Principais - Compact grid
                  _CompactMetricsGrid(),
                  const SizedBox(height: 8),

                  // Últimas Corridas - Minimal
                  _CompactRecentRides(),
                ],
              ),
            ),
          );
        },
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

/// Resumo financeiro compacto - horizontal layout
class _CompactFinancialSummary extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                value: 'R\$ 0,00',
                color: Theme.of(context).colorScheme.primary,
                icon: Icons.trending_up,
              ),
              const SizedBox(width: 8),
              _CompactSummaryItem(
                label: 'Despesas',
                value: 'R\$ 0,00',
                color: Theme.of(context).colorScheme.error,
                icon: Icons.trending_down,
              ),
              const SizedBox(width: 8),
              _CompactSummaryItem(
                label: 'Lucro',
                value: 'R\$ 0,00',
                color: Theme.of(context).colorScheme.tertiary,
                icon: Icons.account_balance_wallet,
                isHighlighted: true,
              ),
            ],
          ),
        ],  // Close Column's children list
      ),
    ));
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
  final String value;
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
                value,
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
class _CompactMetricsGrid extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const minCardWidth = 140.0;
        final crossAxisCount = (constraints.maxWidth / minCardWidth).floor().clamp(2, 4);

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
              value: '0',
              icon: Icons.directions_car,
              color: Theme.of(context).colorScheme.primary,
            ),
            _CompactMetricCard(
              title: 'Km',
              value: '0',
              icon: Icons.route,
              color: Theme.of(context).colorScheme.secondary,
            ),
            _CompactMetricCard(
              title: 'Horas',
              value: '0h',
              icon: Icons.access_time,
              color: Theme.of(context).colorScheme.tertiary,
            ),
            _CompactMetricCard(
              title: 'Média/Corrida',
              value: 'R\$ 0,00',
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
class _CompactRecentRides extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              onPressed: () {
                // Navigate to rides page
              },
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
        Card(
          elevation: 0.5,
          child: ListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            leading: CircleAvatar(
              radius: 18,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(
                Icons.directions_car,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
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
            trailing: Icon(
              Icons.chevron_right,
              size: 18,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            onTap: () {
              // TODO: Navigate to rides page
            },
          ),
        ),
      ],
    );
  }
}
