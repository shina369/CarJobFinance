// Ride Form Page - Criar/Editar corrida
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/finance/commission.dart';
import '../../../core/l10n/currency_provider.dart' as currency_pkg;
import '../../../core/l10n/language_provider.dart';
import '../../../core/l10n/platforms_provider.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/settings/app_settings_notifier.dart';
import '../../../core/settings/country_data.dart';
import '../../../core/settings/locale_helper.dart';
import '../../../data/datasources/local/app_database.dart'
    show OBSOLETE_PLATFORM_NAMES;
import '../../../presentation/controllers/controllers.dart';
import '../../../domain/entities/ride.dart' as entity_ride;

class RideFormPage extends ConsumerStatefulWidget {
  const RideFormPage({super.key, this.rideId});

  final String? rideId;

  bool get isEditing => rideId != null;

  @override
  ConsumerState<RideFormPage> createState() => _RideFormPageState();
}

class _RideFormPageState extends ConsumerState<RideFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();

  // Controllers
  final _dateController = TextEditingController();
  final _earningsController = TextEditingController();
  final _distanceController = TextEditingController();
  final _durationController = TextEditingController();
  final _originController = TextEditingController();
  final _destinationController = TextEditingController();

  // State
  String _selectedPlatform = '';
  String _selectedRideType = AppConstants.rideTypes.first;
  DateTime _selectedDate = DateTime.now();
  bool _platformInitialized = false;

  // Commission snapshot of the ride being edited. While the platform is
  // unchanged, the saved snapshot wins over the current platform config
  // so editing a ride never silently recalculates its commission.
  String _loadedPlatform = '';
  String? _loadedCommissionType;
  double? _loadedCommissionValue;

  @override
  void initState() {
    super.initState();
    _dateController.text = _formatDate(_selectedDate);
    if (widget.isEditing) {
      _loadExistingRide();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialize platform once, preferring the user's active list.
    if (!_platformInitialized) {
      final active = ref.read(activePlatformsProvider);
      final platforms =
          active.isNotEmpty ? active : ref.read(appSettingsProvider).platforms;
      if (platforms.isNotEmpty) {
        _selectedPlatform = platforms.first;
      } else {
        // Fallback to a sensible default if platforms list is somehow empty
        _selectedPlatform = 'Uber';
      }
      _platformInitialized = true;
    }
  }

  @override
  void dispose() {
    _dateController.dispose();
    _earningsController.dispose();
    _distanceController.dispose();
    _durationController.dispose();
    _originController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingRide() async {
    final ridesState = ref.read(ridesControllerProvider);
    if (ridesState is entity_ride.Ride) return;
    // Stream-based: watch and populate when ready
    ref.listen<AsyncValue<List<entity_ride.Ride>>>(
      ridesControllerProvider,
      (_, next) {
        next.whenData((rides) {
          final ride = rides.firstWhere(
            (r) => r.id == widget.rideId,
            orElse: () => throw Exception('Ride not found'),
          );
          setState(() {
            _selectedDate = ride.date;
            _dateController.text = _formatDate(ride.date);
            _earningsController.text = ride.earnings.toString();
            _distanceController.text = ride.distanceKm.toString();
            _durationController.text = ride.durationMinutes.toString();
            _originController.text = ride.origin ?? '';
            _destinationController.text = ride.destination ?? '';
            _selectedPlatform = ride.platform;
            _selectedRideType = ride.rideType;
            _loadedPlatform = ride.platform;
            _loadedCommissionType = ride.commissionType;
            _loadedCommissionValue = ride.commissionValue;
          });
        });
      },
    );
  }

  /// Commission config in effect for [platform]: the loaded snapshot when
  /// editing without changing the platform, the current platform config
  /// otherwise.
  (String?, double?) _commissionConfigFor(String platform) {
    if (widget.isEditing &&
        _loadedPlatform.isNotEmpty &&
        platform == _loadedPlatform) {
      return (_loadedCommissionType, _loadedCommissionValue);
    }
    final info = ref.read(platformsProvider).byName(platform);
    return (info?.commissionType, info?.commissionValue);
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

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDate),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          picked.hour,
          picked.minute,
        );
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final earnings =
        double.tryParse(_earningsController.text.replaceAll(',', '.')) ?? 0.0;
    final distance =
        double.tryParse(_distanceController.text.replaceAll(',', '.')) ?? 0.0;
    final duration = int.tryParse(_durationController.text) ?? 0;
    final (commissionType, commissionValue) =
        _commissionConfigFor(_selectedPlatform);

    final ride = entity_ride.Ride(
      id: widget.rideId ?? _uuid.v4(),
      date: _selectedDate,
      platform: _selectedPlatform,
      earnings: earnings,
      distanceKm: distance,
      durationMinutes: duration,
      origin: _originController.text.isEmpty ? null : _originController.text,
      destination: _destinationController.text.isEmpty
          ? null
          : _destinationController.text,
      rideType: _selectedRideType,
      commissionType: commissionType,
      commissionValue: commissionValue,
      commissionAmount:
          commissionAmountFor(earnings, commissionType, commissionValue),
      createdAt: widget.rideId != null ? null : DateTime.now(),
    );

    final controller = ref.read(ridesControllerProvider.notifier);
    if (widget.isEditing) {
      await controller.edit(ride);
    } else {
      await controller.add(ride);
    }

    if (mounted) context.pop();
  }

  Future<void> _delete() async {
    if (widget.rideId == null) return;
    final lang = ref.read(appLanguageProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(lang.tr('rides.deleteTitle')),
        content: Text(lang.tr('rides.deleteMsg')),
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
      await ref.read(ridesControllerProvider.notifier).remove(widget.rideId!);
      if (mounted) context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final lang = ref.watch(appLanguageProvider);
    final currency = ref.watch(currency_pkg.appCurrencyProvider);
    // Watched (not just read) so the commission summary reacts to config
    // changes made on the Platforms page.
    ref.watch(platformsProvider);
    final activePlatforms = ref.watch(activePlatformsProvider);
    // The Platforms page is the source of truth: only active platforms are
    // offered. While the active list hasn't loaded yet (or the user
    // deactivated everything), fall back to the built-in + DB-seeded lists
    // so the dropdown is never empty.
    final fallbackPlatforms = COUNTRIES
        .where((c) => c.code == settings.countryCode)
        .expand((c) => c.platforms)
        .toSet()
        .union(settings.platforms.toSet());
    final effectivePlatforms = (activePlatforms.isNotEmpty
            ? activePlatforms.toSet()
            : fallbackPlatforms)
        .where((p) => !OBSOLETE_PLATFORM_NAMES.contains(p))
        .toSet();
    if (widget.isEditing && _selectedPlatform.isNotEmpty) {
      // Keep the edited ride's platform selectable even if deactivated.
      effectivePlatforms.add(_selectedPlatform);
    } else if (effectivePlatforms.isNotEmpty &&
        !effectivePlatforms.contains(_selectedPlatform)) {
      _selectedPlatform = effectivePlatforms.first;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
            widget.isEditing ? lang.tr('rides.edit') : lang.tr('rides.new')),
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
            // Data e Hora
            _SectionTitle(lang.tr('rides.sectionDate')),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _dateController,
                    readOnly: true,
                    onTap: _pickDate,
                    decoration: InputDecoration(
                      labelText: lang.tr('rides.fieldData'),
                      prefixIcon: const Icon(Icons.calendar_today),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return lang.tr('rides.validateRequired',
                            args: {'field': lang.tr('rides.fieldData')});
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: TextEditingController(
                      text:
                          '${_selectedDate.hour.toString().padLeft(2, '0')}:${_selectedDate.minute.toString().padLeft(2, '0')}',
                    ),
                    readOnly: true,
                    onTap: _pickTime,
                    decoration: InputDecoration(
                      labelText: lang.tr('rides.fieldHora'),
                      prefixIcon: const Icon(Icons.access_time),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Plataforma
            _SectionTitle(lang.tr('rides.sectionPlatform')),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              // Recreate the field when the option list changes so the
              // selection never points at a removed item.
              key: ValueKey('platform-${effectivePlatforms.join('|')}'),
              initialValue: _selectedPlatform,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.apps),
              ),
              items: effectivePlatforms.map((platform) {
                return DropdownMenuItem(value: platform, child: Text(platform));
              }).toList(),
              onChanged: (value) {
                if (value != null) setState(() => _selectedPlatform = value);
              },
            ),
            const SizedBox(height: 24),

            // Tipo de Corrida
            _SectionTitle(lang.tr('rides.sectionType')),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedRideType,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.star_outline),
              ),
              items: AppConstants.rideTypes.map((type) {
                return DropdownMenuItem(value: type, child: Text(type));
              }).toList(),
              onChanged: (value) {
                if (value != null) setState(() => _selectedRideType = value);
              },
            ),
            const SizedBox(height: 24),

            // Ganhos
            _SectionTitle(lang.tr('rides.sectionEarnings')),
            const SizedBox(height: 8),
            TextFormField(
              controller: _earningsController,
              decoration: InputDecoration(
                labelText: lang.tr('rides.fieldEarnings'),
                prefixText: '${currency.symbol} ',
                prefixIcon: const Icon(Icons.attach_money),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return lang.tr('rides.validateRequired',
                      args: {'field': lang.tr('rides.fieldEarnings')});
                }
                if (double.tryParse(value.replaceAll(',', '.')) == null) {
                  return lang.tr('rides.validateInvalid',
                      args: {'field': lang.tr('rides.fieldEarnings')});
                }
                return null;
              },
            ),
            Builder(builder: (context) {
              final gross = double.tryParse(
                      _earningsController.text.replaceAll(',', '.')) ??
                  0.0;
              final (type, value) = _commissionConfigFor(_selectedPlatform);
              final commission = commissionAmountFor(gross, type, value);
              if (gross <= 0 || commission <= 0) {
                return const SizedBox.shrink();
              }
              String fmt(double v) => LocalizedCurrency.formatFor(v, currency);
              final style = Theme.of(context).textTheme.bodySmall;
              return Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(lang.tr('rides.grossValue'), style: style),
                          Text(fmt(gross), style: style),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(lang.tr('rides.commission'), style: style),
                          Text(
                            '- ${fmt(commission)}',
                            style: style?.copyWith(
                                color: Theme.of(context).colorScheme.error),
                          ),
                        ],
                      ),
                      const Divider(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            lang.tr('rides.netValue'),
                            style: style?.copyWith(
                                fontWeight: FontWeight.w700),
                          ),
                          Text(
                            fmt(gross - commission),
                            style: style?.copyWith(
                                fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 24),

            // Distância e Duração
            _SectionTitle(lang.tr('rides.sectionDistance')),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _distanceController,
                    decoration: InputDecoration(
                      labelText: lang.tr('rides.fieldKm'),
                      prefixIcon: const Icon(Icons.straighten),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value == null || value.isEmpty) return null;
                      final km = double.tryParse(value.replaceAll(',', '.'));
                      if (km == null || km > AppConstants.maxKmPerRide) {
                        return lang.tr('rides.validateInvalid',
                            args: {'field': lang.tr('rides.fieldKm')});
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _durationController,
                    decoration: InputDecoration(
                      labelText: lang.tr('rides.fieldMin'),
                      prefixIcon: const Icon(Icons.timer),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) return null;
                      if (int.tryParse(value) == null) {
                        return lang.tr('rides.validateInvalid',
                            args: {'field': lang.tr('rides.fieldMin')});
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Origem e Destino
            _SectionTitle(lang.tr('rides.sectionOrigDest')),
            const SizedBox(height: 8),
            TextFormField(
              controller: _originController,
              decoration: InputDecoration(
                labelText: lang.tr('rides.fieldOrigem'),
                prefixIcon: const Icon(Icons.my_location),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _destinationController,
              decoration: InputDecoration(
                labelText: lang.tr('rides.fieldDestino'),
                prefixIcon: const Icon(Icons.location_on),
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
                        ? lang.tr('rides.saveChanges')
                        : lang.tr('rides.saveRide')),
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
