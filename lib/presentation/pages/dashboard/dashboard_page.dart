// Dashboard Page - Responsive layout with scroll
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/settings/app_settings_notifier.dart';
import '../../../core/settings/locale_helper.dart';
import '../../../presentation/controllers/controllers.dart';
import '../../../domain/entities/ride.dart' as entity_ride;
import '../../../domain/entities/expense.dart' as entity_expense;

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ridesState = ref.watch(ridesControllerProvider);
    final expensesState = ref.watch(expensesControllerProvider);
    final goalState = ref.watch(monthlyGoalControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(monthlyGoalControllerProvider),
          ),
        ],
      ),
      body: ridesState.when(
        data: (rides) => expensesState.when(
          data: (expenses) => goalState.when(
            data: (goal) => _StaticDashboardBody(
              rides: rides,
              expenses: expenses,
              monthlyGoal: goal,
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const _StaticDashboardBody(
              rides: [],
              expenses: [],
              monthlyGoal: 5000.0,
            ),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Erro: $error')),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Erro: $error')),
      ),
    );
  }
}

class _StaticDashboardBody extends ConsumerStatefulWidget {
  const _StaticDashboardBody({
    required this.rides,
    required this.expenses,
    required this.monthlyGoal,
  });

  final List<entity_ride.Ride> rides;
  final List<entity_expense.Expense> expenses;
  final double monthlyGoal;

  @override
  ConsumerState<_StaticDashboardBody> createState() =>
      _StaticDashboardBodyState();
}

class _StaticDashboardBodyState extends ConsumerState<_StaticDashboardBody> {
  double _localGoal = 5000.0;

  @override
  void initState() {
    super.initState();
    _localGoal = widget.monthlyGoal > 0 ? widget.monthlyGoal : 5000.0;
  }

  @override
  void didUpdateWidget(covariant _StaticDashboardBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.monthlyGoal != widget.monthlyGoal && widget.monthlyGoal > 0) {
      _localGoal = widget.monthlyGoal;
    }
  }

  void _showSetGoalDialog() {
    final settings = ref.read(appSettingsProvider);
    final symbol = settings.currencySymbol;
    final controller = TextEditingController(
      text: _localGoal.toStringAsFixed(2).replaceAll('.', ','),
    );
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Definir Objetivo do Mês'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Valor do objetivo ($symbol)',
            prefixText: '$symbol ',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final value = double.tryParse(
                controller.text.replaceAll(',', '.'),
              );
              if (value != null && value >= 0) {
                ref.read(monthlyGoalControllerProvider.notifier).setGoal(value);
                setState(() => _localGoal = value);
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
    final cs = Theme.of(context).colorScheme;
    final today = _computeTodayData();
    final month = _computeMonthData();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Today summary card
          _todayCard(context, today),
          const SizedBox(height: 12),
          // Action buttons above month panel
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => context.push('/rides/new'),
                  icon: const Icon(Icons.directions_car, size: 18),
                  label: const Text('Nova Corrida'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => context.push('/expenses/new'),
                  icon: const Icon(Icons.receipt_long, size: 18),
                  label: const Text('Nova Despesa'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Month summary card WITHOUT embedded action buttons
          _MonthPanel(
            earnings: month.earnings,
            expenses: month.expenses,
            netProfit: month.netProfit,
            label: month.label,
            goal: _localGoal,
            onSetGoal: _showSetGoalDialog,
          ),
          // Recent rides strip — only when there are rides
          if (widget.rides.isNotEmpty) ...[
            const SizedBox(height: 12),
            _recentRidesStrip(
                context, rides: widget.rides.take(2).toList()),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  _TodayData _computeTodayData() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart
        .add(const Duration(days: 1))
        .subtract(const Duration(seconds: 1));

    final todayRides = widget.rides
        .where((r) =>
            r.date.isAfter(todayStart.subtract(const Duration(seconds: 1))) &&
            r.date.isBefore(todayEnd.add(const Duration(seconds: 1))))
        .toList();
    final todayExpenses = widget.expenses
        .where((e) =>
            e.date.isAfter(todayStart.subtract(const Duration(seconds: 1))) &&
            e.date.isBefore(todayEnd.add(const Duration(seconds: 1))))
        .toList();

    return _TodayData(
      earnings: todayRides.fold<double>(0, (s, r) => s + r.earnings),
      expenses: todayExpenses.fold<double>(0, (s, e) => s + e.amount),
      rides: todayRides.length,
      km: todayRides.fold<double>(0, (s, r) => s + r.distanceKm),
      label:
          '${_weekdayName(now.weekday)}, ${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year.toString().substring(2)}',
    );
  }

  _MonthData _computeMonthData() {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 1)
        .subtract(const Duration(seconds: 1));
    final monthRides = widget.rides
        .where((r) =>
            r.date.isAfter(monthStart.subtract(const Duration(seconds: 1))) &&
            r.date.isBefore(monthEnd.add(const Duration(seconds: 1))))
        .toList();
    final monthExpenses = widget.expenses
        .where((e) =>
            e.date.isAfter(monthStart.subtract(const Duration(seconds: 1))) &&
            e.date.isBefore(monthEnd.add(const Duration(seconds: 1))))
        .toList();

    return _MonthData(
      earnings: monthRides.fold<double>(0, (s, r) => s + r.earnings),
      expenses: monthExpenses.fold<double>(0, (s, e) => s + e.amount),
      label: '${_monthName(now.month)} de ${now.year}',
    );
  }

  String _monthName(int m) => const [
        'Janeiro',
        'Fevereiro',
        'Março',
        'Abril',
        'Maio',
        'Junho',
        'Julho',
        'Agosto',
        'Setembro',
        'Outubro',
        'Novembro',
        'Dezembro',
      ][m - 1];

  String _weekdayName(int w) => const [
        'Segunda-feira',
        'Terça-feira',
        'Quarta-feira',
        'Quinta-feira',
        'Sexta-feira',
        'Sábado',
        'Domingo',
      ][w - 1];
}

class _TodayData {
  const _TodayData({
    required this.earnings,
    required this.expenses,
    required this.rides,
    required this.km,
    required this.label,
  });
  final double earnings;
  final double expenses;
  final int rides;
  final double km;
  final String label;
}

class _MonthData {
  const _MonthData({
    required this.earnings,
    required this.expenses,
    required this.label,
  });
  final double earnings;
  final double expenses;
  final String label;

  double get netProfit => earnings - expenses;
}

// ── TODAY CARD ────────────────────────────────────────────────

Widget _todayCard(BuildContext context, _TodayData t) {
  final ts = Theme.of(context).textTheme;
  final profit = t.earnings - t.expenses;
  final isPositive = profit >= 0;

  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isPositive
            ? [
                const Color(0xFF00C853).withValues(alpha: 0.92),
                const Color(0xFF00E676).withValues(alpha: 0.85),
              ]
            : [
                const Color(0xFFD32F2F).withValues(alpha: 0.92),
                const Color(0xFFEF5350).withValues(alpha: 0.85),
              ],
      ),
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color:
              (isPositive ? const Color(0xFF00C853) : const Color(0xFFD32F2F))
                  .withValues(alpha: 0.35),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header: date + icon
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isPositive
                    ? Icons.account_balance_wallet
                    : Icons.warning_amber_rounded,
                size: 20,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Lucro hoje',
                    style: ts.labelMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.8),
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    t.label,
                    style: ts.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.65),
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
            // Small badge with ride count
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${t.rides} corrida${t.rides != 1 ? 's' : ''}',
                style: ts.labelSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        // Big profit number
        Consumer(
          builder: (context, ref, _) {
            final settings = ref.watch(appSettingsProvider);
            return Row(
              children: [
                Text(
                  isPositive ? '+' : '',
                  style: ts.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Flexible(
                  child: Text(
                    LocalizedCurrency.formatWithSettings(profit, settings),
                    style: ts.displaySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        // Three metric pills in a row
        LayoutBuilder(
          builder: (ctx, constraints) {
            final pillWidth = (constraints.maxWidth - 16) / 3;
            return Row(
              children: [
                _MetricPill(
                  icon: Icons.trending_up,
                  label: 'Ganhos',
                  value: t.earnings,
                  pillWidth: pillWidth,
                ),
                const SizedBox(width: 8),
                _MetricPill(
                  icon: Icons.money_off,
                  label: 'Despesas',
                  value: t.expenses,
                  pillWidth: pillWidth,
                ),
                const SizedBox(width: 8),
                _MetricPill(
                  icon: Icons.speed,
                  label: 'Km rodados',
                  value: t.km,
                  pillWidth: pillWidth,
                ),
              ],
            );
          },
        ),
      ],
    ),
  );
}

// ── METRIC PILL ───────────────────────────────────────────────

class _MetricPill extends ConsumerWidget {
  const _MetricPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.pillWidth,
  });

  final IconData icon;
  final String label;
  final double value;
  final double pillWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final ts = Theme.of(context).textTheme;
    final isExpense = label == 'Despesas';
    return SizedBox(
      width: pillWidth,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: isExpense
              ? Colors.black.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon,
                    size: 13, color: Colors.white.withValues(alpha: 0.75)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    label,
                    style: ts.labelSmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.7),
                      letterSpacing: 0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              LocalizedCurrency.formatWithSettings(value, settings),
              style: ts.titleSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ── MONTH PANEL (card + embedded buttons) ─────────────────────

class _MonthPanel extends StatelessWidget {
  const _MonthPanel({
    required this.earnings,
    required this.expenses,
    required this.netProfit,
    required this.label,
    required this.goal,
    required this.onSetGoal,
  });

  final double earnings;
  final double expenses;
  final double netProfit;
  final String label;
  final double goal;
  final VoidCallback onSetGoal;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;
    final progress =
        goal > 0 ? (netProfit / goal * 100).clamp(0.0, 100.0) : 0.0;
    final progressColor = progress >= 100 ? Colors.green.shade700 : cs.primary;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dark header band
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            color: cs.primary,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Resumo do Mês',
                  style: ts.titleMedium?.copyWith(
                    color: cs.onPrimary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  label,
                  style: ts.labelSmall?.copyWith(
                    color: cs.onPrimary.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Content area
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profit line
                _StatRow(
                  label: 'Lucro no mês',
                  value: netProfit,
                  color: netProfit >= 0
                      ? Colors.green.shade700
                      : Colors.red.shade700,
                  icon: netProfit >= 0
                      ? Icons.trending_up
                      : Icons.trending_down,
                ),
                const SizedBox(height: 10),
                // Goal + progress
                _StatRow(
                  label: 'Objetivo',
                  value: goal,
                  color: cs.primary,
                  icon: Icons.flag,
                ),
                const SizedBox(height: 8),
                _ProgressBar(value: progress / 100, color: progressColor),
                const SizedBox(height: 10),
                // Edit goal link
                Center(
                  child: OutlinedButton.icon(
                    onPressed: onSetGoal,
                    icon: Icon(Icons.edit_outlined,
                        size: 16, color: cs.primary),
                    label: const Text('Alterar objetivo'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: cs.primary,
                      side: BorderSide(color: cs.primary, width: 1.5),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      textStyle: ts.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends ConsumerWidget {
  const _StatRow({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final double value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(label,
                style: ts.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
          ],
        ),
        Text(
          LocalizedCurrency.formatWithSettings(value, settings),
          style: ts.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ── RECENT RIDES COMPACT STRIP ─────────────────────────────────

Widget _recentRidesStrip(
  BuildContext context, {
  required List<entity_ride.Ride> rides,
}) {
  final cs = Theme.of(context).colorScheme;
  final ts = Theme.of(context).textTheme;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Últimas corridas', style: ts.titleSmall),
          TextButton(
            onPressed: () => context.push('/rides'),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text('Ver todas',
                style: ts.labelSmall?.copyWith(color: cs.primary)),
          ),
        ],
      ),
      const SizedBox(height: 4),
      ...rides.map(
        (ride) => Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            leading: CircleAvatar(
              radius: 16,
              backgroundColor: cs.primaryContainer,
              child: Icon(Icons.directions_car,
                  size: 16, color: cs.primary),
            ),
            title: Text(ride.platform, style: ts.bodySmall),
            subtitle: Text(
              '${ride.formattedDate} · ${ride.durationMinutes}min',
              style: ts.labelSmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            trailing: Consumer(
              builder: (context, ref, _) {
                final settings = ref.watch(appSettingsProvider);
                return Text(
                  LocalizedCurrency.formatWithSettings(ride.earnings, settings),
                  style: ts.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: cs.primary,
                  ),
                );
              },
            ),
            onTap: () => context.push('/rides/${ride.id}'),
          ),
        ),
      ),
    ],
  );
}

// ── PROGRESS BAR ───────────────────────────────────────────────

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        return SizedBox(
          height: 28,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Positioned.fill(
                child: Align(
                  alignment: Alignment.center,
                  child: CustomPaint(
                    painter: _BarPainter(value: value, color: color),
                    size: Size(w, 10),
                  ),
                ),
              ),
              if (value > 0 && w > 0)
                Positioned(
                  left: w * value.clamp(0.0, 1.0),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: color,
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
                    child: const Icon(
                      Icons.arrow_forward_ios,
                      size: 10,
                      color: Colors.white,
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

class _BarPainter extends CustomPainter {
  _BarPainter({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0) return;
    final r = size.height / 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(r),
      ),
      Paint()
        ..color = color.withValues(alpha: 0.15)
        ..style = PaintingStyle.fill,
    );
    final pw = size.width * value.clamp(0.0, 1.0);
    if (pw > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, pw, size.height),
          Radius.circular(r),
        ),
        Paint()
          ..color = color
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BarPainter old) =>
      old.value != value || old.color != color;
}
