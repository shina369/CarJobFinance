// Expenses Page - Lista de despesas
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ExpensesPage extends ConsumerWidget {
  const ExpensesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Despesas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              // TODO: Show filter dialog
            },
          ),
          IconButton(
            icon: const Icon(Icons.sort),
            onPressed: () {
              // TODO: Show sort options
            },
          ),
        ],
      ),
      body: _ExpensesList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/expenses/new'),
        icon: const Icon(Icons.add),
        label: const Text('Nova Despesa'),
      ),
    );
  }
}

class _ExpensesList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // TODO: Connect to expenses provider
    return RefreshIndicator(
      onRefresh: () async {
        // TODO: Refresh expenses
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 0, // TODO: expenses.length
        itemBuilder: (context, index) {
          // TODO: Return ExpenseCard(expenses[index])
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

// Placeholder para ExpenseCard
class ExpenseCard extends StatelessWidget {
  const ExpenseCard({super.key});

  @override
  Widget build(BuildContext context) {
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
        title: const Text('Despesa Exemplo'),
        subtitle: const Text('Combustível • R\$ 150,00'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          // TODO: Navigate to detail/edit
        },
      ),
    );
  }
}
