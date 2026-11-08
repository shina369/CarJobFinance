// Expense Form Page - Criar/Editar despesa
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';

class ExpenseFormPage extends ConsumerStatefulWidget {
  const ExpenseFormPage({super.key, this.expenseId});

  final String? expenseId;

  bool get isEditing => expenseId != null;

  @override
  ConsumerState<ExpenseFormPage> createState() => _ExpenseFormPageState();
}

class _ExpenseFormPageState extends ConsumerState<ExpenseFormPage> {
  final _formKey = GlobalKey<FormState>();

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
      // TODO: Load existing expense data
    }
  }

  @override
  void dispose() {
    _dateController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
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

  void _save() {
    if (_formKey.currentState!.validate()) {
      // TODO: Save expense
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Editar Despesa' : 'Nova Despesa'),
        actions: [
          if (widget.isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                // TODO: Show delete confirmation
              },
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Data
            const _SectionTitle('Data'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _dateController,
              readOnly: true,
              onTap: _pickDate,
              decoration: const InputDecoration(
                labelText: 'Data',
                prefixIcon: Icon(Icons.calendar_today),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Data é obrigatória';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Categoria
            const _SectionTitle('Categoria'),
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
            const _SectionTitle('Valor'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Valor',
                prefixText: 'R\$ ',
                prefixIcon: Icon(Icons.attach_money),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Valor é obrigatório';
                }
                if (double.tryParse(value.replaceAll(',', '.')) == null) {
                  return 'Valor inválido';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Descrição
            const _SectionTitle('Descrição (Opcional)'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Descrição',
                prefixIcon: Icon(Icons.description_outlined),
                hintText: 'Ex: Abastecimento completo',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),

            // Recorrente
            const _SectionTitle('Opções'),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Despesa Recorrente'),
              subtitle: const Text('Repete mensalmente'),
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
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton(
                    onPressed: _save,
                    child: Text(widget.isEditing ? 'Salvar Alterações' : 'Salvar Despesa'),
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