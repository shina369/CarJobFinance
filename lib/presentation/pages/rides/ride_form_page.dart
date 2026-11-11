// Ride Form Page - Criar/Editar corrida
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/settings/app_settings_notifier.dart';
import '../../../core/settings/country_data.dart';
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
    // Initialize platform from settings once when dependencies change
    if (!_platformInitialized) {
      final settings = ref.read(appSettingsProvider);
      final platforms = settings.platforms;
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Corrida?'),
        content: const Text('Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
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
    final currencySymbol = settings.currencySymbol;
    final dbPlatforms = settings.platforms;

    // Platforms from COUNTRIES are the source of truth; the DB-seeded
    // (settings.platforms) list and the ride being edited are merged in so
    // nothing the user previously picked disappears from the dropdown.
    // Retired names (BlaBlaCar, Outro) are filtered out of the merge.
    final countryPlatforms = COUNTRIES
        .where((c) => c.code == settings.countryCode)
        .expand((c) => c.platforms)
        .toSet();
    final merged = countryPlatforms.union(dbPlatforms.toSet());
    final effectivePlatforms = merged
        .where((p) => !OBSOLETE_PLATFORM_NAMES.contains(p))
        .toSet()
      ..add(_selectedPlatform);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Editar Corrida' : 'Nova Corrida'),
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
            const _SectionTitle('Data e Hora'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
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
                    decoration: const InputDecoration(
                      labelText: 'Hora',
                      prefixIcon: Icon(Icons.access_time),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Plataforma
            const _SectionTitle('Plataforma'),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
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
            const _SectionTitle('Tipo de Corrida'),
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
            const _SectionTitle('Ganhos'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _earningsController,
              decoration: InputDecoration(
                labelText: 'Valor ganho',
                prefixText: '$currencySymbol ',
                prefixIcon: const Icon(Icons.attach_money),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
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

            // Distância e Duração
            const _SectionTitle('Distância e Duração'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _distanceController,
                    decoration: const InputDecoration(
                      labelText: 'Distância (km)',
                      prefixIcon: Icon(Icons.straighten),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value == null || value.isEmpty) return null;
                      final km = double.tryParse(value.replaceAll(',', '.'));
                      if (km == null || km > AppConstants.maxKmPerRide) {
                        return 'Distância inválida';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _durationController,
                    decoration: const InputDecoration(
                      labelText: 'Duração (min)',
                      prefixIcon: Icon(Icons.timer),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) return null;
                      if (int.tryParse(value) == null) {
                        return 'Duração inválida';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Origem e Destino
            const _SectionTitle('Origem e Destino (Opcional)'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _originController,
              decoration: const InputDecoration(
                labelText: 'Origem',
                prefixIcon: Icon(Icons.my_location),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _destinationController,
              decoration: const InputDecoration(
                labelText: 'Destino',
                prefixIcon: Icon(Icons.location_on),
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
                    child: Text(widget.isEditing
                        ? 'Salvar Alterações'
                        : 'Salvar Corrida'),
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
