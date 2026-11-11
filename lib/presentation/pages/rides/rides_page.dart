// Rides Page - Lista de corridas
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/language_provider.dart';
import '../../../core/l10n/languages.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/settings/app_settings_notifier.dart';
import '../../../core/settings/locale_helper.dart';
import '../../../presentation/controllers/controllers.dart';
import '../../../domain/entities/ride.dart' as entity_ride;

class RidesPage extends ConsumerWidget {
  const RidesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ridesState = ref.watch(ridesControllerProvider);
    final lang = ref.watch(appLanguageProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(lang.tr('rides.title')),
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
      body: ridesState.when(
        data: (rides) => _RidesList(rides: rides, lang: lang),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
            child: Text(lang.tr('error.generic', args: {'error': '$error'}))),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/rides/new'),
        icon: const Icon(Icons.add),
        label: Text(lang.tr('rides.new')),
      ),
    );
  }
}

class _RidesList extends StatelessWidget {
  const _RidesList({required this.rides, required this.lang});

  final List<entity_ride.Ride> rides;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    if (rides.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.directions_car_outlined,
                size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(lang.tr('rides.empty'),
                style: const TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        // Streams auto-update via provider
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: rides.length,
        itemBuilder: (context, index) {
          final ride = rides[index];
          return RideCard(ride: ride);
        },
      ),
    );
  }
}

class RideCard extends ConsumerWidget {
  const RideCard({super.key, required this.ride});

  final entity_ride.Ride ride;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final formattedAmount =
        LocalizedCurrency.formatWithSettings(ride.earnings, settings);

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
        title: Text(ride.platform),
        subtitle: Text(
          '${ride.formattedDate} • ${ride.durationMinutes}min • ${ride.distanceKm.toStringAsFixed(1)} km',
        ),
        trailing: Text(
          formattedAmount,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
        onTap: () => context.push('/rides/${ride.id}'),
      ),
    );
  }
}
