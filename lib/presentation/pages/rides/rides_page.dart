// Rides Page - Lista de corridas
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class RidesPage extends ConsumerWidget {
  const RidesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Corridas'),
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
      body: _RidesList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/rides/new'),
        icon: const Icon(Icons.add),
        label: const Text('Nova Corrida'),
      ),
    );
  }
}

class _RidesList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // TODO: Connect to rides provider
    return RefreshIndicator(
      onRefresh: () async {
        // TODO: Refresh rides
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 0, // TODO: rides.length
        itemBuilder: (context, index) {
          // TODO: Return RideCard(rides[index])
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

// Placeholder para RideCard
class RideCard extends StatelessWidget {
  const RideCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(
            Icons.directions_car,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        title: const Text('Corrida Exemplo'),
        subtitle: const Text('Uber • R\$ 25,00 • 10 km'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          // TODO: Navigate to detail
        },
      ),
    );
  }
}
