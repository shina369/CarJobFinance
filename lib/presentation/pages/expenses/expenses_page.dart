// Expenses Page - Lista de despesas
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/currency_provider.dart' as currency_pkg;
import '../../../core/l10n/language_provider.dart';
import '../../../core/l10n/languages.dart';
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
        data: (expenses) => _ExpensesList(expenses: expenses, lang: lang),
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
  const _ExpensesList({required this.expenses, required this.lang});

  final List<entity_expense.Expense> expenses;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    if (expenses.isEmpty) {
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
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: expenses.length,
        itemBuilder: (context, index) {
          return ExpenseCard(expense: expenses[index]);
        },
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
