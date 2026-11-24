import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/currency_provider.dart' as currency_pkg;
import '../../../core/l10n/language_provider.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/settings/locale_helper.dart';
import '../../../domain/entities/expense.dart' as entity_expense;
import '../../controllers/controllers.dart';
import '../../widgets/detail_section.dart';
import '../../widgets/expense_category_icon.dart';

class ExpenseDetailPage extends ConsumerWidget {
  const ExpenseDetailPage({super.key, required this.expenseId});

  final String expenseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appLanguageProvider);
    final expensesState = ref.watch(expensesControllerProvider);
    final expense = _findExpense(expensesState.valueOrNull, expenseId);

    return Scaffold(
      appBar: AppBar(
        title: Text(lang.tr('expenses.details')),
        actions: [
          if (expense != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push('/expenses/edit/${expense.id}'),
            ),
        ],
      ),
      body: expense != null
          ? _ExpenseDetails(expense: expense)
          : expensesState.hasError
              ? Center(
                  child: Text(lang.tr('error.generic',
                      args: {'error': '${expensesState.error}'})),
                )
              : expensesState.hasValue
                  ? Center(child: Text(lang.tr('expenses.empty')))
                  : const Center(child: CircularProgressIndicator()),
    );
  }

  static entity_expense.Expense? _findExpense(
      List<entity_expense.Expense>? expenses, String id) {
    for (final expense in expenses ?? const <entity_expense.Expense>[]) {
      if (expense.id == id) return expense;
    }
    return null;
  }
}

class _ExpenseDetails extends ConsumerWidget {
  const _ExpenseDetails({required this.expense});

  final entity_expense.Expense expense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appLanguageProvider);
    final currency = ref.watch(currency_pkg.appCurrencyProvider);
    final theme = Theme.of(context);
    final error = theme.colorScheme.error;
    String money(double value) => LocalizedCurrency.formatFor(value, currency);

    final description = expense.description;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: theme.colorScheme.errorContainer,
                      child: Icon(expenseCategoryIcon(expense.category),
                          color: error),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(expense.category,
                          style: theme.textTheme.titleLarge),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  money(expense.amount),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(lang.tr('expenses.fieldValor'),
                    style: theme.textTheme.bodyMedium),
                const SizedBox(height: 16),
                Text(
                  expense.formattedDate,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        DetailSectionCard(
          title: lang.tr('expenses.sectionInfo'),
          children: [
            DetailRow(
              label: lang.tr('expenses.fieldCategory'),
              value: expense.category,
            ),
            DetailRow(
              label: lang.tr('expenses.fieldDate'),
              value: expense.formattedDate,
            ),
            DetailRow(
              label: lang.tr('expenses.fieldRecurring'),
              value: lang.tr(
                  expense.isRecurring ? 'dash.confirmYes' : 'dash.confirmNo'),
            ),
            DetailRow(
              label: lang.tr('expenses.fieldDescription'),
              value: description != null && description.isNotEmpty
                  ? description
                  : '—',
            ),
          ],
        ),
      ],
    );
  }
}
