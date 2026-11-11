// Expense Form Page - Criar/Editar despesa
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/l10n/currency_provider.dart' as currency_pkg;
import '../../../core/l10n/language_provider.dart';
import '../../../core/l10n/strings.dart';
import '../../../presentation/controllers/controllers.dart';
import '../../../domain/entities/expense.dart' as entity_expense;

class ExpenseFormPage extends ConsumerStatefulWidget {
  const ExpenseFormPage({super.key, this.expenseId});

  final String? expenseId;

  bool get isEditing => expenseId != null;

  @override
  ConsumerState<ExpenseFormPage> createState() => _ExpenseFormPageState();
}

class _ExpenseFormPageState extends ConsumerState<ExpenseFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();

  // Controllers
  final _dateController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  // State
  String _selectedCategory = AppConstants.expenseCategories.first;
  DateTime _selectedDate = DateTime.now();
  bool _isRecurring = false;

  @override
  void initState() {
    super.initState();
    _dateController.text = _formatDate(_selectedDate);
    if (widget.isEditing) {
      _loadExistingExpense();
    }
  }

  @override
  void dispose() {
    _dateController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingExpense() async {
    ref.listen<AsyncValue<List<entity_expense.Expense>>>(
      expensesControllerProvider,
      (_, next) {
        next.whenData((expenses) {
          final expense = expenses.firstWhere(
            (e) => e.id == widget.expenseId,
            orElse: () => throw Exception('Expense not found'),
          );
          setState(() {
            _selectedDate = expense.date;
            _dateController.text = _formatDate(expense.date);
            _amountController.text = expense.amount.toString();
            _descriptionController.text = expense.description ?? '';
            _selectedCategory = expense.category;
            _isRecurring = expense.isRecurring;
          });
        });
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = _formatDate(picked);
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final amount =
        double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0.0;

    final expense = entity_expense.Expense(
      id: widget.expenseId ?? _uuid.v4(),
      date: _selectedDate,
      category: _selectedCategory,
      amount: amount,
      description: _descriptionController.text.isEmpty
          ? null
          : _descriptionController.text,
      createdAt: widget.expenseId != null ? null : DateTime.now(),
    );

    final controller = ref.read(expensesControllerProvider.notifier);
    if (widget.isEditing) {
      await controller.edit(expense);
    } else {
      await controller.add(expense);
    }

    if (mounted) context.pop();
  }

  Future<void> _delete() async {
    if (widget.expenseId == null) return;
    final lang = ref.read(appLanguageProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(lang.tr('expenses.deleteTitle')),
        content: Text(lang.tr('expenses.deleteMsg')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(lang.tr('dash.cancel'))),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(lang.tr('rides.delete')),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref
          .read(expensesControllerProvider.notifier)
          .remove(widget.expenseId!);
      if (mounted) context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appLanguageProvider);
    final currencySymbol = ref.watch(currency_pkg.appCurrencyProvider).symbol;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing
            ? lang.tr('expenses.edit')
            : lang.tr('expenses.new')),
        actions: [
          if (widget.isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Data
            _SectionTitle(lang.tr('expenses.sectionData')),
            const SizedBox(height: 8),
            TextFormField(
              controller: _dateController,
              readOnly: true,
              onTap: _pickDate,
              decoration: InputDecoration(
                labelText: lang.tr('expenses.fieldData'),
                prefixIcon: const Icon(Icons.calendar_today),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return lang.tr('expenses.validateRequired',
                      args: {'field': lang.tr('expenses.fieldData')});
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Categoria
            _SectionTitle(lang.tr('expenses.sectionCategory')),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: AppConstants.expenseCategories.map((category) {
                return DropdownMenuItem(value: category, child: Text(category));
              }).toList(),
              onChanged: (value) {
                if (value != null) setState(() => _selectedCategory = value);
              },
            ),
            const SizedBox(height: 24),

            // Valor
            _SectionTitle(lang.tr('expenses.sectionValue')),
            const SizedBox(height: 8),
            TextFormField(
              controller: _amountController,
              decoration: InputDecoration(
                labelText: lang.tr('expenses.fieldValor'),
                prefixText: '$currencySymbol ',
                prefixIcon: const Icon(Icons.attach_money),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return lang.tr('expenses.validateRequired',
                      args: {'field': lang.tr('expenses.fieldValor')});
                }
                if (double.tryParse(value.replaceAll(',', '.')) == null) {
                  return lang.tr('expenses.validateInvalid');
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Descrição
            _SectionTitle(lang.tr('expenses.sectionDesc')),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: lang.tr('expenses.fieldDesc'),
                prefixIcon: const Icon(Icons.description_outlined),
                hintText: lang.tr('expenses.hintDesc'),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),

            // Recorrente
            _SectionTitle(lang.tr('expenses.sectionOptions')),
            const SizedBox(height: 8),
            SwitchListTile(
              title: Text(lang.tr('expenses.recurring')),
              subtitle: Text(lang.tr('expenses.recurringMsg')),
              value: _isRecurring,
              onChanged: (value) => setState(() => _isRecurring = value),
              secondary: Icon(
                Icons.repeat,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 32),

            // Botões
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context.pop(),
                    child: Text(lang.tr('dash.cancel')),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton(
                    onPressed: _save,
                    child: Text(widget.isEditing
                        ? lang.tr('expenses.saveChanges')
                        : lang.tr('expenses.saveExpense')),
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
    );
  }
}
