// Dashboard Page
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter_svg/flutter_svg.dart';

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

class _DashboardContent extends ConsumerStatefulWidget {
  const _DashboardContent({required this.rides, required this.expenses});

  final List<entity_ride.Ride> rides;
  final List<entity_expense.Expense> expenses;

  @override
  ConsumerState<_DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends ConsumerState<_DashboardContent> {
  double _monthlyGoal = 5000.0;

  void _showSetGoalDialog() {
    final controller = TextEditingController(text: _monthlyGoal.toStringAsFixed(2).replaceAll('.', ','));
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Definir Objetivo do Mês'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Valor do objetivo (R\$)',
            prefixText: 'R\$ ',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final value = double.tryParse(controller.text.replaceAll(',', '.'));
              if (value != null && value >= 0) {
                setState(() => _monthlyGoal = value);
              }
              Navigator.pop(dialogContext);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1)).subtract(const Duration(seconds: 1));

    final todayRides = widget.rides
        .where((r) => r.date.isAfter(todayStart.subtract(const Duration(seconds: 1))) &&
            r.date.isBefore(todayEnd.add(const Duration(seconds: 1))))
        .toList();
    final todayExpenses = widget.expenses
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
    final monthRides = widget.rides
        .where((r) => r.date.isAfter(monthStart.subtract(const Duration(seconds: 1))) &&
            r.date.isBefore(monthEnd.add(const Duration(seconds: 1))))
        .toList();
    final monthExpenses = widget.expenses
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
          // Resumo do Mês
          _MonthSummaryCard(
            earnings: monthEarnings,
            expenses: monthExpensesTotal,
            dateLabel: monthLabel,
            monthlyGoal: _monthlyGoal,
            onSetGoal: _showSetGoalDialog,
          ),
          const SizedBox(height: 8),
          if (widget.rides.isNotEmpty) _CompactRecentRides(rides: widget.rides.take(2).toList()),
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

String _formatCurrency(double value) {
  return NumberFormat('#,##0.00', 'pt_BR').format(value);
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
                  displayValue: NumberFormat('#,##0', 'pt_BR').format(rideCount),
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
class _MonthSummaryCard extends ConsumerWidget {
  const _MonthSummaryCard({
    required this.earnings,
    required this.expenses,
    required this.dateLabel,
    required this.monthlyGoal,
    required this.onSetGoal,
  });

  final double earnings;
  final double expenses;
  final String dateLabel;
  final double monthlyGoal;
  final VoidCallback onSetGoal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final netProfit = earnings - expenses;
    final goalProgress = monthlyGoal > 0 ? (netProfit / monthlyGoal * 100).clamp(0, 100) : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
                  'Resumo do Mês',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
            const SizedBox(height: 12),
            // Objetivo do mês em destaque (azul)
            _CompactSummaryItem(
              label: 'Objetivo do mês',
              value: monthlyGoal,
              color: Colors.lightBlue[50]!,
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
                              color: Colors.lightBlue[50]!,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  _ProgressBar(value: goalProgress / 100),
                  const SizedBox(height: 12),
                  // Botão Novo Objetivo abaixo do progresso
                  Center(
                    child: OutlinedButton.icon(
                      onPressed: onSetGoal,
                      icon: const Icon(Icons.flag_outlined, size: 18),
                      label: const Text('Novo Objetivo'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.lightBlue[50]!,
                        side: const BorderSide(color: Colors.blue),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
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
    this.displayValue,
  });

  final String label;
  final double value;
  final Color color;
  final IconData icon;
  final bool isHighlighted;
  final bool fullWidth;
  final String? displayValue;

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
              displayValue ?? _formatCurrency(value),
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
                displayValue ?? _formatCurrency(value),
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
  const _CompactRecentRides({this.rides});

  final List<entity_ride.Ride>? rides;

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
              'Últimas Corridas',
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
        ...?rides?.map((ride) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Card(
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
                  title: Text(ride.platform),
                  subtitle: Text(
                    '${ride.formattedDate} • ${ride.durationMinutes}min',
                  ),
                  trailing: Text(
                    _formatCurrency(ride.earnings),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                  onTap: () => context.push('/rides/${ride.id}'),
                ),
              ),
            )),
      ],
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final barWidth = constraints.maxWidth;
        return SizedBox(
          height: 36,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Positioned.fill(
                child: Align(
                  alignment: Alignment.center,
                  child: CustomPaint(
                    painter: _BarProgressPainter(value: value),
                    size: Size(barWidth, 10),
                  ),
                ),
              ),
              if (value > 0 && barWidth > 0)
                Positioned(
                  left: barWidth * value.clamp(0.0, 1.0),
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: SvgPicture.asset(
                      'assets/icons/car.svg',
                      width: 16,
                      height: 16,
                      colorFilter: const ColorFilter.mode(
                        Colors.white,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _BarProgressPainter extends CustomPainter {
  _BarProgressPainter({required this.value});

  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0) return;

    final trackPaint = Paint()
      ..color = (Colors.lightBlue[50]!).withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;

    final progressPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;

    final radius = size.height / 2;
    final barHeight = size.height;

    // Track background
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, barHeight),
        Radius.circular(radius),
      ),
      trackPaint,
    );

    // Progress fill
    final progressWidth = size.width * value.clamp(0.0, 1.0);
    if (progressWidth > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, progressWidth, barHeight),
          Radius.circular(radius),
        ),
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BarProgressPainter oldDelegate) =>
      oldDelegate.value != value;
}