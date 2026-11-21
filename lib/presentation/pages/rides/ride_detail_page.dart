import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/currency_provider.dart' as currency_pkg;
import '../../../core/l10n/language_provider.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/settings/locale_helper.dart';
import '../../../domain/entities/ride.dart' as entity_ride;
import '../../controllers/controllers.dart';

class RideDetailPage extends ConsumerWidget {
  const RideDetailPage({super.key, required this.rideId});

  final String rideId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appLanguageProvider);
    final ridesState = ref.watch(ridesControllerProvider);
    final ride = _findRide(ridesState.valueOrNull, rideId);

    return Scaffold(
      appBar: AppBar(
        title: Text(lang.tr('rides.details')),
        actions: [
          if (ride != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push('/rides/edit/${ride.id}'),
            ),
        ],
      ),
      body: ride != null
          ? _RideDetails(ride: ride)
          : ridesState.hasError
              ? Center(
                  child: Text(lang.tr('error.generic',
                      args: {'error': '${ridesState.error}'})),
                )
              : ridesState.hasValue
                  ? Center(child: Text(lang.tr('rides.empty')))
                  : const Center(child: CircularProgressIndicator()),
    );
  }

  static entity_ride.Ride? _findRide(List<entity_ride.Ride>? rides, String id) {
    for (final ride in rides ?? const <entity_ride.Ride>[]) {
      if (ride.id == id) return ride;
    }
    return null;
  }
}

class _RideDetails extends ConsumerWidget {
  const _RideDetails({required this.ride});

  final entity_ride.Ride ride;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appLanguageProvider);
    final currency = ref.watch(currency_pkg.appCurrencyProvider);
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    String money(double value) => LocalizedCurrency.formatFor(value, currency);

    final origin = ride.origin;
    final destination = ride.destination;
    final hasRoute = (origin != null && origin.isNotEmpty) ||
        (destination != null && destination.isNotEmpty);

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
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Icon(Icons.directions_car, color: primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(ride.platform,
                          style: theme.textTheme.titleLarge),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  money(ride.netEarnings),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(lang.tr('rides.netValue'),
                    style: theme.textTheme.bodyMedium),
                const SizedBox(height: 16),
                Text(
                  '${ride.formattedDate} • ${ride.formattedTime} • ${ride.rideType}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: lang.tr('rides.sectionEarnings'),
          children: [
            _DetailRow(
              label: lang.tr('rides.grossValue'),
              value: money(ride.earnings),
            ),
            if (ride.hasCommission)
              _DetailRow(
                label: lang.tr('rides.commission'),
                value: '− ${money(ride.commissionAmount)}',
                valueColor: theme.colorScheme.error,
              ),
            _DetailRow(
              label: lang.tr('rides.netValue'),
              value: money(ride.netEarnings),
              bold: true,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: lang.tr('rides.sectionDistance'),
          children: [
            _DetailRow(
              label: lang.tr('rides.fieldKm'),
              value: '${ride.distanceKm.toStringAsFixed(1)} km',
            ),
            _DetailRow(
              label: lang.tr('rides.fieldMin'),
              value: ride.formattedDuration,
            ),
          ],
        ),
        if (hasRoute) ...[
          const SizedBox(height: 16),
          _SectionCard(
            title: lang.tr('rides.sectionOrigDest'),
            children: [
              _DetailRow(
                label: lang.tr('rides.fieldOrigem'),
                value: origin ?? '—',
              ),
              _DetailRow(
                label: lang.tr('rides.fieldDestino'),
                value: destination ?? '—',
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(children: children),
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.bold = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: bold ? FontWeight.bold : FontWeight.w500,
          color: valueColor,
        );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(value, style: style, textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }
}
