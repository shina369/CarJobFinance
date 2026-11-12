// Expenses Page - Lista de despesas
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/finance/commission.dart';
import '../../../core/l10n/currency_provider.dart' as currency_pkg;
import '../../../core/l10n/language_provider.dart';
import '../../../core/l10n/languages.dart';
import '../../../core/l10n/platforms_provider.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/settings/locale_helper.dart';
import '../../../presentation/controllers/controllers.dart';
import '../../../domain/entities/expense.dart' as entity_expense;

class ExpensesPage extends ConsumerWidget {
  const ExpensesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesState = ref.watch(expensesControllerProvider);
    final lang = ref.watch(appLanguageProvider);

    // Platform commissions are virtual expenses, aggregated live from the
    // rides' commission snapshots (not editable expense records).
    final rides = ref.watch(ridesControllerProvider).valueOrNull ?? [];
    final commissionByPlatform = <String, double>{};
    for (final ride in rides) {
      if (ride.commissionAmount > 0) {
        commissionByPlatform[ride.platform] =
            (commissionByPlatform[ride.platform] ?? 0) + ride.commissionAmount;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(lang.tr('expenses.title')),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.sort),
            onPressed: () {},
          ),
        ],
      ),
      body: expensesState.when(
        data: (expenses) => _ExpensesList(
          expenses: expenses,
          commissionByPlatform: commissionByPlatform,
          lang: lang,
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
            child: Text(lang.tr('error.generic', args: {'error': '$error'}))),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/expenses/new'),
        icon: const Icon(Icons.add),
        label: Text(lang.tr('expenses.new')),
      ),
    );
  }
}

class _ExpensesList extends StatelessWidget {
  const _ExpensesList({
    required this.expenses,
    required this.commissionByPlatform,
    required this.lang,
  });

  final List<entity_expense.Expense> expenses;

  /// Total ride commission per platform, computed from the rides.
  final Map<String, double> commissionByPlatform;

  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    if (expenses.isEmpty && commissionByPlatform.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.receipt_long_outlined,
                size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(lang.tr('expenses.empty'),
                style: const TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {},
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (commissionByPlatform.isNotEmpty) ...[
            CommissionSummaryCard(
              commissionByPlatform: commissionByPlatform,
              lang: lang,
            ),
            const SizedBox(height: 24),
            if (expenses.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8, left: 4),
                child: Text(
                  lang.tr('expenses.others'),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
          ],
          ...expenses.map((e) => ExpenseCard(expense: e)),
        ],
      ),
    );
  }
}

/// Aggregated "platform commissions" section: per-platform totals computed
/// live from the rides' commission snapshots. Not editable records.
class CommissionSummaryCard extends ConsumerWidget {
  const CommissionSummaryCard({
    super.key,
    required this.commissionByPlatform,
    required this.lang,
  });

  final Map<String, double> commissionByPlatform;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(currency_pkg.appCurrencyProvider);
    String fmt(double v) => LocalizedCurrency.formatFor(v, currency);
    final platformsPref = ref.watch(platformsProvider);
    String labelOf(String platform) {
      final info = platformsPref.byName(platform);
      if (info == null || !info.hasCommission) return platform;
      final config = formatCommissionConfig(
          info.commissionType, info.commissionValue!, currency);
      return '$platform ($config)';
    }

    final platforms = commissionByPlatform.keys.toList()..sort();
    final total =
        commissionByPlatform.values.fold<double>(0, (sum, v) => sum + v);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.percent,
                    size: 18, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    lang.tr('expenses.commissionSection'),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              lang.tr('expenses.commissionAuto'),
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            ...platforms.map(
              (platform) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(labelOf(platform),
                        style: Theme.of(context).textTheme.bodyMedium),
                    Text(
                      fmt(commissionByPlatform[platform]!),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Color.lerp(
                              Theme.of(context).colorScheme.error,
                              Colors.white,
                              0.35,
                            )!,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  lang.tr('expenses.commissionTotal'),
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  fmt(total),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w700,
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

class ExpenseCard extends ConsumerWidget {
  const ExpenseCard({super.key, required this.expense});

  final entity_expense.Expense expense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(currency_pkg.appCurrencyProvider);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
          child: Icon(
            Icons.local_gas_station,
            color: Theme.of(context).colorScheme.error,
          ),
        ),
        title: Text(expense.category),
        subtitle: Text(expense.formattedDate),
        trailing: Text(
          LocalizedCurrency.formatFor(expense.amount, currency),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.error,
              ),
        ),
        onTap: () => context.push('/expenses/edit/${expense.id}'),
      ),
    );
  }
}
