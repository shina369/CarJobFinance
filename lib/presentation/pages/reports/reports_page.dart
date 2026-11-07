// Reports Page - Relatórios e exportação
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ReportsPage extends ConsumerWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Relatórios'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Período do Relatório
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Período do Relatório',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  _PeriodChips(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Resumo do Período
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Resumo Financeiro',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  _SummaryRow(
                      label: 'Total de Ganhos',
                      value: 'R\$ 0,00',
                      isPositive: true),
                  _SummaryRow(
                      label: 'Total de Despesas',
                      value: 'R\$ 0,00',
                      isPositive: false),
                  const Divider(),
                  _SummaryRow(
                    label: 'Lucro Líquido',
                    value: 'R\$ 0,00',
                    isPositive: true,
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
                  _MetricRow(label: 'Corridas Realizadas', value: '0'),
                  _MetricRow(label: 'Quilometragem Total', value: '0 km'),
                  _MetricRow(label: 'Horas Trabalhadas', value: '0h'),
                  _MetricRow(label: 'Média por km', value: 'R\$ 0,00/km'),
                  _MetricRow(label: 'Média por hora', value: 'R\$ 0,00/h'),
                  _MetricRow(label: 'Média por corrida', value: 'R\$ 0,00'),
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
        ],
      ),
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

class _PeriodChips extends ConsumerStatefulWidget {
  @override
  ConsumerState<_PeriodChips> createState() => _PeriodChipsState();
}

class _PeriodChipsState extends ConsumerState<_PeriodChips> {
  String _selectedPeriod = 'month';

  final periods = [
    ('day', 'Hoje'),
    ('week', 'Esta Semana'),
    ('month', 'Este Mês'),
    ('year', 'Este Ano'),
    ('custom', 'Personalizado'),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: periods.map((period) {
        final isSelected = _selectedPeriod == period.$1;
        return FilterChip(
          label: Text(period.$2),
          selected: isSelected,
          onSelected: (selected) {
            setState(() => _selectedPeriod = period.$1);
          },
          selectedColor: Theme.of(context).colorScheme.primaryContainer,
          checkmarkColor: Theme.of(context).colorScheme.primary,
        );
      }).toList(),
    );
  }
}
